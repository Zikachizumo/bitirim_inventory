# Bitirim Inventory — MASTER CONTEXT

> Bu dosya projenin **tek referans belgesidir**. Yeni bir sohbet/geliştirici bunu okuyunca
> projeyi teknik olarak tamamen anlayıp kaldığı yerden devam edebilmelidir.
> Kronolojik değişiklikler için [`CHANGELOG.md`](./CHANGELOG.md), sürüm planı için
> [`ROADMAP.md`](./ROADMAP.md), kurulum/fork notları için kök dizindeki `BITIRIM.md`.

Son güncelleme: 2026-08-01

---

## 1. Projenin Amacı

FiveM **Qbox** RP sunucusu (**BİTİRİM UCLU RP**) için, sunucunun görsel kimliğine ve RP
mekaniklerine uygun, tamamen özel bir **envanter sistemi**. `ox_inventory` v2.47.9 **fork**
edilerek hem arayüzü (React NUI) hem sunucu/istemci Lua'sı yeniden şekillendiriliyor.

Hedef deneyim (onaylanmış mockup):
- Koyu, **%25 saydam cam** panel (arkada oyun görünür), seviyeye göre değişen neon vurgu rengi.
- **İki panel:** sol = Karakter (ekipman slotları + can/zırh/açlık/susuzluk), sağ = Envanter
  (ağırlık barı + 8×5 grid + dikey 1-5 makro sütunu + çanta kartı).
- **5 seviyeli çanta (Bag Level)** sistemi: seviye arttıkça slot açılır, ağırlık ve tema
  rengi değişir.
- Sağ tık = giy/çıkar, sol tık = Kullan/Divide/At; item verme, yığın bölme, araç bagajı/torpido.

---

## 2. Kullanılan Teknolojiler

| Katman | Teknoloji |
|---|---|
| Framework | **Qbox** (`qbx_core`) |
| Kütüphaneler | `ox_lib`, `oxmysql` |
| Envanter tabanı | **ox_inventory v2.47.9** (fork) |
| Kıyafet/görünüm | `illenium-appearance` (ileride entegre edilecek) |
| Tanışma/kimlik | `bitirim_stranger` (ver özelliği için) |
| Arayüz (NUI) | **React 19 + Vite 8 + TypeScript 6 + Redux Toolkit + react-dnd + SASS** |
| Derleme | **Bun** (`bun install && bun run build`) |
| Sunucu | Ubuntu + txAdmin, veritabanı MySQL (oxmysql) |
| Depo | GitHub `Zikachizumo/bitirim_inventory` (repo adı), sunucuda klasör adı `ox_inventory` |

> ⚠️ **Kritik kısıt:** Sunucuda dağıtılan klasör ve `fxmanifest` `name` alanı **`ox_inventory`
> olmak zorunda**, `version` de düz `2.47.9` kalmalı. `bitirim_inventory` olarak yeniden
> adlandırma + köprü denendi, sunucu açılmadı (detay: `BITIRIM.md`). **Tekrar denenmeyecek.**

---

## 3. Klasör Yapısı

