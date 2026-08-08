--[[
    Bitirim — PREVIEW MANAGER (STUDYO: PREVIEW KAMERASI + KARANLIK VOID)
    ===================================================================
    YAKLASIM (kullanici karari 2026-08-08): karakter onizlemesi %100 SIYAH zemin
    uzerinde gorunsun. FiveM'de bir ped'i arka planindan izole etmenin TEK guvenilir
    yolu: klonu bos/karanlik bir VOID'e alip ONA BAKAN gecici (scripted) bir kamera
    ile cercevelemek.

        GERCEK OYUNCU (mevcut appearance) ──► Gercek Player Ped  (DUNYADA, DOKUNULMAZ)
                                          └──► Preview Clone Ped  (VOID'de, onizleme)

    GAMEPLAY KAMERASI DOKUNULMAZ: scripted kamera SADECE render'i gecici devralir
    (RenderScriptCams). Gameplay kamerasinin pos/rot/fov'u DEGISTIRILMEZ -> envanter
    kapaninca RenderScriptCams(false) ile oyuncu ONCEKI acisina BIREBIR doner (smooth,
    ziplama yok). Kaydetme/geri-yukleme gerekmez (hic degismedi).

    %100 SIYAH: klon uzak VOID'de + GECE override + isiklar kapali (blackout) +
    klona KEY isik (gorunur olsun) + arkasinda BACKDROP objesi. Char-view NUI deligi
    zaten scripted kamera goruntusunu gosterir; kenarlar opak siyah scrim.

    Appearance senkron: tek kaynak = gercek ped. ~150ms diff-loop ile klona AYNALANIR
    (sadece DEGISEN component/prop/silah). Movement/anim AYNALANMAZ (klon STATIK).

    EXPORT API (exports.ox_inventory:<fn>):
        CreatePreview() DestroyPreview() IsPreviewActive()
        UpdateComponent(c,d,t,p) UpdateProp(p,d,t) UpdateWeapon(hash)
        UpdateOutfit() SyncFromPlayer() RotatePreview(mode,val) SetCamera(cfg)
]]

------------------------------------------------------------------------------
-- YAPILANDIRMA
------------------------------------------------------------------------------
local VOID        = vector3(1000.0, -3000.0, 500.0) -- bos/uzak sahne (near-stream, izole)
local FIXED_DIR   = 180.0    -- klonun kameraya karsi referans yonu (reset icin)
local TRANSITION_MS = 500    -- gameplay <-> preview kamera SMOOTH gecis suresi (ms)

-- Preview kamera kompozisyonu (dial edildi — char-view soluna oturuyor).
local cam_cfg = {
    dist = 3.55, height = 0.20, side = -0.98, fov = 44.0, lookz = -0.05, zoom = 1.0,
}

-- Backdrop (klonun ARKASINDA, kameradan UZAKTA -> asla kamerayi sarmaz). Gece'de koyu.
local bd_cfg = { model = 'prop_container_01a', dist = 1.6, z = 1.0, head = 90.0 }

-- KEY isik (klon karanlik void'de gorunur olsun; kameradan klona dogru, yumusak).
local key_cfg = { r = 240, g = 244, b = 255, range = 6.0, intensity = 2.2, zoff = 0.35 }

-- Idle (klon temiz durus, mid-run donma olmasin). Cinsiyete gore.
local IDLE_M = { dict = 'anim@heists@heist_corona@team_idles@male_a',   anim = 'idle' }
local IDLE_F = { dict = 'anim@heists@heist_corona@team_idles@female_a', anim = 'idle' }

local COMPONENTS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS      = { 0, 1, 2, 6, 7 }
local UNARMED    = `WEAPON_UNARMED`

------------------------------------------------------------------------------
-- DURUM
------------------------------------------------------------------------------
local active      = false
local previewPed  = nil
local backdrop    = nil
local bdCx, bdCy, bdCz = 0.0, 0.0, 0.0  -- backdrop origin->merkez ofseti (3D ortalama)
local cam         = nil
local realPed     = nil     -- referans (aynalama); gercek ped DOKUNULMAZ
local dragYaw     = 0.0
local compCache   = {}
local curWeapon   = nil

------------------------------------------------------------------------------
-- SCRIPTED PREVIEW KAMERA (klonu VOID'de cercever; gameplay kamerasi DEGISMEZ)
------------------------------------------------------------------------------
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

--- KEY isigi kameradan klona dogru ciz (klonu aydinlat; backdrop uzak -> koyu kalir).
local function drawKeyLight()
    if not previewPed or not DoesEntityExist(previewPed) then return end
    local cc = GetEntityCoords(previewPed)
    local h = math.rad(FIXED_DIR)
    local fx, fy = -math.sin(h), math.cos(h)
    local lx, ly, lz = cc.x + fx * 1.5, cc.y + fy * 1.5, cc.z + key_cfg.zoff + 0.6
    DrawLightWithRange(lx, ly, lz, key_cfg.r, key_cfg.g, key_cfg.b, key_cfg.range, key_cfg.intensity)
end

------------------------------------------------------------------------------
-- BACKDROP (koyu arka plan objesi — klonun ARKASINDA, kameradan uzakta)
------------------------------------------------------------------------------
local function loadModel(m)
    local hsh = (type(m) == 'number') and m or GetHashKey(m)
    RequestModel(hsh)
    local t = 0
    while not HasModelLoaded(hsh) and t < 100 do Wait(10); t = t + 1 end
    return HasModelLoaded(hsh) and hsh or nil
end

--- Backdrop'i klonun ARKASINA (kameranin TERS yonune) 3D-ortali yerlestir.
local function positionBackdrop()
    if not backdrop or not DoesEntityExist(backdrop) or not previewPed then return end
    local cc = GetEntityCoords(previewPed)
    local h = math.rad(FIXED_DIR)
    local fx, fy = -math.sin(h), math.cos(h)          -- kamera yonu
    -- backdrop klonun ARKASINDA = kameranin TERSI (-f) yonunde
    local bh = (FIXED_DIR + bd_cfg.head) % 360.0
    local hr = math.rad(bh)
    local rx = bdCx * math.cos(hr) - bdCy * math.sin(hr)
    local ry = bdCx * math.sin(hr) + bdCy * math.cos(hr)
    local px = cc.x - fx * bd_cfg.dist
    local py = cc.y - fy * bd_cfg.dist
    SetEntityCoordsNoOffset(backdrop, px - rx, py - ry, cc.z + bd_cfg.z - bdCz, false, false, false)
    SetEntityHeading(backdrop, bh)
end

local function spawnBackdrop()
    if backdrop and DoesEntityExist(backdrop) then return end
    if not bd_cfg.model or bd_cfg.model == '' then return end
    local mh = loadModel(bd_cfg.model)
    if not mh then return end
    local mn, mx = GetModelDimensions(mh)
    bdCx = (mn.x + mx.x) * 0.5
    bdCy = (mn.y + mx.y) * 0.5
    bdCz = (mn.z + mx.z) * 0.5
    backdrop = CreateObject(mh, VOID.x, VOID.y, VOID.z, false, false, false)
    SetModelAsNoLongerNeeded(mh)
    if backdrop and DoesEntityExist(backdrop) then
        SetEntityCollision(backdrop, false, false)
        FreezeEntityPosition(backdrop, true)
        SetEntityInvincible(backdrop, true)
        SetEntityLodDist(backdrop, 1000)
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
    realPed = ped -- SADECE referans; gercek ped'e DOKUNULMAZ (dunyada kalir)

    -- 1) Klon = oyuncunun O ANKI gorunumu (component/prop/head-blend/tattoo kopya).
    previewPed = ClonePed(ped, GetEntityHeading(ped), true, true)
    if not previewPed or previewPed == 0 or not DoesEntityExist(previewPed) then
        print('^1[bitirim] PreviewManager: ClonePed BASARISIZ^7')
        previewPed = nil
        return
    end
    pcall(ClonePedToTarget, ped, previewPed)
    SetEntityAsMissionEntity(previewPed, true, true)

    -- 2) Klonu VOID'e tasi (gercek oyuncu DUNYADA kalir; klon izole/karanlik sahnede).
    active = true
    dragYaw = 0.0
    SetEntityCoordsNoOffset(previewPed, VOID.x, VOID.y, VOID.z, false, false, false)
    FreezeEntityPosition(previewPed, true)  -- KLON statik (movement YOK)
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityLodDist(previewPed, 1000)
    SetEntityHeading(previewPed, FIXED_DIR)

    -- 3) VOID'i stream'e sok (klon+backdrop yuklensin) + backdrop olustur.
    RequestCollisionAtCoord(VOID.x, VOID.y, VOID.z)
    SetFocusPosAndVel(VOID.x, VOID.y, VOID.z, 0.0, 0.0, 0.0)
    spawnBackdrop()
    positionBackdrop()

    -- 4) Scripted preview kamera: SADECE render'i devralir. DOF KAPALI.
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamUseShallowDofMode(cam, false)
    positionCamera()
    SetCamActive(cam, true)
    RenderScriptCams(true, true, TRANSITION_MS, true, true) -- gameplay -> preview (smooth)

    compCache = {}
    curWeapon = nil
    playIdle()
    mirrorWeapon(true)

    -- RENDER thread (Wait 0): GECE override + blackout (arka plan %100 koyu) + KEY isik
    -- (klon gorunur) + ox screenblur kapali (klon net). GAMEPLAY KAMERASINA DOKUNULMAZ.
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            NetworkOverrideClockTime(0, 0, 0)      -- weathersync her frame ezer -> tekrar zorla
            SetArtificialLightsState(true)          -- sehir isiklari kapali (karanlik void)
            drawKeyLight()
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

    -- SMOOTH geri donus: gameplay kamerasi hic DEGISMEDI -> onceki acisina birebir doner.
    RenderScriptCams(false, true, TRANSITION_MS, true, true)
    SetArtificialLightsState(false) -- sehir isiklari geri (gece override kendiliginden resync)

    local doomedCam, doomedPed, doomedBd = cam, previewPed, backdrop
    cam, previewPed, backdrop = nil, nil, nil
    CreateThread(function()
        Wait(TRANSITION_MS + 80) -- gecis bitene kadar klon gorunur kalsin
        if doomedCam and DoesCamExist(doomedCam) then DestroyCam(doomedCam, false) end
        if doomedPed and DoesEntityExist(doomedPed) then
            SetEntityAsMissionEntity(doomedPed, true, true); DeletePed(doomedPed)
        end
        if doomedBd and DoesEntityExist(doomedBd) then
            SetEntityAsMissionEntity(doomedBd, true, true); DeleteObject(doomedBd)
        end
        ClearFocus()
    end)

    realPed = nil
    compCache = {}
    curWeapon = nil
    dragYaw = 0.0
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

