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

## ⚠️ Resource adı `ox_inventory` OLMAK ZORUNDA

Repo adı `bitirim_inventory`, ama **sunucuda dağıtılan klasörün adı `ox_inventory`** olmalı
ve `fxmanifest.lua` içindeki `name` / `version` alanları değiştirilmemeli.

Bunu yeniden adlandırmayı denedik: resource `bitirim_inventory` yapıldı ve yerine tüm export
çağrılarını yönlendiren bir `ox_inventory` köprüsü kondu. **Sunucu açılmadı.** İki
onarılamaz engel var — ikisi de export değil:

1. **Sürüm kontrolü.** `ox_lib`, `ox_inventory` *adlı kaynağın* fxmanifest'inden sürümü okur.
   `qbx_core` `>= 2.42.1`, `ox_fuel` `>= 2.30.0` şartı koyuyor. Köprünün sürümü (`1.0.0`) bu
   kontrolü geçemedi → `qbx_core` "Startup errors detected" deyip sunucuyu kapattı.
2. **Dosya seviyesinde bağımlılık.** `qbx_core`, envanterin dosyalarını doğrudan okuyor:
   `require '@ox_inventory.data.items'`. Bu bir Lua export'u değil, dosya yolu — köprü ile
   taşınamaz.

Ayrıca köprü üzerinden geçen `RegisterStash` çağrısında argümanların kaydığı görüldü
(`received boolean for stash maxWeight`).

**Sonuç:** diğer kaynakların konuştuğu resource, ince bir köprü değil, gerçekten envanterin
kendisi olmak ve adı `ox_inventory` olmak zorunda. Fork'un tamamı bizim; sadece klasör adı
uyumluluk için sabit.

### Korunan / değişen

- **Event isimleri** (`ox_inventory:*`) upstream ile aynı — dokunulmadı.
- **Web tarafı** resource adını runtime'da `GetParentResourceName()` ile alır.
- `init.lua`'da item ikon yolu sabit `nui://ox_inventory/...` yerine
  `GetCurrentResourceName()` üzerinden kuruluyor — şu an aynı sonucu verir, ama klasör adı
  ileride değişirse ikonlar kırılmaz.

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

## Kurulum / dağıtım

Bu fork, sunucudaki `[ox]/ox_inventory` klasörünün **tam yerine** geçer. Ayrı bir köprü
kaynağı, `server.cfg` değişikliği veya yükleme sırası ayarı **gerekmez** — orijinal
ox_inventory ile aynı yerde, aynı adla, aynı sırada yüklenir.

İlk kurulum (sunucuda):

```bash
# 1) Orijinali yedekle (resources DISINA tasi ki taranmasin)
mv 'resources/[ox]/ox_inventory' './ox_inventory_ORIJINAL_YEDEK'

# 2) Forku ayni yere, ox_inventory adiyla klonla
git clone <repo-url> 'resources/[ox]/ox_inventory'
```

Güncelleme:

```bash
git -C 'resources/[ox]/ox_inventory' pull
```

ardından txAdmin Live Console'da `restart ox_inventory`.

> **Sorun çıkarsa geri dönüş:** `resources/[ox]/ox_inventory` klasörünü sil, yedeği geri taşı,
> sunucuyu başlat. Yedeği ilk temiz test tamamlanana kadar silme.

## Yol haritası

- **Faz 0** — Fork + repo kurulumu ✅
- **Faz 1** — Sunucuda çalışır hale getirme (isim/sürüm uyumu, `web/build` dağıtımı) ✅
- **Faz 2** — Sağ panel reskin: grid + hotbar + ağırlık + context menü (Kullan/Ayır/At) + tooltip; koyu/neon tema, 5 seviyeli çanta renkleri
- **Faz 3** — Sol panel: statlar (CAN/ZIRH/AÇLIK/SUSUZLUK) + işlevsel equip slotları (zırh+silah+çanta+maske) + sağ tık giy/çıkar + illenium köprüsü *(C yaklaşımı)*
- **Faz 4** — "Ver" barı + `bitirim_stranger` yakın-oyuncu seçici (ID + isim / Stranger)
- **Faz 5** — Kozmetik kıyafet-as-item (tam katalog) + çanta seviye/upgrade sistemi

Tasarım referansı: onaylanmış mockup (koyu + seviye rengi tema, sol Karakter / sağ Envanter,
%25 saydam cam panel, sol tık = Kullan/Ayır/At, sağ tık = giy/çıkar).
