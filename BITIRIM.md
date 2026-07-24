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

### Export uyumluluk köprüsü ✅

qbx_core ve diğer kaynaklar hâlâ `exports.ox_inventory:...` çağırıyor. Bunun için
[`compat/ox_inventory/`](compat/ox_inventory/) altında **27 client + 52 server** export'u
`bitirim_inventory`'e devreden minik bir köprü kaynağı var. Kurulum ve `server.cfg`
sırası için o klasördeki README'ye bak.

Ayrıca `init.lua`'daki sabit `nui://ox_inventory/web/images` yolu dinamik hale getirildi
(`GetCurrentResourceName()`), aksi halde rename tüm item ikonlarını kırıyordu.

## Derleme (UI)

ox_inventory 2.47.9 **Bun** kullanır:

```bash
cd web
bun install
bun run build      # web/build/ üretir — fxmanifest bunu servis eder
```

> **`web/build/` bilerek repoya dahildir.** `init.lua` açılışta `web/build/index.html`
> arar; yoksa kaynak hiç başlamaz. Sunucuda (Ubuntu) Bun/Node kurulu olmadığı için
> derleme orada yapılamaz — UI'de değişiklik yaptıktan sonra **lokalde build alıp
> çıktısıyla birlikte commit et**, sunucuda sadece `git pull` + `restart` yeterli olsun.

## Yol haritası

- **Faz 0** — Fork + rebrand + repo kurulumu *(bu PR)*
- **Faz 1** — Sağ panel reskin: grid + hotbar + ağırlık + context menü (Kullan/At/Ayır) + tooltip; koyu/neon tema
- **Faz 2** — Sol panel: statlar (CAN/ZIRH/AÇLIK/SUSUZLUK) + işlevsel equip slotları (zırh+silah+çanta+maske) + çift-tık giy/çıkar + illenium köprüsü *(C yaklaşımı)*
- **Faz 3** — "Ver" barı + `bitirim_stranger` yakın-oyuncu seçici (ID + isim / Stranger)
- **Faz 4** — Kozmetik kıyafet-as-item (tam katalog) + çanta seviye/upgrade sistemi
