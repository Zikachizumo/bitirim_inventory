--[[
    Bitirim — PREVIEW MANAGER (STUDIO / "Studio Camera" KARAKTER ONIZLEMESI)
    ============================================================================
    STUDIO MIMARISI: Envanter acilinca, oyuncunun YEREL (local-only) bir klonu
    SABIT bir DUNYA KONUMUNDA (void/bos bir noktada, oyuncunun gercek konumundan
    BAGIMSIZ) durur; ona bakan SCRIPTED bir kamera devreye girer; klonun arkasina
    TAM KAPLAYAN siyah panel konur.
        GERCEK OYUNCU ──► Gercek Player Ped  (yerel GIZLI; agda normal gorunur)
                      └──► Mirror Klon Ped    (YEREL; SABIT void konumunda; studio
                                                kamerasi buna bakar)

    NEDEN STUDIO KAMERA + SABIT VOID KONUM (onceki "sabit gameplay kamerasi +
    oyuncunun oldugu yer" yerine):
    - Gameplay kamerasi sabit degildi: TP/FP/egimli zemin -> kameranin pitch'i degisiyor,
      dik tek-yuzlu backdrop paneli o acilarda kameradan kacip GORUNMEZ oluyordu.
    - Oyuncunun GERCEK konumunda klonlamak, oyuncunun bulundugu yere gore (bina,
      esya, baska ped) arka planin her zaman temiz olmasini GARANTI EDEMEZ.
      SABIT VOID KONUM (kullanicinin belirledigi `cfg.worldPos/worldHead`, bos bir
      nokta -mesela gokyuzu-) + scripted kamera -> arka plan HER ZAMAN %100 kapli,
      karakter hep ayni net kadrajda, kamera MODUNDAN (FP/TP/egim) TAMAMEN BAGIMSIZ.
    - GECIS ANIMASYONU YOK: envanter acilir acilmaz (bir sonraki frame) direkt studio
      kadrajina gecilir (RenderScriptCams ease=false); kapaninca da aninda gameplay'e
      doner (yaris durumu/entity sizintisi riskine karsi da aninda kesim tercih edildi).
    - Insurance icin 2 backdrop paneli (ters heading; hangisi "on yuz" olursa olsun
      biri HER ZAMAN kameraya doner).

    Klon local-only (ClonePed isNetwork=false) -> diger oyuncular klonu HIC gormez.
    Gercek ped SADECE yerel gizlenir -> preview'da 2. karakter yok; agda arkadaslar beni
    normal/dogru kiyafetli gorur. Appearance senkron: tek kaynak = gercek ped (~150ms diff).

    EXPORT API (exports.ox_inventory:<fn>):
        CreatePreview() DestroyPreview() IsPreviewActive()
        UpdateComponent(c,d,t,p) UpdateProp(p,d,t) UpdateWeapon(hash)
        UpdateOutfit() SyncFromPlayer() RotatePreview(mode,val) SetCamera(cfg) TuneScene(action)
]]

------------------------------------------------------------------------------
-- YAPILANDIRMA (studio kamerasi + backdrop; /cam VEYA ok tuslari+Numpad1/2 ile dial edilir)
------------------------------------------------------------------------------
local cfg = {
    -- KLONUN SABIT DUNYA KONUMU (void/bos nokta). Kullanici belirledi. Oyuncunun
    -- gercek konumundan TAMAMEN BAGIMSIZ -> her zaman ayni temiz arka plan.
    worldPos  = vector3(-301.72, -71.13, 316.92),
    worldHead = 149.61,

    camDist   = 2.55,  -- kamera klonun kac metre ONUNDE (klonun bakis yonunde) — Numpad1/2 zoom
    camSide   = 0.0,   -- kamera YATAY ofseti (ekranda kadraji sag/sol kaydirir) — ok Sol/Sag
    camHeight = 0.05,  -- kamera DIKEY ofseti (klon UST GOGUS bonuna gore) — ok Yukari/Asagi
    lookDown  = 0.30,  -- bakis hedefi: ust gogusun kac metre ALTI (govde ortasi)
    fov       = 42.0,  -- gorus acisi (dar = portre, dunya kacagi az)
    backDist  = 2.40,  -- backdrop klonun kac metre ARKASINDA
    backZ     = 0.0,   -- backdrop dikey ince ayar
    balpha    = 255,   -- siyah panel opaklik (0..255; tam opak)
    bmodel    = 'bitirim_backdrop01',  -- stream'deki 20m+ SIYAH panel
}

-- Idle (klon temiz durus). Cinsiyete gore.
local IDLE_M = { dict = 'anim@heists@heist_corona@team_idles@male_a',   anim = 'idle' }
local IDLE_F = { dict = 'anim@heists@heist_corona@team_idles@female_a', anim = 'idle' }

-- Aynalanan ped bilesenleri / proplari (illenium + GTA standart).
local COMPONENTS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS      = { 0, 1, 2, 6, 7 }
local UNARMED    = `WEAPON_UNARMED`
local BONE_CHEST = 24818  -- SKEL_Spine3 (ust gogus) — kadraj/odak referansi

------------------------------------------------------------------------------
-- DURUM
------------------------------------------------------------------------------
local active       = false
local previewPed   = nil    -- YEREL klon (studio kamerasi buna bakar)
local realPed      = nil    -- referans (aynalama) + YEREL gizlenir
local studioCam    = nil    -- scripted kamera
local backdrop     = nil    -- siyah panel (on yuz kameraya bakar)
local backdrop2    = nil    -- ikinci panel (backface guvencesi)
local dragYaw      = 0.0    -- kullanici surukleme/donme ofseti (klonu dondurur)
local compCache    = {}     -- aynalama diff onbellegi
local curWeapon    = nil

------------------------------------------------------------------------------
-- YERLESIM (SABIT geometri: klon SABIT dunya konumunda; kamera+backdrop ona gore)
------------------------------------------------------------------------------
local function forwardOf(h)
    local r = math.rad(h)
    return vector3(-math.sin(r), math.cos(r), 0.0)  -- heading h'de ileri yon
end

local function rightOf(h)
    local r = math.rad(h)
    return vector3(math.cos(r), math.sin(r), 0.0)  -- heading h'nin sagi
end

--- Iki backdrop panelini klonun ARKASINA, kameraya bakacak sekilde yerlestir.
--- Panel yuzu (-Y) heading+180'de +fwd'e (kameraya) bakar; ikinci panel ters -> hangi
--- acidan olursa olsun biri HER ZAMAN kaplar (backface-culling guvencesi).
local function positionBackdrop(fwd, centerZ)
    local a = cfg.worldPos
    local bx = a.x - fwd.x * cfg.backDist
    local by = a.y - fwd.y * cfg.backDist
    local bz = centerZ + cfg.backZ
    if backdrop and DoesEntityExist(backdrop) then
        SetEntityCoordsNoOffset(backdrop, bx, by, bz, false, false, false)
        SetEntityHeading(backdrop, (cfg.worldHead + 180.0) % 360.0)
    end
    if backdrop2 and DoesEntityExist(backdrop2) then
        SetEntityCoordsNoOffset(backdrop2, bx - fwd.x * 0.1, by - fwd.y * 0.1, bz, false, false, false)
        SetEntityHeading(backdrop2, cfg.worldHead % 360.0)
    end
end

--- Klon + kamera + backdrop'u studio geometrisine gore yerlestir. Klon SABIT dunya
--- konumunda durur (cfg.worldPos/worldHead); kamera camDist/camSide/camHeight ile o
--- klona gore konumlanir (bunlar ok tuslari + Numpad1/2 ile canli dial edilir).
--- dragYaw sadece klonu kendi ekseninde dondurur (kamera degismez).
local function setupStudio()
    if not previewPed or not DoesEntityExist(previewPed) or not studioCam then return end
    local a = cfg.worldPos
    local fwd = forwardOf(cfg.worldHead)
    -- Kamera klonun ONUNE (fwd) bakar; camSide/camHeight KAMERANIN kadraj ofseti
    -- (kamera-sag vektoru = klona bakan kameranin kendi yaw'ina gore: worldHead+180).
    local right = rightOf((cfg.worldHead + 180.0) % 360.0)
    -- Klon: SABIT studio konumunda dur (+dragYaw ile kendi ekseninde donebilir)
    SetEntityCoordsNoOffset(previewPed, a.x, a.y, a.z, false, false, false)
    SetEntityHeading(previewPed, (cfg.worldHead + dragYaw) % 360.0)
    -- Kadraj: ust gogus bonuna gore (klon boyu ne olursa olsun ortali)
    local chest = GetPedBoneCoords(previewPed, BONE_CHEST, 0.0, 0.0, 0.0)
    SetCamCoord(studioCam,
        a.x + fwd.x * cfg.camDist + right.x * cfg.camSide,
        a.y + fwd.y * cfg.camDist + right.y * cfg.camSide,
        chest.z + cfg.camHeight)
    SetCamFov(studioCam, cfg.fov)
    PointCamAtCoord(studioCam, a.x, a.y, chest.z - cfg.lookDown)
    positionBackdrop(fwd, chest.z)
end

--- Iki siyah paneli spawn et.
local function spawnBackdrop()
    local h = GetHashKey(cfg.bmodel)
    if not IsModelInCdimage(h) or not IsModelValid(h) then
        print(('^1[bitirim] backdrop model gecersiz: "%s" (stream/ytyp yuklendi mi?)^7'):format(cfg.bmodel))
        return
    end
    RequestModel(h)
    local t = 0
    while not HasModelLoaded(h) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(h) then print('^1[bitirim] backdrop model yuklenemedi^7'); return end
    local ep = cfg.worldPos
    for i = 1, 2 do
        local obj = CreateObject(h, ep.x, ep.y, ep.z, false, false, false)
        if obj and DoesEntityExist(obj) then
            SetEntityCollision(obj, false, false)
            FreezeEntityPosition(obj, true)
            SetEntityInvincible(obj, true)
            SetEntityLodDist(obj, 1000)
            SetEntityAlpha(obj, math.floor(cfg.balpha), false)
            if i == 1 then backdrop = obj else backdrop2 = obj end
        end
    end
    SetModelAsNoLongerNeeded(h)
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
-- YASAM DONGUSU
------------------------------------------------------------------------------
local function CreatePreview()
    if active then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    realPed = ped

    -- 1) Klon = oyuncunun O ANKI gorunumu. isNetwork=FALSE -> YEREL entity; ag uzerinde
    -- YAYILMAZ, diger oyuncular klonu HIC gormez (default-kiyafet kopya bug'inin kok nedeni).
    previewPed = ClonePed(ped, GetEntityHeading(ped), false, false)
    if not previewPed or previewPed == 0 or not DoesEntityExist(previewPed) then
        print('^1[bitirim] PreviewManager: ClonePed BASARISIZ^7')
        previewPed = nil
        return
    end
    pcall(ClonePedToTarget, ped, previewPed)
    SetEntityAsMissionEntity(previewPed, true, true)
    FreezeEntityPosition(previewPed, true)  -- KLON statik
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityLodDist(previewPed, 1000)
    SetEntityVisible(previewPed, true, false)
    ResetEntityAlpha(previewPed)

    -- 2) Klon SABIT dunya konumunda durur (cfg.worldPos/worldHead) — oyuncunun gercek
    -- konumundan BAGIMSIZ, her zaman ayni temiz void arka plan.
    dragYaw = 0.0

    -- 3) Scripted kamera (dogrudan studio konumunda olusturulur; GECIS ANIMASYONU YOK)
    local wp = cfg.worldPos
    studioCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', wp.x, wp.y, wp.z, 0.0, 0.0, 0.0, cfg.fov, false, 2)

    spawnBackdrop()

    active = true
    compCache = {}
    curWeapon = nil
    setupStudio()               -- klon+kamera+backdrop studio konumuna
    SetCamActive(studioCam, true)
    -- ANINDA GECIS: bir sonraki frame direkt studio kadrajinda goruntulenir (ease=false,
    -- sure=0). Smooth blend YOK — kullanici istegi.
    RenderScriptCams(true, false, 0, true, true)
    playIdle()
    mirrorWeapon(true)

    -- RENDER thread (Wait 0): gercek bedeni yerel gizle + ilk karelerde kadraji
    -- oturt (bone'lar settle olunca) + odak klona + ox screenblur kapat.
    CreateThread(function()
        local frames = 0
        while active and previewPed and DoesEntityExist(previewPed) do
            if realPed and DoesEntityExist(realPed) then SetEntityLocallyInvisible(realPed) end
            if frames < 8 then setupStudio(); frames = frames + 1 end
            local chest = GetPedBoneCoords(previewPed, BONE_CHEST, 0.0, 0.0, 0.0)
            SetFocusPosAndVel(chest.x, chest.y, chest.z, 0.0, 0.0, 0.0)
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

    -- Kamerayi gameplay'e ANINDA geri ver (sure=0). Smooth (400ms) donus + hemen
    -- ardindan cam/klon/backdrop silme YARIS DURUMU yaratir: kullanici o 400ms
    -- icinde tekrar acarsa (active zaten false) yeni bir klon/kamera olusur, eskisi
    -- henuz silinmemis olabilir -> entity sizintisi/cift kamera. Aninda kesim guvenli.
    RenderScriptCams(false, false, 0, true, true)
    if studioCam then
        DestroyCam(studioCam, false)
        studioCam = nil
    end

    if backdrop and DoesEntityExist(backdrop) then
        SetEntityAsMissionEntity(backdrop, true, true); DeleteObject(backdrop)
    end
    backdrop = nil
    if backdrop2 and DoesEntityExist(backdrop2) then
        SetEntityAsMissionEntity(backdrop2, true, true); DeleteObject(backdrop2)
    end
    backdrop2 = nil

    if previewPed and DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed, true, true)
        DeletePed(previewPed)
    end
    previewPed = nil

    -- Gercek bedeni kesin geri goster (LocallyInvisible zaten kendini sifirlar; emniyet).
    if realPed and DoesEntityExist(realPed) then
        SetEntityVisible(realPed, true, false)
        ResetEntityAlpha(realPed)
    end
    realPed = nil

    ClearFocus()
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
    SetEntityHeading(previewPed, (cfg.worldHead + dragYaw) % 360.0)
end

--- Studio kadraj ince ayari (klon SABIT konumda kalir; sadece kamera mesafe/fov/
--- yukseklik/yatay). /cam ile dial edilir (chat). Geriye donuk uyum icin 'down' -> camHeight.
local function SetCamera(cfgIn)
    if type(cfgIn) ~= 'table' then return end
    if cfgIn.dist     then cfg.camDist   = cfgIn.dist + 0.0 end
    if cfgIn.fov      then cfg.fov       = cfgIn.fov + 0.0 end
    if cfgIn.height   then cfg.camHeight = cfgIn.height + 0.0 end
    if cfgIn.down     then cfg.camHeight = cfgIn.down + 0.0 end   -- eski /cam uyumu
    if cfgIn.side     then cfg.camSide   = cfgIn.side + 0.0 end
    if cfgIn.look     then cfg.lookDown  = cfgIn.look + 0.0 end
    if cfgIn.backdist then cfg.backDist  = cfgIn.backdist + 0.0 end
    setupStudio()
end

--- Klavye ayar (index.tsx -> NUI 'bitirim:charTune' -> buraya):
---   Ok tuslari (up/down/left/right) = KAMERA kadraj ofseti (camHeight/camSide).
---   Numpad 1/2 (zoomin/zoomout)     = ZOOM (camDist; yakin=buyuk).
--- Klon SABIT konumda kalir (cfg.worldPos/worldHead), sadece kamera kadraji degisir.
--- Begenilen degerleri F8'de gorup soyle -> kalici yaparim.
local function TuneScene(action)
    if not active then return end
    local POS, ZSTEP = 0.03, 0.05
    if action == 'up' then          cfg.camHeight = cfg.camHeight + POS
    elseif action == 'down' then    cfg.camHeight = cfg.camHeight - POS
    elseif action == 'left' then    cfg.camSide   = cfg.camSide - POS
    elseif action == 'right' then   cfg.camSide   = cfg.camSide + POS
    elseif action == 'zoomin' then  cfg.camDist   = math.max(1.0, cfg.camDist - ZSTEP)
    elseif action == 'zoomout' then cfg.camDist   = cfg.camDist + ZSTEP
    else return end
    setupStudio()
    print(('^3[bitirim] studio camSide=%.2f camHeight=%.2f camDist=%.2f^7')
        :format(cfg.camSide, cfg.camHeight, cfg.camDist))
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
exports('TuneScene',       TuneScene)
exports('SetCamera',       SetCamera)

-- Emniyet: kaynak durursa temizle.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then DestroyPreview() end
end)
