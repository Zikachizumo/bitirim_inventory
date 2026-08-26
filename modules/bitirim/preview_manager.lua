--[[
    Bitirim — PREVIEW MANAGER (STUDIO / "Studio Camera" KARAKTER ONIZLEMESI)
    ============================================================================
    STUDIO MIMARISI (2026-08-26 GUNCELLEMESI — "OYUNCUNUN OLDUGU YERDE" MODELI):
    Envanter acilinca, oyuncunun YEREL (local-only) bir klonu oyuncunun O ANKI
    konumuyla AYNI X/Y/Z'de (yukari/uzaga TASINMADAN), hemen yaninda kucuk bir
    yatay offsetle durur; ona bakan SCRIPTED bir kamera devreye girer.
        GERCEK OYUNCU ──► Gercek Player Ped  (yerel GIZLI; agda normal gorunur)
                      └──► Mirror Klon Ped    (YEREL; oyuncunun TAM YANIBASINDA,
                                                AYNI Z'de; studio kamerasi buna bakar)

    ONCEKI MIMARI (ARTIK KULLANILMIYOR, TARIHSEL NOT): Klon oyuncunun +2m
    USTUNDE (acik gokyuzu, "guvenli void") tutuluyordu; oyuncu bir interior
    icindeyse bu varsayim gecersiz oldugu icin SABIT bir sehir-disi koordinata
    (`interiorFallbackPos`) dusuluyordu. Bu, kullanicinin bina icinde envanter
    acinca gokyuzu/sehir manzarasi gormesine VE kameranin duvar/tavan icine
    girmesine (raycast/collision kontrolu olmadigi icin) yol aciyordu. KULLANICI
    ISTEGI UZERINE bu mimari TAMAMEN TERK EDILDI — artik "+Z offset" ve
    "interior fallback" YOK; previewPed HER ZAMAN oyuncunun GERCEKTEN bulundugu
    yerde (sokak/ev/ofis/garaj/arac farketmez) kalir.

    YENI COZUM: previewPed, oyuncunun kendi konumunun (Z DAHIL) aynisinda,
    sadece kamera-sag ekseninde kucuk bir yatay offsetle (`cfg.camSide`,
    ~0.5-0.8m) durur. Boylece previewPed HER ZAMAN oyuncunun bulundugu ODADA/
    SOKAKTA kalir -> "farkli dunyaya isinlanma" veya "stream sogumasi" riski
    ortadan kalkar (X/Y/Z hep gercek, hep "sicak" bolge).
    - Kamera mesafesi (`cfg.camDist`) de KISALTILDI (eskiden 2.55m) ve ARTIK
      HER KAREDE bir SHAPE TEST (`computeCameraBasis`) ile previewPed ile
      kamera arasinda engel (duvar/nesne) olup olmadigi kontrol edilir; engel
      varsa kamera mesafesi otomatik, guvenli bir degere (min. `MIN_CAM_DIST`)
      kisilir -> kamera ARTIK duvarin/binanin icine giremez.
    - Gameplay kamerasi (TP/FP/egim) hala ONEMSIZ: kendi scripted kameramiz klona
      SABIT bir acidan bakar -> arka plan HER ZAMAN previewPed'i cerceveler.
    - GECIS ANIMASYONU YOK: envanter acilir acilmaz (bir sonraki frame) direkt studio
      kadrajina gecilir (RenderScriptCams ease=false); kapaninca da aninda gameplay'e
      doner (yaris durumu/entity sizintisi riskine karsi da aninda kesim tercih edildi).
    - Backdrop panel sistemi (2 siyah panel) KODDA HALA VAR ama varsayilan olarak
      KAPALI (cfg.balpha=0) — arka plan GERCEK oyun dunyasi (seffaf). Kamera
      KLONUN ARKASINDA durur ve klonla AYNI yone bakar (computeCameraBasis'teki
      YON DUZELTMESI notuna bak) -> gorunen manzara artik karakterin GERCEKTEN
      baktigi yonle eslesir.

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
    -- ARTIK BIR YUKSEKLIK OFSETI YOK: previewPed oyuncunun Z'siyle AYNI kalir
    -- (bkz updateAnchor). Eski `heightOffset` (+2m gokyuzu) VE interior fallback
    -- koordinati KALDIRILDI — previewPed HER ZAMAN oyuncunun gercekte bulundugu
    -- yerde (ayni oda/sokak/arac) kalir, baska bir dunya noktasina TASINMAZ.

    -- ISTENEN (kamera duvara/binaya carpmadigi surece kullanilan) kamera mesafesi.
    -- Her karede computeCameraBasis() bunu shape-test ile kontrol edip gerekirse
    -- kisar (bkz MIN_CAM_DIST/CAM_SAFETY_MARGIN asagida) — bu deger sadece
    -- "engel yokken" kullanilacak HEDEF mesafedir.
    camDist   = 1.70,  -- kamera klonun ONUNDE kac metre (SABIT HEDEF; /cam ile degisir, shape-test ile kisilabilir) — A/B TEST (2026-08-26): 1.15 tam-boy kadraj icin yetersizdi (FOV=64 ile ~1.44m dikey kapsama alani, ~1.8m boy sigmiyordu); 1.70 ~1.8m boyu %20 payla sigdirir.
    camSide   = 0.0,   -- KLONUN yatay konumu (kamera-sag ekseni) — 0 = TAM KARSIDAN/SIMETRIK (2026-08-27, kullanici istegi). ONEMLI: kamera PointCamAtCoord ile HAM anchorPos'a bakar (bkz computeCameraBasis), klonun camSide'a gore KAYDIRILMIS konumuna DEGIL (bilerek — kamera sabit kalsin, ok tuslariyla klon kadraj icinde DOGRUDAN kaysin diye). Bu yuzden camSide != 0 iken klon kameranin optik ekseninden disari dusuyor -> genis FOV'da (zoom out) belirgin bir "yamuk/carpik" gorunume yol aciyor (genis acida merkez-disi nesneler gerilir). Merkezden kaydirmak istersen ok tuslari (sol/sag) canli dial icin hala kullanilabilir, sadece KALICI varsayilan artik 0.
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

------------------------------------------------------------------------------
-- KAMERA COLLISION (DUVAR/BINA ICINE GIRMEYI ONLEME)
------------------------------------------------------------------------------
-- computeCameraBasis() her karede previewPed (chest) ile "istenen" kamera
-- noktasi arasinda bir shape test (kapsul) atar. Engel varsa kamera mesafesi
-- carpismaya kadar olan mesafe - guvenlik payi kadar kisilir, ASLA MIN_CAM_DIST
-- altina inmez (previewPed'in icine girmesin diye).
local MIN_CAM_DIST      = 0.45  -- ped govdesi + kamera FOV'una gore belirlenmis en yakin guvenli mesafe
local CAM_SAFETY_MARGIN = 0.08  -- carpisma noktasindan bu kadar geride dur (duvara gomulmesin)
local CAM_TEST_RADIUS   = 0.15  -- kapsul yaricapi (ince kenarlardan "sizmasin" diye)
local CAM_TEST_FLAGS    = 1     -- SADECE dunya/statik geometri (bina/duvar) — ped'leri (realPed/previewPed) otomatik yok sayar

------------------------------------------------------------------------------
-- ROUND 10 (2026-08-26) TERRAIN-SAFE YERLESIM (previewPed'in SOLUNDAKI kaya/
-- yamaca gomulmesini onleme)
------------------------------------------------------------------------------
-- Round 7-9 collision diagnostic'i (previewCollisionDebug/dbgShapeTest, asagida)
-- SOL tarafta previewPed'in TUM bone'larinin (pelvis..head) ayni dunya/statik
-- geometriye (ent=8229640) HIT verdigini, previewSide=LEFT icin cameraLOS'un
-- CLEAR kaldigini VE probe matematiginin (camR bazli, RIGHT ile birebir ayna)
-- zaten dogru oldugunu kanitladi -> previewPed'in kendisi camSide=-0.22
-- nedeniyle o kayaya SAGdan daha yakin duruyor, gercek terrain de o yonde
-- yukseliyor (LEFT groundZ ~0.47m daha yuksek). Bu YUZDEN placeKlon()'un
-- SONUNA (mevcut satirlar DEGISMEDEN) BAGIMSIZ bir govde-terrain guvenlik
-- kontrolu eklendi -- diagnostic kodunu (dbgShapeTest) CAGIRMAZ, kendi
-- StartShapeTestCapsule/GetShapeTestResult cagrisini yapar (resolveSafeCamDist
-- ile AYNI CAM_TEST_FLAGS=1/CAM_TEST_RADIUS deseni). SADECE previewPed'in SOLUNDA
-- (camR'nin TERSI) LEFT_TERRAIN_SAFE_DIST icinde dunya/statik geometri varsa
-- previewPed'i SAGA (camR yonunde), sadece eksigi kadar (en fazla
-- LEFT_TERRAIN_MAX_PUSH) kaydirir. HIT yoksa (duz zemin/RIGHT taraf) pushAmount
-- 0 kalir -> previewPed'in konumu HICBIR SEKILDE etkilenmez.
--
-- ROUND 11 (2026-08-26) REVIZYON — Round 10 CANLIDA ETKISIZ KALDI: incelemede
-- LEFT_TERRAIN_SAFE_DIST=0.55m'nin, ayni engeli 1.5m'de (DBG_PROBE_DISTANCE)
-- bulan Round 7-9 diagnostic'ine kiyasla COK KISA oldugu (probe hicbir zaman
-- HIT bulamamis olabilir) VE duzeltmenin SADECE X/Y yaptigi, previewPed Z'sinin
-- HER ZAMAN anchorPos.z+camHeight'ta sabit kaldigi (SOL zemin ~0.47m daha
-- yuksekken previewPed'in ayaklarinin zemine GOMULMUS olabilecegi) tespit
-- edildi. Bu yuzden: (1) LEFT_TERRAIN_SAFE_DIST asagida 1.5'e cikarildi (artik
-- diagnostic'in FIILEN buldugu mesafeyle uyumlu), (2) placeKlon()'un sonuna
-- AYRICA previewPed'in (yatay duzeltmeden SONRAKI nihai) X/Y'sindeki GERCEK
-- zemin yuksekligini (GetGroundZFor_3dCoord, Round 5 diagnostic'teki AYNI
-- guvenli desen: z+50'den asagi arama + pcall + found kontrolu) previewPed'in
-- mevcut Z'siyle karsilastiran, previewPed'i SADECE zemin daha YUKSEKSE VE
-- SADECE o gercek fark kadar (MAX_TERRAIN_Z_LIFT ile sinirli) YUKARI kaldiran
-- bagimsiz bir dikey kontrol eklendi. Her iki kontrol de HER CAGRIDA (her
-- frame) `pos`'tan (yani taze anchorPos'tan) SIFIRDAN hesaplanir -> ONCEKI
-- karenin duzeltilmis konumu asla girdi olarak kullanilmaz (kumulatif SURUKLENME
-- YOK). Duz zeminde/RIGHT tarafta iki kontrol de "duzeltme gerekmiyor" sonucuna
-- varir -> previewPed'e HICBIR ek SetEntityCoordsNoOffset cagrisi yapilmaz.
local LEFT_TERRAIN_SAFE_DIST = 1.5   -- previewPed'in SOLUNDA bu mesafeye kadar dunya/statik geometri OLMAMALI -- Round 7-9 diagnostic'in AYNI engeli 1.5m'de bulmus olmasiyla UYUMLU (bkz Round 11 notu)
local LEFT_TERRAIN_MAX_PUSH  = 0.30  -- previewPed en fazla bu kadar SAGA (camR yonunde) itilebilir -- kadraj/kompozisyon asiri bozulmasin
local MAX_TERRAIN_Z_LIFT     = 0.60  -- previewPed en fazla bu kadar YUKARI kaldirilabilir -- GetGroundZFor_3dCoord yanlis/asiri deger donerse buyuk Z sicramasina karsi guvenlik ustsiniri (bilinen gercek fark ~0.47m'nin biraz uzerinde)

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
local anchorPos    = nil    -- klonun durdugu konum (= GERCEK oyuncu konumu, birebir) — HER ACILISTA/KAREDE yeniden hesaplanir
local anchorHead   = 0.0    -- klonun heading'i (acilis anindaki oyuncu heading'i) — SABIT (kamera bunu kullanir)
local dragYaw      = 0.0    -- kullanici surukleme/donme ofseti (klonu dondurur)
local compCache    = {}     -- aynalama diff onbellegi
local curWeapon    = nil
local camF         = nil    -- kamera SABIT ileri vektoru (session boyunca degismez)
local camR         = nil    -- kamera SABIT sag vektoru (session boyunca degismez)
local curSafeDist  = nil    -- collision-aware kamera mesafesi (smoothing icin kareler arasi tasinir; bkz computeCameraBasis)

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
--- Kamera ile previewPed (chest) arasinda shape test atar; aralarinda duvar/nesne
--- varsa "istenen" camDist yerine carpismaya kadar olan guvenli mesafeyi doner.
--- Sadece DUNYA/statik geometriyle (CAM_TEST_FLAGS=1) test eder -> realPed/
--- previewPed (ped'ler) otomatik yok sayilir, ayrica entity ignore etmeye gerek yok.
--- SMOOTHING: kuculme (yeni engel/daha yakin duvar) ANINDA uygulanir (guvenlik —
--- bir kare bile duvarin icine girmesin), buyume (engel kalkinca eski mesafeye
--- donus) YUMUSAK (lerp) yapilir -> shape test'in kare-kare ufak sapmalarindan
--- kaynaklanan "0.90/0.65/0.90..." titremesi engellenir.
local function resolveSafeCamDist(chestX, chestY, chestZ, fwd, desired)
    local endX = chestX - fwd.x * desired
    local endY = chestY - fwd.y * desired
    local rayHandle = StartShapeTestCapsule(chestX, chestY, chestZ, endX, endY, chestZ, CAM_TEST_RADIUS, CAM_TEST_FLAGS, 0, 7)
    local _, hit, endCoords = GetShapeTestResult(rayHandle)

    local raw = desired
    if hit == 1 or hit == true then
        local hitDist = #(vector3(endCoords.x - chestX, endCoords.y - chestY, endCoords.z - chestZ))
        raw = math.max(MIN_CAM_DIST, hitDist - CAM_SAFETY_MARGIN)
    end

    if curSafeDist == nil or raw < curSafeDist then
        curSafeDist = raw
    else
        curSafeDist = curSafeDist + (raw - curSafeDist) * 0.25
    end

    return curSafeDist
end

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

    local dist = resolveSafeCamDist(anchorPos.x, anchorPos.y, chest.z, fwd, cfg.camDist)

    SetCamCoord(studioCam,
        anchorPos.x - fwd.x * dist,
        anchorPos.y - fwd.y * dist,
        chest.z)
    SetCamFov(studioCam, cfg.fov)
    -- Kamera ARKADA (-fwd), buraya (anchorPos, klonun konumu) bakar -> bakis yonu
    -- otomatik +fwd olur (klonla AYNI yon) — pozisyon flip'i yeterli, ayrica bir
    -- "ileriye bak" hedefi gerekmez.
    PointCamAtCoord(studioCam, anchorPos.x, anchorPos.y, chest.z - cfg.lookDown)
end

-- ROUND 12 (2026-08-26) GECICI OLCUM ICIN: son print zamani (throttle). Root
-- cause netlesince bu degisken + asagidaki print blogu KALDIRILACAK.
local round12DebugLast = 0

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

    -- ROUND 10/11 TERRAIN-SAFE DUZELTME (bkz ustteki modul basi aciklamasi):
    -- previewPed'in SOLUNDA (camR'nin TERSI) dunya/statik geometri varsa SAGA
    -- it (X/Y) VE previewPed'in (yatay duzeltmeden SONRAKI) nihai X/Y'sindeki
    -- zemin previewPed'in Z'sinden yuksekse YUKARI kaldir (Z). Ikisi de HER
    -- CAGRIDA `pos`'tan (taze anchorPos'tan) SIFIRDAN hesaplanir -> ONCEKI
    -- karenin sonucu asla girdi olarak kullanilmaz (kumulatif surukleme YOK).
    -- Diagnostic kodundan (dbgShapeTest) BAGIMSIZ; hicbir HIT/fark yoksa
    -- previewPed'e EK bir SetEntityCoordsNoOffset cagrisi YAPILMAZ.
    local safeX, safeY, safeZ = pos.x, pos.y, pos.z
    local moved = false

    -- 1) YATAY: SOLDA LEFT_TERRAIN_SAFE_DIST icinde dunya/statik geometri varsa
    --    SAGA, sadece eksigi kadar (en fazla LEFT_TERRAIN_MAX_PUSH) it.
    local leftTestX = pos.x - camR.x * LEFT_TERRAIN_SAFE_DIST
    local leftTestY = pos.y - camR.y * LEFT_TERRAIN_SAFE_DIST
    local leftRay = StartShapeTestCapsule(pos.x, pos.y, chest.z, leftTestX, leftTestY, chest.z, CAM_TEST_RADIUS, CAM_TEST_FLAGS, 0, 7)
    local _, leftHit, leftEndCoords = GetShapeTestResult(leftRay)

    local leftHitDist, deficit, pushAmount = nil, nil, nil
    if leftHit == 1 or leftHit == true then
        leftHitDist = #(vector3(leftEndCoords.x - pos.x, leftEndCoords.y - pos.y, leftEndCoords.z - chest.z))
        deficit = LEFT_TERRAIN_SAFE_DIST - leftHitDist
        if deficit > 0.0 then
            pushAmount = math.min(deficit, LEFT_TERRAIN_MAX_PUSH)
            safeX = pos.x + camR.x * pushAmount
            safeY = pos.y + camR.y * pushAmount
            moved = true
        end
    end

    -- 2) DIKEY: previewPed'in nihai (yukaridaki duzeltmeden SONRAKI) X/Y'sindeki
    --    GERCEK zemin previewPed'in Z'sinden yuksekse (ayaklar gomulur), SADECE
    --    o gercek fark kadar (en fazla MAX_TERRAIN_Z_LIFT) YUKARI kaldir. Zemin
    --    daha ALCAKSA (duz zemin/RIGHT taraf) HICBIR SEY degismez (asla asagi
    --    indirmez). Ayni guvenli GetGroundZFor_3dCoord deseni (z+50'den asagi
    --    arama + pcall + found kontrolu) Round 5 diagnostic thread'inde zaten
    --    kullaniliyor -- burada BAGIMSIZ bir kopyasi.
    local okGround, foundGround, groundZ = pcall(GetGroundZFor_3dCoord, safeX, safeY, pos.z + 50.0, false)
    local zDeficit = nil
    if okGround and foundGround and groundZ then
        zDeficit = groundZ - pos.z
        if zDeficit > 0.0 then
            safeZ = pos.z + math.min(zDeficit, MAX_TERRAIN_Z_LIFT)
            moved = true
        end
    end

    if moved then
        SetEntityCoordsNoOffset(previewPed, safeX, safeY, safeZ, false, false, false)
        positionBackdrop(camF, safeX, safeY, chest.z)
    end

    -- ROUND 12 GECICI OLCUM: SADECE print, hicbir davranisi/pozisyonu etkilemez.
    -- Root cause netlesince bu blok KALDIRILACAK.
    local round12Now = GetGameTimer()
    if round12Now - round12DebugLast >= 1000 then
        round12DebugLast = round12Now
        local finalPos = GetEntityCoords(previewPed)
        print(('[round12-probe] pos=(%.2f,%.2f,%.2f) camR=(%.3f,%.3f) leftHit=%s leftHitDist=%s deficit=%s pushAmount=%s okGround=%s foundGround=%s groundZ=%s zDeficit=%s moved=%s finalPos=(%.2f,%.2f,%.2f)')
            :format(pos.x, pos.y, pos.z, camR.x, camR.y,
                tostring(leftHit), tostring(leftHitDist), tostring(deficit), tostring(pushAmount),
                tostring(okGround), tostring(foundGround), tostring(groundZ), tostring(zDeficit),
                tostring(moved), finalPos.x, finalPos.y, finalPos.z))
    end
