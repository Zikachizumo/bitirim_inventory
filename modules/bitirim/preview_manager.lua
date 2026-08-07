--[[
    Bitirim — PREVIEW MANAGER (yeniden kullanilabilir CANLI KARAKTER ONIZLEMESI)
    ===========================================================================
    TEK ekipman/skin sistemi. Onizleme = GERCEK oyuncuyu AYNALAYAN gecici bir
    "Preview Ped" (klon). Tek dogruluk kaynagi = oyuncunun gercek ped'i.

        Player Ped  ->  Clone Preview Ped  ->  Inventory Camera

    Bu modul SADECE bir API sunar; baska kaynaklar (envanter, kiyafet magazasi,
    berber, estetik, karakter olusturucu, kiyafet sistemi) YALNIZCA bu export'lar
    uzerinden konusur. Ikinci bir skin/appearance sistemi YOK.

    EXPORT API (exports.ox_inventory:<fn>):
        CreatePreview(opts)      klon + kamera + idle -> sahneyi ac
        DestroyPreview()         her seyi temizle (ped/cam/render)
        IsPreviewActive()        -> bool
        UpdateComponent(c,d,t,p) tek bilesen (kiyafet) guncelle
        UpdateProp(p,d,t)        tek prop (sapka/gozluk...) guncelle (d<0 => temizle)
        UpdateWeapon(hash)       preview silahini ayarla (nil/unarmed => kaldir)
        UpdateOutfit()           gercek ped'ten TAM yeniden esitle (bilesen+prop)
        RotatePreview(mode,val)  'left'|'right'|'drag'|'reset'
        SetCamera(cfg)           kamera kompozisyonu (dist/height/side/fov/lookz/zoom)
        SyncFromPlayer()         gercek ped -> preview canli aynalama (bilesen+prop+silah)

    PERFORMANS: Sistem YALNIZCA onizleme acikken calisir. 2 hafif thread (render +
    ~150ms mirror). Kapaninca her sey silinir; kapaliyken ~0 maliyet. Klon BIR KEZ
    yaratilir; sadece DEGISEN sey guncellenir.
]]

------------------------------------------------------------------------------
-- YAPILANDIRMA (SetCamera ile calisirken degistirilebilir)
------------------------------------------------------------------------------
-- Dedike onizleme sahnesi: YUKSEK irtifa void -> ped'in arkasi (yatay bakis)
-- karanlik gokyuzu; sehir/isik kalabaligi karede degil. Gece override karartir.
local SCENE      = vector3(1000.0, -2000.0, 1400.0)
local NIGHT_HOUR = 1        -- gece saati (0-4 en koyu). Her kare uygulanir (senkronu yener)
local FIXED_DIR  = 180.0    -- kamera SABIT referans yonu (ped bu yone bakinca on-goruntu).
                            -- Klon heading'i degisince ped GORSEL doner (kamera sabit).

-- Kamera kompozisyonu (AAA: tam vucut, hafif yuksek, 35-45 FOV, ortali).
local cam_cfg = {
    dist   = 3.55,   -- ped uzakligi (buyuk = kucuk/uzak)
    height = 0.20,   -- kamera yuksekligi (hafif yukaridan)
    side   = -0.98,  -- yatay: ped'i karede SOLA al (bakis hedefi kaydir)
    fov    = 44.0,   -- 35-45 arasi
    lookz  = -0.05,  -- bakis hedefi yuksekligi
    zoom   = 1.0,    -- ileride kolay zoom: dist / zoom (buyuk = yakin)
}

-- STUDYO ISIK: KEY = kameradan beyaz on dolgu (ped parlak/net). Menzil KISA ->
-- backdrop'a tasmaz (backdrop KOYU kalir -> gercek dunya kapanir; renkli glow'u
-- CSS veriyor, referans 1.jpg gibi). Seviye-renkli arka aura CSS'te (bag rengi).
local KEY_INT, KEY_RANGE, KEY_ZOFF = 2.4, 3.6, 0.35

-- BACKDROP: ped'in ARKASINA konan KOYU prop -> gercek dunyayi (gece sehir) kapatir.
-- ISIKLANDIRILMAZ (KEY menzili kisa) -> karanlikta dokusu gorunmez, temiz koyu zemin.
-- Renkli glow/gradyan CSS'ten gelir (.bx-char-view). /cam bdist/bzoff/bhead/bmodel.
local BACKDROP_MODEL   = `prop_container_01a`
local BACKDROP_DIST    = 1.4   -- ped'in ARKASINA (kameradan uzak) uzaklik (yakin=buyuk)
local BACKDROP_ZOFF    = 0.2   -- dikey kaydirma (kareyi doldur)
local BACKDROP_HEADOFF = 90.0  -- duz yuzu kameraya cevir

