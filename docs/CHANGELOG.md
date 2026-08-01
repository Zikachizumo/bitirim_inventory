# Bitirim Inventory — CHANGELOG

Tüm önemli değişiklikler burada, kronolojik (en yeni üstte). Temel: ox_inventory v2.47.9 fork.
Sürüm eşlemesi için [`ROADMAP.md`](./ROADMAP.md).

Etiketler: `feat` yeni özellik · `fix` düzeltme · `revert` geri alma · `chore` altyapı.

---

## [v0.5] — 2026-08-01  ·  Kilitli slot sunucu koruması

- **2026-08-01** `feat(backend)` **Kilitli slot sunucu koruması** (`swapItems` hook,
  `modules/bitirim/server.lua`): oyuncunun KENDİ envanterine (`toType=='player'`) çanta
  seviyesiyle **kilitli** bir slota taşı/değiştir/yığın **sunucuda reddedilir**; client
  `cb(success or false)` ile iyimser hareketi geri alır. **FAIL-OPEN** — seviye kesin
  bilinemezse (oyuncu çözülemedi / seviye önbelleğe alınmadı) izin verilir, meşru item
  hareketi asla kesilmez. Kilit formülü `slot > 5 + seviye*8` (frontend `backpack.ts` ile
  aynı). Kayıt: self-export'ta ham fonksiyon indekslenemediği için ref olarak metatable'lı
  **callable table** (`__call`) verildi. Kapsam dışı: `AddItem` yolları (market/kraft/give)
  hâlâ kilitli slotu seçebilir — ayrı iş.

## [v0.4] — 2026-07-31 → 2026-08-01  ·  Araç depolama, Drop, Divide

- **2026-08-01** `fix` Bagaj + yere-atma ağırlık sınırı **999.999 KG** (pratikte sınırsız). Divide
  diyaloğu düzeltmeleri: input barı %50 küçültüldü (kutu dışına taşımıyor), default "1"
  artık **silinebilir** (string input), envanter kapanınca (ESC dahil) diyalog kapanır. `(b066832)`
- **2026-08-01** `fix(ui)` Drop paneline temiz başlık ("Yere Atılanlar", plaka/ID+KG yok) →
  drop grid satırları envanter grid satırlarıyla **hizalı**. Torpido (glovebox) 50 KG ağırlık
  barı **görünür** kılındı (limit korunuyor). `(3d633c2)`
- **2026-08-01** `feat(ui)` **Divide (yığın bölme)** diyaloğu: sağ tık menüsünde "Give" yerine;
  adet kutusu (default 1) + %25/%50/%75; seçilen adet boş grid slotuna bölünür. Ayrıca
  bagaj/torpido/drop başlığındaki plaka/ID + KG barı gizlendi. `(a19d3f1)`
- **2026-07-31** `feat(ui)` Drop paneli **5×5 (25 slot)** + altta karakter statları
  (CAN/ZIRH/AÇLIK/SUSUZLUK). `CharacterStats` paylaşılabilir bileşene çıkarıldı. `(eb775fe)`
- **2026-07-31** `revert` Drop-gizleme geri alındı — yerdeki item envanterde tekrar görünür. `(07c2fbd)`
- **2026-07-31** `feat(ui)` *(geçici, aynı gün geri alındı)* Drop item'i envanterde gizle. `(998efd7)`
- **2026-07-25** `fix` Bagaj KG limiti kaldırıldı, torpido 5→**6 slot**, slot hover üst-kenar
  taşması giderildi (`translateY` kaldırıldı). `(d0d921b)`
- **2026-07-25** `feat` Ağırlık barı **çanta seviyesi kapasitesine** eşitlendi; araçlarda torpido
  5 slot/50 KG, bagaj 6×6=36 slot; kap paneli 6 sütun render; `PAGE_SIZE` 30→48. `(a97de05)`

