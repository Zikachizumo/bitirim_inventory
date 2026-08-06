# Kıyafet (Ekipman Item'i) Ekleme Rehberi

Bu rehber, envantere **yeni bir giyilebilir kıyafet item'i** eklemeyi baştan sona
anlatır. Üç şey gerekir: **(1)** item tanımı, **(2)** slot + drawable/texture
eşlemesi, **(3)** görsel (PNG). Üçü de aşağıda.

> Kısa mantık: Oyuncu item'i **use** eder (Kullan / çift sol tık / sağ tık) →
> karakter panelinde ilgili slota takılır + oyunda ped'e uygulanır + DB'ye
> kaydedilir (relog'da kalır). Panelde dolu slota tıklayınca item envantere döner.

---

## Adım 0 — Bir parça seç ve drawable/texture sayılarını bul

GTA'da kıyafet = **component/prop id** + **drawable** + **texture**. Bu sayılar
**cinsiyete göre değişir** (erkek `mp_m_freemode_01` ≠ kadın `mp_f_freemode_01`).

Sayıları bulmanın en kolay yolu, oyundaki **kıyafet dükkânı** (illenium) + bizim
yardımcı komut:

1. Kıyafet dükkânına gir, istediğin parçayı (ör. bir maske) **üstüne giy**.
2. Menüden çık, oyunda şunu yaz:
   ```
   /kiyafetbak
   ```
3. **F8 konsolunu** aç. Şöyle bir çıktı görürsün (cinsiyet + her slotun değeri):
   ```
   [bitirim] Su an giyili degerler — cinsiyet: erkek (male)
     slot      | tip        id | drawable texture
     mask      | component   1 | drawable=52 texture=0
     hat       | prop        0 | drawable=5  texture=0
     ...
   ```
4. Eklemek istediğin parçanın satırındaki **drawable** ve **texture**'ı not al
   (örnekte maske: component 1, drawable 52, texture 0).

> Kadın karakter için doğru sayılar farklı olabilir. İki cinsiyeti de destekleyeceksen
> bir de kadın karakterle aynı parçayı giyip `/kiyafetbak` çalıştır, o sayıları da al.

---

## Adım 1 — Item tanımı (`data/items.lua`)

Bag/örnek kıyafetlerin yanına yeni item ekle. `consume`/`usetime` **yazma**
(use akışı bizim giyme sistemine düşsün). `close = false` → giyince envanter açık kalır.

```lua
['mask_black'] = {
    label = 'Siyah Maske',
    weight = 200,
    stack = false,
    close = false,
},
```

---

## Adım 2 — Slot + görünüm eşlemesi (`data/bitirim_clothing.lua`)

`items` tablosuna item adını, hangi panel slotuna gittiğini ve drawable/texture'ı gir.

**Basit (erkek/kadın aynı):**
```lua
['mask_black'] = { slot = 'mask', drawable = 52, texture = 0 },
```

**Cinsiyete göre (drawable farklıysa — çoğu giysi):**
```lua
['mask_black'] = {
    slot = 'mask',
    male   = { drawable = 52, texture = 0 },
    female = { drawable = 33, texture = 0 },
},
```

Kullanılabilir `slot` anahtarları (aynı dosyadaki `slots` tablosu):

| Aksesuar (prop) | Giysi (component) |
|---|---|
| `hat` `glasses` `ears` `watch` `ring` | `mask` `gloves` `pants` `shoes` `necklace` `tshirt` `armour` `jacket` |

> `bag` (çanta), `weapon` (silah), `ammo` bu sistemde YÖNETİLMEZ — ayrı çalışır.

---

## Adım 3 — Görsel (`web/images/<item_adı>.png`)

Envanterde item görselini **dosya adından** çeker: `web/images/mask_black.png`.
PNG'yi bu klasöre koy (dosya adı = item adı). Kod değişikliği gerekmez; envanterde
otomatik çıkar. Kare (ör. 100×100) PNG önerilir.

> Görsel yoksa envanter slotu boş görünür (bug değil). Karakter panelinde ise
> parça takılıyken temiz bir kategori ikonu + vurgu gösterilir.

---

## Adım 4 — Yayına al (deploy)

Değişiklikleri commit + push, GitHub'da main'e merge et, sonra **sunucuda çek**:

```bash
git -C '/opt/fivem/artifacts/txData/Qbox_57FBFD.base/resources/[ox]/ox_inventory' pull
```
Ardından txAdmin `restart ox_inventory` (web/build gelmezse bir kez daha restart).

> Sadece Lua/görsel değiştiyse `bun run build` gerekmez. Sadece `web/src` (arayüz)
> değiştiyse `cd web && bun run build` gerekir ve `web/build/` commit'lenir.

---

## Adım 5 — Test

1. `/setkiyafet mask_black` → item envantere gelir + anında takılır (hızlı test).
2. Karakter panelinde slotun dolduğunu ve oyunda ped'e uygulandığını gör.
3. **Relog** → hâlâ takılı (DB kalıcı).
4. Panelde dolu slota tıkla → item envantere döner, ped'ten kalkar.
5. Sorun olursa F8 konsolunda `bitirim`/`equipment` hatalarına bak.

---

## Komut özeti

| Komut | İş |
|---|---|
| `/kiyafetbak` | Şu an giyili tüm slotların drawable/texture değerlerini + cinsiyeti F8'e yazar (katalog için). |
| `/setkiyafet <item>` | Item'i envantere verir + giydirir (admin, test). |
| `/setkiyafet clear <slot>` | O slotu çıkarır. |
