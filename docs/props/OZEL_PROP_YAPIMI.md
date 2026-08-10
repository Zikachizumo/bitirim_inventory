# Özel Backdrop Prop'u Yapımı (envanter karakter arka planı)

Envanterdeki karakter önizlemesinin arkasına kendi tasarladığın bir **düz kare panel**
koymak için gereken teknik şartname ve iş akışı. Sen modeli (`.ydr` + `.ytd`) üretirsin,
ben archetype ytyp'ini otomatik üretip sisteme bağlarım.

---

## 1) Ne üreteceksin — dosya uzantıları
| Dosya | Ne | Kim üretir |
|------|-----|-----------|
| **`.ydr`** | 3B model (mesh + materyal). Kare düzlem (plane). | **Sen** (Blender) |
| **`.ytd`** | Doku sözlüğü (texture, DDS). `.ydr` içine gömülü olabilir. | **Sen** (Blender/Sollumz) |
| **`.ytyp`** | Archetype tanımı (modeli spawn edilebilir yapar). | **Ben** (CodeWalker.Core aracıyla) |

Sen bana **`.ydr`** (ve ayrıysa `.ytd`) dosyasını verirsin; gerisini ben `stream/`'e
koyup `BD_MODELS`'e ekleyip ytyp'ini üretirim.

---

## 2) Araçlar (ücretsiz, standart pipeline)
- **Blender** (3.x veya 4.x) — modelleme.
- **Sollumz** eklentisi — Blender'dan doğrudan GTA V `.ydr`/`.ytd`/`.ytyp` export eder.
  (Alternatif: 3ds Max + GIMS Evo. Sende CodeWalker var ama CodeWalker mesh ÜRETMEZ,
  sadece görüntüler/dönüştürür — mesh için Blender+Sollumz gerekir.)

---

## 3) Mesh (model) şartnamesi
- **Şekil:** tek bir **kare düzlem (plane)**, en-boy **1:1**.
- **Boyut:** ~**3m × 3m** öneririm (karakter ~1.8m; panel kadrajı doldursun).
  Kesin şart değil — oyunda `Numpad 1/2` (uzaklık) ile büyüklüğü ayarlayabilirsin.
- **Pivot / origin:** merkezde (0,0,0). Böylece arkada tam ortalanır.
- **Normaller:** kameraya bakan yüz **öne** baksın (tek yüz görünür; istersen çift taraflı
  materyal). Panel dikey dursun (XZ düzleminde, kalınlık Y ekseninde ~0).
- **Poly:** 1 quad (2 üçgen) yeterli — düz panel.

---

## 4) Doku (texture) şartnamesi — 4K için
- **Çözünürlük:** **kare** ve **2'nin kuvveti**. 4K monitörde net için **2048×2048**
  (ideal denge) veya maksimum keskinlik için **4096×4096**.
- **Format:** `.ytd` içinde **DDS**.
  - Saydamlık (alpha) istiyorsan: **BC7** veya **DXT5/BC3** (alpha kanalı olan formatlar).
  - Alpha gerekmezse: DXT1/BC1.
- **Mipmap:** açık (uzaktan titremesin).

---

## 5) %75 opaklık (saydamlık) — iki yol
1. **Kod tarafı (önerilen, zaten hazır):** backdrop varsayılanı **%75 opak** (alpha 191)
   olarak ayarlandı; oyunda **Numpad 7/8** ile ince ayar yapabilirsin. Bu, tüm objeye
   **eşit** saydamlık uygular → dokunu **opak** hazırlaman yeterli.
