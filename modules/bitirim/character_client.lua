--[[
    Bitirim — ENVANTERDE CANLI 3B KARAKTER ONIZLEMESI ("STUDYO" sahnesi)
    --------------------------------------------------------------------
    Envanterin KARAKTER paneli goruncе, oyuncunun bir KLONU gizli bir sahneye
    (VOID) tasinir ve gercek ped gizlenir; kamera klona bakar; ekranin karakter
    panelindeki SEFFAF delikten bu klon gorunur. Giyili kiyafetler klona kopyalanir.

    ARKA PLAN = TASARLANMIS KOYU STUDYO (referans gorsele gore, Option A):
      - VOID + BACKDROP prop dunyayi kapatir + NetworkOverrideClockTime(gece) ->
        temiz KOYU zemin (gercek dunya gorunmez, tutarli).
      - STUDYO ISIK: void'de gunes yok -> ped'i BIZ aydinlatiriz.
          * KEY  = beyaz on dolgu (kameradan) -> ped parlak/net.
          * AURA = canta-seviyesi renginde arka glow -> backdrop'ta hafif renkli
                   gradyan (referanstaki mor his). Backdrop KONTROLLU oldugu icin
                   bu isiklar BLOOM/HAZE yapmaz (o sorun gercek dunya parlakken
                   oluyordu; burada isik tasarimin parcasi).
      - Ayak alti yuvarlak zemin golgesi/yansimasi = CSS (.bx-char-view::after).

    Dondurme: NUI'den (bitirim:charRotate) sol/sag (heading) + fareyle surukle.
    Ince ayar: /cam komutu (kamera + backdrop + isik). Sahne acikken kullan.
]]

------------------------------------------------------------------------------
-- AYAR SABITLERI (oyunda /cam ile ayarlanabilir)
------------------------------------------------------------------------------
-- VOID: gizli/bos sahne konumu. Backdrop dunyayi kapatir, gece override karartir.
local VOID = vector3(1000.0, -2000.0, 250.0)

-- Kamera (kullanici oyunda dial etti — kalici degerler)
local CAM_DIST   = 3.55   -- kameranin klona uzakligi
local CAM_HEIGHT = 0.20   -- kamera yuksekligi (klon merkezine gore)
local CAM_SIDE   = -0.98  -- YATAY: bakis hedefi kaydirma (ped ekranda sola)
local CAM_FOV    = 44.0   -- gorus acisi
local CAM_LOOK_Z = -0.05  -- bakis hedefi yuksekligi

local TOP_DIST   = 2.0    -- "ust" acisinda uzaklik
local TOP_HEIGHT = 1.15   -- "ust" acisinda yukseklik

-- BACKDROP: ped'in ARKASINA konan buyuk prop -> dunyayi kapatir, koyu studyo zemin.
-- Karanlik sahne + AURA isigi ile referanstaki gradyan. /cam bmodel/bdist/bzoff/bhead.
local BACKDROP_MODEL   = `prop_container_01a` -- duz genis yuzey (koyu sahnede notr)
local BACKDROP_DIST    = 2.6   -- ped'in ARKASINA (kameradan uzak yon) uzaklik
local BACKDROP_ZOFF    = 0.0   -- dikey kaydirma
local BACKDROP_HEADOFF = 90.0  -- prop'un DUZ yuzunu kameraya cevir