end

--- Tam yerlesim: kamera tabani + klon. /cam (chat) ve ilk yerlesim (settle) icin.
local function setupStudio()
    computeCameraBasis()
    placeKlon()
end

--- Ankoru (anchorPos/anchorHead) GUNCEL oyuncu konumundan yeniden hesaplar
--- (klona/kameraya DOKUNMAZ — bu setupStudio'nun isi, ayri cagrilir).
--- Hem ilk kurulumda (CreatePreview) HEM HER KAREDE (render thread) cagrilir ->
--- araç/uçak/helikopterle hareket ederken, yürürken, asansör/interior gecislerinde
--- previewPed HER ZAMAN oyuncunun GERCEKTEN bulundugu konumu (Z DAHIL, offsetsiz)
--- takip eder — ARTIK ne +Z offseti ne de interior icin ayri bir fallback VAR
--- (bkz dosya basi mimari notu): previewPed asla oyuncunun bulundugu yerin
--- disina (baska interior/routing/gokyuzu/sehir ustu) TASINMAZ.
local function updateAnchor()
    if not realPed or not DoesEntityExist(realPed) then return end
    anchorPos  = GetEntityCoords(realPed)
    anchorHead = GetEntityHeading(realPed)
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
    -- FIX (2026-08-26): "false" previewPed'i GTA'nin otomatik ambient ped/entity
    -- temizliginden KORUMUYORDU (mission-entity DEGIL) — networked=true oldugu
    -- icin (yukaridaki AG-GORUNURLUGU notu) VE interior'larin acik dunyaya gore
    -- COK DAHA SIKI ped/entity butcesi oldugu icin previewPed acilistan ~1sn
    -- sonra motor tarafindan SESSIZCE SILINIYORDU (debug log ile KANITLANDI:
    -- previewPed exists=true iken ansizin exists=false oluyor, render thread
    -- bunun uzerine sona eriyor, realPed'in yerel-gizli override'i bir daha
    -- tazelenmiyor -> gercek karakter tekrar gorunur oluyor). `true` previewPed'i
    -- script-korumali mission entity yapar -> otomatik temizlikten MUAF olur,
    -- sadece bizim DestroyPreview()'imiz onu silebilir.
    SetEntityAsMissionEntity(previewPed, true, true)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    -- GERCEK COZUM: madem klon HER HALUKARDA agda (yukaridaki not), sizinti
    -- SORUNU YOK ETMEK yerine EKRANDA GIZLEME'YE gecildi. SetEntityVisible(false)
    -- klonu AGDAKI HERKESE (kendimiz DAHIL) gorunmez yapar -> render loop'ta
    -- (asagida) HER KARE SetEntityLocallyVisible(previewPed) ile SADECE KENDI
    -- client'imizda uzerine yazilir. Boylece baska hicbir oyuncu (mesafe/LOD
    -- ONEMSIZ, garanti) klonu goremez, sadece biz goruruz. `showCharacter=false`
    -- (kap gorunumlerinde karakter gizli kalsin istegi) icin render loop bu
    -- override'i hic cagirmaz -> klon bize de gorunmez kalir (eskisiyle ayni sonuc).
    -- NOT: bu asamada FreezeEntityPosition/SetEntityCollision HENUZ cagrilmiyor —
    -- bkz asagidaki "INTERIOR ODA/PORTAL KAYDI" notu (previewPed once NIHAI
    -- konumuna tasinip collision'i ACIKKEN bir-iki kare beklemesi gerekiyor).
    SetEntityVisible(previewPed, false, false)
    ResetEntityAlpha(previewPed)

    -- 2) Klon konumu: oyuncunun O ANKI X/Y/Z'sinin BIREBIR AYNISI (offsetsiz) —
    -- oyuncu sokakta/evde/ofiste/garajda/arac icinde farketmez, previewPed HER
    -- ZAMAN ayni yerde kalir (updateAnchor() HER KAREDE de cagrilir, bkz render
    -- thread). curSafeDist da her acilista sifirlanir ki eski oturumdan kalan
    -- collision-mesafesi yeni sahneye "sizmasin".
    updateAnchor()
    dragYaw = 0.0
    curSafeDist = cfg.camDist

    -- 3) Scripted kamera (dogrudan studio konumunda olusturulur; GECIS ANIMASYONU YOK)
    studioCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', anchorPos.x, anchorPos.y, anchorPos.z, 0.0, 0.0, 0.0, cfg.fov, false, 2)

    spawnBackdrop()

    active = true
    compCache = {}
    curWeapon = nil
    setupStudio()               -- klon+kamera+backdrop studio konumuna (previewPed HALA collision'li/frozen degil)

    -- INTERIOR ODA/PORTAL KAYDI (previewPed interior icinde GORUNMEZ OLMA sorununun
    -- gercek kok nedeni): GTA'nin oda/portal (MLO interior) sistemi bir entity'nin
    -- "hangi odada" oldugunu, o entity fizik/collision guncellemesi ALDIGI ANDA
    -- kaydeder (CPortalTracker). previewPed daha ONCEDEN previewPed'i ayni karede
    -- HEM olusturup HEM konumlandirip HEM DE ANINDA freeze+collision-disable
    -- yapiyorduk -> entity hicbir zaman bir fizik/collision guncellemesi ALMADAN
    -- "donduruluyordu", dolayisiyla oda kaydi hic OLUSMUYORDU. Disarida (rooms
    -- yok, portal culling yok) bu fark etmiyordu -> previewPed hep gorunuyordu.
    -- Interior'da (oda/portal culling VAR) ise previewPed "tanimsiz/yanlis oda"da
    -- kaliyor, entity var/gorunur-bayragi acik olmasina RAGMEN render asamasindaki
    -- PORTAL TESTI onu eliyordu (`SetEntityLocallyVisible` HER KARE dogru
    -- calisiyordu — bu, TAMAMEN AYRI bir filtre; visible-bayragi ile oda/portal
    -- gorunurlugu birbirinden BAGIMSIZ iki kontrol).
    -- COZUM: previewPed'i NIHAI (ofsetli) konumuna tasidiktan SONRA, collision
    -- HALA acikken (ClonePed varsayilani) birkac kare bekleyip oda kaydinin
    -- olusmasina izin veriyoruz, ANCAK BUNDAN SONRA freeze+collision-disable
    -- uyguluyoruz. previewPed bu pencerede AG'de zaten gorunmez (SetEntityVisible
    -- false, henuz LocallyVisible cagrilmadi) -> hicbir gorsel sizinti/flicker
    -- olmaz. NOT: interior fallback (eski -301.72,-71.13,316.92 koordinati) GERI
    -- GETIRILMEDI — previewPed hep GERCEK oyuncu konumunda kalir, sadece oda
    -- KAYDI duzeltiliyor.
    RequestCollisionAtCoord(anchorPos.x, anchorPos.y, anchorPos.z)
    Wait(0)
    Wait(0)

    -- GUVENLIK: yukaridaki Wait(0)'lar CreatePreview'i ARTIK kesilebilir (preemptible)
    -- yapiyor — bu pencerede kullanici envanteri ANINDA kapatirsa (ayri bir coroutine'de
    -- DestroyPreview() calisirsa) previewPed COKTAN silinmis olabilir. Boyle bir durumda
    -- silinmis/gecersiz entity uzerinde native cagirmamak icin burada durup cikariz
    -- (DestroyPreview zaten her seyi temizledi, tekrar dokunmuyoruz).
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end

    FreezeEntityPosition(previewPed, true)  -- KLON statik (ARTIK oda kaydi olustuktan SONRA)
    SetEntityCollision(previewPed, false, false)

    SetCamActive(studioCam, true)
    -- ANINDA GECIS: bir sonraki frame direkt studio kadrajinda goruntulenir (ease=false,
    -- sure=0). Smooth blend YOK — kullanici istegi. (Yukaridaki 2 karelik oda-kaydi
    -- bekleme suresi ~32ms, goz ile fark edilmez -> "aninda" his korunur.)
    RenderScriptCams(true, false, 0, true, true)
    playIdle()
    mirrorWeapon(true)

    -- GECICI DEBUG (2026-08-26 — "kim/ne siliyor" arastirmasinin 2. turu): previewPed'in
    -- KİMLİK bilgilerini (handle, network ID, model, dogum zamani) BIR KEZ kaydediyoruz.
    -- Amac: previewPed daha sonra "yok oldugunda" ayni kimlik mi (gercek silinme) yoksa
    -- handle-reuse gibi baska bir anomalimi oldugunu ayirt edebilmek + tam yasam suresini
    -- (ms) olcebilmek.
    local dbgPreviewHandle = previewPed
    local dbgOkNetId, dbgPreviewNetId = pcall(NetworkGetNetworkIdFromEntity, previewPed)
    local dbgPreviewModel = GetEntityModel(previewPed)
    local dbgCreatedAt = GetGameTimer()
    local dbgOkOwner, dbgOwnerPlayerIdx = pcall(NetworkGetEntityOwner, previewPed)
    local dbgOwnerServerId = (dbgOkOwner and dbgOwnerPlayerIdx and dbgOwnerPlayerIdx ~= -1) and GetPlayerServerId(dbgOwnerPlayerIdx) or -1
    local dbgOkBucket, dbgClientBucket = pcall(GetEntityRoutingBucket, previewPed)
    print(('^2[bitirim-debug] previewPed DOGDU: handle=%s netId=%s model=%s t=%d owner(playerIdx)=%s owner(serverId)=%s clientBucket=%s^7')
        :format(tostring(dbgPreviewHandle), tostring(dbgOkNetId and dbgPreviewNetId), tostring(dbgPreviewModel), dbgCreatedAt,
            tostring(dbgOkOwner and dbgOwnerPlayerIdx), tostring(dbgOwnerServerId), tostring(dbgOkBucket and dbgClientBucket)))

    -- GECICI DEBUG: SUNUCU tarafinda bu netId'nin routing bucket'ini VE oyuncunun
    -- KENDI routing bucket'ini gormek icin — client'ta bucket native'i yoksa/guvenilmezse
    -- bu, kesin cevabi sunucudan alir (bkz modules/bitirim/server.lua 'bitirim:debugPreviewNetInfo').
    if dbgOkNetId and dbgPreviewNetId then
        TriggerServerEvent('bitirim:debugPreviewNetInfo', dbgPreviewNetId, dbgCreatedAt)
    end

    -- RENDER thread (Wait 0): gercek bedeni yerel gizle + HER KAREDE ankoru guncelle
    -- (araç/uçak/helikopterle hareket ederken sahne akici sekilde takip eder) + kadraji
    -- oturt + odak klona + ox screenblur kapat.
    -- GECICI DEBUG (2026-08-26 — interior'da previewPed ~1sn sonra kaybolma arastirmasi
    -- icin eklendi, root cause kesinlesince KALDIRILACAK): 500ms'de bir previewPed/
    -- realPed durumunu yazdirir + thread NEDEN sona erdi (hangi kosul false oldu) onu
    -- yakalar. Production davranisini DEGISTIRMEZ (sadece print).
    local dbgLastPrint = 0
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            if realPed and DoesEntityExist(realPed) then SetEntityLocallyInvisible(realPed) end
            -- Klon agda GENEL OLARAK gorunmez (yukaridaki not) -> SADECE showCharacter
            -- ise, SADECE bu client'ta HER KARE uzerine yazip gorunur yapariz (native
            -- kendini sifirlar, SetEntityLocallyInvisible ile ayni desen). Baska
            -- oyuncular ASLA gormez; showCharacter=false ise (kap gorunumu) biz de
            -- gormeyiz (mevcut niyetle ayni).
            if showCharacter then SetEntityLocallyVisible(previewPed) end
            updateAnchor()
            setupStudio()
            local chest = GetPedBoneCoords(previewPed, BONE_CHEST, 0.0, 0.0, 0.0)
            SetFocusPosAndVel(chest.x, chest.y, chest.z, 0.0, 0.0, 0.0)
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
            TriggerScreenblurFadeOut(0.0)

            -- GECICI DEBUG: ILK 300ms'de HER KAREDE (dogum ~olum penceresi 87-110ms
            -- oldugu icin 500ms'lik eski aralik bunu tamamen KACIRIYORDU), ondan sonra
            -- 500ms'de bir durum snapshot'i.
            local dbgNow = GetGameTimer()
            local dbgInBurst = (dbgNow - dbgCreatedAt) < 300
            if dbgInBurst or (dbgNow - dbgLastPrint >= 500) then
                dbgLastPrint = dbgNow
                local pc = GetEntityCoords(previewPed)
                local netOk, netVal = pcall(NetworkGetEntityIsNetworked, previewPed)
                local ownOk, ownIdx = pcall(NetworkGetEntityOwner, previewPed)
                local realVisible = realPed and DoesEntityExist(realPed) and IsEntityVisible(realPed)
                local realInterior = realPed and DoesEntityExist(realPed) and GetInteriorFromEntity(realPed)
                print(('^5[bitirim-debug] t+%dms previewPed exists=%s pos=%.2f,%.2f,%.2f interior=%s visible=%s networked=%s owner=%s || realPed interior=%s visible=%s^7')
                    :format(dbgNow - dbgCreatedAt, tostring(DoesEntityExist(previewPed)), pc.x, pc.y, pc.z,
                        tostring(GetInteriorFromEntity(previewPed)), tostring(IsEntityVisible(previewPed)),
                        tostring(netOk and netVal), tostring(ownOk and ownIdx), tostring(realInterior), tostring(realVisible)))
            end

            Wait(0)
        end
        -- GECICI DEBUG: while dongusu NEDEN sona erdi (hangi kosul false oldu)? + previewPed'in
        -- YASAM SURESI (ms) + network ID hala "var" mi (handle-reuse/ownership-migration
        -- ihtimalini ayirt etmek icin NetworkDoesEntityExistWithNetworkId ile CAPRAZ kontrol —
        -- eger local handle "yok" derken network ID hala "var" derse, entity SILINMEDI,
        -- sadece bizim local handle'imiz bozuldu/devredildi demektir; ikisi de "yok" derse
        -- entity GERCEKTEN silindi demektir).
        local dbgDiedAt = GetGameTimer()
        local dbgNetStillExists = nil
        if dbgOkNetId and dbgPreviewNetId and dbgPreviewNetId ~= 0 then
            local okCheck, stillExists = pcall(NetworkDoesEntityExistWithNetworkId, dbgPreviewNetId)
            dbgNetStillExists = okCheck and stillExists
        end
        print(('^1[bitirim-debug] RENDER THREAD SONA ERDI: active=%s previewPed~=nil=%s previewPedExists=%s | handle=%s netId=%s netIdStillExists=%s | yasamSuresi=%dms^7')
            :format(tostring(active), tostring(previewPed ~= nil), tostring(previewPed ~= nil and DoesEntityExist(previewPed)),
                tostring(dbgPreviewHandle), tostring(dbgOkNetId and dbgPreviewNetId), tostring(dbgNetStillExists),
                dbgDiedAt - dbgCreatedAt))
    end)

    -- MIRROR thread (~150ms): gercek ped -> klon appearance aynalama (movement DEGIL).
    CreateThread(function()
        while active and previewPed and DoesEntityExist(previewPed) do
            mirrorAppearance()
            mirrorWeapon(false)
            Wait(150)
        end
        -- GECICI DEBUG
        print('^1[bitirim-debug] MIRROR THREAD SONA ERDI^7')
    end)

    --[[
        GECICI DEBUG (ROUND 5, 2026-08-26) — "dag karakterin SOLUNDAYKEN" teshisi.
        SADECE OKUMA/print yapar; previewPed'in Z'sini, kamera geometrisini,
        cfg degerlerini, forwardOf/rightOf'u, computeCameraBasis/placeKlon/
        resolveSafeCamDist algoritmalarini HICBIR SEKILDE degistirmez/etkilemez.
        Amac: previewPed'in camSide (-0.22, yani anchor'in right ekseninde NEGATIF
        -> anchor'in SOLUNA) offsetlendigi noktadaki GERCEK zemin (ground) Z'sini,
        anchor'in kendi zemin Z'si VE simetrik +0.22 (sag) noktasindaki zemin Z'siyle
        karsilastirip egimli/dagli arazide asimetri olup olmadigini SAYISAL olarak
        kanitlamak. Ilk yerlesimde 1 log, sonra ~500ms'de bir log (spam yok).
    ]]
    CreateThread(function()
        local dbgTerrainLast = 0
        local dbgTerrainFirst = true

        --- GetGroundZFor_3dCoord'u guvenli sarmalar: basarisizsa nil doner (ASLA
        --- gecersiz/0 gibi bir degeri "gecerli Z" olarak KULLANMAZ). Arama baslangic
        --- noktasi olarak z+50.0 kullanilir (egimli/dagli arazide dahi anchor'in
        --- 0.22m yanindaki zemin, 50m'den fazla farkli olamayacagi icin GUVENLI bir
        --- ust sinir — cok daha yuksek/dusuk bir sonuc cikarsa asagida ayrica
        --- loglanacak "supheli deger" olarak degerlendirilebilir).
        local function groundAt(x, y, z)
            local ok, found, gz = pcall(GetGroundZFor_3dCoord, x, y, z + 50.0, false)
            if ok and found and gz then return gz end
            return nil
        end

        while active and previewPed and DoesEntityExist(previewPed) do
            local now = GetGameTimer()
            if dbgTerrainFirst or (now - dbgTerrainLast >= 500) then
                dbgTerrainFirst = false
                dbgTerrainLast = now

                if anchorPos and camR then
                    local ax, ay, az = anchorPos.x, anchorPos.y, anchorPos.z

                    -- SOL nokta: MEVCUT cfg.camSide (-0.22) ile previewPed'in GERCEKTEN
                    -- offsetlendigi nokta (placeKlon() ile AYNI formul, SADECE OKUMA).
                    local leftX = ax + camR.x * cfg.camSide
                    local leftY = ay + camR.y * cfg.camSide
                    -- SAG nokta: simetrik karsilastirma icin +0.22 (camSide'in mutlak
                    -- degeriyle AYNI buyuklukte, ters yonde).
                    local rightX = ax + camR.x * 0.22
                    local rightY = ay + camR.y * 0.22

                    local anchorGroundZ = groundAt(ax, ay, az)
                    local leftGroundZ   = groundAt(leftX, leftY, az)
                    local rightGroundZ  = groundAt(rightX, rightY, az)

                    local pp = DoesEntityExist(previewPed) and GetEntityCoords(previewPed) or nil
                    local previewGroundZ = pp and groundAt(pp.x, pp.y, pp.z) or nil

                    local leftDelta        = (leftGroundZ and anchorGroundZ) and (leftGroundZ - anchorGroundZ) or nil
                    local rightDelta       = (rightGroundZ and anchorGroundZ) and (rightGroundZ - anchorGroundZ) or nil
                    local previewGroundDelta = (previewGroundZ and anchorGroundZ) and (previewGroundZ - anchorGroundZ) or nil
                    local previewZMinusGround = (pp and previewGroundZ) and (pp.z - previewGroundZ) or nil

                    local camPos = (studioCam and DoesCamExist(studioCam)) and GetCamCoord(studioCam) or nil
                    local camPreviewDist = (camPos and pp) and #(pp - camPos) or nil

                    print(('^3[bitirim-terrain-debug] head=%.1f anchor=(%.2f,%.2f,%.2f) anchorGroundZ=%s || LEFT camSide=%.2f pt=(%.2f,%.2f) leftGroundZ=%s leftDelta=%s || RIGHT +0.22 pt=(%.2f,%.2f) rightGroundZ=%s rightDelta=%s || preview=(%.2f,%.2f,%.2f) previewGroundZ=%s previewGroundDelta=%s previewZMinusGround=%s || camDist=%.2f safeDist=%s cam=(%s) camPreviewDist=%s^7')
                        :format(
                            anchorHead, ax, ay, az, tostring(anchorGroundZ),
                            cfg.camSide, leftX, leftY, tostring(leftGroundZ), tostring(leftDelta),
                            rightX, rightY, tostring(rightGroundZ), tostring(rightDelta),
                            pp and pp.x or -1, pp and pp.y or -1, pp and pp.z or -1,
                            tostring(previewGroundZ), tostring(previewGroundDelta), tostring(previewZMinusGround),
                            cfg.camDist, tostring(curSafeDist),
                            camPos and ('%.2f,%.2f,%.2f'):format(camPos.x, camPos.y, camPos.z) or 'nil',
                            tostring(camPreviewDist)))
                end
            end
            Wait(0)
        end
    end)