## [v0.3] — 2026-07-25  ·  Çanta Seviye Sistemi (Bag Level)

- **2026-07-25** `feat(backend)` Çanta seviyesi **kalıcı (MySQL `bitirim_backpack`)** +
  onbellekli; seviyeye göre **gerçek ağırlık sınırı** (`Inventory.SetMaxWeight`);
  `/setcanta <id> <0-5>` admin komutu; `BitirimGet/SetBagLevel` exports. Client artık gerçek
  seviyeyi server event'iyle alır (`/cantatest` yalnız görsel test). `(076114b)`
- **2026-07-25** `feat(ui)` **Seviye 0 (çantasız)** — yeni oyuncu varsayılanı: tüm grid kilitli,
  sadece 5 makro slotu, gri tema. `(efca51d)`
- **2026-07-25** `feat(ui)` Çanta **5 seviye görsel çekirdek**: seviye 0-5 → tema rengi
  (gri/beyaz/mavi/mor/turuncu/altın) + kilitli slot (asma kilit) + kart rozeti + kapasite.
  `store/backpack.ts`, `/cantatest` test komutu. `(9dca916)`

## [v0.2] — 2026-07-24 → 2026-07-25  ·  Tema & Layout

- **2026-07-25** `fix(ui)` **2×2 hizalı düzen**: Karakter=Envanter yüksekliği, Kullanım=Ver barı
  yüksekliği eşit; çanta kartı ile statlar dikeyde ortadan hizalı. `(5dc9ed9)`
- **2026-07-24** `fix(ui)` Kullanım talimatları 2×2; "Shift+Sürükle" satırı kaldırıldı; çanta kartı
  kompakt; kontrol paneli yerine talimatlar; Use→**Unequip** (kuşanılı silah). `(da562f8)`
- **2026-07-24** `fix(ui)` Grid **8×5=40** (fazladan slotlar kaldırıldı), makro sütunu grid
  satırlarıyla hizalı, "0/Use/Give/Close" kontrol paneli yerine kullanım talimatları; oyuncu
  slotu 45. `(0eb8337)`
- **2026-07-24** `feat(ui)` **Mockup yerleşimi**: cam pencere, üst bar, Karakter paneli
  (4-3-5-2-2 ekipman), dikey makro sütunu, çanta kartı, "Sürükle & Ver" barı. `(fccab06)`
- **2026-07-24** `feat(ui)` **Tema temeli**: %25 saydam cam panel, `:root[data-lv]` seviye renkleri,
  8 sütunlu grid. `(f7eb98b)`

## [v0.1] — 2026-07-24  ·  Fork & Sunucuda Çalışma

- **2026-07-24** `fix` Resource adı **`ox_inventory`'e geri alındı**, köprü yaklaşımı kaldırıldı
  (rename + shim ile sunucu açılmıyordu: ox_lib sürüm kontrolü + qbx_core dosya bağımlılığı).
  Kalıcı karar: dağıtılan klasör/isim `ox_inventory`. `(f191f83)`
- **2026-07-24** `feat` *(geçici, aynı gün geri alındı)* `ox_inventory` uyumluluk köprüsü +
  fork'u sunucuda çalışır hale getirme (isim/sürüm/`web/build`). `(b1bfc39)`
- **2026-07-24** `chore` Geliştirme sırasında `web/build` gitignore (sonra bilerek dahil edildi). `(562b3ee)`
- **2026-07-24** `feat` Fork'u `bitirim_inventory` olarak markala (fxmanifest, README). `(560f037)`
- **2026-07-24** `chore` **ox_inventory v2.47.9** fork temeli olarak içe aktarıldı. `(a4501aa)`

---

> Not: Bazı özellikler aynı gün eklenip geri alındı (drop-gizleme, rename köprüsü). Bunlar
> şeffaflık için bırakıldı; nihai durum için [`MASTER_CONTEXT.md`](./MASTER_CONTEXT.md) bölüm 12-13.