2. **Dokuya gömülü:** DDS alpha kanalını **%75** (191/255) yaparsan panel dokudan yarı
   saydam olur. Bu durumda materyal shader'ı **alpha blend** destekleyen bir GTA shader'ı
   olmalı (Sollumz'da örn. `decal`, `normal_decal`, `spec_alpha` / `normal_spec_reflect`).

> Not: Bu turda gördüğün "alt/üst renk farkı" hazır `hei_mph_cntl2_glass01` modelinin
> KENDİ dokusundan kaynaklanıyordu. Kendi panelinde **tek renk/tek tip** bir doku
> kullanırsan o fark olmaz.

---

## 6) Shader (materyal) seçimi
- Saydam/cam görünümü: **alpha destekli** shader (`decal`, `normal_decal`, `spec_alpha`).
- Düz opak panel + kod tarafı saydamlık (yol 1): normal shader da olur; `SetEntityAlpha`
  motor seviyesinde çalışır, çoğu shader'da objeyi soldurur.

---

## 7) İsimlendirme + teslim
- Modele **benzersiz bir isim** ver, örn. **`bitirim_backdrop01`**.
- Blender/Sollumz'da `.ydr`'yi bu isimle export et: `bitirim_backdrop01.ydr` (+ gerekiyorsa
  `bitirim_backdrop01.ytd`).
- Dosyayı bana ver → ben:
  1. `stream/bitirim_backdrop01.ydr` (+ `.ytd`) olarak koyarım,
  2. archetype ytyp'ini üretirim (mevcut cam için yaptığım araçla),
  3. `BD_MODELS`'e `bitirim_backdrop01` eklerim.
- Deploy: `git pull` + `restart ox_inventory`. Oyunda backdrop olarak görünür.

---

## BLENDER — SIFIRDAN ADIM ADIM

### Faz 0 — Kurulum (bir kez)
1. **Blender**'ı indir/kur (blender.org, 4.x).
2. **Sollumz** eklentisini indir (GitHub: Sollumz/Sollumz — "Code > Download ZIP" ya da
   Releases'ten `.zip`). ZIP'i **açma**.
3. Blender: **Edit > Preferences > Add-ons > Install…** → indirdiğin ZIP'i seç → listede
   **Sollumz**'u işaretle (aktif et).
4. Sağ tarafta **N** tuşuna basınca açılan panelde **"Sollumz Tools"** sekmesi görünmeli.

### Faz 1 — Yeni proje + temizlik
5. **File > New > General**.
6. Sahnedeki varsayılan **Cube**'u sil: üstüne tıkla → **X > Delete**. (Camera ve Light
   kalabilir, export'a dahil değiller.)
7. Ölçü birimi metre: **Scene Properties > Units > Metric** (varsayılan metre).

### Faz 2 — Kare paneli oluştur
8. **Add > Mesh > Plane**. (Varsayılan 2m×2m kare gelir — zaten kare, 1:1.)
9. Boyutu 3m yap: **N** paneli > **Item > Dimensions**: X=**3**, Y=**3**, Z=0.
10. Paneli **dik** çevir (GTA'da Z yukarı; panel kameraya baksın): obje seçili → **R, X, 90,
    Enter** (X ekseninde 90° döndür). Artık panel dikey, yüzü **-Y**'ye bakar.
11. Origin merkezde olsun: **Object > Set Origin > Origin to Geometry** (genelde zaten
    merkezde). Konumu sıfırla: **Alt+G** (konum 0,0,0'a).

### Faz 3 — Transformları uygula (ÇOK ÖNEMLİ)
12. **Object > Apply > All Transforms** (Ctrl+A > All Transforms). Bu, döndürme/ölçeği
    modele "pişirir" — yapılmazsa oyunda yamuk/yanlış boyut görünür.

### Faz 4 — UV aç
13. **Tab** ile Edit Mode → **A** (tümünü seç) → **U > Unwrap**. (Tek quad temiz maplenir.)
14. **Tab** ile Object Mode'a dön.

### Faz 5 — Görseli hazırla
15. Kullanacağın görseli **kare** ve **2'nin kuvveti** yap: **2048×2048** (ideal) veya 4K
    keskinlik için **4096×4096**. PNG olabilir (Sollumz export'ta DDS'e çevirir).
16. Tek tip/opak tut (alt-üst renk farkı istemiyorsan). Saydamlığı **koda** bırakıyoruz (%75).

### Faz 6 — Sollumz materyali + texture
17. N-panel > **Sollumz Tools > Materials**. **Shader** açılır menüsünden bir shader seç:
    - Opak panel (önerilen, saydamlığı kod veriyor): **`normal_spec_reflect`** veya **`default`**.
    - Dokudan saydamlık istiyorsan: **`decal`** / **`normal_decal`** / **`spec_alpha`**.
18. **"Create Shader Material"** butonuna bas → materyal node grubu kurulur.
19. **Shading** workspace'ine geç (üst sekme). Materyal node'larında **DiffuseSampler**
    (Image Texture) node'unu bul → **Open** ile 15. adımdaki görselini yükle.
20. Texture'ı **gömülü** yap: Sollumz'da texture'ı seçip **"Embedded"** işaretle (ytd, ydr
    içine gömülür → ayrı .ytd dosyası taşımana gerek kalmaz).

### Faz 7 — Drawable'a çevir
21. Panel mesh'i seçili → **Sollumz Tools > Create > "Convert to Drawable"** (ya da
    "Auto Convert Mesh to Drawable"). Obje bir **Drawable** hiyerarşisine dönüşür.
22. Drawable objesinin **adını** ver: Outliner'da yeniden adlandır → **`bitirim_backdrop01`**
    (küçük harf, boşluksuz — bu isim oyunda model adı olacak).

### Faz 8 — Export (.ydr)
23. **File > Export > Sollumz Export (.ydr / .yft …)** (ya da Sollumz Tools içindeki Export).
24. Format **.ydr** olsun, "Embed textures" / ytd gömme açık olsun. Bir klasöre kaydet:
    çıktı **`bitirim_backdrop01.ydr`** olmalı (ayrıca .ytd üretirse onu da al).

### Faz 9 — Bana teslim
25. `bitirim_backdrop01.ydr` (+ varsa `.ytd`) dosyasını ver. Ben `stream/`'e koyar,
    archetype ytyp'ini üretir, `BD_MODELS`'e eklerim → `git pull` + `restart ox_inventory`.

> Sollumz sürümüne göre menü adları biraz değişebilir; mantık aynı: **mesh → shader
> materyali + gömülü texture → Drawable → .ydr export**. Takılırsan hangi adımda kaldığını
> söyle.

---

## Özet
Sen: **Blender + Sollumz** ile **3m kare düz panel** + **2048² (veya 4096²) kare DDS doku**
→ `bitirim_backdrop01.ydr` (+ `.ytd`). Opaklığı bana bırak (kod %75). Gerisini ben bağlarım.
