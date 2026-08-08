--[[
    Bitirim — PREVIEW MANAGER (CANLI KARAKTER ONIZLEMESI, "Option A")
    ================================================================
    MIMARI (kullanici spec'i):
        GERCEK OYUNCU (mevcut appearance) ──► Gercek Player Ped  (DOKUNULMAZ)
                                          └──► Preview Clone Ped  (onizlemede)

    - Gercek oyuncu ped'i oyun dunyasinda KALIR: silinmez, teleport edilmez, FREEZE
      EDILMEZ, appearance'i degistirilmez, network state'i degismez. Temiz onizleme
      icin SADECE LOKAL gizlenir (SetEntityVisible/SetEntityLocallyInvisible) -> yalniz
      kendi ekranimizi etkiler, diger oyuncular gormeye devam eder.
    - Klon = oyuncunun O ANKI gorunumunun kopyasi; oyuncunun DURDUGU YERDE durur
      (havaya tasima YOK); arka planda gercek dunya DOF ile bulaniklastirilir.
    - GAMEPLAY kamerasi DEGISTIRILMEZ: envanter acilinca state'i (pos/rot/fov)
      kaydedilir; onizleme icin AYRI bir scripted preview-kamera kullanilir;
      envanter kapaninca gameplay kamerasina SMOOTH (interp) geri donulur ->
      oyuncu envanter oncesi hangi acidaysa oraya doner. Ani ziplama YOK.
    - Appearance senkron: tek kaynak = gercek ped. Item giyince/cikinca gercek
      ped'e uygulanir (mevcut equipment sistemi), klon ~150ms diff-loop ile
      AYNALANIR (sadece DEGISEN component/prop/silah yazilir). Ikinci skin YOK.
    - Kapaninca klon tamamen silinir (entity leak yok).

    EXPORT API (exports.ox_inventory:<fn>):
        CreatePreview() DestroyPreview() IsPreviewActive()
        UpdateComponent(c,d,t,p) UpdateProp(p,d,t) UpdateWeapon(hash)
        UpdateOutfit() SyncFromPlayer() RotatePreview(mode,val) SetCamera(cfg)
]]

------------------------------------------------------------------------------
-- YAPILANDIRMA
------------------------------------------------------------------------------
-- Klon SAHNESI: klon oyuncunun TAM durdugu yerde olusturulur (havaya/6m yukari
-- TASIMA YOK). Gercek oyuncu ile cakisma, gercek ped'in SADECE LOKAL gizlenmesiyle
-- onlenir (dunya/network/pozisyon/appearance DOKUNULMAZ). Preview kamera SADECE
-- klonu cercever; arka planda GERCEK DUNYA gorunur, DOF ile bulaniklastirilir.
local TRANSITION_MS = 550   -- gameplay <-> preview kamera SMOOTH gecis suresi (ms)
local FIXED_DIR    = 180.0  -- preview kamera referans yonu (ped bu yone bakinca on).

-- Preview kamera kompozisyonu (dialed). SetCamera ile degistirilebilir.
local cam_cfg = {
    dist = 3.55, height = 0.20, side = -0.98, fov = 44.0, lookz = -0.05, zoom = 1.0,
}

-- DOF (Depth of Field) — referans gorunum: KLON net (odakta), ARKA PLAN bulanik.
-- near/far = net kalan derinlik araligi (klonun mesafesi ~cam_cfg.dist icine alinir);
-- strength = bulaniklik siddeti. /cam near|far|strength ile in-game dial edilir.
local dof_cfg = { near = 2.6, far = 5.0, strength = 1.0 }

-- Idle (klon donuk gorunmesin: yerinde nefes/kucuk salinim). Cinsiyete gore.
local IDLE_M = { dict = 'anim@heists@heist_corona@team_idles@male_a',   anim = 'idle' }
local IDLE_F = { dict = 'anim@heists@heist_corona@team_idles@female_a', anim = 'idle' }

-- Aynalanan ped bilesenleri / proplari (illenium + GTA standart).
local COMPONENTS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS      = { 0, 1, 2, 6, 7 }
local UNARMED    = `WEAPON_UNARMED`

------------------------------------------------------------------------------
-- DURUM
------------------------------------------------------------------------------
local active      = false
local previewPed  = nil
local cam         = nil
local realPed     = nil     -- SADECE referans (aynalama icin); DOKUNULMAZ
local heading     = FIXED_DIR
local compCache   = {}      -- aynalama diff onbellegi
local curWeapon   = nil
-- Gameplay kamera state'i (kayit; RenderScriptCams(false, interp) ile geri yuklenir).
local savedCamCoord, savedCamRot, savedCamFov = nil, nil, nil

------------------------------------------------------------------------------
-- PREVIEW KAMERA (klon icin; gameplay kamerasindan BAGIMSIZ)
------------------------------------------------------------------------------
--- Preview kamerayi klonun onune yerlestir (ped char-view'de SOLA gelir: side).
--- Klonu dondurmek (RotatePreview) gorsel donme yapar; kamera cerceve degismez.
local function positionCamera()
    if not cam or not previewPed or not DoesEntityExist(previewPed) then return end
    local cc = GetEntityCoords(previewPed)
    local cx, cy, cz = cc.x, cc.y, cc.z
    local h = math.rad(FIXED_DIR)
    local fx, fy = -math.sin(h), math.cos(h)   -- referans on (kamera bu yonde)
    local rx, ry = math.cos(h), math.sin(h)    -- saga vektor
    local dist = cam_cfg.dist / (cam_cfg.zoom > 0 and cam_cfg.zoom or 1.0)
    SetCamCoord(cam, cx + fx * dist, cy + fy * dist, cz + cam_cfg.height)
    PointCamAtCoord(cam, cx + rx * cam_cfg.side, cy + ry * cam_cfg.side, cz + cam_cfg.lookz)
    SetCamFov(cam, cam_cfg.fov)
end

--- DOF'u uygula: sig-DOF modu + klonun mesafesine gore net araligi. Arka plan
--- (bina/sokak) bulanik, klon net. Render loop'ta SetUseHiDof() ile pekistirir.
local function applyDof()
    if not cam or not DoesCamExist(cam) then return end
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, dof_cfg.near)
    SetCamFarDof(cam, dof_cfg.far)
    SetCamDofStrength(cam, dof_cfg.strength)
end

------------------------------------------------------------------------------
-- IDLE + CANLI AYNALAMA
------------------------------------------------------------------------------
local function playIdle()
    if not previewPed or not DoesEntityExist(previewPed) then return end
    local a = (GetEntityModel(previewPed) == `mp_f_freemode_01`) and IDLE_F or IDLE_M
    RequestAnimDict(a.dict)
    local t = 0
    while not HasAnimDictLoaded(a.dict) and t < 50 do Wait(10); t = t + 1 end
    if HasAnimDictLoaded(a.dict) then
        TaskPlayAnim(previewPed, a.dict, a.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

--- Bilesen + prop diff: gercek ped -> klon. Sadece DEGISEN slot yazilir (perf).
local function mirrorAppearance()
    if not previewPed or not DoesEntityExist(previewPed) or not realPed or not DoesEntityExist(realPed) then return end
    for i = 1, #COMPONENTS do
        local c = COMPONENTS[i]
        local d, tx, pl = GetPedDrawableVariation(realPed, c), GetPedTextureVariation(realPed, c), GetPedPaletteVariation(realPed, c)
        local key = d .. ':' .. tx .. ':' .. pl
        if compCache['c' .. c] ~= key then
            SetPedComponentVariation(previewPed, c, d, tx, pl)
            compCache['c' .. c] = key
        end
    end
    for i = 1, #PROPS do
        local p = PROPS[i]
        local d, tx = GetPedPropIndex(realPed, p), GetPedPropTextureIndex(realPed, p)
        local key = d .. ':' .. tx
        if compCache['p' .. p] ~= key then
            if d < 0 then ClearPedProp(previewPed, p) else SetPedPropIndex(previewPed, p, d, tx, true) end
            compCache['p' .. p] = key
        end
    end
end

--- Silah aynalama: gercek ped'in secili silahi -> klon (elinde gorunur).
local function mirrorWeapon(force)
    if not previewPed or not DoesEntityExist(previewPed) or not realPed or not DoesEntityExist(realPed) then return end
    local w = GetSelectedPedWeapon(realPed)
    if not force and w == curWeapon then return end
    curWeapon = w
    pcall(function()
        RemoveAllPedWeapons(previewPed, true)
        if w and w ~= UNARMED and w ~= 0 and w ~= -1 then
            RequestWeaponAsset(w, 31, 0)
            local t = 0
            while not HasWeaponAssetLoaded(w) and t < 50 do Wait(10); t = t + 1 end
            GiveWeaponToPed(previewPed, w, 1000, false, true)
            SetCurrentPedWeapon(previewPed, w, true)
        end
    end)
end

------------------------------------------------------------------------------
-- YASAM DONGUSU
------------------------------------------------------------------------------
local function CreatePreview()
    if active then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    realPed = ped -- referans (aynalama) + SADECE LOKAL gizlenir; silme/freeze/tp/network YOK

    -- 1) GAMEPLAY kamera state'ini KAYDET (kapanista geri yuklenir).
    savedCamCoord = GetGameplayCamCoord()
    savedCamRot   = GetGameplayCamRot(2)
    savedCamFov   = GetGameplayCamFov()

    -- 2) Klon = oyuncunun O ANKI gorunumu (component/prop/head-blend/tattoo kopya).
    previewPed = ClonePed(ped, GetEntityHeading(ped), true, true)
    if not previewPed or previewPed == 0 or not DoesEntityExist(previewPed) then
        print('^1[bitirim] PreviewManager: ClonePed BASARISIZ^7')
        previewPed = nil
        return
    end
    pcall(ClonePedToTarget, ped, previewPed)
    SetEntityAsMissionEntity(previewPed, true, true) -- guvenli DeletePed

    -- 2b) GERCEK ped'i SADECE LOKAL gizle -> klon ile cakismasin. Bu sadece kendi
    --     ekranimizi etkiler: entity silinmez/teleport/freeze YOK, diger oyuncular
    --     ve network state DEGISMEZ. Kapanista (klon silindikten sonra) geri acilir.
    SetEntityVisible(ped, false, false)

    -- 3) KLON oyuncunun TAM konumunda kalir (havaya/6m yukari TASIMA YOK) -> arka
    --    planda gercek dunya gorunur; kamera DOF ile arkasini bulaniklastirir.
    local pos = GetEntityCoords(ped)
    local sx, sy, sz = pos.x, pos.y, pos.z
    SetEntityCoordsNoOffset(previewPed, sx, sy, sz, false, false, false)
    FreezeEntityPosition(previewPed, true)  -- KLON freeze (oyuncu DEGIL)
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityLodDist(previewPed, 1000)
    heading = FIXED_DIR
    SetEntityHeading(previewPed, heading)
    RequestCollisionAtCoord(sx, sy, sz)
    SetFocusPosAndVel(sx, sy, sz, 0.0, 0.0, 0.0)

    -- 4) AYRI scripted preview kamera (SADECE klonu cercever). Gameplay kamerasindan
    --    SMOOTH interpolate ile devralinir (RenderScriptCams ease=true) -> ziplama yok.
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    positionCamera()
    applyDof()               -- referans gorunum: klon net, arka plan bulanik (DOF)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, TRANSITION_MS, true, true) -- gameplay -> preview (smooth)

    active = true
    compCache = {}
    curWeapon = nil
    playIdle()
    mirrorWeapon(true)

    -- RENDER thread: (a) gercek ped'i her kare LOKAL gizli tut (SetEntityVisible
    -- bazi durumlarda geri acilabilir; garanti icin pekistir), (b) ox screenblur'u
    -- kapat (klon net kalsin), (c) SetUseHiDof ile yuksek kaliteli DOF'u zorla
    -- (arka plan bulanik). Minimal, sadece onizleme acikken.
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            if realPed and DoesEntityExist(realPed) then SetEntityLocallyInvisible(realPed) end
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
            TriggerScreenblurFadeOut(0.0)
            SetUseHiDof()
            Wait(0)
        end
    end)

    -- MIRROR thread (~150ms): gercek ped -> klon canli aynalama (incremental).
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            mirrorAppearance()
            mirrorWeapon(false)
            Wait(150)
        end
    end)
