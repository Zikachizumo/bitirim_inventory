# ox_inventory — uyumluluk köprüsü

Bu klasör **envanter değildir**. Gerçek envanter `bitirim_inventory`'dir.

Burası, sunucudaki diğer kaynakların hâlâ yaptığı `exports.ox_inventory:X(...)`
çağrılarını olduğu gibi `bitirim_inventory`'e devreden ~30 satırlık bir yönlendiricidir.

## Neden gerekli?

Envanteri `bitirim_inventory` olarak yeniden adlandırdık. Ancak `qbx_core`, marketler,
silah/iş scriptleri gibi onlarca kaynak `exports.ox_inventory:...` diye çağırıyor.
Köprü olmadan bunların hepsi "resource not found" hatası verir.

Yönlendirilen export sayısı: **27 client + 52 server**.

## Kurulum

1. Sunucudaki **eski** `[ox]/ox_inventory` klasörünü kaldır (veya `ox_inventory.disabled`
   olarak yeniden adlandır). Aynı anda iki `ox_inventory` olamaz.
2. Bu `compat/ox_inventory` klasörünü sunucudaki `resources/[bitirim]/ox_inventory`
   yoluna kopyala.
3. `bitirim_inventory`'i de `resources/[bitirim]/bitirim_inventory` olarak koy.
4. `server.cfg` — **sıra önemli**, önce hedef sonra köprü:

```cfg
ensure ox_lib
ensure oxmysql
ensure bitirim_inventory
ensure ox_inventory
```

Köprü, hedef kaynak başlatılmamışsa açılışta konsola kırmızı uyarı yazar.

## Köprüye ihtiyaç duymayan şeyler

- **Event'ler** (`ox_inventory:*`) — fork'ta bilerek korundu. Event isimleri global
  string olduğu için kaynak adından bağımsız çalışır.
- **NUI / arayüz** — resource adını çalışma anında `GetParentResourceName()` ile alır.
- **Item ikonları** — `init.lua` artık yolu `GetCurrentResourceName()` üzerinden kurar.

## Bilinen sınır

Bir kaynak item ikonlarını **elle** `nui://ox_inventory/web/images/...` diye yazıyorsa
o görseller kırık görünür (köprü Lua export'larını taşır, NUI dosya yollarını değil).
Böyle bir yer çıkarsa ya o kaynağı `bitirim_inventory` kullanacak şekilde düzeltiriz,
ya da görselleri bu köprü klasörüne kopyalayıp `files{}` ile yayınlarız.