```
bitirim_inventory/               (repo adı; sunucuda "ox_inventory")
├── fxmanifest.lua               resource tanımı (name 'ox_inventory', 2.47.9)
├── init.lua                     convar/shared ayarları (playerslots=45, dropslots=25, dropweight)
├── client.lua / server.lua      ox çekirdek client/server
├── data/
│   ├── items.lua, weapons.lua   item/silah tanımları
│   └── vehicles.lua             ⭐ Bitirim: bagaj 36 slot / 999.999 KG, torpido 6 slot / 50 KG
├── modules/
│   ├── bitirim/                 ⭐ BİZİM modüller
│   │   ├── client.lua           stat/kuşanılı-slot/çanta-seviyesi -> NUI; /cantatest (görsel test)
│   │   └── server.lua           çanta seviyesi DB persistans + SetMaxWeight; /setcanta; exports
│   ├── inventory/               ox çekirdek envanter mantığı (server.lua ~2700 satır)
│   ├── hooks/                   ox hook sistemi (registerHook, swapItems)
│   ├── bridge/qbx/              qbx köprüsü (oyuncu yükleme: loadInventory state bag)
│   └── items/, shops/, ...      diğer ox modülleri
├── locales/                     dil dosyaları (JSON)
├── setup/                       kurulum/dönüştürme scriptleri
├── web/
│   ├── src/
│   │   ├── index.scss           ⭐ TÜM stiller tek dosyada (tema + layout)
│   │   ├── components/inventory/
│   │   │   ├── index.tsx        kök: 2×2 grid düzeni, NUI event yönlendirme
│   │   │   ├── BitirimTopBar.tsx, CharacterPanel.tsx, CharacterStats.tsx,
│   │   │   ├── PlayerPanel.tsx, DropPanel.tsx, GiveBar.tsx, BitirimHints.tsx,
│   │   │   ├── SplitDialog.tsx, BitirimIcons.tsx   ⭐ BİZİM bileşenler
│   │   │   └── InventoryGrid.tsx, InventorySlot.tsx, InventoryHotbar.tsx,
│   │   │       InventoryContext.tsx, RightInventory.tsx  (ox, düzenlenmiş)
│   │   └── store/
│   │       ├── inventory.ts, tooltip.ts, contextMenu.ts   (ox)
│   │       └── backpack.ts, playerStatus.ts, equipment.ts, split.ts  ⭐ BİZİM
│   └── build/                   ⭐ DERLENMİŞ ÇIKTI — repoya dahil, sunucuya bu gider
├── BITIRIM.md                   fork notları / kurulum / rename kararı
└── docs/                        bu klasör (MASTER_CONTEXT, ROADMAP, CHANGELOG)
```

⭐ = Bitirim'e özel eklenen/değiştirilen. Diğerleri upstream ox_inventory.

---

## 4. Bitirim'e Özel Eklenen Sistemler

1. **Tema + layout reskin** (`web/src/index.scss`, `components/inventory/*`) — cam panel, 2×2
   hizalı düzen, seviye renkleri.
2. **Çanta seviye sistemi (Bag Level 0-5)** — görsel (renk/kilit/kapasite) + backend
   (DB persistans + gerçek ağırlık sınırı + kilitli slot koruması). Çanta = **item** (`bag_1..5`),
   **use ile giyilir** (yalnız yükseltme, çıkarılamaz). Bkz. bölüm 6.
3. **Karakter panel + statlar** — CAN/ZIRH/AÇLIK/SUSUZLUK, `modules/bitirim/client.lua`'dan.
4. **Divide (yığın bölme) diyaloğu** — sağ tık menüsünde "Give" yerine; %25/%50/%75.
5. **Ver barı (Sürükle & Ver)** — şimdilik ox `onGive`; ileride `bitirim_stranger` seçici.
6. **Drop paneli** — 5×5, temiz başlık, altta karakter statları.
7. **Araç depolama ayarı** (`data/vehicles.lua`) — tüm araçlarda bagaj 6×6 / 999.999 KG,
   torpido 6 slot / 50 KG.
8. **Use↔Unequip** — kuşanılı silahta context menü etiketi değişir.

---

## 5. Inventory Mimarisi

