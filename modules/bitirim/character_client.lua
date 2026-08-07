--[[
    Bitirim — ENVANTERDE CANLI 3B KARAKTER ONIZLEMESI
    -------------------------------------------------
    Envanterin KARAKTER paneli goruncе, oyuncunun bir KLONU gizli/bos bir
    konuma (void) tasinir, kamera ona bakar; ekranin karakter panelindeki
    SEFFAF pencereden bu klon gorunur. Giyili kiyafetler klona kopyalanir
    (ClonePed component/prop kopyalar) -> ustunde otomatik gorunur.

    Arka plan: bos void koordinati + koyu timecycle + CANTA SEVIYESINE gore
    renkli spot isik -> mockup'taki "isikli void" hissi.

    Dondurme: NUI'den (bitirim:charRotate) sol/sag (klon heading), ust (kamera
    yuksek aci), ve fareyle surukle (heading delta).

    NOT: Kamera cerceveleme ve void gorunumu OYUNDA ince ayar ister. Asagida
    "AYARLA" isaretli sabitler ekran goruntusuyle guncellenecek. Testsiz makul
    defaultlar konuldu. ADDITIVE + pcall guard.
]]

------------------------------------------------------------------------------
-- AYAR SABITLERI (oyunda ekran goruntusuyle guncelle)
------------------------------------------------------------------------------
-- SIYAH VOID: haritanin DISI (bounds ~-4000..4500). Uzak dis koordinatta terrain
-- akmaz -> arka plan SIYAH. Klon spot + beyaz dolgu isigiyla aydinlatilir.
local VOID = vector3(-6500.0, -6500.0, 100.0)

-- Kullanici oyunda dial etti (klavye canli-ayar). Kalici degerler:
local CAM_DIST   = 3.55   -- kameranin klona uzakligi
local CAM_HEIGHT = 0.20   -- kamera yuksekligi (klon merkezine gore)
local CAM_SIDE   = -0.98  -- YATAY: bakis hedefi kaydirma (ped ekranda sola)
local CAM_FOV    = 44.0   -- gorus acisi
local CAM_LOOK_Z = -0.05  -- bakis hedefi yuksekligi (buyuk = ped karede ASAGI/ayaklar alta)

local TOP_DIST   = 2.0    -- "ust" acisinda uzaklik
local TOP_HEIGHT = 1.15   -- "ust" acisinda yukseklik
-- BLUR timecycle KULLANMA (karakter bulaniklasiyordu). Yeralti void zaten koyu;
-- ped kendi isiklarimizla aydinlanir. Gerekirse koyu (blur DEGIL) modifier dene.
local DARK_TIMECYCLE = nil

-- BACKDROP: klonun ARKASINA konan buyuk prop -> dunyayi kapatir, KOYU zemin verir.
-- NOT: GTA'da ped SADECE dunyada render olur; render-target/DUI ped'i texture'a
-- alamaz (onlar scaleform/web icin). Bu yuzden "pur siyah" yerine koyu backdrop +
-- spot isik = mockup'taki "isikli void" gorunumu. /cam ile oyunda ayarlanabilir.
local BACKDROP_MODEL   = `prop_container_01a` -- buyuk duz yuzey; /cam bmodel <model>
local BACKDROP_DIST    = 2.4   -- ped'in ARKASINA (kameradan uzak yon) uzaklik
local BACKDROP_ZOFF    = 0.0   -- dikey kaydirma (prop merkezini karede otur)
local BACKDROP_HEADOFF = 90.0  -- prop'un DUZ yuzunu kameraya cevir

-- Seviye -> spot isik RGB (tema paletiyle ayni: L0 gri ... L5 altin)
local LEVEL_RGB = {
    [0] = { 139, 147, 167 },
    [1] = { 223, 226, 238 },
    [2] = { 47, 155, 255 },
    [3] = { 192, 38, 211 },
    [4] = { 255, 122, 26 },
    [5] = { 245, 197, 24 },
}

------------------------------------------------------------------------------
-- DURUM
------------------------------------------------------------------------------
local sceneActive = false
local clone = nil
local backdrop = nil      -- arka plan prop'u (dunyayi kapatir)
local cam = nil
local realPed = nil       -- gercek oyuncu (dondurulur, sahne suresince)
local heading = 0.0       -- klonun bakis yonu (donmus)
local topView = false     -- ust aci acik/kapali
local currentLevel = 0    -- spot isik rengi icin