-- Idle animasyonlari (cinsiyete gore). Donuk gorunmesin: nefes/kucuk salinim.
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
local backdrop    = nil     -- koyu arka plan prop'u (gercek dunyayi kapatir)
local cam         = nil
local realPed     = nil
local heading     = FIXED_DIR
local compCache   = {}     -- aynalama diff onbellegi
local curWeapon   = nil
-- NOT: seviye-renkli arka glow artik CSS'te (.bx-char-view, --accent bag rengini
-- alir). Bu yuzden Lua'da seviye/RIM takibi YOK.

------------------------------------------------------------------------------
-- BACKDROP (koyu okluder — gercek dunyayi kapatir)
------------------------------------------------------------------------------
--- Backdrop'u ped'in ARKASINA (kameraya gore) sabit yerlestir. Kamera SABIT
--- yonde oldugu icin backdrop da FIXED_DIR'e gore konur (ped donse de arkada kalir).
local function positionBackdrop()
    if not backdrop or not DoesEntityExist(backdrop) or not previewPed or not DoesEntityExist(previewPed) then return end
    local cc = GetEntityCoords(previewPed)
    local h = math.rad(FIXED_DIR)
    local fx, fy = -math.sin(h), math.cos(h) -- kamera yonu (referans on)
    -- Ped'in arkasi = kameradan uzak = -on yon.
    SetEntityCoordsNoOffset(backdrop, cc.x - fx * BACKDROP_DIST, cc.y - fy * BACKDROP_DIST, cc.z + BACKDROP_ZOFF, false, false, false)
    SetEntityHeading(backdrop, FIXED_DIR + BACKDROP_HEADOFF)
end

--- Backdrop prop'unu (yeniden) yarat.
local function spawnBackdrop()
    if backdrop and DoesEntityExist(backdrop) then DeleteEntity(backdrop) end
    backdrop = nil
    if not previewPed or BACKDROP_MODEL == 0 then return end
    RequestModel(BACKDROP_MODEL)
    local t = 0
    while not HasModelLoaded(BACKDROP_MODEL) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(BACKDROP_MODEL) then
        print('^1[bitirim] PreviewManager: backdrop yuklenemedi^7'); return
    end
    local cc = GetEntityCoords(previewPed)
    backdrop = CreateObject(BACKDROP_MODEL, cc.x, cc.y, cc.z + BACKDROP_ZOFF, false, false, false)
    SetEntityInvincible(backdrop, true)
    FreezeEntityPosition(backdrop, true)
    SetEntityCollision(backdrop, false, false)
    SetEntityLodDist(backdrop, 1000)
    SetModelAsNoLongerNeeded(BACKDROP_MODEL)
    positionBackdrop()
end