end

local function DestroyPreview()
    if not active then return end
    -- GECICI DEBUG (bkz CreatePreview render thread notu): DestroyPreview'in
    -- BEKLENMEDIK sekilde tetiklenip tetiklenmedigini ayirt etmek icin. GetInvokingResource()
    -- bu export'u BASKA bir resource cagirdiysa o resource'un adini doner (ayni resource
    -- icinden -export uzerinden bile olsa- cagrilirsa genelde nil/kendi adimiz donebilir).
    local okInv, invoker = pcall(GetInvokingResource)
    print(('^1[bitirim-debug] DestroyPreview() CAGRILDI (invoker=%s previewPedExists=%s)^7')
        :format(tostring(okInv and invoker), tostring(previewPed ~= nil and DoesEntityExist(previewPed))))
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
    curSafeDist = nil
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
-- ROUND 7 GECICI DIAGNOSTIC (2026-08-26) — "dag karakterin SOLUNDAYKEN" previewPed
-- govde/kol/omuz TERRAIN/KAYA ile clipping/occlusion yasiyor mu? SADECE OKUMA.
-- Hicbir entity'nin position/heading/visibility/collision/alpha/routing bucket
-- degerini DEGISTIRMEZ -- sadece bone/kamera koordinati okur, shape-test atar,
-- print eder. /previewdebug ile ac/kapa (varsayilan KAPALI). Root cause
-- kesinlesince KALDIRILACAK.
------------------------------------------------------------------------------
local previewCollisionDebug = false
local DBG_PROBE_DISTANCE = 1.5
local DBG_TEST_FLAGS = 1 -- SADECE dunya/statik geometri (mevcut CAM_TEST_FLAGS ile AYNI desen) -> ped'ler (previewPed dahil) otomatik disarida kalir

