# stream/ — Bitirim özel prop stream'i

Bu klasör, envanterin arka planında kullanılan `hei_mph_cntl2_glass01` prop'unu
**spawn edilebilir** yapan `bitirim_props.ytyp` (archetype) dosyasını barındırır.

## Neden gerekli?
`hei_mph_cntl2_glass01` bir interior/heist prop'udur: modelin verisi (`.ydr`) base
oyunun RPF'lerinde vardır ama onu dünyada `CreateObject` ile spawn edilebilir kılan
**archetype tanımı yoktur** → `IsModelInCdimage = false`. `bitirim_props.ytyp` bu isimle
bir archetype tanımlar; `fxmanifest.lua` içindeki `DLC_ITYP_REQUEST` ile yüklenir,
archetype kaydolur ve `preview_manager.lua` prop'u backdrop olarak oluşturabilir.

## `bitirim_props.ytyp` HAZIR — ek adım yok
`bitirim_props.ytyp` CodeWalker.Core (CodeWalker'ın çekirdek kütüphanesi) ile
üretilip commit'lendi. Tek archetype içerir:
- `name` / `assetName` = `hei_mph_cntl2_glass01` (hash **581526179**)
- `assetType` = `ASSET_TYPE_DRAWABLE`
- Geniş simetrik bounding box (culling'i önlemek için; gerçek görünüm `.ydr`'den gelir)

Sadece **pull + restart** yeterli:
```
git -C '.../[ox]/ox_inventory' pull
# txAdmin: restart ox_inventory
```

## Yine görünmüyorsa (drawable base RPF'te yoksa)
ytyp yüklendiği hâlde arka planda hiçbir şey görünmüyorsa, `hei_mph_cntl2_glass01.ydr`
drawable'ı base RPF'lerde yok demektir. O zaman `.ydr` (ve varsa ayrı `.ytd` texture)
dosyasını da bu `stream/` klasörüne koy — dosya adı archetype `assetName` ile birebir
aynı olmalı: `hei_mph_cntl2_glass01.ydr`. (Archetype zaten var; sadece drawable verisi
eksik olur.)

## ytyp'i yeniden üretmek / başka model eklemek
Üreteç: bu repoda tutulmuyor (scratchpad). CodeWalker kuruluysa küçük bir .NET aracı
`YtypFile` + `AddArchetype` + `Save()` ile aynı dosyayı üretir. Farklı bir model için
archetype adını değiştirip yeniden üretmen yeterli. Bounding box'ı gerçek modele göre
küçültmek istersen CodeWalker'da modeli yükleyip `Calculate extents` kullan.

CodeWalker XML kaynağı (referans): `docs/props/hei_mph_cntl2_glass01.ytyp.xml`.
