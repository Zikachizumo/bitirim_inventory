# Bitirim Inventory

**ox_inventory v2.47.9** tabanlı özel envanter forku — **Qbox** sunucusu için.

> Bu resource, [overextended/ox_inventory](https://github.com/overextended/ox_inventory) v2.47.9'un forkudur.
> Orijinal lisans (`LICENSE`) ve telif bildirimleri (`NOTICE.md`) korunmuştur.

---

## Neden fork?

Sunucunun görsel kimliğine ve RP mekaniklerine uygun, tamamen özel bir envanter isteniyor:
koyu tema + neon magenta, sol karakter/ekipman paneli, sağ grid + hotbar, "ver" akışında
tanışıklık (Stranger/isim) sistemi. Bunlar ox'un native UI'ının ötesinde, o yüzden reskin
değil **fork** yapıldı — hem `web/` (arayüz) hem Lua tarafında özgürlük.

## Stack

| Katman | Sistem |
|---|---|
| Framework | Qbox (`qbx_core`, `ox_lib`, `oxmysql`) |
| Kıyafet/görünüm | `illenium-appearance` |
| Tanışma/kimlik | `bitirim_stranger` (yakın oyuncu + Stranger/isim etiketi) |
| UI | React + Vite + TypeScript (Bun ile derlenir) |

## Rename notları (ox_inventory → bitirim_inventory)

Resource adı `bitirim_inventory` olarak değişti. Güvenli, çünkü:

- **Event isimleri** (`ox_inventory:*`) bilerek **korundu** — global string namespace; kendi
  içinde tutarlı ve dış resource uyumluluğunu artırır.
- **Web tarafı** resource adını runtime'da `GetParentResourceName()` ile alır → otomatik uyum.
- Değiştirilen tek gerçek kod: `modules/inventory/client.lua`'daki kendi export self-call'u
  (`exports.ox_inventory:openInventory` → `exports.bitirim_inventory:openInventory`).

### ⚠️ Dağıtımdan önce: export uyumluluk köprüsü (TODO)

qbx_core ve diğer resource'lar hâlâ `exports.ox_inventory:...` çağırıyor. Sunucuda test
etmeden önce, tüm export çağrılarını `bitirim_inventory`'e yönlendiren küçük bir
`ox_inventory` shim resource'u eklenecek (veya qbx tarafı yapılandırılacak). Repo kurulumunu
engellemez; ilk sunucu testinden önce halledilecek.

## Derleme (UI)

ox_inventory 2.47.9 **Bun** kullanır:

```bash
cd web
bun install
bun run build      # web/build/ üretir — fxmanifest bunu servis eder
```

> Not: `web/build/` henüz yok (kaynak fork). Lokal geliştirme için Bun kurulu olmalı.

## Yol haritası

- **Faz 0** — Fork + rebrand + repo kurulumu *(bu PR)*
- **Faz 1** — Sağ panel reskin: grid + hotbar + ağırlık + context menü (Kullan/At/Ayır) + tooltip; koyu/neon tema
- **Faz 2** — Sol panel: statlar (CAN/ZIRH/AÇLIK/SUSUZLUK) + işlevsel equip slotları (zırh+silah+çanta+maske) + çift-tık giy/çıkar + illenium köprüsü *(C yaklaşımı)*
- **Faz 3** — "Ver" barı + `bitirim_stranger` yakın-oyuncu seçici (ID + isim / Stranger)
- **Faz 4** — Kozmetik kıyafet-as-item (tam katalog) + çanta seviye/upgrade sistemi