-- Klasik PedBoneId tablosu (BONE_CHEST=24818/SKEL_Spine3 ile AYNI aile — bu
-- deger zaten yillardir bu dosyada canli/dogrulanmis calisiyor). Diger ID'ler
-- ayni yaygin/standart tablodan; herhangi biri yanlis cikarsa (silik/pelvis'e
-- esdeger bir koordinat donerse) ilgili satirdaki bone ismini degistirmek yeterli.
local DBG_BONE_PELVIS = 11816  -- SKEL_Pelvis
local DBG_BONE_SPINE0 = 57597  -- SKEL_Spine0
local DBG_BONE_SPINE2 = 24817  -- SKEL_Spine2
local DBG_BONE_NECK   = 39317  -- SKEL_Neck_1
local DBG_BONE_HEAD   = 31086  -- SKEL_Head
local DBG_BONE_L_HAND = 18905  -- SKEL_L_Hand
local DBG_BONE_R_HAND = 57031  -- SKEL_R_Hand

--- SADECE OKUMA: iki nokta arasinda kapsul shape-test atar, hit/mesafe/entity/model/
--- hit-koordinati/hit-normali doner. DBG_TEST_FLAGS=1 (dunya/statik) oldugu icin
--- previewPed/realPed dahil HICBIR ped sonuca dahil olmaz (mevcut resolveSafeCamDist'teki
--- AYNI desen) -> previewPed'in kendi govdesini "yanlislikla" hit olarak raporlama
--- riski yapisal olarak yok.
-- ROUND 8 (2026-08-26): pelvis probe'unda "SCRIPT ERROR: Error executing native"
-- gorulduyu icin StartShapeTestCapsule/GetShapeTestResult/GetEntityModel artik
-- pcall ile sarili ve HER asamadan HEMEN ONCE bir START marker basiliyor.
-- Boylece native cagrisi pcall'un bile yakalayamadigi sert bir hata ile thread'i
-- oldurse dahi, en son basilan marker hangi native'in patladigini tam olarak
-- gosterir. Radius (0.05) ve DBG_TEST_FLAGS (1) DEGISMEDI.
-- Donus imzasi degisti: hit, isError, dist, ent, model, coords, normal.
local function dbgShapeTest(tag, x1, y1, z1, x2, y2, z2)
    print(('[bitirim-collision-debug] %s SHAPE from=(%.2f,%.2f,%.2f) to=(%.2f,%.2f,%.2f)'):format(tag, x1, y1, z1, x2, y2, z2))
    print(('[bitirim-collision-debug] %s SHAPE START'):format(tag))

    local okHandle, handle = pcall(StartShapeTestCapsule, x1, y1, z1, x2, y2, z2, 0.05, DBG_TEST_FLAGS, 0, 7)
    if not okHandle then
        print(('[bitirim-collision-debug] %s SHAPE ERROR stage=StartShapeTestCapsule error=%s'):format(tag, tostring(handle)))
        return false, true, nil, 0, 0, nil, nil
    end
    print(('[bitirim-collision-debug] %s SHAPE HANDLE OK handle=%s'):format(tag, tostring(handle)))

    print(('[bitirim-collision-debug] %s SHAPE RESULT START'):format(tag))
    local okResult, retval, hit, endCoords, surfaceNormal, entityHit = pcall(GetShapeTestResult, handle)
    if not okResult then
        print(('[bitirim-collision-debug] %s SHAPE ERROR stage=GetShapeTestResult error=%s'):format(tag, tostring(retval)))
        return false, true, nil, 0, 0, nil, nil
    end
    print(('[bitirim-collision-debug] %s SHAPE RESULT OK hit=%s'):format(tag, tostring(hit)))

    if hit == 1 or hit == true then
        local dist = #(vector3(endCoords.x - x1, endCoords.y - y1, endCoords.z - z1))
        local model = 0
        if entityHit and entityHit ~= 0 then
            -- ROUND 9 (2026-08-26): GetEntityModel() tek basina "dag solda" testinde
            -- native error verebildigi icin, HIT olan entity hakkinda 6 ek salt-okunur
            -- native de (hepsi ayri pcall) eklendi. Biri patlasa bile digerleri calismaya
            -- devam eder -> entityHit'in ped/vehicle/object oldugu (ve var olup olmadigi,
            -- konumu) kesin olarak tespit edilebilir.
            print(('[bitirim-collision-debug] %s ENTITY INFO START ent=%s'):format(tag, tostring(entityHit)))

            local okExists, existsResult = pcall(DoesEntityExist, entityHit)
            if okExists then
                print(('[bitirim-collision-debug] %s ENTITY EXISTS=%s'):format(tag, tostring(existsResult)))
            else
                print(('[bitirim-collision-debug] %s ENTITY EXISTS ERROR=%s'):format(tag, tostring(existsResult)))
            end

            local okType, typeResult = pcall(GetEntityType, entityHit)
            if okType then
                print(('[bitirim-collision-debug] %s ENTITY TYPE=%s'):format(tag, tostring(typeResult)))
            else
                print(('[bitirim-collision-debug] %s ENTITY TYPE ERROR=%s'):format(tag, tostring(typeResult)))
            end

            local okPed, pedResult = pcall(IsEntityAPed, entityHit)
            if okPed then
                print(('[bitirim-collision-debug] %s ENTITY PED=%s'):format(tag, tostring(pedResult)))
            else
                print(('[bitirim-collision-debug] %s ENTITY PED ERROR=%s'):format(tag, tostring(pedResult)))
            end

            local okVeh, vehResult = pcall(IsEntityAVehicle, entityHit)
            if okVeh then
                print(('[bitirim-collision-debug] %s ENTITY VEHICLE=%s'):format(tag, tostring(vehResult)))
            else
                print(('[bitirim-collision-debug] %s ENTITY VEHICLE ERROR=%s'):format(tag, tostring(vehResult)))
            end

            local okObj, objResult = pcall(IsEntityAnObject, entityHit)
            if okObj then
                print(('[bitirim-collision-debug] %s ENTITY OBJECT=%s'):format(tag, tostring(objResult)))
            else
                print(('[bitirim-collision-debug] %s ENTITY OBJECT ERROR=%s'):format(tag, tostring(objResult)))
            end

            local okCoords, coordsResult = pcall(GetEntityCoords, entityHit)
            if okCoords then
                print(('[bitirim-collision-debug] %s ENTITY COORDS=(%.2f,%.2f,%.2f)'):format(tag, coordsResult.x, coordsResult.y, coordsResult.z))
            else
                print(('[bitirim-collision-debug] %s ENTITY COORDS ERROR=%s'):format(tag, tostring(coordsResult)))
            end

            local okModel, modelResult = pcall(GetEntityModel, entityHit)
            if okModel then
                model = modelResult
                print(('[bitirim-collision-debug] %s ENTITY MODEL OK model=%s'):format(tag, tostring(model)))
            else
                print(('[bitirim-collision-debug] %s ENTITY MODEL ERROR=%s'):format(tag, tostring(modelResult)))
            end

            print(('[bitirim-collision-debug] %s ENTITY INFO END ent=%s'):format(tag, tostring(entityHit)))
        end
        return true, false, dist, (entityHit or 0), model, endCoords, surfaceNormal
    end

    return false, false, nil, 0, 0, nil, nil