-- Canta seviyesini dinle (isik rengi). Ayni event bag backend'inde de var; birden
-- fazla handler sorun degil.
RegisterNetEvent('bitirim:client:bagLevel', function(level)
    currentLevel = math.max(0, math.min(5, math.floor(tonumber(level) or 0)))
end)

--- Backdrop'u klonun ARKASINA (kameradan uzak yon = -on vektor) yerlestir ve duz
--- yuzunu kameraya cevir. Klon dondugunde de arkada kalir.
local function positionBackdrop()
    if not backdrop or not DoesEntityExist(backdrop) or not clone or not DoesEntityExist(clone) then return end
    local cc = GetEntityCoords(clone)
    local h = math.rad(GetEntityHeading(clone))
    local fx, fy = -math.sin(h), math.cos(h) -- klonun ONU
    SetEntityCoordsNoOffset(backdrop, cc.x - fx * BACKDROP_DIST, cc.y - fy * BACKDROP_DIST, cc.z + BACKDROP_ZOFF, false, false, false)
    SetEntityHeading(backdrop, GetEntityHeading(clone) + BACKDROP_HEADOFF)
end

--- Backdrop prop'unu (yeniden) yarat: eskiyi sil, BACKDROP_MODEL'i yukle + koy.
local function spawnBackdrop()
    if backdrop and DoesEntityExist(backdrop) then DeleteEntity(backdrop) end
    backdrop = nil
    if not clone or BACKDROP_MODEL == 0 then return end
    RequestModel(BACKDROP_MODEL)
    local t = 0
    while not HasModelLoaded(BACKDROP_MODEL) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(BACKDROP_MODEL) then
        print('^1[bitirim] backdrop model yuklenemedi^7'); return
    end
    local cc = GetEntityCoords(clone)
    backdrop = CreateObject(BACKDROP_MODEL, cc.x, cc.y, cc.z + BACKDROP_ZOFF, false, false, false)
    SetEntityInvincible(backdrop, true)
    FreezeEntityPosition(backdrop, true)
    SetEntityCollision(backdrop, false, false)
    SetEntityLodDist(backdrop, 1000)
    SetModelAsNoLongerNeeded(BACKDROP_MODEL)
    positionBackdrop()
end

--- Kamerayi klonun onune yerlestir + klona baktir. Ped'i ekranin SOLUNA almak
--- icin: kamera TAM ONDE durur, ama BAKIS HEDEFI saga kaydirilir (CAM_SIDE) ->
--- ped karede sola kayar. (Eskiden hem kamera hem hedef ayni yana kayiyordu =
--- ped ortada kaliyordu; duzeltildi.)
local function positionCamera()
    if not cam or not clone or not DoesEntityExist(clone) then return end

    local dist = topView and TOP_DIST or CAM_DIST
    local height = topView and TOP_HEIGHT or CAM_HEIGHT

    local cc = GetEntityCoords(clone)
    local cx, cy, cz = cc.x, cc.y, cc.z
    local h = math.rad(GetEntityHeading(clone))
    local fx, fy = -math.sin(h), math.cos(h)   -- klonun ONU (yuzune baktigimiz yon)
    local rx, ry = math.cos(h), math.sin(h)    -- saga vektor

    -- Kamera tam onde (yana kaydirma YOK).
    SetCamCoord(cam, cx + fx * dist, cy + fy * dist, cz + height)
    -- Bakis hedefi saga kaydik -> ped karede SOLA gelir. topView'da yukaridan bakar.
    PointCamAtCoord(cam, cx + rx * CAM_SIDE, cy + ry * CAM_SIDE, cz + (topView and 0.0 or CAM_LOOK_Z))
    SetCamFov(cam, CAM_FOV)
    positionBackdrop()
end