end

local function DestroyPreview()
    if not active then return end
    active = false -- thread'ler cikar

    -- SMOOTH geri donus: preview kamerasindan GAMEPLAY kamerasina interpolate.
    -- Gameplay kamerasi hic DEGISTIRILMEDI -> onceki pos/rot/fov'una doner.
    RenderScriptCams(false, true, TRANSITION_MS, true, true)

    -- Klon + kamera GECIS BITINCE temizlenir (klon gecis boyunca gorunur kalsin).
    -- Gercek ped'in LOKAL gorunurlugu, KLON silindikten SONRA geri verilir ->
    -- gecis boyunca gercek ped ile klon cakismaz (temiz swap).
    local doomedCam, doomedPed, doomedReal = cam, previewPed, realPed
    cam, previewPed = nil, nil
    CreateThread(function()
        Wait(TRANSITION_MS + 80)
        if doomedCam and DoesCamExist(doomedCam) then DestroyCam(doomedCam, false) end
        if doomedPed and DoesEntityExist(doomedPed) then
            SetEntityAsMissionEntity(doomedPed, true, true)
            DeletePed(doomedPed)
        end
        if doomedReal and DoesEntityExist(doomedReal) then
            SetEntityVisible(doomedReal, true, false) -- LOKAL gorunurlugu geri ver
        end
        ClearFocus()
    end)

    realPed = nil -- artik dongulerde referans verilmesin (gorunurluk yukarida geri alinir)
    compCache = {}
    curWeapon = nil
    heading = FIXED_DIR