local function UpdateOutfit()
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end
    pcall(ClonePedToTarget, realPed, previewPed)
    compCache = {}
    mirrorAppearance()
    mirrorWeapon(true)
end

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
        dragYaw = (dragYaw - 45.0) % 360.0
    elseif mode == 'right' then
        dragYaw = (dragYaw + 45.0) % 360.0
    elseif mode == 'drag' then
        dragYaw = (dragYaw + (tonumber(value) or 0.0) * 0.4) % 360.0
    elseif mode == 'reset' then
        dragYaw = 0.0
    end
    SetEntityHeading(previewPed, (FIXED_DIR + dragYaw) % 360.0)
end

local function SetCamera(cfg)
    if type(cfg) ~= 'table' then return end
    if cfg.dist   then cam_cfg.dist   = cfg.dist   + 0.0 end
    if cfg.height then cam_cfg.height = cfg.height + 0.0 end
    if cfg.side   then cam_cfg.side   = cfg.side   + 0.0 end
    if cfg.fov    then cam_cfg.fov    = cfg.fov    + 0.0 end
    if cfg.lookz  then cam_cfg.lookz  = cfg.lookz  + 0.0 end
    if cfg.zoom   then cam_cfg.zoom   = math.max(0.4, cfg.zoom + 0.0) end
    -- backdrop + isik knob'lari
    if cfg.bdist  then bd_cfg.dist  = cfg.bdist + 0.0 end
    if cfg.bz     then bd_cfg.z     = cfg.bz    + 0.0 end
    if cfg.bhead  then bd_cfg.head  = cfg.bhead + 0.0 end
    if cfg.keyint then key_cfg.intensity = cfg.keyint + 0.0 end
    if cfg.bmodel then
        bd_cfg.model = cfg.bmodel
        if active then
            if backdrop and DoesEntityExist(backdrop) then
                SetEntityAsMissionEntity(backdrop, true, true); DeleteObject(backdrop)
            end
            backdrop = nil
            spawnBackdrop()
        end
    end
    positionCamera()
    positionBackdrop()
end

local function IsPreviewActive() return active end

------------------------------------------------------------------------------
-- EXPORT'LAR
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

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then DestroyPreview() end
end)