-- STUDYO ISIK siddet/menzil (void'de gunes yok). /cam keyint/keyrange/auraint/aurarange.
local KEY_INT    = 2.4   -- beyaz key light siddeti (ped parlakligi)
local KEY_RANGE  = 4.2   -- key menzili (~ped'e yetsin, backdrop'a az tassin)
local KEY_ZOFF   = 0.35  -- key yuksekligi (kamera hizasindan yukari)
local AURA_INT   = 2.6   -- seviye-renkli arka aura siddeti
local AURA_RANGE = 5.5   -- aura menzili (backdrop'a yayilsin)
local AURA_ZOFF  = 1.05  -- aura yuksekligi (ped govde/omuz hizasi)

-- Gece override saati (backdrop/void karartma). 0-4 arasi en koyu.
local NIGHT_HOUR = 1

-- Seviye -> AURA RGB (tema paleti: L0 gri ... L5 altin)
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
local currentLevel = 0    -- aura rengi icin

-- Canta seviyesini dinle (aura rengi).
RegisterNetEvent('bitirim:client:bagLevel', function(level)
    currentLevel = math.max(0, math.min(5, math.floor(tonumber(level) or 0)))
end)

--- Backdrop'u klonun ARKASINA (kameradan uzak yon = -on vektor) yerlestir.
local function positionBackdrop()
    if not backdrop or not DoesEntityExist(backdrop) or not clone or not DoesEntityExist(clone) then return end
    local cc = GetEntityCoords(clone)
    local h = math.rad(GetEntityHeading(clone))
    local fx, fy = -math.sin(h), math.cos(h) -- klonun ONU
    SetEntityCoordsNoOffset(backdrop, cc.x - fx * BACKDROP_DIST, cc.y - fy * BACKDROP_DIST, cc.z + BACKDROP_ZOFF, false, false, false)
    SetEntityHeading(backdrop, GetEntityHeading(clone) + BACKDROP_HEADOFF)
end

--- Backdrop prop'unu (yeniden) yarat.
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

--- Kamerayi klonun onune yerlestir + klona baktir (ped ekranda SOLA).
local function positionCamera()
    if not cam or not clone or not DoesEntityExist(clone) then return end

    local dist = topView and TOP_DIST or CAM_DIST
    local height = topView and TOP_HEIGHT or CAM_HEIGHT

    local cc = GetEntityCoords(clone)
    local cx, cy, cz = cc.x, cc.y, cc.z
    local h = math.rad(GetEntityHeading(clone))
    local fx, fy = -math.sin(h), math.cos(h)   -- klonun ONU (yuzune baktigimiz yon)
    local rx, ry = math.cos(h), math.sin(h)    -- saga vektor

    SetCamCoord(cam, cx + fx * dist, cy + fy * dist, cz + height)
    PointCamAtCoord(cam, cx + rx * CAM_SIDE, cy + ry * CAM_SIDE, cz + (topView and 0.0 or CAM_LOOK_Z))
    SetCamFov(cam, CAM_FOV)
    positionBackdrop()
end

--- Sahneyi ac: klon -> VOID + backdrop + gece + studyo isik.
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
    pcall(ClonePedToTarget, ped, clone)
    print(('^2[bitirim] karakter sahnesi ACILDI: clone=%s^7'):format(tostring(clone)))

    -- Klonu VOID'e tasi (gizli studyo sahnesi).
    SetEntityCoordsNoOffset(clone, VOID.x, VOID.y, VOID.z, false, false, false)
    FreezeEntityPosition(clone, true)
    SetEntityInvincible(clone, true)
    SetEntityCollision(clone, false, false)
    SetBlockingOfNonTemporaryEvents(clone, true)
    SetEntityLodDist(clone, 1000)
    heading = 180.0 -- kameraya donuk baslasin
    SetEntityHeading(clone, heading)

    -- Gercek oyuncuyu GIZLE + dondur.
    SetEntityVisible(realPed, false, false)
    FreezeEntityPosition(realPed, true)

    -- Void'i akit/gorunur kil.
    RequestCollisionAtCoord(VOID.x, VOID.y, VOID.z)
    SetFocusPosAndVel(VOID.x, VOID.y, VOID.z, 0.0, 0.0, 0.0)

    -- Backdrop (dunyayi kapatir -> koyu studyo zemin).
    spawnBackdrop()

    -- KOYU sahne: yerel saati GECEYE cevir (backdrop + void kararir). Sadece bu
    -- client; kapaninca geri alinir.
    NetworkOverrideClockTime(NIGHT_HOUR, 0, 0)

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    topView = false
    -- Depth-of-field KAPALI (ped net).
    SetCamUseShallowDofMode(cam, false)
    SetCamDofStrength(cam, 0.0)
    SetCamNearDof(cam, 0.0)
    SetCamFarDof(cam, 1000.0)
    positionCamera()
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()

    -- ox screenblur KAPAT (ped net kalsin).
    TriggerScreenblurFadeOut(0.0)

    sceneActive = true

    -- STUDYO ISIK + blur-kill + zoom-kilit dongusu (yalniz sahne acikken).
    CreateThread(function()
        while sceneActive and clone and DoesEntityExist(clone) do
            local rgb = LEVEL_RGB[currentLevel] or LEVEL_RGB[0]
            local cc = GetEntityCoords(clone)
            local h = math.rad(GetEntityHeading(clone))
            local fx, fy = -math.sin(h), math.cos(h) -- klonun ONU

            -- KEY light: kameradan (on) beyaz dolgu -> ped parlak/net. Menzil kisa
            -- ki cogunlukla ped'e vursun (backdrop'ta az iz).
            if cam then
                local cp = GetCamCoord(cam)
                DrawLightWithRange(cp.x, cp.y, cp.z + KEY_ZOFF, 255, 252, 246, KEY_RANGE, KEY_INT)
            end
            -- AURA: ped ile backdrop ARASINDA seviye-renkli glow -> backdrop'ta
            -- yumusak renkli gradyan (referanstaki his). Ped'in ARKASINA (-on) koy.
            local ax = cc.x - fx * (BACKDROP_DIST * 0.55)
            local ay = cc.y - fy * (BACKDROP_DIST * 0.55)
            DrawLightWithRange(ax, ay, cc.z + AURA_ZOFF, rgb[1], rgb[2], rgb[3], AURA_RANGE, AURA_INT)

            -- ox screenblur her karede kapali tut.
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
            TriggerScreenblurFadeOut(0.0)

            -- ZOOM/tekerlek kontrollerini kapat.
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 96, true)
            DisableControlAction(0, 97, true)
            DisableControlAction(0, 241, true)
            DisableControlAction(0, 242, true)
            DisableControlAction(0, 261, true)
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
    NetworkClearClockTimeOverride() -- gece override geri al

    -- Gercek oyuncuyu geri gorunur yap + coz.
    if realPed and DoesEntityExist(realPed) then
        SetEntityVisible(realPed, true, false)
        FreezeEntityPosition(realPed, false)
    end
    realPed = nil
    topView = false
end

------------------------------------------------------------------------------
-- NUI KOPRUSU
------------------------------------------------------------------------------
RegisterNUICallback('bitirim:charScene', function(data, cb)
    cb(1)
    if type(data) == 'table' and data.open then
        openScene()
    else
        closeScene()
    end
end)

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
        heading = (heading - delta * 0.4) % 360.0
        SetEntityHeading(clone, heading)
    end

    positionCamera()
end)

