--[[
    Bitirim — PREVIEW MANAGER (STATIK KARAKTER ONIZLEMESI, "Sabit Kamera")
    =====================================================================
    YENI MIMARI (kullanici spec'i — 2026-08-08):
        GERCEK OYUNCU (mevcut appearance) ──► Gercek Player Ped  (LOKAL gizli)
                                          └──► Preview Clone Ped  (onizlemede)

    EN ONEMLI KURAL: GAMEPLAY KAMERASINA HIC DOKUNULMAZ.
    - Scripted kamera OLUSTURULMAZ, RenderScriptCams CAGRILMAZ, FOV/rot/pos/focus
      DEGISTIRILMEZ. Envanter acilinca oyuncu hangi acidan bakiyorsa oyle kalir;
      kapaninca da ayni. Kamera restore'a bile gerek yok (hic degismedi).
    - Klon, SABIT gameplay kamerasinin ONUNE yerlestirilir (kamerayi okuruz,
      DEGISTIRMEYIZ): cam-onu * dist + yatay/dikey ofset -> char-view deligine
      girer. Klon kameraya bakar (heading = camYaw+180). 6m/havaya TASIMA YOK.
    - ARKA PLAN: NUI (.bx-scrim) tum oyun dunyasini OPAK SIYAH ile kapatir; sadece
      char-view'de clip-path DELIK vardir. Deligin arkasinda dunya gorunmesin diye
      klonun HEMEN ARKASINA koyu bir BACKDROP objesi konur -> klon koyu zemin uzerinde.
      DOF/blur KULLANILMAZ.
    - Appearance senkron: tek kaynak = gercek ped. ~150ms diff-loop ile klona
      AYNALANIR (sadece DEGISEN component/prop/silah). Movement/anim AYNALANMAZ.
    - Kapaninca klon + backdrop silinir, gercek ped lokal gorunur olur.

    EXPORT API (exports.ox_inventory:<fn>):
        CreatePreview() DestroyPreview() IsPreviewActive()
        UpdateComponent(c,d,t,p) UpdateProp(p,d,t) UpdateWeapon(hash)
        UpdateOutfit() SyncFromPlayer() RotatePreview(mode,val) SetCamera(cfg)
]]

------------------------------------------------------------------------------
-- YAPILANDIRMA (hepsi /cam ile in-game dial edilir)
------------------------------------------------------------------------------
local FIXED_DIR = 180.0   -- klonun kameraya karsi referans yonu (reset icin)

-- Klon YERLESIMI (gameplay kamerasina GORE; kamera-uzayinda ofsetler) + BACKDROP.
local cfg = {
    dist = 3.4,    -- klon kameranin kac metre ONUNDE (tam boy sigsin)
    side = -0.30,  -- YATAY ofset (char-view sol kolon -> ekranda sola)
    down = -0.70,  -- DIKEY ofset (ayak-bas kadraja ortalansin; feet asagi)
    bdist = 1.0,   -- BACKDROP klonun kac metre ARKASINDA (kameradan daha uzak)
    bz    = 1.0,   -- BACKDROP dikey merkez (klon govdesi; ayak+bz)
    bhead = 0.0,   -- BACKDROP aci ofseti (camYaw + bhead)
    -- BACKDROP KAPALI (kullanici istegi): konteyner cok buyuk olup kamerayi iceri
    -- aliyordu -> "demir cubuk" gibi bozuk render. Klon artik gercek dunya onunde
    -- gorunur (kenarlar zaten siyah overlay). /cam bmodel <prop> ile tekrar acilir.
    bmodel = false,
}

-- Idle (klon temiz durus, mid-run donma olmasin). Cinsiyete gore.
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
local backdrop    = nil     -- koyu arka plan objesi (klonun arkasinda)
local bdropCx, bdropCy, bdropCz = 0.0, 0.0, 0.0  -- backdrop origin->merkez ofseti (3D ortalama)
local realPed     = nil     -- referans (aynalama) + LOKAL gizlenir
local dragYaw     = 0.0     -- kullanici surukleme/donme ofseti
local compCache   = {}      -- aynalama diff onbellegi
local curWeapon   = nil

------------------------------------------------------------------------------
-- VEKTOR YARDIMCILARI + KAMERA TABANI (SADECE OKUR)
------------------------------------------------------------------------------
local function crossv(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end
local function normv(v)
    local m = #v
    if m > 0.0001 then return v / m end
    return v
end

--- Gameplay kamerasinin (DOKUNULMADAN okunan) pos + forward/right/up + yaw'i.
local function camBasis()
    local rot = GetGameplayCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local cx = math.cos(xr)
    local forward = vector3(-math.sin(zr) * cx, math.cos(zr) * cx, math.sin(xr))
    local right = normv(crossv(forward, vector3(0.0, 0.0, 1.0)))
    local up = crossv(right, forward)
    return GetGameplayCamCoord(), forward, right, up, rot.z
end

--- Klonu (ve backdrop'i) SABIT gameplay kamerasinin onune yerlestir. Kamera
--- DEGISTIRILMEZ; sadece okunur. Her karede cagrilir (kamera oynasa bile klon
--- char-view deliginde kalir; NUI focus'ta kamera zaten sabittir).
local function positionScene()
    if not previewPed or not DoesEntityExist(previewPed) then return end
    local camPos, f, r, u, camYaw = camBasis()
    local base = camPos + f * cfg.dist + r * cfg.side + u * cfg.down
    SetEntityCoordsNoOffset(previewPed, base.x, base.y, base.z, false, false, false)
    SetEntityHeading(previewPed, (camYaw + 180.0 + dragYaw) % 360.0) -- kameraya bak + surukleme
    if backdrop and DoesEntityExist(backdrop) then
        -- Klonun HEMEN arkasina, GOVDE ortasina TAM HIZALI. Modelin origin'i nerede
        -- olursa olsun (konteyner gibi kosede olabilir) modelin 3D MERKEZINI hedef
        -- noktaya oturturuz: yatay merkez ofseti heading ile dondurulup cikarilir,
        -- dikey merkez z'den cikarilir -> klonu tam ortar, arkadaki dunya sizmaz.
        local bh = (camYaw + cfg.bhead) % 360.0
        local hr = math.rad(bh)
        local rx = bdropCx * math.cos(hr) - bdropCy * math.sin(hr)
        local ry = bdropCx * math.sin(hr) + bdropCy * math.cos(hr)
        local px = base.x + f.x * cfg.bdist
        local py = base.y + f.y * cfg.bdist
        SetEntityCoordsNoOffset(backdrop, px - rx, py - ry, base.z + cfg.bz - bdropCz, false, false, false)
        SetEntityHeading(backdrop, bh)
    end
end

------------------------------------------------------------------------------
-- IDLE + CANLI AYNALAMA (SADECE APPEARANCE; MOVEMENT DEGIL)
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
-- BACKDROP (koyu arka plan objesi — klonun arkasinda)
------------------------------------------------------------------------------
local function loadModel(m)
    local h = (type(m) == 'number') and m or GetHashKey(m)
    RequestModel(h)
    local t = 0
    while not HasModelLoaded(h) and t < 100 do Wait(10); t = t + 1 end
    return HasModelLoaded(h) and h or nil
end

local function spawnBackdrop()
    if backdrop and DoesEntityExist(backdrop) then return end
    if not cfg.bmodel or cfg.bmodel == '' then return end -- backdrop KAPALI -> klon dunyada
    local mh = loadModel(cfg.bmodel)
    if not mh then return end -- model yuklenmezse backdrop atlanir (klon dunyada gorunur)
    -- Modelin origin->3D merkez ofseti (ortalama icin; her prop'ta origin farkli).
    local mn, mx = GetModelDimensions(mh)
    bdropCx = (mn.x + mx.x) * 0.5
    bdropCy = (mn.y + mx.y) * 0.5
    bdropCz = (mn.z + mx.z) * 0.5
    local camPos, f = camBasis()
    local b = camPos + f * (cfg.dist + cfg.bdist)
    backdrop = CreateObject(mh, b.x, b.y, b.z, false, false, false)
    SetModelAsNoLongerNeeded(mh)
    if backdrop and DoesEntityExist(backdrop) then
        SetEntityCollision(backdrop, false, false)
        FreezeEntityPosition(backdrop, true)
        SetEntityInvincible(backdrop, true)
        SetEntityLodDist(backdrop, 1000)
    end
end

------------------------------------------------------------------------------
-- YASAM DONGUSU
------------------------------------------------------------------------------
local function CreatePreview()
    if active then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    realPed = ped -- referans (aynalama) + LOKAL gizlenir; dunya/network DOKUNULMAZ

    -- 1) GERCEK ped'i SADECE LOKAL gizle (klon ile cakismasin). Kapanista geri acilir.
    SetEntityVisible(ped, false, false)

    -- 2) Klon = oyuncunun O ANKI gorunumu (component/prop/head-blend/tattoo kopya).
    previewPed = ClonePed(ped, GetEntityHeading(ped), true, true)
    if not previewPed or previewPed == 0 or not DoesEntityExist(previewPed) then
        print('^1[bitirim] PreviewManager: ClonePed BASARISIZ^7')
        previewPed = nil
        SetEntityVisible(ped, true, false)
        return
    end
    pcall(ClonePedToTarget, ped, previewPed)
    SetEntityAsMissionEntity(previewPed, true, true) -- guvenli DeletePed
    FreezeEntityPosition(previewPed, true)  -- KLON statik (movement YOK)
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityLodDist(previewPed, 1000)

    -- 3) BACKDROP (koyu arka plan) + ilk yerlesim. GAMEPLAY KAMERASINA DOKUNULMAZ.
    active = true
    dragYaw = 0.0
    spawnBackdrop()
    positionScene()
    local camPos = GetGameplayCamCoord()
    SetFocusPosAndVel(camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0) -- sahne texture'lari otursun

    compCache = {}
    curWeapon = nil
    playIdle()
    mirrorWeapon(true)

    -- RENDER thread (Wait 0): (a) klonu+backdrop'i sabit kameranin onunde tut,
    -- (b) gercek ped'i lokal gizli tut, (c) ox screenblur'u kapat (klon net).
    -- KAMERA/DOF'a DOKUNULMAZ.
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            positionScene()
            if realPed and DoesEntityExist(realPed) then SetEntityLocallyInvisible(realPed) end
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
            TriggerScreenblurFadeOut(0.0)
            Wait(0)
        end
    end)

    -- MIRROR thread (~150ms): gercek ped -> klon appearance aynalama (movement DEGIL).
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

    if backdrop and DoesEntityExist(backdrop) then
        SetEntityAsMissionEntity(backdrop, true, true)
        DeleteObject(backdrop)
    end
    backdrop = nil

    if previewPed and DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed, true, true)
        DeletePed(previewPed)
    end
    previewPed = nil

    if realPed and DoesEntityExist(realPed) then
        SetEntityVisible(realPed, true, false) -- LOKAL gorunurlugu geri ver
    end
    realPed = nil

    ClearFocus()
    compCache = {}
    curWeapon = nil
    dragYaw = 0.0
    -- Kamera restore YOK: gameplay kamerasi hic degistirilmedi.
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
-- DONME / YERLESIM API
------------------------------------------------------------------------------
--- Klonu dondur (kendi ekseninde) — kamera DEGISMEZ, sadece klon heading ofseti.
local function RotatePreview(mode, value)
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    if mode == 'left' then
        dragYaw = (dragYaw - 45.0) % 360.0
    elseif mode == 'right' then
        dragYaw = (dragYaw + 45.0) % 360.0
    elseif mode == 'drag' then
        dragYaw = (dragYaw + (tonumber(value) or 0.0) * 0.4) % 360.0
    elseif mode == 'reset' then
        dragYaw = 0.0
    end
    positionScene()
end

--- Klon yerlesimi + backdrop ayari (KAMERA DEGISMEZ). /cam ile dial edilir.
local function SetCamera(cfgIn)
    if type(cfgIn) ~= 'table' then return end
    if cfgIn.bmodel then
        cfg.bmodel = cfgIn.bmodel
        if active then -- backdrop'i yeni modelle yeniden olustur
            if backdrop and DoesEntityExist(backdrop) then
                SetEntityAsMissionEntity(backdrop, true, true); DeleteObject(backdrop)
            end
            backdrop = nil
            spawnBackdrop()
        end
    end
    if cfgIn.dist  then cfg.dist  = cfgIn.dist  + 0.0 end
    if cfgIn.side  then cfg.side  = cfgIn.side  + 0.0 end
    if cfgIn.down  then cfg.down  = cfgIn.down  + 0.0 end
    if cfgIn.bdist then cfg.bdist = cfgIn.bdist + 0.0 end
    if cfgIn.bz    then cfg.bz    = cfgIn.bz    + 0.0 end
    if cfgIn.bhead then cfg.bhead = cfgIn.bhead + 0.0 end
    positionScene()
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