- **ox mimarisi korundu.** Sunucu-otoriter: tüm item hareketleri sunucuda doğrulanır
  (`ox_inventory:swapItems` callback + `swapItems` hook'ları). NUI iyimser günceller,
  sunucu reddederse geri alır.
- **NUI ↔ Lua akışı:** `client.lua` NUI'ye `SendNUIMessage({action, data})` yollar
  (`init`, `setupInventory`, `refreshSlots`, `displayMetadata`, ...). NUI, `fetchNui`
  ile callback çağırır (`uiLoaded`, `giveItem`, `useItem`, `swapItems`, `exit`, ...).
  Resource adı NUI'de runtime'da `GetParentResourceName()` ile alınır.
- **Başlangıç sırası (kritik):** `client.lua`, NUI `uiLoaded` sinyalini bekler
  (`while not client.uiLoaded do Wait(50) end`), sonra `init` yollar ve `PlayerData`
  yüklenir. NUI çökerse `uiLoaded` gitmez → "player inventory has not loaded" hatası.
- **React yapısı:** `components/inventory/index.tsx` kök bileşen. State Redux'ta
  (`store/`). `LeftInventory` = oyuncunun envanteri, `RightInventory` = ikincil kap
  (stash/bagaj/torpido/market/drop).
- **Bizim 2×2 düzen (A seçeneği):** sol üst = Karakter (veya kap açıksa onun yerini alır),
  sağ üst = oyuncu envanteri, sol alt = Kullanım talimatları, sağ alt = Sürükle & Ver.
  `drop` tipi özel: `DropPanel` (5×5 + statlar). `align-items: stretch` ile satırlar
  eşit yükseklikte.

---

## 6. Çanta (Bag Level) Sistemi

**Seviyeler 0-5.** Her seviye: açık grid slotu + ağırlık kapasitesi + tema rengi belirler.

| Seviye | Açık grid slotu | Kapasite (KG) | Tema rengi | Nasıl elde edilir |
|---|---|---|---|---|
| 0 (çantasız) | 0 (sadece 5 makro) | 10 *(placeholder)* | Gri `#8b93a7` | Yeni oyuncu varsayılanı |
| 1 | 8 | 20 | Beyaz `#dfe2ee` | 724 Market'ten satın al *(planlı)* |
| 2 | 16 | 35 | Mavi `#2f9bff` | 724 Market'ten satın al *(planlı)* |
| 3 | 24 | 50 | Mor `#c026d3` | %30 kraft *(planlı)* |
| 4 | 32 | 70 | Turuncu `#ff7a1a` | %30 kraft *(planlı)* |
| 5 | 40 | 90 | Altın `#f5c518` | %30 kraft *(planlı)* |

- **Açık grid slotu = seviye × 8.** Kilitli slotlar arayüzde **asma kilit** ile gösterilir.
- **Yeni oyuncu 0 (çantasız):** sadece 5 makro/hotbar slotu kullanılabilir, tüm 40 grid kilitli.
- **Çanta giyilince kalıcı** (çıkarılamaz — DB seviyesi, geri alma mekanizması yok).
- **Leveling modeli — çanta = ITEM, use ile giyilir (KODLANDI):**
  - `bag_1..bag_5` itemleri (`data/items.lua`). **Otomatik giyme YOK.** Market itemi verir,
    oyuncu **use** (Kullan / çift sol tık / sağ tık) ile takar.
  - **Sadece YÜKSELTME:** item seviyesi > mevcut → item tükenir + seviye kalıcı yükselir;
    ≤ mevcut → reddedilir, **item kalır** (düşürme yok, aynı seviye takma yok).
  - Use handler: `modules/bitirim/server.lua` → qbx `CreateUseableItem` (`equipBag`). Item
    `consume`'suz tanımlı → ox use akışı `server.UseItem` → `QBX:CanUseItem`'a düşer.
  - **724 Market'te 1-5 satışı:** fiyatlar kullanıcıdan bekleniyor (item + use hazır; sadece
    `data/shops.lua` listesi + fiyat kaldı). Kraft (L3-5) opsiyonel/ileride (tarifler bekleniyor).
  - Görseller placeholder: `web/images/bag_1.png..bag_5.png` (sanat gelince değiştirilecek).