end

------------------------------------------------------------------------------
-- INCREMENTAL GUNCELLEME API (sadece DEGISENI yaz)
------------------------------------------------------------------------------
local function UpdateComponent(componentId, drawable, texture, palette)
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    SetPedComponentVariation(previewPed, componentId, drawable, texture or 0, palette or 0)
    compCache['c' .. componentId] = drawable .. ':' .. (texture or 0) .. ':' .. (palette or 0)
end

local function UpdateProp(propId, drawable, texture)
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    if drawable == nil or drawable < 0 then
        ClearPedProp(previewPed, propId)
        compCache['p' .. propId] = '-1:0'
    else
        SetPedPropIndex(previewPed, propId, drawable, texture or 0, true)
        compCache['p' .. propId] = drawable .. ':' .. (texture or 0)
    end
end

local function UpdateWeapon(weaponHash)
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    pcall(function()
        RemoveAllPedWeapons(previewPed, true)
        if weaponHash and weaponHash ~= UNARMED and weaponHash ~= 0 and weaponHash ~= -1 then
            if type(weaponHash) == 'string' then weaponHash = GetHashKey(weaponHash) end
            RequestWeaponAsset(weaponHash, 31, 0)
            local t = 0
            while not HasWeaponAssetLoaded(weaponHash) and t < 50 do Wait(10); t = t + 1 end
            GiveWeaponToPed(previewPed, weaponHash, 1000, false, true)
            SetCurrentPedWeapon(previewPed, weaponHash, true)
        end
        curWeapon = weaponHash
    end)
