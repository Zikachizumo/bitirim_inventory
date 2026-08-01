# Bitirim Inventory — ROADMAP

Sürüm mantığıyla tamamlanan ve planlanan geliştirmeler. Teknik bağlam için
[`MASTER_CONTEXT.md`](./MASTER_CONTEXT.md), değişiklik geçmişi için [`CHANGELOG.md`](./CHANGELOG.md).

> Sürümler Bitirim-içi mantıktır (temel: ox_inventory v2.47.9). "Faz" isimleri eski
> planlamayla uyum için parantez içinde verildi.

Durum: 🟢 tamamlandı · 🟡 kısmen · 🔴 planlandı

---

## ✅ v0.1 — Fork & Sunucuda Çalışır Hale Getirme  *(Faz 0-1)*  🟢
- ox_inventory v2.47.9 fork'u, `Zikachizumo/bitirim_inventory` deposu.
- Sunucuda `ox_inventory` adıyla dağıtım (rename denendi → geri alındı, kalıcı karar).
- `web/build` repoya dahil (sunucuda Bun/Node yok), `init.lua` ikon yolu dinamik.
- Bun ile derleme akışı; git branch→PR→merge iş akışı.

## ✅ v0.2 — Tema & Layout (Arayüz Kimliği)  *(Faz 2)*  🟢
- Cam panel (%25 saydam + blur), seviye-tabanlı vurgu rengi altyapısı.
- 2×2 hizalı düzen: Karakter | Envanter (eşit yükseklik), Kullanım | Sürükle&Ver (eşit yükseklik).
- Üst bar (çanta ikonu + marka + nakit), 8×5 grid, dikey 1-5 makro sütunu (satır hizalı), çanta kartı.
- Statlar CAN/ZIRH/AÇLIK/SUSUZLUK (gerçek veri), Use↔Unequip (silah).
- Oyuncu slotu 45 (5 makro + 40 grid). Kullanım talimatları paneli (2×2).

## ✅ v0.3 — Çanta Seviye Sistemi (Bag Level)  *(Faz 3 — çekirdek)*  🟢
- **Görsel:** seviye 0-5 → tema rengi + kilitli slot (asma kilit) + kart rozeti + kapasite.
  L0 = çantasız (yeni oyuncu). `/cantatest <0-5>` görsel test.
- **Backend:** `bitirim_backpack` MySQL tablosu, kalıcı+onbellekli seviye; seviyeye göre
  gerçek ağırlık sınırı (`SetMaxWeight`); `/setcanta` admin; `BitirimGet/SetBagLevel` exports.

## ✅ v0.4 — Araç Depolama & Drop & Divide  *(ek istekler)*  🟢
- Araç bagajı 6×6 / 999.999 KG, torpido 6 slot / 50 KG (bar görünür).
- Drop paneli 5×5, temiz başlık (plaka/ID+KG gizli), altta karakter statları, grid hizalı.
- Bagaj/drop başlığı gizli; drop/bagaj ağırlık limiti 999.999 KG.
- **Divide (yığın bölme)** diyaloğu: sağ tık menüsünde "Give" yerine; adet kutusu (default 1,
  silinebilir) + %25/%50/%75; boş grid slotuna böler; ESC'te kapanır.

---

## 🟢 v0.5 — Kilitli Slot Koruması  *(tamamlandı)*  🟢
- ✅ Sunucu tarafı `swapItems` hook'u: çanta seviyesinin üstündeki (kilitli) slotlara item
  taşı/değiştir/yığın **reddedilir**. Fail-open (seviye bilinemezse İZİN — item hareketi asla
  kilitlenmez). Client `cb(success or false)` ile iyimser hareketi geri alır.
- ✅ `AddItem` yolları (market/kraft/give/pickup): core `usableSlots(inv)` ile kilitli slota item
  gitmez, açık slot dolunca eklenmez. `inv.slots` 45 kalır (client görseli).
- Bununla çanta sistemi (drag/drop + otomatik yerleştirme) "görsel"den **tam işlevsel**e geçti.

## 🟢 v0.6 — Çanta = Item + Use ile Giyme + Market + Karakter Slotu  *(tamamlandı)*  🟢
- ✅ `bag_lv1..bag_lv5` itemleri (`data/items.lua`) + **use ile giyme** (qbx `CreateUseableItem`).
  Sadece **yükseltme** (düşürme/aynı seviye takma yok), item tükenir, seviye kalıcı, çıkarılamaz.
  Otomatik giyme yok. **Çift-sol-tık = kullan** (`InventorySlot.onDoubleClick`).
- ✅ **724 Market (ayrı repo `bitirim_724`):** çanta kategorisi `bag_lv1..5` (`kind='item'`) satar
  → `AddItem`. Fiyat 5k/10k/15k/20k/25k, "LEVEL N BACKPACK".
- ✅ **Çanta görselleri** `web/images/bag_lv1.png..bag_lv5.png` (eklendi).
- ✅ **Karakter panelinde takılı çanta görseli** (`CharacterPanel` Çanta slotu, seviyeye göre)
  + equip slot numaraları.

## 🔴 v0.7 — Çanta Ekonomisi: Kraft  *(opsiyonel)*  🔴
- **L3/L4/L5** için %30 başarı şanslı kraft (opsiyonel; market 1-5 zaten satacak).
- **Gerekli girdi:** her seviye için kraft tarifleri.

## 🔴 v0.8 — Araç Bagaj Kilitleri  🔴
- Araç seviyesi/modeline göre bagaj slotlarının kilidini aç/kapa (çanta kilit mantığının aynısı).

## 🔴 v0.9 — Ver (Give) Sistemi + bitirim_stranger  *(Faz 4)*  🔴
- Sürükle & Ver barına item bırakınca yakındaki oyuncular listelensin: tanıştıysan **ID + isim**,
  tanışmadıysan **Stranger #ID**. Seçip ver.
- `bitirim_stranger`'a export ekle (`GetNearbyPlayers`, `GetLabel`) — ayrı VM.

## 🔴 v1.0 — Ekipman Giyme (illenium)  *(Faz 3 — tam / Faz 5)*  🔴
- Sol paneldeki equip slotları **işlevsel**: zırh + silah + çanta + maske (C yaklaşımı),
  illenium-appearance köprüsü. Sağ tık giy/çıkar altyapısı hazır.
- Ardından: kozmetik kıyafet-as-item (tam katalog), çanta upgrade cilası.

---

## Bekleyen Kullanıcı Girdileri
- L0 (çantasız) ağırlık kapasitesi onayı (şu an 10 KG placeholder).
- L1/L2 market fiyatları.
- L3/L4/L5 kraft tarifleri.