--- Sahneyi ac: klon + kamera + void + koyu sahne.
local function openScene()
    if sceneActive then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    realPed = ped

    -- Klon (gorunum + kiyafetler kopyalanir).
    clone = ClonePed(ped, GetEntityHeading(ped), true, true)
    if not clone or clone == 0 or not DoesEntityExist(clone) then
        print('^1[bitirim] karakter sahnesi: ClonePed BASARISIZ^7')
        clone = nil
        return
    end
    -- Emniyet: gorunumu (component/prop) hedefe kopyala (klon eksik kopyalarsa).
    pcall(ClonePedToTarget, ped, clone)
    print(('^2[bitirim] karakter sahnesi ACILDI: clone=%s^7'):format(tostring(clone)))

    SetEntityCoordsNoOffset(clone, VOID.x, VOID.y, VOID.z, false, false, false)
    FreezeEntityPosition(clone, true)
    SetEntityInvincible(clone, true)
    SetEntityCollision(clone, false, false)
    SetBlockingOfNonTemporaryEvents(clone, true)
    SetEntityLodDist(clone, 1000) -- uzak void'de klon net kalsin
    heading = 180.0 -- kameraya donuk baslasin (AYARLA)
    SetEntityHeading(clone, heading)

    -- Void'i akit/gorunur kil (oyuncu uzakta; kamera oraya baksin).
    RequestCollisionAtCoord(VOID.x, VOID.y, VOID.z)
    SetFocusPosAndVel(VOID.x, VOID.y, VOID.z, 0.0, 0.0, 0.0)

    -- Arka plan backdrop (dunyayi kapatir -> koyu zemin).
    spawnBackdrop()

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    topView = false
    -- Depth-of-field KAPALI (ped bulaniklasmasin).
    SetCamUseShallowDofMode(cam, false)
    SetCamDofStrength(cam, 0.0)
    SetCamNearDof(cam, 0.0)
    SetCamFarDof(cam, 1000.0)
    positionCamera()
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    if DARK_TIMECYCLE then pcall(SetTimecycleModifier, DARK_TIMECYCLE) end

    -- ASIL BULANIKLIK SEBEBI: ox envanter acilinca TriggerScreenblurFadeIn cagirir
    -- (tum oyunu, ped'i de bulanaklastirir). Karakter onizlemesi net olsun diye
    -- ekran blur'unu KAPAT.
    TriggerScreenblurFadeOut(0.0)

    -- Gercek oyuncu sahne suresince dondurulur (NUI input aciklen kaymasin).
    FreezeEntityPosition(realPed, true)

    sceneActive = true

    -- Spot isik + blur-kill + zoom-kilit dongusu (yalniz sahne acikken). Kamera
    -- degerleri KALICI; canli klavye ayari kaldirildi (kazara zoom yapiyordu).
    -- Backdrop/kamera ince ayari gerekirse /cam komutu (chat) ile yapilir.
    CreateThread(function()
        while sceneActive and clone and DoesEntityExist(clone) do
            local rgb = LEVEL_RGB[currentLevel] or LEVEL_RGB[0]
            local cc = GetEntityCoords(clone)
            local cx, cy, cz = cc.x, cc.y, cc.z
            -- Beyaz ON DOLGU: kamera tarafindan -> ped hangi acida olursa olsun
            -- gorunen yuzu aydinlanir (siyah void'de net durur).
            if cam then
                local cp = GetCamCoord(cam)
                DrawLightWithRange(cp.x, cp.y, cp.z, 255, 255, 255, CAM_DIST + 3.0, 2.2)
            end
            -- Seviye-renkli ust/arka GLOW (tema vurgusu).
            DrawLightWithRange(cx, cy, cz + 1.7, rgb[1], rgb[2], rgb[3], 4.5, 2.6)
            DrawLightWithRangeAndShadow(cx, cy, cz + 0.4, rgb[1], rgb[2], rgb[3], 3.5, 1.2, 0.0)

            -- Ekran blur'unu (ox screenblur) her karede SIFIRDA tut. ox envanter
            -- acilinca TriggerScreenblurFadeIn cagirir; tek seferlik FadeOut fade-in
            -- ile yarisabiliyor -> her karede kapat = kesin cozum.
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
            TriggerScreenblurFadeOut(0.0)

            -- ZOOM/tekerlek kontrollerini kapat (kazara yakinlastirma/uzaklastirma
            -- olmasin). Kamera degerleri artik KALICI; canli klavye ayari kaldirildi.
            DisableControlAction(0, 14, true)   -- weapon wheel next (tekerlek asagi)
            DisableControlAction(0, 15, true)   -- weapon wheel prev (tekerlek yukari)
            DisableControlAction(0, 16, true)   -- select next weapon
            DisableControlAction(0, 17, true)   -- select prev weapon
            DisableControlAction(0, 96, true)   -- "-" (INPUT_VEH_...)
            DisableControlAction(0, 97, true)   -- "+"
            DisableControlAction(0, 241, true)  -- cursor scroll up
            DisableControlAction(0, 242, true)  -- cursor scroll down
            DisableControlAction(0, 261, true)  -- look scroll
            DisableControlAction(0, 262, true)

            Wait(0)
        end
    end)
end

--- Sahneyi kapat: her seyi temizle.
local function closeScene()
    if not sceneActive then return end
    sceneActive = false

    RenderScriptCams(false, false, 0, true, true)
    if cam then DestroyCam(cam, false); cam = nil end
    if backdrop and DoesEntityExist(backdrop) then DeleteEntity(backdrop) end
    backdrop = nil
    if clone and DoesEntityExist(clone) then DeleteEntity(clone) end
    clone = nil

    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    ClearFocus()

    -- Gercek oyuncuyu coz.
    if realPed and DoesEntityExist(realPed) then
        FreezeEntityPosition(realPed, false)
    end
    realPed = nil
    topView = false
end

------------------------------------------------------------------------------
-- NUI KOPRUSU
------------------------------------------------------------------------------
-- Envanter karakter paneli gorundu/gizlendi (index.tsx yollar).
RegisterNUICallback('bitirim:charScene', function(data, cb)
    cb(1)
    if type(data) == 'table' and data.open then
        openScene()
    else
        closeScene()
    end
end)

-- Donme: sol/sag (heading), ust (kamera aci), drag (heading delta).
RegisterNUICallback('bitirim:charRotate', function(data, cb)
    cb(1)
    if not sceneActive or not clone or not DoesEntityExist(clone) then return end

    local mode = type(data) == 'table' and data.mode or nil
    if mode == 'left' then
        heading = (heading + 45.0) % 360.0
        SetEntityHeading(clone, heading)
    elseif mode == 'right' then
        heading = (heading - 45.0) % 360.0
        SetEntityHeading(clone, heading)
    elseif mode == 'top' then
        topView = not topView
    elseif mode == 'drag' then
        local delta = tonumber(data.value) or 0.0
        heading = (heading - delta * 0.4) % 360.0 -- hassasiyet AYARLA
        SetEntityHeading(clone, heading)
    end

    positionCamera()
end)

--[[
    /cam — CANLI KAMERA AYARI (sahne acikken kullan). Ped'i karakter penceresinin
    ortasina/istedigin boyuta oturtmak icin degerleri degistir; begenince cikan
    degerleri bana soyle, kalici yaparim.
      /cam dist <n>    kamera uzakligi (buyuk = ped kucuk/uzak)
      /cam side <n>    yatay: buyuk = ped daha SOLA (bakis hedefi saga kayar)
      /cam height <n>  kamera yuksekligi
      /cam fov <n>     gorus acisi (kucuk = yakinlasma)
      /cam lookz <n>   bakis hedefi yuksekligi (gogus/yuz)
      -- BACKDROP (arka plan prop'u):
      /cam bmodel <model>  backdrop prop modelini degistir (or: prop_container_01a)
      /cam bdist <n>       backdrop'un ped arkasina uzakligi
      /cam bzoff <n>       backdrop dikey kaydirma
      /cam bhead <n>       backdrop yuzunun kameraya donme acisi
      /cam show            guncel degerleri F8'e yazar
]]
RegisterCommand('cam', function(_, args)
    local p, v = args[1], tonumber(args[2])
    if p == 'dist' and v then CAM_DIST = v
    elseif p == 'side' and v then CAM_SIDE = v
    elseif p == 'height' and v then CAM_HEIGHT = v
    elseif p == 'fov' and v then CAM_FOV = v
    elseif p == 'lookz' and v then CAM_LOOK_Z = v
    elseif p == 'bdist' and v then BACKDROP_DIST = v
    elseif p == 'bzoff' and v then BACKDROP_ZOFF = v
    elseif p == 'bhead' and v then BACKDROP_HEADOFF = v
    elseif p == 'bmodel' and args[2] then
        BACKDROP_MODEL = GetHashKey(args[2])
        if sceneActive then spawnBackdrop() end
        print('^3[bitirim] backdrop model = '..args[2]..'^7')
        return
    end

    positionCamera()
    print(('^3[bitirim] cam dist=%.2f side=%.2f height=%.2f fov=%.1f lookz=%.2f | backdrop dist=%.2f zoff=%.2f head=%.1f (sahne:%s)^7')
        :format(CAM_DIST, CAM_SIDE, CAM_HEIGHT, CAM_FOV, CAM_LOOK_Z, BACKDROP_DIST, BACKDROP_ZOFF, BACKDROP_HEADOFF, tostring(sceneActive)))
end, false)

-- Emniyet: kaynak durursa temizle.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then closeScene() end
end)
