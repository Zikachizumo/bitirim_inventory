# stream/ — Bitirim özel prop stream'i

Bu klasör, envanterin arka planında kullanılan `hei_mph_cntl2_glass01` prop'unu
**spawn edilebilir** yapan `.ytyp` (archetype) dosyasını barındırır.

## Neden gerekli?
`hei_mph_cntl2_glass01` bir interior/heist prop'udur: modelin verisi (`.ydr`) base
oyunun RPF'lerinde vardır ama onu dünyada `CreateObject` ile spawn edilebilir kılan
**archetype tanımı yoktur** → `IsModelInCdimage = false`. Buraya bir `.ytyp` koyup
`fxmanifest.lua` içinde `DLC_ITYP_REQUEST` ile tanıtınca archetype kaydolur ve
`preview_manager.lua` prop'u backdrop olarak oluşturabilir.

## Yapman gereken TEK adım (CodeWalker, ~2 dk)
1. **CodeWalker**'ı aç (RPF Explorer). GTA yolunu tanıttığından emin ol.
2. Menü: **Tools → Project Window → New → New YTYP**.
3. Sağdaki ağaçta ytyp'e sağ tık → **New Archetype** (Base).
4. Alanları doldur (ya da hazır kaynağı içe aktar — aşağıya bak):
   - `name` = `hei_mph_cntl2_glass01`
   - `assetName` = `hei_mph_cntl2_glass01`
   - `assetType` = `ASSET_TYPE_DRAWABLE`
   - Extents: modeli önce sahnede/preview'de görüp **Calculate extents** ile otomatik doldur.
5. Ytyp'i **`bitirim_props.ytyp`** adıyla **bu `stream/` klasörüne** kaydet.

### Hazır kaynağı içe aktarmak istersen
`docs/props/hei_mph_cntl2_glass01.ytyp.xml` CodeWalker formatındadır. CodeWalker'da
Project → import edip **Save as .ytyp** yapabilirsin. **Extents değerleri kabadır** —
modeli yükleyip `Calculate extents` ile gerçek değerlere güncelle (yanlış kutu = obje
bazı kamera açılarından kaybolabilir/culled olur).

## Model base oyunda gerçekten yoksa
Eğer ytyp'i eklemene rağmen hâlâ görünmüyorsa, drawable base RPF'te yok demektir.
O zaman `.ydr` (ve varsa ayrı `.ytd` texture) dosyasını da bu `stream/` klasörüne koy.
Dosya adları archetype `assetName` ile birebir aynı olmalı: `hei_mph_cntl2_glass01.ydr`.

## Dağıtım
`stream/bitirim_props.ytyp` dosyasını commit'le (ya da doğrudan sunucudaki
`[ox]/ox_inventory/stream/` içine koy) → `restart ox_inventory`. `fxmanifest.lua`
zaten `data_file 'DLC_ITYP_REQUEST' 'stream/bitirim_props.ytyp'` satırını içeriyor.

> `.ytyp` henüz yokken sunucu açılışında "couldn't load DLC_ITYP_REQUEST ..." uyarısı
> normaldir; dosyayı ekleyince kaybolur ve prop spawn edilebilir olur.
