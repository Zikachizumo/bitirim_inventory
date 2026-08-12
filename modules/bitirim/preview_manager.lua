--[[
    Bitirim — PREVIEW MANAGER (STUDIO / "Studio Camera" KARAKTER ONIZLEMESI)
    ============================================================================
    STUDIO MIMARISI: Envanter acilinca, oyuncunun YEREL (local-only) bir klonu
    oyuncunun O ANKI konumunun `cfg.heightOffset` metre TAM USTUNDE (havada, void'e
    yakin) durur; ona bakan SCRIPTED bir kamera devreye girer; klonun arkasina
    TAM KAPLAYAN siyah panel konur.
        GERCEK OYUNCU ──► Gercek Player Ped  (yerel GIZLI; agda normal gorunur)
                      └──► Mirror Klon Ped    (YEREL; oyuncunun USTUNDE; studio
                                                kamerasi buna bakar)

    NEDEN "OYUNCUNUN AYNI X/Y'SI, FARKLI Z'SI" (SABIT UZAK VOID KOORDINATI DEGIL):
    - Once tek bir SABIT uzak dunya koordinati (kullanicinin verdigi vec4) denendi.
      Sorun: kamera + klon + backdrop o UZAK noktaya tasininca, motor o bolgeyi
      stream etmeye baslar ve oyuncunun GERCEK bulundugu yerin cevresi "soguyabilir"
      (stream disi kalabilir). Envanter kapaninca kamera ANINDA (0ms) gameplay'e
      donunce, oyuncunun etrafi henuz tam stream olmamis olabilir -> "oyuna donunce
      render sorunu" (pop-in/LOD/kara ekran hissi). Kullanici bunu bildirdi.
    - COZUM: klon HER ACILISTA oyuncunun O ANKI X/Y konumunun AYNISINDA, farkli bir
      Z'de konur (`cfg.heightOffset`). X/Y oyuncuyla AYNI oldugu icin cevresindeki
      stream hep "sicak" kalir (kamera uzaklasmaz, sadece dikeyde kayar) -> ani
      kapanista render sorunu olmaz.
    - ASAGI (NEGATIF/haritanin alti) DENENDI, TERK EDILDI: klon gercek zemin/kayaya
      gomuluyordu -> "haritanin altı" guvenilir bos void degil. YUKARI (acik gokyuzu)
      guvenilir bos alan -> heightOffset pozitif kalir (su an +5, KUCUK -> asagidaki
      GERCEK gizlilik cozumu sayesinde artik BUYUK olmasina GEREK YOK).
    - Gameplay kamerasi (TP/FP/egim) hala ONEMSIZ: kendi scripted kameramiz klona
      SABIT bir acidan bakar -> arka plan HER ZAMAN %100 kapli.
    - GECIS ANIMASYONU YOK: envanter acilir acilmaz (bir sonraki frame) direkt studio
      kadrajina gecilir (RenderScriptCams ease=false); kapaninca da aninda gameplay'e
      doner (yaris durumu/entity sizintisi riskine karsi da aninda kesim tercih edildi).
    - Insurance icin 2 backdrop paneli (ters heading; hangisi "on yuz" olursa olsun
      biri HER ZAMAN kameraya doner). NOT: backdrop artik varsayilan olarak KAPALI
      (cfg.balpha=0, kullanici istegi, bkz asagisi) — arka plan artik GERCEK oyun
      dunyasi (seffaf). Kamera KLONUN ARKASINDA durur ve klonla AYNI yone bakar
      (computeCameraBasis'teki YON DUZELTMESI notuna bak) -> gorunen manzara artik
      karakterin GERCEKTEN baktigi yonle eslesir.

    **AG-GORUNURLUGU — GERCEK KOK NEDEN BULUNDU VE COZULDU (2026-08-12):**
    `ClonePed(...,isNetwork=false,...)` bu sunucuda previewPed'i GERCEKTEN yerel
    tutmuyor — F8 debug ile KANITLANDI: `NetworkGetEntityIsNetworked(previewPed)`
    ClonePed'in HEMEN ARDINDAN (bizim hicbir kodumuz calismadan once) bile `true`
    donuyordu (bircok adimda bisect edildi, SUCLU BIZIM KODUMUZ DEGIL — ClonePed'in
    kendisi/FiveM'in bu ortamdaki davranisi). Yani "yerel kalma" garantisine
    GUVENILEMEZ, bu YONTEM TAMAMEN TERK EDILDI (mesafe/LOD tabanli onceki denemeler
    de bu yuzden yetersiz kaliyordu — networked bir entity'nin LOD/gorunurlugu
    HER CLIENT KENDI degerini kullanir, yaratanin ayarladigi deger baskalarina
    YANSIMAZ). **GERCEK COZUM:** klon `SetEntityVisible(previewPed,false,false)`
    ile agdaki HERKESE (biz dahil) gorunmez yapilir, SONRA render thread'de HER
    KARE `SetEntityLocallyVisible(previewPed)` ile SADECE bizim client'imizda
    uzerine yazilir (tipki gercek ped icin kullanilan `SetEntityLocallyInvisible`'in
    TAM TERSI — ayni desen, matematiksel garantisi var: baska hicbir client bu
    override'i cagirmiyor, dolayisiyla klon onlarin ekraninda HICBIR ZAMAN
    gorunmez, mesafe/LOD/ne olursa olsun). Detay: `CreatePreview`'daki ilgili not.
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
    -- klon, oyuncunun O ANKI konumunun (ayni X/Y) kac metre USTUNDE durur.
    -- NEGATIF (ASAGI/haritanin alti) DENENDI, TERK EDILDI: -1000'de klon GERCEK
    -- ZEMIN/KAYAYA gomuluyordu -> "haritanin altı" guvenilir void degil, SADECE
    -- YUKARI (acik gokyuzu) guvenilir bos alan. Baskalarina gorunmezlik ARTIK bu
    -- degerden BAGIMSIZ (SetEntityVisible+SetEntityLocallyVisible deseni, bkz
    -- CreatePreview) -> KUCUK/rahat bir deger yeterli, sadece render/streaming
    -- kalitesi icin ayarlanir.
    heightOffset = 2.0,

    -- Oyuncu bir BINA/INTERIOR icindeyse (GetInteriorFromEntity ~= 0), "ustu" mantikli
    -- degil (interior'lar dunyada farkli/istiflenmis konumlarda olabilir) -> bunun
    -- yerine kullanicinin daha once test ettigi SABIT sehir-yolu konumuna dusulur.
    interiorFallbackPos  = vector3(-301.72, -71.13, 316.92),
    interiorFallbackHead = 149.61,

    camDist   = 2.55,  -- kamera klonun ONUNDE kac metre (SABIT; sadece /cam ile degisir)
    camSide   = -1.10, -- KLONUN yatay konumu (kamera-sag ekseni) — KALICI (kullanici dial etti)
    camHeight = 0.05,  -- KLONUN dikey konumu (dunya-yukari ekseni) — KALICI (kullanici dial etti)
    lookDown  = 0.30,  -- bakis hedefi: ust gogusun kac metre ALTI (govde ortasi)
    fov       = 64.0,  -- gorus acisi (dar=yakin/buyuk gorunur) — KALICI (kullanici dial etti)
    backDist  = 2.40,  -- backdrop klonun kac metre ARKASINDA
    backZ     = 0.0,   -- backdrop dikey ince ayar
    -- TEK NOKTA: butun panellerin (karakter/envanter/depo/bagaj/torpido) arka plan
    -- OPAKLIGI burasi. KULLANICI ISTEGI (2026-08-12): arka plan KOMPLE KALDIRILDI,
    -- tamamen seffaf -> 0. spawnBackdrop() balpha<=0 iken hic obje SPAWN ETMEZ
    -- (asagida) -> gercek gorunmez obje degil, GERCEKTEN yok. Geri istenirse SADECE
    -- bu sayiyi degistir (>0 yap), baska hicbir yeri DOKUNMA.
    balpha    = 0,
    bmodel    = 'bitirim_backdrop01',  -- stream'deki 50m SIYAH panel (SABIT - canta seviyesine gore degismez)
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
local anchorPos    = nil    -- klonun durdugu konum (oyuncu XY + heightOffset Z) — HER ACILISTA yeniden hesaplanir
local anchorHead   = 0.0    -- klonun heading'i (acilis anindaki oyuncu heading'i) — SABIT (kamera bunu kullanir)
local dragYaw      = 0.0    -- kullanici surukleme/donme ofseti (klonu dondurur)
local compCache    = {}     -- aynalama diff onbellegi
local curWeapon    = nil
local camF         = nil    -- kamera SABIT ileri vektoru (session boyunca degismez)
local camR         = nil    -- kamera SABIT sag vektoru (session boyunca degismez)

------------------------------------------------------------------------------
-- YERLESIM
------------------------------------------------------------------------------
-- ONEMLI TASARIM KARARI: kamera camDist HARIC SABIT kalir; camSide/camHeight KLONU
-- (kamerayi DEGIL) camera-sag/camera-yukari ekseninde kaydirir. Once kamera hareket
-- ettirilmisti (klon sabit) ama bu PARALAKS TERSLIGI yaratiyordu: kamera saga kayinca
-- SABIT klon ekranda SOLA kayar gibi gorunuyor -> "sag" tusuna basinca karakter ters
-- yone gidiyormus hissi, kullanici kadraji ayarlayamadi. Klon hareket ederken kamera
-- sabitse, klon basilan tusun yonune DOGRUDAN (ters donmeden) kayar. Zoom (Numpad1/2)
-- kameranin FOV'unu degistirir (kamera pozisyonuna hic dokunmaz) -> zoom de sabit.
local function forwardOf(h)
    local r = math.rad(h)
    return vector3(-math.sin(r), math.cos(r), 0.0)  -- heading h'de ileri yon
end

local function rightOf(h)
    local r = math.rad(h)
    return vector3(math.cos(r), math.sin(r), 0.0)  -- heading h'nin sagi
end

--- Iki backdrop panelini KLONUN (offsetli konumunun) ARKASINA, kameraya bakacak
--- sekilde yerlestir. Panel yuzu (-Y) heading+180'de +fwd'e (kameraya) bakar; ikinci
--- panel ters -> hangi acidan olursa olsun biri HER ZAMAN kaplar (backface guvencesi).
local function positionBackdrop(fwd, klonX, klonY, centerZ)
    local bx = klonX - fwd.x * cfg.backDist
    local by = klonY - fwd.y * cfg.backDist
    local bz = centerZ + cfg.backZ
    if backdrop and DoesEntityExist(backdrop) then
        SetEntityCoordsNoOffset(backdrop, bx, by, bz, false, false, false)
        SetEntityHeading(backdrop, (anchorHead + 180.0) % 360.0)
    end
    if backdrop2 and DoesEntityExist(backdrop2) then
        SetEntityCoordsNoOffset(backdrop2, bx - fwd.x * 0.1, by - fwd.y * 0.1, bz, false, false, false)
        SetEntityHeading(backdrop2, anchorHead % 360.0)
    end
end

--- KAMERA TABANINI hesaplar (SADECE kamera; klona DOKUNMAZ). previewPed'i GECICI
--- olarak offsetsiz anchor'a koyup gercek gogus yuksekligini okur -> kamera Z'si
--- klonun KENDI side/height offsetinden ETKILENMEZ (aksi halde klon yukari kayinca
--- kamera da onunla birlikte kayar, ekranda hicbir sey degismezmis gibi gorunurdu).
--- /cam (dist/fov/look) VEYA ilk yerlesim (settle) sirasinda cagrilir; ok tuslari/
--- Numpad BUNU CAGIRMAZ (kamera dial sirasinda SABIT kalsin diye).
---
--- YON DUZELTMESI (2026-08-12, KULLANICI GORSEL KANITLA BILDIRDI): eskiden kamera
--- klonun ONUNE (anchorHead yonunde, +fwd*camDist) konup GERIYE (-fwd) bakiyordu
--- ("selfie" kurulumu -> karakterin YUZUNU gormek icin sart). Ama bu YUZDEN
--- kameranin GERCEKTE gosterdigi manzara HER ZAMAN karakterin baktigi yonun TAM
--- TERSIYDI (herhangi bir selfie'de arka plan hep SIRTINIZIN arkasindaki yerdir,
--- BAKTIGINIZ yer degil) — arka plan komple kaldirilinca (seffaf) bu ters yon
--- COK BELIRGIN hale geldi ("dağa bakıyor çanta şehre açılıyor" vb.).
--- ARTIK KAMERA KLONUN ARKASINA konur (-fwd*camDist, omuz-ustu/3.sahis takip
--- kamerasi gibi) ve klonla AYNI yone (+fwd) bakar -> manzara ARTIK karakterin
--- GERCEKTEN baktigi yonu gosterir. camR de ARTIK AYNA-TERSI DEGIL (rightOf(anchorHead)
--- duz) — kamera artik ayna degil, ayni yone bakan bir takip kamerasi oldugu icin
--- sag/sol kavrami klonun KENDI sag/solu ile ayni.
---
--- YUZ/YON NOTU (HEMEN ARDINDAN duzeltildi, ayni gun): kamera KONUMU/BAKISI (yon
--- dogrulugu icin) yukaridaki gibi SABIT kalir, AMA klonun KENDI heading'i (SetEntityHeading)
--- ARTIK ayrica +180 CEVRILIR. Bu SADECE kozmetik/gorsel bir donus — dunyada NEYIN
--- gorundugunu (arka plan yonu, kameranin gercek konum/bakisiyla belirlenir) HIC
--- ETKILEMEZ, SADECE izleyicinin klonun ONUNU mu ARKASINI mi gordugunu degistirir.
--- Boylece kamera hala DOGRU yone bakarken (arka plan hala oyuncunun gercekte
--- baktigi yon), klon da artik kameraya DONUK (yuzu/kiyafetleri gorunur) —
--- onceki "ya yuz ya dogru yon" ikilemi boylece COZULDU (ikisi ayni anda mumkunmus).
local function computeCameraBasis()
    if not previewPed or not DoesEntityExist(previewPed) or not studioCam or not anchorPos then return end
    local fwd = forwardOf(anchorHead)
    local right = rightOf(anchorHead)
    SetEntityCoordsNoOffset(previewPed, anchorPos.x, anchorPos.y, anchorPos.z, false, false, false)
    -- KLONUN YUZU kameraya donuk olsun diye +180 (bkz asagidaki YUZ/YON NOTU) —
    -- SADECE gorsel/kozmetik, kameranin konumu/baktigi yonu (dolayisiyla arka
    -- planda gorunen dunya yonu) ETKILEMEZ.
    SetEntityHeading(previewPed, (anchorHead + 180.0) % 360.0)
    local chest = GetPedBoneCoords(previewPed, BONE_CHEST, 0.0, 0.0, 0.0)
    camF = fwd
    camR = right
    SetCamCoord(studioCam,
        anchorPos.x - fwd.x * cfg.camDist,
        anchorPos.y - fwd.y * cfg.camDist,
        chest.z)
    SetCamFov(studioCam, cfg.fov)
    -- Kamera ARKADA (-fwd), buraya (anchorPos, klonun konumu) bakar -> bakis yonu
    -- otomatik +fwd olur (klonla AYNI yon) — pozisyon flip'i yeterli, ayrica bir
    -- "ileriye bak" hedefi gerekmez.
    PointCamAtCoord(studioCam, anchorPos.x, anchorPos.y, chest.z - cfg.lookDown)
end

--- Klonu (ve arkasindaki backdrop'u) camSide/camHeight/dragYaw'a gore yerlestirir.
--- KAMERA BURADA DEGISMEZ -> ok tuslari basinca klon basilan yone DOGRUDAN kayar.
local function placeKlon()
    if not previewPed or not DoesEntityExist(previewPed) or not camR or not anchorPos then return end
    local pos = vector3(
        anchorPos.x + camR.x * cfg.camSide,
        anchorPos.y + camR.y * cfg.camSide,
        anchorPos.z + cfg.camHeight)
    SetEntityCoordsNoOffset(previewPed, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(previewPed, (anchorHead + 180.0 + dragYaw) % 360.0)
    local chest = GetPedBoneCoords(previewPed, BONE_CHEST, 0.0, 0.0, 0.0)
    positionBackdrop(camF, pos.x, pos.y, chest.z)
end

--- Tam yerlesim: kamera tabani + klon. /cam (chat) ve ilk yerlesim (settle) icin.
local function setupStudio()
    computeCameraBasis()
    placeKlon()
end

--- Iki siyah paneli spawn et. balpha<=0 -> arka plan KOMPLE KALDIRILDI (kullanici
--- istegi), hic obje spawn edilmez (gorunmez obje degil, GERCEKTEN yok).
local function spawnBackdrop()
    if cfg.balpha <= 0 then return end
    local h = GetHashKey(cfg.bmodel)
    if not IsModelInCdimage(h) or not IsModelValid(h) then
        print(('^1[bitirim] backdrop model gecersiz: "%s" (stream/ytyp yuklendi mi?)^7'):format(cfg.bmodel))
        return
    end
    RequestModel(h)
    local t = 0
    while not HasModelLoaded(h) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(h) then print('^1[bitirim] backdrop model yuklenemedi^7'); return end
    local ep = anchorPos or GetEntityCoords(PlayerPedId())
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
--- showCharacter=false: klon YINE olusturulur/konumlanir (kamera cercevelemesi
--- gogus bonuna gore hesaplanir) ama GORUNMEZ yapilir -> backdrop panel gorunur,
--- karakter gorunmez. Torpido/bagaj/motel/otel gibi kap gorunumlerinde kullanilir
--- (kullanici istegi: arka plan HER YERDE ama karakter SADECE karakter panelinde).
local function CreatePreview(showCharacter)
    if showCharacter == nil then showCharacter = true end
    if active then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    realPed = ped

    -- 1) Klon = oyuncunun O ANKI gorunumu. NOT (2026-08-12, debug ile KANITLANDI):
    -- isNetwork=false bu sunucuda previewPed'i GERCEKTEN yerel tutmuyor —
    -- NetworkGetEntityIsNetworked(previewPed) ClonePed'in HEMEN ARDINDAN (bizim
    -- hicbir kodumuz calismadan) bile true donuyordu (F8 ile dogrulandi, birden
    -- fazla adimda bisect edildi). Yani "yerel kal" garantisine GUVENILEMEZ.
    previewPed = ClonePed(ped, GetEntityHeading(ped), false, false)
    if not previewPed or previewPed == 0 or not DoesEntityExist(previewPed) then
        print('^1[bitirim] PreviewManager: ClonePed BASARISIZ^7')
        previewPed = nil
        return
    end
    pcall(ClonePedToTarget, ped, previewPed)
    SetEntityAsMissionEntity(previewPed, false, true)
    FreezeEntityPosition(previewPed, true)  -- KLON statik
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    -- GERCEK COZUM: madem klon HER HALUKARDA agda (yukaridaki not), sizinti
    -- SORUNU YOK ETMEK yerine EKRANDA GIZLEME'YE gecildi. SetEntityVisible(false)
    -- klonu AGDAKI HERKESE (kendimiz DAHIL) gorunmez yapar -> render loop'ta
    -- (asagida) HER KARE SetEntityLocallyVisible(previewPed) ile SADECE KENDI
    -- client'imizda uzerine yazilir. Boylece baska hicbir oyuncu (mesafe/LOD
    -- ONEMSIZ, garanti) klonu goremez, sadece biz goruruz. `showCharacter=false`
    -- (kap gorunumlerinde karakter gizli kalsin istegi) icin render loop bu
    -- override'i hic cagirmaz -> klon bize de gorunmez kalir (eskisiyle ayni sonuc).
    SetEntityVisible(previewPed, false, false)
    ResetEntityAlpha(previewPed)

    -- 2) Klon konumu: oyuncunun O ANKI X/Y'sinde, Z + heightOffset (yukarida, acik
    -- gokyuzu). X/Y oyuncuyla AYNI oldugu icin o bolgenin streami "sicak" kalir ->
    -- kapaniste render sorunu olmaz (uzak sabit koordinat denendi, bu soruna yol
    -- acti — kaldirildi). ISTISNA: oyuncu bir BINA/INTERIOR icindeyse "ustu" guvenilir
    -- degil (interior'lar dunyada farkli/istiflenmis konumlarda olabilir, +Z acik
    -- gokyuzune cikmayabilir) -> bu durumda SABIT, onceden test edilmis sehir-yolu
    -- konumuna dusulur.
    if GetInteriorFromEntity(ped) ~= 0 then
        anchorPos  = cfg.interiorFallbackPos
        anchorHead = cfg.interiorFallbackHead
    else
        local basePos = GetEntityCoords(ped)
        anchorPos  = basePos + vector3(0.0, 0.0, cfg.heightOffset)
        anchorHead = GetEntityHeading(ped)
    end
    dragYaw = 0.0

    -- 3) Scripted kamera (dogrudan studio konumunda olusturulur; GECIS ANIMASYONU YOK)
    studioCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', anchorPos.x, anchorPos.y, anchorPos.z, 0.0, 0.0, 0.0, cfg.fov, false, 2)

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
            -- Klon agda GENEL OLARAK gorunmez (yukaridaki not) -> SADECE showCharacter
            -- ise, SADECE bu client'ta HER KARE uzerine yazip gorunur yapariz (native
            -- kendini sifirlar, SetEntityLocallyInvisible ile ayni desen). Baska
            -- oyuncular ASLA gormez; showCharacter=false ise (kap gorunumu) biz de
            -- gormeyiz (mevcut niyetle ayni).
            if showCharacter then SetEntityLocallyVisible(previewPed) end
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
        SetEntityAsMissionEntity(previewPed, false, true)
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
    anchorPos = nil
    anchorHead = 0.0
    camF = nil
    camR = nil
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
    SetEntityHeading(previewPed, (anchorHead + 180.0 + dragYaw) % 360.0)