------------------------------------------------------------------------------
-- KAMERA
------------------------------------------------------------------------------
--- Kamerayi SABIT referans yone gore yerlestir (klon heading'inden BAGIMSIZ) ->
--- ped'i dondurmek gorsel donme yapar; kamera cerceve degismez.
local function positionCamera()
    if not cam or not previewPed or not DoesEntityExist(previewPed) then return end
    local cc = GetEntityCoords(previewPed)
    local cx, cy, cz = cc.x, cc.y, cc.z
    local h = math.rad(FIXED_DIR)
    local fx, fy = -math.sin(h), math.cos(h)   -- referans "on" (kamera bu yonde durur)
    local rx, ry = math.cos(h), math.sin(h)    -- saga vektor
    local dist = cam_cfg.dist / (cam_cfg.zoom > 0 and cam_cfg.zoom or 1.0)
    SetCamCoord(cam, cx + fx * dist, cy + fy * dist, cz + cam_cfg.height)
    PointCamAtCoord(cam, cx + rx * cam_cfg.side, cy + ry * cam_cfg.side, cz + cam_cfg.lookz)
    SetCamFov(cam, cam_cfg.fov)
end

------------------------------------------------------------------------------
-- IDLE ANIMASYON
------------------------------------------------------------------------------
local function playIdle()
    if not previewPed or not DoesEntityExist(previewPed) then return end
    local isFemale = GetEntityModel(previewPed) == `mp_f_freemode_01`
    local a = isFemale and IDLE_F or IDLE_M
    RequestAnimDict(a.dict)
    local t = 0
    while not HasAnimDictLoaded(a.dict) and t < 50 do Wait(10); t = t + 1 end
    if HasAnimDictLoaded(a.dict) then
        -- flag 1 = looping. Yerinde (root motion yok) -> ped kaymadan nefes alir.
        TaskPlayAnim(previewPed, a.dict, a.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

------------------------------------------------------------------------------
-- CANLI AYNALAMA (incremental — sadece DEGISENI guncelle)
------------------------------------------------------------------------------
--- Bilesen + prop diff: gercek ped -> preview. Sadece degisen slot yazilir.
local function mirrorAppearance()
    if not previewPed or not DoesEntityExist(previewPed) or not realPed or not DoesEntityExist(realPed) then return end
    for i = 1, #COMPONENTS do
        local c = COMPONENTS[i]
        local d = GetPedDrawableVariation(realPed, c)
        local tx = GetPedTextureVariation(realPed, c)
        local pl = GetPedPaletteVariation(realPed, c)
        local key = d .. ':' .. tx .. ':' .. pl
        if compCache['c' .. c] ~= key then
            SetPedComponentVariation(previewPed, c, d, tx, pl)
            compCache['c' .. c] = key
        end
    end
    for i = 1, #PROPS do
        local p = PROPS[i]
        local d = GetPedPropIndex(realPed, p)
        local tx = GetPedPropTextureIndex(realPed, p)
        local key = d .. ':' .. tx
        if compCache['p' .. p] ~= key then
            if d < 0 then
                ClearPedProp(previewPed, p)
            else
                SetPedPropIndex(previewPed, p, d, tx, true)
            end
            compCache['p' .. p] = key
        end
    end
end

--- Silah aynalama: gercek ped'in secili silahi -> preview (elinde gorunur).
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
--- Onizlemeyi ac: klon (BIR KEZ) + kamera + idle + aynalama.
local function CreatePreview(opts)
    if active then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    realPed = ped

    -- Klon = oyuncunun TAM gorunumu (bilesen/prop/head-blend/tattoo kopyalanir).
    previewPed = ClonePed(ped, GetEntityHeading(ped), true, true)
    if not previewPed or previewPed == 0 or not DoesEntityExist(previewPed) then
        print('^1[bitirim] PreviewManager: ClonePed BASARISIZ^7')
        previewPed = nil
        return
    end
    pcall(ClonePedToTarget, ped, previewPed) -- emniyet: bilesen/prop tam kopya
    SetEntityAsMissionEntity(previewPed, true, true) -- sahiplen -> guvenli DeletePed

    -- Dedike sahneye tasi + dondur/gizle.
    SetEntityCoordsNoOffset(previewPed, SCENE.x, SCENE.y, SCENE.z, false, false, false)
    FreezeEntityPosition(previewPed, true)
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityLodDist(previewPed, 1000)
    heading = FIXED_DIR
    SetEntityHeading(previewPed, heading)

    -- Gercek oyuncuyu GIZLE + dondur (klonla cakismasin, NUI odakli iken kaymasin).
    SetEntityVisible(realPed, false, false)
    FreezeEntityPosition(realPed, true)

    RequestCollisionAtCoord(SCENE.x, SCENE.y, SCENE.z)
    SetFocusPosAndVel(SCENE.x, SCENE.y, SCENE.z, 0.0, 0.0, 0.0)

    -- Koyu backdrop (gercek dunyayi kapatir -> temiz koyu zemin).
    spawnBackdrop()

    -- Kamera (SADECE preview ped'i cercever).
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamUseShallowDofMode(cam, false)
    SetCamDofStrength(cam, 0.0)
    SetCamNearDof(cam, 0.0)
    SetCamFarDof(cam, 1000.0)
    positionCamera()
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    TriggerScreenblurFadeOut(0.0)

    active = true
    compCache = {}
    curWeapon = nil

    -- Idle + ilk aynalama.
    playIdle()
    mirrorWeapon(true)

    -- RENDER thread (Wait 0): gece override + isik + blur-kill + zoom-kilit.
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            -- Gece override'i HER KARE (sunucu zaman senkronunu yener -> koyu sahne).
            NetworkOverrideClockTime(NIGHT_HOUR, 0, 0)

            -- KEY: kameradan beyaz dolgu -> ped parlak/net. Menzil KISA -> backdrop'a
            -- tasmaz (backdrop koyu kalir). Renkli glow CSS'te (seviye rengi).
            if cam then
                local cp = GetCamCoord(cam)
                DrawLightWithRange(cp.x, cp.y, cp.z + KEY_ZOFF, 255, 252, 246, KEY_RANGE, KEY_INT)
            end

            -- ox screenblur kapali tut (ped net).
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
            TriggerScreenblurFadeOut(0.0)

            -- Zoom/tekerlek kontrollerini kapat.
            DisableControlAction(0, 14, true);  DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true);  DisableControlAction(0, 17, true)
            DisableControlAction(0, 96, true);  DisableControlAction(0, 97, true)
            DisableControlAction(0, 241, true); DisableControlAction(0, 242, true)
            DisableControlAction(0, 261, true); DisableControlAction(0, 262, true)

            Wait(0)
        end
    end)

    -- MIRROR thread (~150ms): gercek ped -> preview canli aynalama (Wait 0 DEGIL).
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            mirrorAppearance()
            mirrorWeapon(false)
            Wait(150)
        end
    end)