end

local function dbgFormatHit(hit, isError, dist, ent, model, coords, normal)
    if isError then return 'ERROR' end
    if not hit then return 'CLEAR' end
    local coordsStr = coords and ('(%.2f,%.2f,%.2f)'):format(coords.x, coords.y, coords.z) or 'nil'
    local normalStr = normal and ('(%.2f,%.2f,%.2f)'):format(normal.x, normal.y, normal.z) or 'nil'
    return ('HIT dist=%.2f ent=%s model=%s coords=%s normal=%s'):format(dist, tostring(ent), tostring(model), coordsStr, normalStr)
end

RegisterCommand('previewdebug', function()
    previewCollisionDebug = not previewCollisionDebug
    print(('^3[bitirim-collision-debug]^0 %s'):format(previewCollisionDebug and 'ENABLED' or 'DISABLED'))
end, false)

CreateThread(function()
    while true do
        Wait(250)
        if previewCollisionDebug then
            print(('[bitirim-collision-debug] THREAD tick active=%s previewPed=%s exists=%s camR=%s anchorPos=%s'):format(
                tostring(active),
                tostring(previewPed ~= nil),
                tostring(previewPed and DoesEntityExist(previewPed) or false),
                tostring(camR ~= nil),
                tostring(anchorPos ~= nil)
            ))
        end
        if previewCollisionDebug and active and previewPed and DoesEntityExist(previewPed) and camR and anchorPos then
            print('[bitirim-collision-debug] ENTER MAIN BLOCK')
            -- previewSide: SADECE camSide'in isaretinden (dosyanin kendi rightOf()
            -- konvansiyonuna gore previewPed'in karakterin LOCAL sag ekseninde
            -- NEGATIF/POZITIF yonde kaydigini belirtir).
            local previewSide = (cfg.camSide < 0 and 'LEFT') or (cfg.camSide > 0 and 'RIGHT') or 'CENTER'
            local camPos = (studioCam and DoesCamExist(studioCam)) and GetCamCoord(studioCam) or nil
            local previewPos = GetEntityCoords(previewPed)
            local camPreviewDist = camPos and #(vector3(previewPos.x - camPos.x, previewPos.y - camPos.y, previewPos.z - camPos.z)) or nil
            print('[bitirim-collision-debug] STEP camera/preview coords OK')

            local bones = {
                { name = 'pelvis', id = DBG_BONE_PELVIS },
                { name = 'spine0', id = DBG_BONE_SPINE0 },
                { name = 'chest',  id = BONE_CHEST },
                { name = 'spine2', id = DBG_BONE_SPINE2 },
                { name = 'neck',   id = DBG_BONE_NECK },
                { name = 'head',   id = DBG_BONE_HEAD },
                { name = 'lhand',  id = DBG_BONE_L_HAND },
                { name = 'rhand',  id = DBG_BONE_R_HAND },
            }
            print('[bitirim-collision-debug] STEP bones table OK')

            local lines = {}
            print('[bitirim-collision-debug] STEP lines OK')
            lines[#lines + 1] = ('[bitirim-collision-debug] head=%.1f previewSide=%s camDist=%.2f safeDist=%s')
                :format(anchorHead, previewSide, cfg.camDist, tostring(curSafeDist))
            lines[#lines + 1] = ('  anchor=(%.2f,%.2f,%.2f) preview=(%.2f,%.2f,%.2f) camera=%s cameraPreviewDist=%s')
                :format(anchorPos.x, anchorPos.y, anchorPos.z, previewPos.x, previewPos.y, previewPos.z,
                    camPos and ('(%.2f,%.2f,%.2f)'):format(camPos.x, camPos.y, camPos.z) or 'nil', tostring(camPreviewDist))

            -- GENEL kamera -> previewPed LOS (bone-bazli detaydan AYRI, tek ozet satir).
            print('[bitirim-collision-debug] STEP cameraLOS START')
            if camPos then
                local ovHit, ovIsError, ovDist, ovEnt, ovModel, ovCoords, ovNormal = dbgShapeTest('OVERVIEW', camPos.x, camPos.y, camPos.z, previewPos.x, previewPos.y, previewPos.z)
                lines[#lines + 1] = ('  cameraLOS(preview)=%s'):format(dbgFormatHit(ovHit, ovIsError, ovDist, ovEnt, ovModel, ovCoords, ovNormal))
            else
                lines[#lines + 1] = '  cameraLOS(preview)=camera yok'
            end
            print('[bitirim-collision-debug] STEP cameraLOS END')

            for i = 1, #bones do
                local b = bones[i]
                print(('[bitirim-collision-debug] BONE START name=%s id=%s'):format(b.name, tostring(b.id)))
                local origin = GetPedBoneCoords(previewPed, b.id, 0.0, 0.0, 0.0)
                print(('[bitirim-collision-debug] BONE COORD OK name=%s pos=(%.2f,%.2f,%.2f)'):format(
                    b.name, origin.x, origin.y, origin.z
                ))
                local leftEnd = vector3(origin.x - camR.x * DBG_PROBE_DISTANCE, origin.y - camR.y * DBG_PROBE_DISTANCE, origin.z)
                local rightEnd = vector3(origin.x + camR.x * DBG_PROBE_DISTANCE, origin.y + camR.y * DBG_PROBE_DISTANCE, origin.z)

                local lHit, lIsError, lDist, lEnt, lModel, lCoords, lNormal = dbgShapeTest('L', origin.x, origin.y, origin.z, leftEnd.x, leftEnd.y, leftEnd.z)
                local rHit, rIsError, rDist, rEnt, rModel, rCoords, rNormal = dbgShapeTest('R', origin.x, origin.y, origin.z, rightEnd.x, rightEnd.y, rightEnd.z)

                local cHit, cIsError, cDist, cEnt, cModel, cCoords, cNormal = false, false, nil, 0, 0, nil, nil
                if camPos then
                    cHit, cIsError, cDist, cEnt, cModel, cCoords, cNormal = dbgShapeTest('C', camPos.x, camPos.y, camPos.z, origin.x, origin.y, origin.z)
                end

                lines[#lines + 1] = ('  %-6s pos=(%.2f,%.2f,%.2f)'):format(b.name, origin.x, origin.y, origin.z)
                lines[#lines + 1] = ('    L=%s'):format(dbgFormatHit(lHit, lIsError, lDist, lEnt, lModel, lCoords, lNormal))
                lines[#lines + 1] = ('    R=%s'):format(dbgFormatHit(rHit, rIsError, rDist, rEnt, rModel, rCoords, rNormal))
                lines[#lines + 1] = ('    camLOS=%s'):format(dbgFormatHit(cHit, cIsError, cDist, cEnt, cModel, cCoords, cNormal))
                print(('[bitirim-collision-debug] BONE END name=%s'):format(b.name))
            end

            print('[bitirim-collision-debug] PRINT FINAL')
            print(table.concat(lines, '\n'))
        end
    end
end)

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