--[[
    /cam — CANLI AYAR (sahne acikken). Begenince cikan degerleri bana soyle.
      -- KAMERA:
      /cam dist <n> | side <n> | height <n> | fov <n> | lookz <n>
      -- BACKDROP (arka plan prop'u):
      /cam bmodel <model> | bdist <n> | bzoff <n> | bhead <n>
      -- ISIK (studyo):
      /cam keyint <n>   key (beyaz) isik siddeti
      /cam keyrange <n> key menzili
      /cam auraint <n>  seviye-renkli aura siddeti
      /cam aurarange <n> aura menzili
      /cam night <0-23> gece saati (koyuluk)
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
    elseif p == 'keyint' and v then KEY_INT = v
    elseif p == 'keyrange' and v then KEY_RANGE = v
    elseif p == 'auraint' and v then AURA_INT = v
    elseif p == 'aurarange' and v then AURA_RANGE = v
    elseif p == 'night' and v then NIGHT_HOUR = math.floor(v); if sceneActive then NetworkOverrideClockTime(NIGHT_HOUR, 0, 0) end
    elseif p == 'bmodel' and args[2] then
        BACKDROP_MODEL = GetHashKey(args[2])
        if sceneActive then spawnBackdrop() end
        print('^3[bitirim] backdrop model = '..args[2]..'^7')
        return
    end

    positionCamera()
    print(('^3[bitirim] cam d=%.2f side=%.2f h=%.2f fov=%.1f lookz=%.2f | bdrop dist=%.2f zoff=%.2f head=%.1f | key int=%.1f rng=%.1f | aura int=%.1f rng=%.1f | night=%d^7')
        :format(CAM_DIST, CAM_SIDE, CAM_HEIGHT, CAM_FOV, CAM_LOOK_Z, BACKDROP_DIST, BACKDROP_ZOFF, BACKDROP_HEADOFF, KEY_INT, KEY_RANGE, AURA_INT, AURA_RANGE, NIGHT_HOUR))
end, false)

-- Emniyet: kaynak durursa temizle.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then closeScene() end
end)