end

--- Onizlemeyi kapat: HER SEYI temizle (ped/cam/render/gece/gizleme).
local function DestroyPreview()
    if not active then return end
    active = false -- thread'ler cikar

    RenderScriptCams(false, false, 0, true, true)
    if cam then DestroyCam(cam, false); cam = nil end
    if backdrop and DoesEntityExist(backdrop) then DeleteEntity(backdrop) end
    backdrop = nil
    if previewPed and DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed, true, true)
        DeletePed(previewPed)
    end
    previewPed = nil

    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    ClearFocus()
    NetworkClearClockTimeOverride()

    if realPed and DoesEntityExist(realPed) then
        SetEntityVisible(realPed, true, false)
        FreezeEntityPosition(realPed, false)
    end
    realPed = nil
    compCache = {}
    curWeapon = nil
    heading = FIXED_DIR
end

------------------------------------------------------------------------------
-- INCREMENTAL GUNCELLEME API (sadece DEGISENI guncelle)
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

--- Tam yeniden esitle (gercek ped -> preview). Berber/estetik/magaza sonrasi cagir.
local function UpdateOutfit()
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    pcall(ClonePedToTarget, realPed, previewPed) -- bilesen+prop tam kopya
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
-- KAMERA / DONME API
------------------------------------------------------------------------------
--- Ped'i dondur (kamera SABIT -> gorsel donme). mode: left/right/drag/reset.
local function RotatePreview(mode, value)
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    -- Isaret duzeltildi: fareyle SAGA cekince ped SAGA doner (eskiden tersti).
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
    -- Kamera SABIT; yeniden konumlandirmaya gerek yok (ped gorsel doner).
end

--- Kamera kompozisyonu + backdrop guncelle (dist/height/side/fov/lookz/zoom +
--- bdist/bzoff/bhead/bmodel). Zoom ilerisi hazir.
local function SetCamera(cfg)
    if type(cfg) ~= 'table' then return end
    if cfg.dist   then cam_cfg.dist   = cfg.dist   + 0.0 end
    if cfg.height then cam_cfg.height = cfg.height + 0.0 end
    if cfg.side   then cam_cfg.side   = cfg.side   + 0.0 end
    if cfg.fov    then cam_cfg.fov    = cfg.fov    + 0.0 end
    if cfg.lookz  then cam_cfg.lookz  = cfg.lookz  + 0.0 end
    if cfg.zoom   then cam_cfg.zoom   = math.max(0.4, cfg.zoom + 0.0) end
    -- Backdrop ince ayari (koyu okluder konum/model).
    if cfg.bdist  then BACKDROP_DIST    = cfg.bdist + 0.0 end
    if cfg.bzoff  then BACKDROP_ZOFF    = cfg.bzoff + 0.0 end
    if cfg.bhead  then BACKDROP_HEADOFF = cfg.bhead + 0.0 end
    if cfg.bmodel then
        BACKDROP_MODEL = type(cfg.bmodel) == 'string' and GetHashKey(cfg.bmodel) or cfg.bmodel
        if active then spawnBackdrop() end
    end
    positionCamera()
    positionBackdrop()
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
