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
    -- 2026-08-27 GERCEK KOK NEDEN BULUNDU: camDist=1.70 + fov=64 kombinasyonu
    -- GENIS-ACI PORTRE DISTORSIYONU yaratiyordu -- kamera govdeye COK yakinken
    -- genis FOV, klonun kameraya yakin kisimlarini (govdenin one bakan tarafi)
    -- orantisiz BUYUK, uzak kisimlarini KUCUK gosterir -> poz/pozisyon MUKEMMEL
    -- simetrik olsa BILE (camSide=0, ambient anim kapali, TaskStandStill duz
    -- durus) hala "yamuk/carpik" gorunur (fotografcilikta bilinen bir etki:
    -- yakin+genis-aci portre COK az kişide duz/simetrik durur). Numpad zoom-out
    -- FOV'u daha da genislettigi (80'e kadar) icin sorun BUYUYORDU. Kullanicinin
    -- "eskiden 2.55m'de duz goruyordu" hatirlamasi bu teoriyi DOGRULADI.
    -- COZUM: kamerayi GERIYE al (camDist buyut) + FOV'u AYNI dikey kapsamayi
    -- (tam-boy kadraj) koruyacak sekilde DARALT -- matematik: kapsama =
    -- 2*camDist*tan(fov/2) SABIT tutuldu (eskiden 1.70*tan(32)=1.06 -> yeni
    -- 2.55*tan(22.6)=1.06). Bu, fotografcilikta "portre icin uzun lensle
    -- uzaktan cek, genis lensle yakinlasma" kuralinin AYNISI -- persfektifi
    -- DUZLESTIRIR, distorsiyonu koklu sekilde azaltir.
    camDist   = 2.55,  -- kamera klonun ONUNDE kac metre (SABIT HEDEF; /cam ile degisir, shape-test ile kisilabilir)
    camSide   = 0.0,   -- KLONUN KADRAJDAKI yatay yeri (kamera-sag ekseni). 2026-08-29'dan beri KLONU DEGIL KAMERAYI kaydirir (bkz computeCameraBasis "LENS KAYDIRMA") -> klon her zaman oyuncunun GERCEK dunya konumunda kalir. 0 = klon kadrajin ortasinda. Ok tuslari (sol/sag) ile canli dial edilir.
    camHeight = 0.05,  -- KLONUN KADRAJDAKI dikey yeri — camSide gibi KAMERAYI kaydirir (klonun dunyadaki Z'sine DOKUNMAZ). Ok tuslari (yukari/asagi) ile dial edilir.
    lookDown  = 0.30,  -- bakis hedefi: ust gogusun kac metre ALTI (govde ortasi)
    fov       = 45.0,  -- gorus acisi (dar=yakin/buyuk gorunur) — 2026-08-27: 64'ten 45'e DARALTILDI (camDist buyumesiyle AYNI dikey kapsamayi korur, bkz ustteki not) — genis-aci distorsiyonunu azaltmak icin
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
-- Kamera geri cekilemeyip YAKLASMAK ZORUNDA kaldiginda (dar alan) FOV'u ayni
-- dikey kapsamayi (tam boy kadraj) koruyacak sekilde GENISLETIRIZ -> klon asla
-- kirpilmaz. Bu ust sinir olmasa cok dar alanlarda FOV 100+'e cikip asiri
-- genis-aci distorsiyonu yaratirdi (bkz camDist/fov notu yukarida).
local MAX_COMPENSATED_FOV = 75.0

------------------------------------------------------------------------------
-- DAR/KAPALI/ENGELLI ALAN COZUMU: STUDIO YONUNUN (AZIMUT) OTOMATIK SECIMI
------------------------------------------------------------------------------
-- SORUN (2026-08-29, kullanici ekran goruntuleri): kamera HER ZAMAN oyuncunun
-- ARKASINDA konumlaniyordu, yani sahnenin yonu TAMAMEN oyuncunun o anki bakis
-- yonune bagliydi. Kopru ayagi/beton kolon dibinde veya magaza rafi-tezgahi
-- arasinda canta acilinca kadraj bu geometriyle DOLUYOR: klonun onunde tezgah,
-- arkasinda beton kolon kaliyor, sahne kullanilamaz hale geliyordu.
-- COZUM: klonun ETRAFINDAKI yonler taranir; her yon icin (a) KAMERA tarafindaki
-- serbest mesafe (kadraji BU belirler) ve (b) klonun ARKASINDAKI (arka plan)
-- serbest mesafe olculur, en FERAH yon secilir. Oyuncunun kendi bakis yonu kucuk
-- bir BONUSLA her zaman ilk adaydir -> ACIK ALANDA DAVRANIS HIC DEGISMEZ, sadece
-- sikisik yerlerde sahne ferah yone doner. Klon kameraya bakmaya devam ettigi
-- icin (heading = studioYaw + 180) kullanicinin gordugu TEK fark ARKA PLANDIR.
-- TARAMA CANTA ACILIRKEN BIR KEZ yapilir, secilen yon canta kapanana kadar
-- DEGISMEZ. Ilk surumde 500ms'de bir tazeleniyordu; olcum sonuclarinin bir kismi
-- her turda farkli karede yetistigi icin secilen yon durmadan degisiyor ve sahne
-- oynuyordu (kullanici: "ekranda saniyede bir sicrama"). Tek seferlik tarama hem
-- bu sorunu kokten kaldirir hem de yeterlidir: canta acikken oyuncu yerinde durur.
local YAW_STEPS        = 8      -- 360/8 = 45 derecelik adimlarla aday yon
local YAW_BATCH        = 2      -- ayni karede baslatilan aday yon sayisi (2 yon x 3 yukseklik x 2 taraf = 12 es zamanli shape test) -> tarama 4 karede biter
local YAW_PROBE_H      = { 0.35, 1.00, 1.60 }  -- ayak / govde / bas hizasi (tek yukseklik ince tezgah/korkulugu KACIRIR)
local YAW_BACK_CLEAR   = 2.20   -- klonun ARKASINDA (arka plan) aranan bosluk (metre) — bundan fazlasi puanlamada AYNI sayilir
local YAW_BACK_WEIGHT  = 0.60   -- arka plan IKINCIL (kadraji kamera tarafi belirler) ama ONEMSIZ DEGIL: kolon/raf dibinde sikayetin ASIL kaynagi arka plandi
local YAW_NATURAL_BONUS = 0.45  -- oyuncunun kendi bakis yonune verilen avantaj -> acik alanda ASLA gereksiz yere donmez (ama tek tarafi kapali bir yeri de "idare eder" diye SECMEZ)
local PROBE_MAX_WAIT   = 8      -- bir grubun shape-test sonuclari icin beklenecek EN FAZLA kare; gelmezse o grup PUANLANMAZ (yarim olcumle karar vermek "saniyede bir sicrama" hatasinin sebebiydi)
local SCAN_MAX_FRAMES  = 14     -- TUM taramanin toplam kare butcesi -- sonuclar gecikse bile canta acilisi bu suredan (~230ms) fazla beklemez, kalan yonler puanlanmadan gecilir

------------------------------------------------------------------------------
-- TERRAIN-SAFE YERLESIM: KALDIRILDI (2026-08-29)
------------------------------------------------------------------------------
-- Round 10/11'de eklenen iki duzeltme (klonu SOLDAKI kaya/duvardan SAGA itme +
-- altindaki zemin daha yuksekse YUKARI kaldirma) SADECE su yuzden gerekliydi:
-- klon, kadrajda dogru yerde dursun diye camSide/camHeight ile oyuncunun gercek
-- konumundan KAYDIRILIYORDU; kaydirilan noktada bazen kaya/yamac/zemin farki
-- oluyordu. Bu iki duzeltmenin KENDISI de sonradan hatalarin kaynagi oldu
-- (kopru tabliyesini "zemin" sanip klonu 0.60m havaya kaldirmasi, ic mekanda ust
-- kat zeminine carpmasi).
-- Klon ARTIK HIC KAYDIRILMIYOR (kadraj yerlesimi kamerayla yapiliyor, bkz
-- computeCameraBasis "LENS KAYDIRMA") -> klon her zaman oyuncunun GERCEK ayak
-- bastigi noktada. Oyuncunun kendisi kayaya gomulu/havada olamayacagi icin bu
-- duzeltmelere ARTIK GEREK YOK; ikisi de (ve LEFT_TERRAIN_*/MAX_TERRAIN_Z_LIFT/
-- GROUND_PROBE_MARGIN sabitleri) tamamen kaldirildi.


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
local anchorHead   = 0.0    -- oyuncunun GERCEK heading'i (her karede tazelenir) — studio yon taramasinin ILK/tercihli adayidir, kamera artik DOGRUDAN bunu degil studioYaw'i kullanir
local dragYaw      = 0.0    -- kullanici surukleme/donme ofseti (klonu dondurur)
local compCache    = {}     -- aynalama diff onbellegi
local curWeapon    = nil
local camF         = nil    -- kamera ileri vektoru (studioYaw'dan turetilir)
local camR         = nil    -- kamera sag vektoru (studioYaw'dan turetilir; camSide bu eksende kaydirir)
local chestOffsetZ = nil    -- klonun gogus yuksekliginin ankora gore ofseti; BIR KEZ olculur (bkz chestZ) -> kamera Z nefes animasyonuyla titremez
local studioCamDist = nil   -- canta acilisinda BIR KEZ belirlenen kamera mesafesi (secilen yonun olculen boslugundan); canta kapanana kadar SABIT -> kamera hic oynamaz
local studioYaw    = nil    -- sahnenin O ANKI yonu (yumusak sekilde studioYawTarget'a yaklasir)
local studioYawTgt = nil    -- taramanin sectigi HEDEF yon (bkz "STUDIO YONUNUN OTOMATIK SECIMI")

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

--- Sahnenin O ANDA gecerli yonu. Tarama henuz sonuc uretmediyse (ilk kare)
--- oyuncunun kendi heading'ine duser -> eski davranisla BIREBIR ayni baslangic.
local function currentYaw()
    return studioYaw or anchorHead
end

--- previewPed'i SADECE GERCEKTEN degistiyse tasir/dondurur.
--- Konum/heading her karede YENIDEN yazilmasi (ayni degerle bile) oyunun ped ses
--- sistemini tetikleyip sessiz ortamda duyulan "her saniye adim atiyor / spawn
--- oluyor" tarzi bir artefakt uretebiliyor (kullanici kulaklikla bildirdi,
--- 2026-08-29; canta kapaninca ses kayboluyordu). Klon zaten dogru yerdeyse
--- native HIC cagrilmaz -> oyuncu yerinde dururken sahne TAMAMEN hareketsiz.
--- Aractayken anchor gercekten degistigi icin takip AYNEN calismaya devam eder.
local POSE_POS_EPS  = 0.01   -- metre
local POSE_HEAD_EPS = 0.10   -- derece
local function setKlonPose(x, y, z, heading)
    local c = GetEntityCoords(previewPed)
    if math.abs(c.x - x) > POSE_POS_EPS or math.abs(c.y - y) > POSE_POS_EPS or math.abs(c.z - z) > POSE_POS_EPS then
        SetEntityCoordsNoOffset(previewPed, x, y, z, false, false, false)
    end
    local h = GetEntityHeading(previewPed)
    if math.abs((h - heading + 540.0) % 360.0 - 180.0) > POSE_HEAD_EPS then
        SetEntityHeading(previewPed, heading)
    end
end

--- Klonun gogus yuksekligi (kadraj/odak referansi), ankora GORE ofset olarak
--- BIR KEZ olculur ve oturum boyunca kullanilir.
--- NEDEN CANLI OKUNMUYOR (2026-08-29): GetPedBoneCoords canli bir kemik konumu
--- dondurur; klon dursa bile nefes alma animasyonu yuzunden bu deger her karede
--- milimetrik oynar. Kamera Z'si buna bagli oldugu icin kamera (ve ona bagli SES
--- DINLEYICISI) surekli titriyordu -> sessiz ortamda duyulan periyodik ses
--- artefaktinin kaynaklarindan biri. Ofset sabit olunca kamera tas gibi durur;
--- oyuncu araca binip hareket ederse anchorPos degistigi icin takip bozulmaz.
local function chestZ()
    if chestOffsetZ == nil then
        if not previewPed or not DoesEntityExist(previewPed) or not anchorPos then return nil end
        local c = GetPedBoneCoords(previewPed, BONE_CHEST, 0.0, 0.0, 0.0)
        chestOffsetZ = c.z - anchorPos.z
    end
    return anchorPos.z + chestOffsetZ
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
        SetEntityHeading(backdrop, (currentYaw() + 180.0) % 360.0)
    end
    if backdrop2 and DoesEntityExist(backdrop2) then
        SetEntityCoordsNoOffset(backdrop2, bx - fwd.x * 0.1, by - fwd.y * 0.1, bz, false, false, false)
        SetEntityHeading(backdrop2, currentYaw() % 360.0)
    end
end

------------------------------------------------------------------------------
-- STUDIO YONU TARAMASI (bkz yukaridaki "DAR/KAPALI/ENGELLI ALAN COZUMU" notu)
------------------------------------------------------------------------------
--- (cx,cy,cz)'den (dx,dy) yonunde maxDist metreye kadar bakan bir shape test
--- BASLATIR ve handle dondurur. Sonuc AYNI KAREDE hazir olmaz -> bkz tryReadProbe.
local function startFreeProbe(cx, cy, cz, dx, dy, maxDist)
    return StartShapeTestCapsule(cx, cy, cz,
        cx + dx * maxDist, cy + dy * maxDist, cz,
        CAM_TEST_RADIUS, CAM_TEST_FLAGS, 0, 7)
end

--- Sonuc HAZIRSA serbest mesafeyi, hazir DEGILSE nil doner.
--- KRITIK (2026-08-29, kullanici "ekranda saniyede bir sicrama" olarak bildirdi):
--- GetShapeTestResult'in ILK donus degeri DURUMDUR (2 = hazir, 1 = hesaplaniyor).
--- Bu durum eskiden yok sayiliyordu; hesaplanmakta olan bir isin "carpma yok"
--- gibi okunmasi o yonu "tamamen acik" gosteriyordu. Hangi isinin hangi karede
--- yetisecegi degisken oldugu icin her taramada BASKA bir yon kazaniyor, sahne
--- surekli oraya savriliyordu. Artik hazir olmayan sonuc OKUNMAZ, beklenir.
local function tryReadProbe(handle, cx, cy, maxDist)
    local state, hit, endCoords = GetShapeTestResult(handle)
    if state ~= 2 then return nil end
    if hit == 1 or hit == true then
        local d = #(vector3(endCoords.x - cx, endCoords.y - cy, 0.0))
        if d < maxDist then return d end
    end
    return maxDist
end

--- Bir grubun butun isinlarini sonuclanana kadar (en fazla PROBE_MAX_WAIT kare)
--- toplar. Hepsi geldiyse true, gelmediyse false doner -> eksik olcumle karar
--- VERILMEZ, o grup atlanir.
local function collectProbes(batch, ox, oy, budget)
    local pending = #batch * #YAW_PROBE_H * 2
    local tries = 0
    while pending > 0 and tries < PROBE_MAX_WAIT and budget.frames < SCAN_MAX_FRAMES do
        Wait(0)
        tries = tries + 1
        budget.frames = budget.frames + 1
        if not active then return false end
        for _, c in ipairs(batch) do
            for k = 1, #YAW_PROBE_H do
                if c.camD[k] == nil then
                    local d = tryReadProbe(c.camH[k], ox, oy, cfg.camDist)
                    if d then c.camD[k] = d; pending = pending - 1 end
                end
                if c.backD[k] == nil then
                    local d = tryReadProbe(c.backH[k], ox, oy, YAW_BACK_CLEAR)
                    if d then c.backD[k] = d; pending = pending - 1 end
                end
            end
        end
    end
    return pending == 0
end

--- Klonun etrafindaki YAW_STEPS yonu tarar, en ferah olani studioYawTgt'ye yazar.
--- SADECE canta acilirken (kamera aktiflesmeden once) BIR KEZ calisir — periyodik
--- tekrar YOK (bkz CreatePreview'daki not). Kendi Wait(0)'lari oldugu icin bir
--- coroutine icinden cagrilmalidir.
local function scanStudioYaw()
    if not active or not anchorPos then return end
    local origin, natural = anchorPos, anchorHead
    local best, bestScore, bestClear = nil, -1.0, nil
    local budget = { frames = 0 }   -- tum taramanin ortak kare butcesi (bkz SCAN_MAX_FRAMES)

    -- Adaylar YAW_BATCH'lik gruplar halinde islenir: motorun ayni anda
    -- hesaplayabilecegi shape-test sayisi sinirli oldugu icin 8 yonun 6'sar isini
    -- TEK karede baslatmak sonuclari geciktirir; tek tek ilerlemek ise acilisi
    -- gereksiz uzatir.
    local i = 0
    while i < YAW_STEPS and budget.frames < SCAN_MAX_FRAMES do
        if not active or not anchorPos then return end
        local batch = {}
        for _ = 1, YAW_BATCH do
            if i >= YAW_STEPS then break end
            local yaw = (natural + i * (360.0 / YAW_STEPS)) % 360.0
            local f = forwardOf(yaw)
            local camH, backH = {}, {}
            for k, h in ipairs(YAW_PROBE_H) do
                local z = origin.z + h
                camH[k]  = startFreeProbe(origin.x, origin.y, z, -f.x, -f.y, cfg.camDist)
                backH[k] = startFreeProbe(origin.x, origin.y, z,  f.x,  f.y, YAW_BACK_CLEAR)
            end
            batch[#batch + 1] = { idx = i, yaw = yaw, camH = camH, backH = backH, camD = {}, backD = {} }
            i = i + 1
        end

        -- Olcumler EKSIKSE bu grup PUANLANMAZ (yarim veriyle karar verilmez),
        -- diger gruplarla devam edilir.
        if collectProbes(batch, origin.x, origin.y, budget) then
            for _, c in ipairs(batch) do
                -- Bir yonun puani EN DAR yuksekligiyle belirlenir: gogus hizasi bos
                -- olsa bile diz hizasindaki tezgah kadraji bozar (magaza gorseli).
                local camClear, backClear = cfg.camDist, YAW_BACK_CLEAR
                for k = 1, #YAW_PROBE_H do
                    if c.camD[k] < camClear then camClear = c.camD[k] end
                    if c.backD[k] < backClear then backClear = c.backD[k] end
                end

                local score = camClear + backClear * YAW_BACK_WEIGHT
                if c.idx == 0 then score = score + YAW_NATURAL_BONUS end  -- oyuncunun kendi bakis yonu
                if score > bestScore then bestScore, best, bestClear = score, c.yaw, camClear end
            end
        elseif not active then
            return
        end
    end

    -- Hicbir yon olculemediyse (butun isinlar zaman asimina ugradi) sahneyi
    -- oyuncunun kendi bakis yonunde birak — eski davranisin AYNISI.
    studioYawTgt = best or natural

    -- KAMERA MESAFESI de burada, SECILEN yonun OLCULEN boslugundan BIR KEZ
    -- belirlenir; canta kapanana kadar degismez (bkz resolveSafeCamDist notu).
    -- Yon ferahsa istenen mesafe aynen kullanilir; dar ise duvara gomulmemek
    -- icin guvenlik payi kadar geride durulur.
    if bestClear and bestClear < cfg.camDist then
        studioCamDist = math.max(MIN_CAM_DIST, bestClear - CAM_SAFETY_MARGIN)
    else
        studioCamDist = cfg.camDist
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
--- KAMERA MESAFESI ARTIK HER KARE HESAPLANMIYOR (2026-08-29).
--- Eskiden her karede kamera ile klon arasina bir shape test atilip mesafe
--- yeniden belirleniyordu. Iki sorunu vardi:
---   1) test AYNI KAREDE okunuyordu -> sonuc cogu zaman hazir degil, yani
---      koruma pratikte calismiyordu; ara sira hazir gelen bir sonuc ise
---      "kuculme ANINDA uygulanir" kurali yuzunden kamerayi tek karede
---      metrelerce one ziplatiyordu,
---   2) ses dinleyicisi (audio listener) kameraya bagli oldugu icin bu
---      ziplama, sessiz ortamda duyulan periyodik bir ses artefakti
---      uretiyordu (kullanici: "her saniye adim atiyor/spawn oluyor gibi
---      render sesi", canta kapaninca kayboluyor).
--- ARTIK: guvenli mesafe, yon taramasi sirasinda SECILEN yonun OLCULEN
--- boslugundan BIR KEZ hesaplanir (bkz scanStudioYaw -> studioCamDist) ve
--- canta kapanana kadar SABIT kalir -> kamera tamamen hareketsiz, dolayisiyla
--- ses dinleyicisi de hareketsiz.

local function computeCameraBasis()
    if not previewPed or not DoesEntityExist(previewPed) or not studioCam or not anchorPos then return end

    -- Sahnenin yonu: tarama canta acilirken BIR KEZ karar verir ve o yon canta
    -- kapanana kadar SABIT kalir (studioYaw). Tarama sonuc uretmediyse oyuncunun
    -- kendi heading'ine duser -> eski davranisin AYNISI.
    -- SABIT OLMASI KASITLI (2026-08-29): yon canta acikken tekrar hesaplansaydi
    -- her tazelemede kucuk olcum farklari sahneyi oynatirdi; kullanici bunu
    -- "ekranda saniyede bir sicrama" olarak bildirdi.
    local yaw = studioYaw or studioYawTgt or anchorHead
    studioYaw = yaw
    local fwd = forwardOf(yaw)
    local right = rightOf(yaw)
    -- KLONUN YUZU kameraya donuk olsun diye +180 (bkz asagidaki YUZ/YON NOTU) —
    -- SADECE gorsel/kozmetik, kameranin konumu/baktigi yonu (dolayisiyla arka
    -- planda gorunen dunya yonu) ETKILEMEZ. dragYaw da BURADA dahil edilir:
    -- eskiden bu satir dragYaw'siz, placeKlon ise dragYaw'li yaziyordu -> klon
    -- her karede IKI FARKLI heading arasinda gidip geliyordu (kullanici mouse ile
    -- cevirdiginde). Ikisi artik AYNI degeri kullanir.
    setKlonPose(anchorPos.x, anchorPos.y, anchorPos.z, (yaw + 180.0 + dragYaw) % 360.0)
    local cz = chestZ()
    if not cz then return end
    camF = fwd
    camR = right

    -- LENS KAYDIRMA (2026-08-29, KULLANICI BILDIRDI): klonun kadrajdaki yeri
    -- (sol taraftaki KARAKTER panelinin ortasi) ESKIDEN KLONU dunyada yana/yukari
    -- kaydirarak ayarlaniyordu -> klon oyuncunun GERCEK durdugu noktadan gozle
    -- gorulur sekilde KAYIK duruyordu ("oyun ici karakter beyaz+sari cizginin
    -- kesistigi noktada, canli ped biraz solunda"). ARTIK KLON HIC KAYDIRILMAZ
    -- (bkz placeKlon); ayni yerlesimi KAMERA ile yapariz: kamera VE bakis hedefi
    -- AYNI miktarda yana (sx) / yukari (sz) otelenir -> sahne kadrajda ayni yere
    -- oturur ama klon oyuncunun GERCEK dunya konumunda kalir.
    -- ISARET: kadraji SAGA otelemek klonu ekranda SOLA goturur; ok tuslarinin
    -- yonu degismesin diye camSide/camHeight'in TERSI alinir.
    local sx, sz = -cfg.camSide, -cfg.camHeight
    local aimX = anchorPos.x + right.x * sx
    local aimY = anchorPos.y + right.y * sx
    local aimZ = cz + sz

    -- Tarama sirasinda bir kez belirlenen SABIT mesafe (bkz yukaridaki not).
    local dist = math.min(cfg.camDist, studioCamDist or cfg.camDist)

    SetCamCoord(studioCam,
        aimX - fwd.x * dist,
        aimY - fwd.y * dist,
        aimZ)

    -- FOV TELAFISI: kamera bir engel yuzunden hedef mesafesine cikamadiysa
    -- (dar/kapali alan) SABIT bir FOV klonu KIRPARDI (kadraj daralir, kafa/ayak
    -- disarida kalir). Dikey kapsamayi (kapsama = 2*mesafe*tan(fov/2)) SABIT
    -- tutacak sekilde FOV'u genisletiriz -> klon her mesafede TAM BOY kalir.
    -- Genis-aci distorsiyonu buyumesin diye MAX_COMPENSATED_FOV ile sinirli.
    local fov = cfg.fov
    if dist < cfg.camDist - 0.01 then
        local halfCoverage = cfg.camDist * math.tan(math.rad(cfg.fov) * 0.5)
        -- Telafi SADECE GENISLETIR: kullanici Numpad ile cfg.fov'u zaten ust sinirin
        -- uzerine cikardiysa (zoom-out) daraltip zoom'unu geri almaz.
        fov = math.max(cfg.fov, math.min(MAX_COMPENSATED_FOV, math.deg(2.0 * math.atan(halfCoverage / dist))))
    end
    SetCamFov(studioCam, fov)
    -- Kamera ARKADA (-fwd), buraya (anchorPos, klonun konumu) bakar -> bakis yonu
    -- otomatik +fwd olur (klonla AYNI yon) — pozisyon flip'i yeterli, ayrica bir
    -- "ileriye bak" hedefi gerekmez.
    PointCamAtCoord(studioCam, aimX, aimY, aimZ - cfg.lookDown)
end

--- Klonu yerlestirir. ARTIK HICBIR OFSET UYGULAMAZ: klon oyuncunun GERCEK dunya
--- konumunda (anchorPos) ve gercek noktasinda durur -- oyun icinde karakter yol
--- cizgilerinin kesistigi noktadaysa, cantada da TAM O NOKTADA durur.
--- KLONUN KADRAJ ICINDEKI yeri (camSide/camHeight) KAMERAYI kaydirarak ayarlanir
--- (bkz computeCameraBasis "LENS KAYDIRMA") -> gorunum ayni, konum GERCEK.
local function placeKlon()
    if not previewPed or not DoesEntityExist(previewPed) or not camR or not anchorPos then return end
    setKlonPose(anchorPos.x, anchorPos.y, anchorPos.z, (currentYaw() + 180.0 + dragYaw) % 360.0)
    positionBackdrop(camF, anchorPos.x, anchorPos.y, chestZ() or anchorPos.z)
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
--- Notr/simetrik durus: previewPed'e ozel bir "sahne" animasyonu (orn. soygun
--- ekibi bekleme animi) OYNATMIYORUZ artik -- boyle animasyonlar genelde rahat/
--- yan-donuk duruslar icin tasarlanir (kameraya degil, digerlerine bakar), zoom
--- out'ta govde daha cok gorununce bu asimetri "yamuk" gibi algilaniyordu
--- (2026-08-27, kullanici bildirdi + ekran goruntusuyle dogrulandi). TaskStandStill
--- ped'in KENDI varsayilan "oldugu yerde durma" duruşunu kullanir -- normal oyun
--- ici bekleme pozu, SetEntityHeading ile ayarlanan yone tam kare/simetrik durur,
--- ayrica anim dict yuklemesi gerektirmez (RequestAnimDict/HasAnimDictLoaded
--- bekleme dongusune gerek kalmadi).
local function playIdle()
    if not previewPed or not DoesEntityExist(previewPed) then return end
    -- ClonePed, gercek oyuncunun O ANKI aktif task'ini (yuruyor/donuyor/vs.) miras
    -- alabilir -- TaskStandStill tek basina bunun UZERINE binip beklenmedik bir
    -- karisim/gecikme yaratabilir. Once sert sifirla, SONRA duz duruşu ata.
    ClearPedTasksImmediately(previewPed)
    TaskStandStill(previewPed, -1)
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
    -- TaskStandStill'in KENDI temel duruşu simetriktir, AMA GTA ped'leri bunun
    -- ustune periyodik olarak rastgele "ambient idle" varyasyonlari (etrafa
    -- bakinma, agirlik degistirme, vb.) oynatmaya devam eder -- bu, SetBlockingOf-
    -- NonTemporaryEvents'in KAPSAMADIGI AYRI bir katman (o sadece disaridan
    -- tetiklenen reaksiyonlari engeller, KENDI ambient varyasyonunu degil). Bu
    -- yuzden klon zaman zaman "yamuk/yana donuk" gorunuyordu (2026-08-27,
    -- kullanici bildirdi). SetPedCanPlayAmbientAnims(false) bu varyasyon katmanini
    -- tamamen kapatir -> previewPed HER ZAMAN TaskStandStill'in duz/simetrik
    -- temel pozunda kalir.
    SetPedCanPlayAmbientAnims(previewPed, false)
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
    -- thread). studioCamDist/studioYaw da her acilista sifirlanir ki eski oturumdan kalan
    -- collision-mesafesi yeni sahneye "sizmasin".
    updateAnchor()
    dragYaw = 0.0
    studioCamDist, chestOffsetZ = nil, nil
    -- Studio yonu her acilista SIFIRLANIR: ilk kare oyuncunun kendi bakis yonuyle
    -- (eski davranisin AYNISI) baslar, tarama thread'i sonuc uretince (ilk sonuc
    -- ~150ms) sahne gerekiyorsa ferah yone YUMUSAKCA doner.
    studioYaw, studioYawTgt = nil, nil

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

    -- ILK YON TARAMASI kamera AKTIFLESMEDEN ONCE calisir -> sahne daha ILK karede
    -- dogru (ferah) yonde acilir, acildiktan sonra gozle gorulur bir donme OLMAZ
    -- Secilen yon canta kapanana kadar SABIT kalir (periyodik tazeleme YOK).
    -- Tarama grup basina sonuclar gelene kadar bekler (tipik 8 yon / YAW_BATCH =
    -- 4 kare, ~65ms; sonuclar gecikirse grup basina en fazla PROBE_MAX_WAIT kare).
    scanStudioYaw()

    -- GUVENLIK: yukaridaki Wait(0)'lar CreatePreview'i ARTIK kesilebilir (preemptible)
    -- yapiyor — bu pencerede kullanici envanteri ANINDA kapatirsa (ayri bir coroutine'de
    -- DestroyPreview() calisirsa) previewPed COKTAN silinmis olabilir. Boyle bir durumda
    -- silinmis/gecersiz entity uzerinde native cagirmamak icin burada durup cikariz
    -- (DestroyPreview zaten her seyi temizledi, tekrar dokunmuyoruz).
    if not active or not previewPed or not DoesEntityExist(previewPed) then return end

    setupStudio()   -- taramanin sectigi yonle kamerayi/klonu yeniden otur

    FreezeEntityPosition(previewPed, true)  -- KLON statik (ARTIK oda kaydi olustuktan SONRA)
    SetEntityCollision(previewPed, false, false)

    SetCamActive(studioCam, true)
    -- ANINDA GECIS: bir sonraki frame direkt studio kadrajinda goruntulenir (ease=false,
    -- sure=0). Smooth blend YOK — kullanici istegi. (Yukaridaki oda-kaydi + yon
    -- taramasi beklemesi toplam ~6 kare / ~100ms, goz ile fark edilmez -> "aninda"
    -- his korunur; buna karsilik sahne ILK karede dogru yonde acilir.)
    RenderScriptCams(true, false, 0, true, true)
    playIdle()
    mirrorWeapon(true)

    -- ox'un screenblur'u ZATEN kapali (character_client.lua: client.screenblur=false),
    -- bu yalnizca emniyet: acilista bir kez varsa calisan fade'i kes. ESKIDEN HER
    -- KAREDE cagriliyordu (asagidaki render thread icinde) -- screenblur fade'i
    -- oyunun frontend/pause ses sahnesine bagli oldugu icin her kare yeniden
    -- tetiklemek sessiz ortamda duyulabilen bir ses artefakti birakabiliyor
    -- (kullanici kulaklikla bildirdi, 2026-08-29). Tek sefer yeterli.
    if IsScreenblurFadeRunning() then DisableScreenblurFade() end
    TriggerScreenblurFadeOut(0.0)

    -- RENDER thread (Wait 0): gercek bedeni yerel gizle + HER KAREDE ankoru guncelle
    -- (araç/uçak/helikopterle hareket ederken sahne akici sekilde takip eder) + kadraji
    -- oturt + odak klona.
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
            -- Odak SABIT bir noktaya kurulur (canli kemik degil) -> streaming/ses
            -- sistemi her karede yeniden hedeflenmez (bkz chestZ notu).
            SetFocusPosAndVel(anchorPos.x, anchorPos.y, chestZ() or anchorPos.z, 0.0, 0.0, 0.0)
            -- Blur SADECE gercekten calisiyorsa kesilir; her karede yeniden
            -- TETIKLENMEZ (bkz yukaridaki ses artefakti notu).
            if IsScreenblurFadeRunning() then DisableScreenblurFade() end
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
    -- Sahne yonu bir sonraki acilisa SIZMASIN (yeni yer, yeni tarama).
    studioYaw, studioYawTgt = nil, nil

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
    studioCamDist, chestOffsetZ = nil, nil
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
    SetEntityHeading(previewPed, (currentYaw() + 180.0 + dragYaw) % 360.0)
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
---   Ok tuslari up/down    = KLONUN KADRAJDAKI dikey yeri (camHeight)
---   Ok tuslari left/right = KLONUN KADRAJDAKI yatay yeri (camSide)
---   Numpad 1/2 zoomin/zoomout = ZOOM (fov; kucuk fov=yakin/buyuk gorunur)
--- 2026-08-29'dan beri bu iki eksen KLONU DEGIL KAMERAYI oteler (lens kaydirma,
--- bkz computeCameraBasis) -> klon oyuncunun GERCEK konumunda kalir. Isaret
--- computeCameraBasis'te terslendigi icin basilan tusun yonu ile klonun ekranda
--- kaydigi yon HALA AYNI (ters paralaks YOK).
--- Begenilen degerleri F8'de gorup soyle -> kalici yaparim.
local function TuneScene(action)
    if not active then return end
    local POS, FOVSTEP = 0.10, 2.0  -- tek tusa basinca ACIKCA gorunur adim
    if action == 'up' then
        cfg.camHeight = cfg.camHeight + POS
        setupStudio()
    elseif action == 'down' then
        cfg.camHeight = cfg.camHeight - POS
        setupStudio()
    elseif action == 'left' then
        cfg.camSide = cfg.camSide - POS
        setupStudio()
    elseif action == 'right' then
        cfg.camSide = cfg.camSide + POS
        setupStudio()
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