end

--- Tam yeniden esitle (gercek ped -> klon). Berber/estetik/magaza sonrasi cagir.
local function UpdateOutfit()
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    pcall(ClonePedToTarget, realPed, previewPed)
    compCache = {}
    mirrorAppearance()
    mirrorWeapon(true)
end

--- Disaridan cagrilabilen genel aynalama (bilesen+prop+silah).
local function SyncFromPlayer()
    mirrorAppearance()
    mirrorWeapon(false)
end

------------------------------------------------------------------------------
-- DONME / KAMERA API
------------------------------------------------------------------------------
local function RotatePreview(mode, value)
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    if mode == 'left' then
        heading = (heading - 45.0) % 360.0
    elseif mode == 'right' then
        heading = (heading + 45.0) % 360.0
    elseif mode == 'drag' then
        heading = (heading + (tonumber(value) or 0.0) * 0.4) % 360.0
    elseif mode == 'reset' then
        heading = FIXED_DIR
    end
    SetEntityHeading(previewPed, heading)
end

local function SetCamera(cfg)
    if type(cfg) ~= 'table' then return end
    if cfg.dist   then cam_cfg.dist   = cfg.dist   + 0.0 end
    if cfg.height then cam_cfg.height = cfg.height + 0.0 end
    if cfg.side   then cam_cfg.side   = cfg.side   + 0.0 end
    if cfg.fov    then cam_cfg.fov    = cfg.fov    + 0.0 end
    if cfg.lookz  then cam_cfg.lookz  = cfg.lookz  + 0.0 end
    if cfg.zoom   then cam_cfg.zoom   = math.max(0.4, cfg.zoom + 0.0) end
    -- DOF (arka plan bulanikligi) tunable'lari.
    if cfg.near     then dof_cfg.near     = math.max(0.0, cfg.near + 0.0) end
    if cfg.far      then dof_cfg.far      = math.max(0.1, cfg.far  + 0.0) end
    if cfg.strength then dof_cfg.strength = math.max(0.0, cfg.strength + 0.0) end
    positionCamera()
    applyDof()
end

local function IsPreviewActive() return active end

------------------------------------------------------------------------------
-- EXPORT'LAR (tek iletisim yolu)
------------------------------------------------------------------------------
exports('CreatePreview',   CreatePreview)
exports('DestroyPreview',  DestroyPreview)
exports('IsPreviewActive', IsPreviewActive)
exports('UpdateComponent', UpdateComponent)
exports('UpdateProp',      UpdateProp)
exports('UpdateWeapon',    UpdateWeapon)
exports('UpdateOutfit',    UpdateOutfit)
exports('SyncFromPlayer',  SyncFromPlayer)
exports('RotatePreview',   RotatePreview)
exports('SetCamera',       SetCamera)

-- Emniyet: kaynak durursa temizle.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then DestroyPreview() end
end)