- **Backend (kodlandı):** seviye `bitirim_backpack(citizenid, level)` MySQL tablosunda kalıcı;
  onbellekli. `modules/bitirim/server.lua`.
  - Uygulanış: `loadInventory` state bag'inde (ox ile aynı sinyal, +1.5s) + `lib.callback
    'bitirim:server:getBagLevel'` ile.
  - Exports: `BitirimGetBagLevel(source)`, `BitirimSetBagLevel(source, level)` (market/kraft
    bunları çağıracak).
  - Admin/test: `/setcanta <id> <0-5>` (ACE `bitirim.admin`).
- **Frontend:** `store/backpack.ts` (`setBagLevel`, `unlockedGridSlots`, `BAG_CAP_KG`).
  Seviye değişince `<html data-lv="0..5">` yazılır → `:root[data-lv]` tema tokenları değişir.
  Client `modules/bitirim/client.lua` gerçek seviyeyi `bitirim:client:bagLevel` event'iyle alır.
- **`/cantatest <0-5>`** sadece **görsel** test komutudur (sunucuyu/ağırlığı değiştirmez).

---

## 7. Slot Sistemi

- **Oyuncu envanteri = 45 slot** (`init.lua` `inventory:slots` varsayılanı 50→45):
  **5 makro (1-5)** + **40 grid (6-45, 8×5)**. Grid'de makro slotları tekrar gösterilmez.
- **Makro sütunu:** grid'in sağında dikey 5 slot (1-5), grid satırlarıyla **hizalı** (makro N ↔ satır N).
- **Kilitli slotlar:** çanta seviyesine göre `unlockedGridSlots(level)=level*8` sonrası slotlar
  kilitli render edilir (`InventoryGrid` `lockedFrom` prop'u, `.bx-slot-locked`).
  ✅ **Sunucu tarafı kilit koruması (swapItems hook) YAPILDI** (`modules/bitirim/server.lua`):
  oyuncunun kendi envanterine (`toType=='player'`) kilitli slota taşı/değiştir/yığın **sunucuda
  reddedilir**; client `cb(success or false)` ile iyimser hareketi geri alır. **FAIL-OPEN:**
  seviye kesin bilinemezse (oyuncu çözülemedi / seviye önbelleğe alınmadı) izin verilir —
  meşru item hareketi asla kesilmez. Kilit formülü: `slot > 5 + level*8` (frontend ile aynı).
  ✅ **`AddItem` yolları da korunuyor:** market/kraft/give/pickup, core `usableSlots(inv)` ile
  oyuncunun `bitirimUsableSlots` sınırına kadar slot seçer — kilitli slota item gitmez, açık
  slot dolunca eklenmez. `inv.slots` 45 kalır (client görseli). Bkz. bölüm 13.
- **Araç depolama** (`data/vehicles.lua`):
  - **Bagaj (trunk):** tüm araçlarda **36 slot (6×6)**, ağırlık 999.999 KG (sınırsız). 6 sütun render.
  - **Torpido (glovebox):** tüm araçlarda **6 slot**, ağırlık **50 KG** (sınır aktif, barı görünür).
  - **Drop (yerdeki):** **25 slot (5×5)**, 5 sütun render, ağırlık 999.999 KG.

---

## 8. Ağırlık Sistemi

- ox ağırlığı **gram** tutar; arayüz **KG** gösterir (`/1000`).
- **Oyuncu ağırlık sınırı = çanta seviyesinin kapasitesi.**
  - Görsel: `PlayerPanel` ağırlık barı `BAG_CAP_KG[level]` üzerinden.
  - Gerçek uygulanış: `modules/bitirim/server.lua` → `Inventory.SetMaxWeight(source,
    BAG_CAP_KG[level]*1000)` (oyuncu yüklenince + seviye değişince). Yani bar hem gösterir
    hem gerçekten sınırlar.
- **Kaplar:** bagaj/drop 999.999 KG (999999000 g, pratikte sınırsız); torpido 50 KG (50000 g).
- Ağırlık barı %85'i geçince kırmızıya kayma vb. cila kuralları tasarımda var (uygulanışı
  ox `WeightBar` bileşeni üzerinden).

---

## 9. UI Tasarım Kuralları

- **Tek görsel dünya:** koyu, cam (blur), tek vurgu rengi (seviyeye göre). Oyun HUD'ı olduğu
  için tek-tema (light/dark ayrımı yok).
- **CSS değişken tabanlı tema.** Tüm renkler `:root` custom property. Vurgu (`--accent`,
  `--accent-2`, `--accent-ink`, `--accent-dim`, `--accent-line`, `--accent-glow`)
  **seviyeye göre** `:root[data-lv='0'..'5']` ile değişir. Semantik renkler (CAN kırmızı,
  ZIRH mavi, AÇLIK amber, SUSUZLUK cyan, para yeşil) seviyeden bağımsız sabit.
- **Sınıf ön eki `bx-`** Bitirim'e özel elementlerde. ox'un kendi sınıf isimleri
  (`.inventory-slot`, `.inventory-grid-container` vb.) **korunur** (JSX'i bozmamak için).
- **Layout:** `bx-body` = 2×2 CSS grid, `align-items: stretch` (satırlar eşit yükseklik).
  Slot boyutu `--slot-sz: 9.5vh`. Grid 8 sütun; kaplar 6 sütun; drop 5 sütun.
- **Etkileşim:** hover = tooltip; **sol tık = Kullan/Divide/At menüsü**; **sağ tık = giy/çıkar
  (Use↔Unequip)**; Shift+sürükle = yarısını ayır. (ox InventorySlot: `onContextMenu`
  menüyü açar; etiketler bizim.)
- **Dil:** Arayüz Türkçe; yalnız **çanta kartı İngilizce** (kullanıcı isteği: Backpack/Level/
  Used/Capacity).
- **Yazı tipi:** system-ui yığını (webfont CDN yok). Sayılar `tabular-nums`.
- **Slot hover'da `transform: translateY` KULLANMA** — üst sıra slotları grid kırpma
  sınırına taşıyor; sadece kenar rengiyle geri bildirim.
- **Boşluk bırakma:** paneller `stretch` ile eşit yükseklik; alt bölgeler (stat/çanta kartı)
  dikeyde ortalanıp hizalanır, panel altında ölü boşluk kalmaz.

---

## 10. Kod Yazım Standartları

- **Lua (Bitirim modülleri):** ADDITIVE ol — ox çekirdek dosyalarını mümkünse değiştirme,
  kendi modülünü (`modules/bitirim/`) ekle. Framework çağrılarını **pcall/guard** ile sar
  (qbx/MySQL hazır değilse boot kırılmasın). Yorumlar Türkçe, ASCII (ç/ş/ı yerine c/s/i —
  bazı Lua/konsol ortamları için güvenli). Event isimleri `bitirim:client:*` /
  `bitirim:server:*`.
- **TypeScript/React:** ox'un mevcut sınıf isimlerini ve JSX yapısını koru; yeni bileşenleri
  `bx-` sınıflarıyla ekle. Redux Toolkit slice deseni. `useNuiEvent` ile NUI mesajları,
  `store/*` selektörleri. Gerçek veri gelmeden **uydurma değer gösterme** (veri yoksa o
  bölümü render etme).
- **Commit mesajları:** `feat(ui):`, `fix:`, `feat(backend):`, `revert:`, `chore:` önekleri;
  gövde Türkçe açıklama + neden. Sonunda `Co-Authored-By: Claude Opus 4.8`.
- **Lisans:** `LICENSE` (LGPL) ve `NOTICE.md` korunur; overextended telifi silinmez.

---

## 11. Performans Kuralları

- **Client döngüleri NUI odaklıyken çalışır:** `modules/bitirim/client.lua` stat/seviye
  gönderimini yalnız `IsNuiFocused()` iken ve **değer değiştiyse** yapar (gereksiz
  `SendNUIMessage` yok). Envanter kapalıyken 1000ms, açıkken 500ms tick.
- **Grid sayfalama:** büyük kaplar (stash) `PAGE_SIZE=48` ile sayfalanır; oyuncu gridi
  (40) tek seferde render (sayfalama yok). Kaplar (bagaj 36, torpido 6) ilk sayfada tam görünür.
- **Onbellek:** çanta seviyesi sunucuda `levelCache[citizenid]` ile tutulur; her açılışta DB
  sorgusu yok.
- **Derleme çıktısı commit'lenir** → sunucuda build yok, sadece `git pull` + `restart`.

---

## 12. Bugüne Kadar Tamamlanan Özellikler

- ✅ Fork kurulumu, sunucuda `ox_inventory` adıyla sorunsuz çalışma (isim/sürüm/`web/build`).
- ✅ Tema + tam mockup layout (cam panel, 2×2 hizalı, üst bar, karakter paneli, dikey makro
  sütunu, çanta kartı, kullanım talimatları, ver barı).
- ✅ Statlar (CAN/ZIRH/AÇLIK/SUSUZLUK) — gerçek veriden.
- ✅ Çanta 5 seviye **görsel** (renk + kilitli slot + rozet + kapasite) — 0-5, çantasız dahil.
- ✅ Çanta **backend**: DB'de kalıcı seviye + gerçek ağırlık sınırı (`SetMaxWeight`) +
  `/setcanta` admin + `BitirimGet/SetBagLevel` exports.
- ✅ **Kilitli slot sunucu koruması** — iki katman: (1) swapItems hook (manuel sürükle-bırak),
  (2) core `usableSlots` ile otomatik yerleştirme (market/kraft/give/pickup) kilitli slota gitmez.
  İkisi de fail-open (seviye bilinemezse izin). Açık slot dolunca item eklenmez.
- ✅ **Çanta = item + use ile giyme** (`bag_1..bag_5`): use → yalnız yükseltme (düşürme/aynı yok),
  item tükenir, seviye kalıcı yükselir, çıkarılamaz. qbx `CreateUseableItem`. Otomatik giyme yok.
- ✅ Use↔Unequip (kuşanılı silah).
- ✅ Araç: bagaj 6×6 / 999.999 KG, torpido 6 slot / 50 KG (bar görünür), drop 5×5 (temiz başlık +
  statlar), bagaj/drop başlığı (plaka/ID+KG) gizli.
- ✅ **Divide (yığın bölme)** diyaloğu: default 1 (silinebilir) + %25/%50/%75; boş grid slotuna böler.
- ✅ Ver barı (şimdilik ox `onGive` bırakma hedefi).

---

## 13. Bilinen Eksikler

- ✅ **Kilitli slot sunucu koruması (swapItems)** — YAPILDI. Bkz. bölüm 7/12. Not: `registerHook`
  export'u ref'i indeksliyor; ox içinden self-export'ta ham fonksiyon sarılmayabildiği için ref
  olarak metatable'lı **callable table** (`__call`) verildi.
- ✅ **Kilitli slota `AddItem` yolları** — YAPILDI. Core'a `usableSlots(inv)` yardımcısı eklendi;
  `AddItem` / `GetItemSlots` / `GetSlotForItem` / `GetEmptySlot` otomatik yerleştirme döngüleri
  oyuncuda `inv.bitirimUsableSlots` (=5+seviye*8) ile sınırlanır. `inv.slots` 45 KALIR (client
  görseli); item market/kraft/give/pickup ile artık kilitli slota gitmez, açık slot dolunca
  eklenmez. Alanı `applyLevel` yazar. Downgrade (admin) edge'i: yüksek slottaki item gizlenir.
- ✅ **Çanta giyme (item + use)** — YAPILDI (`bag_1..5` + qbx `CreateUseableItem`, yalnız yükseltme).
- ❌ **724 Market'te 1-5 çanta satışı** — item + use hazır; sadece `data/shops.lua` listesi +
  **fiyatlar** kullanıcıdan bekleniyor. (Market itemi verir, oyuncu use ile takar.)
- ❌ **Çanta görselleri** — `web/images/bag_1.png..bag_5.png` placeholder; **sanat** bekleniyor.
- ❌ **L3-5 kraft** (%30, başarısız = kayıp) — opsiyonel/ileride; **tarifler** kullanıcıdan bekleniyor.
- ❌ **L0 (çantasız) ağırlık kapasitesi** 10 KG placeholder — onay bekliyor.
- ❌ **Ekipman giyme sistemi** (zırh/silah/maske, illenium-appearance köprüsü) — sol paneldeki
  equip slotları şu an **görsel**. (Çanta artık item+use ile işlevsel; görsel-çanta-slotu bu işle gelir.)
- ❌ **Ver barı yakın-oyuncu seçici** (`bitirim_stranger` ile ID+isim / Stranger) — şu an
  sadece ox `onGive`.
- ❌ **Araç bagaj kilitleri** (araç seviyesi/modeline göre slot aç/kapa).
- ❌ **Kozmetik kıyafet-as-item** (tam katalog).

---

## 14. Bundan Sonra Geliştirilecek Özellikler (öncelik sırası)

1. ✅ **Kilitli slot koruması** — YAPILDI (swapItems hook + core `usableSlots` add-path guard).
2. ✅ **Çanta giyme (item + use)** — YAPILDI (`bag_1..5`, yalnız yükseltme). Kalan: **724 Market
   listesi + fiyatlar** (kullanıcıdan) ve **çanta görselleri** (sanat).
3. **Kraft L3-5** — opsiyonel; tarifler gelince.
4. **Araç bagaj kilitleri** — seviye/modele göre.
5. **Ver barı + bitirim_stranger** yakın-oyuncu seçici.
6. **Ekipman giyme** (illenium köprüsü: zırh+silah+maske; görsel çanta slotu).
7. **Kozmetik kıyafet-as-item.**

Detaylı sürüm planı: [`ROADMAP.md`](./ROADMAP.md).

---

## 15. Yeni Sohbet / Geliştirici İçin Teknik Kılavuz

**Depo & dağıtım**
- Repo: `https://github.com/Zikachizumo/bitirim_inventory`. Sunucuda:
  `/opt/fivem/artifacts/txData/Qbox_57FBFD.base/resources/[ox]/ox_inventory` (main'in klonu).
- Klasör + fxmanifest adı `ox_inventory` KALMALI (bkz. bölüm 2 / BITIRIM.md). Rename tekrar denenmez.
- **Deploy:** sunucuda `git -C '.../[ox]/ox_inventory' pull` + txAdmin `restart ox_inventory`.
  Bazen ilk restart yeni `web/build`'i tam yüklemez → **bir kez daha `restart ox_inventory`**.

**Derleme**
- UI değişince: `cd web && bun run build` (Bun kurulu; Node yok). `web/build/` **commit'lenir**
  (sunucuda derleme yok). Sadece Lua değişince build gerekmez.

**Git akışı (kullanıcı kuralı)**
- Her değişiklik **yeni branch** (slash YOK) → push → kullanıcıya
  `compare/main...<branch>?expand=1` linki → **kullanıcı tarayıcıdan merge eder**.
- Merge sonrası: main'i senkronla, branch'i sil, yeni iş için yeni branch. (`gh` CLI yok.)

**UI'yi doğrulama (oyunsuz)**
- `cd web && bun run start` (vite dev). ox'un `debugData` fixture'ı sadece DEV'de çalışır.
- In-app tarayıcıda (Claude Browser) `preview_start` ile localhost'u aç, `MessageEvent`
  dispatch ederek NUI mesajlarını taklit et (`setupInventory`, `setPlayerStatus`,
  `setBagLevel` ...), `javascript_tool` ile ölç. Pane çoğu zaman screenshot vermez → JS ölçümü kullan.
- Üretim davranışı için `build/` klasörünü servis et (debugData çalışmaz, `init` mesajı gerekir).

**Kritik dosyalar**
- `data/vehicles.lua` — araç depolama (bagaj/torpido).
- `init.lua` — `playerslots=45`, `dropslots=25`, `dropweight=999999000`, ikon yolu.
- `modules/bitirim/server.lua` — çanta backend (DB, SetMaxWeight, /setcanta, exports).
- `modules/bitirim/client.lua` — stat/seviye/kuşanılı-slot → NUI, `/cantatest`.
- `web/src/index.scss` — tüm stiller (`:root[data-lv]` tema).
- `web/src/components/inventory/index.tsx` — 2×2 düzen + NUI event yönlendirme.
- `web/src/store/backpack.ts` — seviye/kapasite/açık-slot mantığı.

**Bağımlılık API'leri (hazır)**
- Oyuncu: `exports.qbx_core:GetPlayer(source).PlayerData.citizenid / .metadata`.
- Kuşanılı silah: `exports.ox_inventory:getCurrentWeapon()`.
- Ağırlık/slot: `Inventory.SetMaxWeight`, `Inventory.SetSlotCount` (server.lua içi).
- Çanta: `exports.ox_inventory:BitirimGetBagLevel/BitirimSetBagLevel`.
- Ver/tanışma: `bitirim_stranger` (ayrı resource) — `Bitirim.Identity.label/isKnown`,
  `Bitirim.Proximity.tracked` (ayrı VM olduğu için export eklenecek).
