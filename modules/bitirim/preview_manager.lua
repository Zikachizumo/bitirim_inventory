--[[
    Bitirim — PREVIEW MANAGER (AYNA / "Mirror" KARAKTER ONIZLEMESI, Sabit Kamera)
    ============================================================================
    AYNA MIMARISI (kullanici spec'i): gercek karakter OYUNDA GORUNMEYE DEVAM EDER;
    review'da onun canli bir AYNASI (mirror klon) gosterilir -> 2 yerde karakter.
        GERCEK OYUNCU (mevcut appearance) ──► Gercek Player Ped  (oyunda GORUNUR kalir)
                                          └──► Mirror Klon Ped    (review'da; canli aynalanir)

    EN ONEMLI KURAL: GAMEPLAY KAMERASINA HIC DOKUNULMAZ.
    - Scripted kamera OLUSTURULMAZ, RenderScriptCams CAGRILMAZ. Kamera YAW/pozisyon
      degismez; TEK istisna: envanter acikken gameplay kamerasi PITCH'i cfg.pitch'e
      KILITLENIR (SetGameplayCamRelativePitch) -> nasil bakarsan bak klon HEP ayni onden
      goruntude (yukaridan bakma + o acidaki DOF bulanikligi biter). Kullanici istegi.
    - Mirror klon KAMERA-UZAYINDA sabit ofset: camPos + f*dist + r*side + u*down (pitch
      dahil taban). Ilk ~12 kare yerlestirilir (pitch otururken) sonra DUNYADA DONUK ->
      per-obje motion blur olmaz. Klon kameraya bakar (heading = camYaw+180+dragYaw).
    - GERCEK PED GIZLENMEZ (ayna modu). Arkada o noktadaki oyun dunyasi gorunur.
    - Appearance senkron: tek kaynak = gercek ped. ~150ms diff-loop ile klona
      AYNALANIR (sadece DEGISEN component/prop/silah). Movement/anim AYNALANMAZ.
    - Kapaninca mirror klon silinir; gercek ped'e zaten dokunulmadi.

    EXPORT API (exports.ox_inventory:<fn>):
        CreatePreview() DestroyPreview() IsPreviewActive()
        UpdateComponent(c,d,t,p) UpdateProp(p,d,t) UpdateWeapon(hash)
        UpdateOutfit() SyncFromPlayer() RotatePreview(mode,val) SetCamera(cfg)
]]

------------------------------------------------------------------------------
-- YAPILANDIRMA (hepsi /cam ile in-game dial edilir)
------------------------------------------------------------------------------
-- SADECE CANLI KLON (backdrop TAMAMEN kaldirildi — kullanici karari). Klon gercek ped'i
-- canli aynalar, sabit gameplay kamerasinin onune (review kutusuna) yerlestirilir; gercek
-- ped/kamera ISINLANMAZ. Arka planda o noktadaki oyun dunyasi gorunur (delik kabul edildi).
local cfg = {
    dist = 3.45,   -- klon kameranin kac metre ONUNDE (kamera-uzayi) — KALICI
    side = -1.11,  -- YATAY ofset (kamera-sag; negatif = ekranda sola) — KALICI
    down = 0.02,   -- DIKEY ofset (kamera-YUKARI; saf kamera-uzayi, pitch'ten bagimsiz) — KALICI
    pitch = -10.0, -- GAMEPLAY kamerasi pitch KILIDI (envanter acikken). Nasil bakarsan bak,
                   -- acilinca kamera bu acida oturur -> klon HEP ayni onden/net gorunur.
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
local realPed     = nil     -- referans (aynalama) + LOKAL gizlenir
local dragYaw     = 0.0     -- kullanici surukleme/donme ofseti
local compCache   = {}      -- aynalama diff onbellegi
local curWeapon   = nil

------------------------------------------------------------------------------
-- KLON YERLESIMI (gameplay kamerasini SADECE OKUR)
------------------------------------------------------------------------------
--- Klonu yerlestir. Kamera DEGISTIRILMEZ; sadece okunur.
--- KLON TAMAMEN KAMERA-UZAYINDA SABIT OFSET: dist=ileri, side=sag, down=yukari (hepsi
--- kamera cercevesinde, pitch DAHIL taban). Ayak/kamera-yuksekligi terimleri YOK ->
--- down artik SAF kamera-uzayi ofset: kamera hangi acida olursa olsun klon EKRANDA
--- BIREBIR AYNI konum/acida gorunur (dial edilen degerler her pitch'te ayni sonucu verir).
--- Sadece dragYaw ile sag/sola doner.
local function positionScene()
    if not previewPed or not DoesEntityExist(previewPed) then return end
    local camPos = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local cxr, sxr = math.cos(xr), math.sin(xr)
    local szr, czr = math.sin(zr), math.cos(zr)
    -- KAMERA TABANI (pitch dahil): ileri / yatay-sag / kamera-yukari
    local f = vector3(-szr * cxr, czr * cxr, sxr)
    local r = vector3(czr, szr, 0.0)
    local u = vector3(szr * sxr, -czr * sxr, cxr)
    SetEntityCoordsNoOffset(previewPed,
        camPos.x + f.x * cfg.dist + r.x * cfg.side + u.x * cfg.down,
        camPos.y + f.y * cfg.dist + r.y * cfg.side + u.y * cfg.down,
        camPos.z + f.z * cfg.dist + r.z * cfg.side + u.z * cfg.down,
        false, false, false)
    SetEntityHeading(previewPed, (rot.z + 180.0 + dragYaw) % 360.0)
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
    realPed = ped -- referans (aynalama) + LOKAL gizlenir; dunya/network DOKUNULMAZ

    -- 1) Klon = oyuncunun O ANKI gorunumu. ONCE klonla (ped HALA gorunur) -> klon
    -- gorunmezligi MIRAS ALMAZ. Gizlemeyi klon kurulduktan SONRA yapariz.
    previewPed = ClonePed(ped, GetEntityHeading(ped), true, true)
    if not previewPed or previewPed == 0 or not DoesEntityExist(previewPed) then
        print('^1[bitirim] PreviewManager: ClonePed BASARISIZ^7')
        previewPed = nil
        return
    end
    pcall(ClonePedToTarget, ped, previewPed)
    SetEntityAsMissionEntity(previewPed, true, true) -- guvenli DeletePed
    FreezeEntityPosition(previewPed, true)  -- KLON statik (movement YOK)
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityLodDist(previewPed, 1000)
    SetEntityVisible(previewPed, true, false)  -- MIRROR KESIN GORUNUR
    ResetEntityAlpha(previewPed)

    -- 2) AYNA MODU: gercek ped GIZLENMEZ -> oyunda karakter gorunmeye devam eder;
    -- mirror klon review'da ayrica gorunur (2 yerde karakter). Kullanici istegi.

    -- 3) Ilk yerlesim + odak (klonun oldugu yer render/stream edilsin). Kamera YAW/pozisyon
    -- degismez; sadece PITCH render loop'ta cfg.pitch'e kilitlenir (klon hep ayni acida).
    active = true
    dragYaw = 0.0
    positionScene()
    local cp = GetGameplayCamCoord()
    SetFocusPosAndVel(cp.x, cp.y, cp.z, 0.0, 0.0, 0.0)

    compCache = {}
    curWeapon = nil
    playIdle()
    mirrorWeapon(true)

    -- RENDER thread (Wait 0):
    --  (a) GAMEPLAY kamerasi PITCH'ini cfg.pitch'e KILITLE -> nasil bakarsan bak, envanter
    --      acilinca kamera nötr açıya oturur, klon HEP ayni onden/net gorunur (yukaridan
    --      bakma/DOF bulanikligi biter). Yaw/pozisyon DEGISMEZ (fare ile donme dragYaw).
    --  (b) Klon ilk ~12 karede yerlestirilir (pitch otururken) sonra DONDURULUR (her kare
    --      repos YOK -> per-obje motion blur olmaz, net).
    --  (c) ox screenblur kapat + fare-kamera engelle.
    CreateThread(function()
        local placeFrames = 0
        while active and previewPed and DoesEntityExist(previewPed) do
            SetGameplayCamRelativePitch(cfg.pitch, 1.0)
            if placeFrames < 12 then positionScene(); placeFrames = placeFrames + 1 end
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
            TriggerScreenblurFadeOut(0.0)
            DisableControlAction(0, 1, true)  -- INPUT_LOOK_LR
            DisableControlAction(0, 2, true)  -- INPUT_LOOK_UD
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

    if previewPed and DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed, true, true)
        DeletePed(previewPed)
    end
    previewPed = nil
    realPed = nil  -- ayna modunda gizlenmedi -> geri acmaya gerek yok

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

--- Klon yerlesimi ince ayar (KAMERA DEGISMEZ). /cam ile dial edilir (chat).
local function SetCamera(cfgIn)
    if type(cfgIn) ~= 'table' then return end
    if cfgIn.dist then cfg.dist = cfgIn.dist + 0.0 end
    if cfgIn.side then cfg.side = cfgIn.side + 0.0 end
    if cfgIn.down then cfg.down = cfgIn.down + 0.0 end
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
