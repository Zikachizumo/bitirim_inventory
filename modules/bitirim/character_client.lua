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

    -- Onceki oturumdan kalmis olabilecek TUM timecycle modifier'lari temizle
    -- (eski BLUR modifier'i takili kaliyordu -> karakter bulanik). ClearFocus'suz.
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    if DARK_TIMECYCLE then pcall(SetTimecycleModifier, DARK_TIMECYCLE) end

    -- Gercek oyuncu sahne suresince dondurulur (NUI input aciklen kaymasin).
    FreezeEntityPosition(realPed, true)

    sceneActive = true

    -- Spot isik + KLAVYE CANLI AYAR dongusu (yalniz sahne acikken). Envanter
    -- acikken chat (T) acilmadigi icin kamera ok tuslari + fare tekerlegi ile
    -- ayarlanir; degerler degisince F8'e yazilir (begenince bana soyle).
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

            -- Canli ayar (ok tuslari + tekerlek). Hem enabled hem disabled kontrol
            -- (NUI odakli iken bazi kontroller disabled olabilir). Kontroller:
            -- 174/175 sol/sag ok, 172/173 yukari/asagi ok, 241/242 tekerlek, 96/97 pad.
            local function pressed(c) return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) end
            local shift = IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21) -- LSHIFT
            local changed = false
            if pressed(174) then CAM_SIDE = CAM_SIDE - 0.05; changed = true end
            if pressed(175) then CAM_SIDE = CAM_SIDE + 0.05; changed = true end
            -- Yukari/asagi ok: SHIFT'siz = kamera yuksekligi; SHIFT'li = ped'i karede
            -- yukari/asagi al (lookz -> ayak hizasi). Shift+asagi = ayaklar ALTA.
            if pressed(172) then
                if shift then CAM_LOOK_Z = CAM_LOOK_Z - 0.03 else CAM_HEIGHT = CAM_HEIGHT + 0.05 end
                changed = true
            end
            if pressed(173) then
                if shift then CAM_LOOK_Z = CAM_LOOK_Z + 0.03 else CAM_HEIGHT = CAM_HEIGHT - 0.05 end
                changed = true
            end
            if pressed(241) then CAM_DIST = math.max(0.5, CAM_DIST - 0.1); changed = true end
            if pressed(242) then CAM_DIST = CAM_DIST + 0.1; changed = true end
            if pressed(96) then CAM_FOV = math.max(10.0, CAM_FOV - 1.0); changed = true end
            if pressed(97) then CAM_FOV = math.min(90.0, CAM_FOV + 1.0); changed = true end

            if changed then
                positionCamera()
                print(('^3[bitirim] cam dist=%.2f side=%.2f height=%.2f fov=%.1f lookz=%.2f^7')
                    :format(CAM_DIST, CAM_SIDE, CAM_HEIGHT, CAM_FOV, CAM_LOOK_Z))
            end

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
      /cam show        guncel degerleri F8'e yazar
]]
RegisterCommand('cam', function(_, args)
    local p, v = args[1], tonumber(args[2])
    if p == 'dist' and v then CAM_DIST = v
    elseif p == 'side' and v then CAM_SIDE = v
    elseif p == 'height' and v then CAM_HEIGHT = v
    elseif p == 'fov' and v then CAM_FOV = v
    elseif p == 'lookz' and v then CAM_LOOK_Z = v
    end

    positionCamera()
    print(('^3[bitirim] cam dist=%.2f side=%.2f height=%.2f fov=%.1f lookz=%.2f (sahne:%s)^7')
        :format(CAM_DIST, CAM_SIDE, CAM_HEIGHT, CAM_FOV, CAM_LOOK_Z, tostring(sceneActive)))
end, false)

-- Emniyet: kaynak durursa temizle.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then closeScene() end
end)