end

--- Studio kadraj ince ayari (chat /cam icin — tum degerleri kabul eder, kamera TABANINI
--- yeniden hesaplar). Ok tuslari/Numpad1-2 (TuneScene) BUNU KULLANMAZ (kamera dial
--- sirasinda sabit kalsin diye placeKlon/SetCamFov'u dogrudan cagirir).
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

--- Klavye ayar (index.tsx -> NUI 'bitirim:charTune' -> buraya). 2 EKSEN + zoom:
---   Ok tuslari up/down    = KLON DIKEY konumu (camHeight) — kamera SABIT
---   Ok tuslari left/right = KLON YATAY konumu (camSide) — kamera SABIT
---   Numpad 1/2 zoomin/zoomout = ZOOM (fov; kucuk fov=yakin/buyuk gorunur)
--- KAMERA POZISYONU BURADA HIC DEGISMEZ (computeCameraBasis/setupStudio CAGRILMAZ) ->
--- basilan tusun yonu ile klonun ekrandaki hareketi AYNI (ters paralaks YOK).
--- Begenilen degerleri F8'de gorup soyle -> kalici yaparim.
local function TuneScene(action)
    if not active then return end
    local POS, FOVSTEP = 0.10, 2.0  -- tek tusa basinca ACIKCA gorunur adim
    if action == 'up' then
        cfg.camHeight = cfg.camHeight + POS
        placeKlon()
    elseif action == 'down' then
        cfg.camHeight = cfg.camHeight - POS
        placeKlon()
    elseif action == 'left' then
        cfg.camSide = cfg.camSide - POS
        placeKlon()
    elseif action == 'right' then
        cfg.camSide = cfg.camSide + POS
        placeKlon()
    elseif action == 'zoomin' then
        cfg.fov = math.max(10.0, cfg.fov - FOVSTEP)
        if studioCam then SetCamFov(studioCam, cfg.fov) end
    elseif action == 'zoomout' then
        cfg.fov = math.min(80.0, cfg.fov + FOVSTEP)
        if studioCam then SetCamFov(studioCam, cfg.fov) end
    else
        return
    end
    print(('^3[bitirim] studio camSide=%.2f camHeight=%.2f fov=%.1f^7')
        :format(cfg.camSide, cfg.camHeight, cfg.fov))
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
