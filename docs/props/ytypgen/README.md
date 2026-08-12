# ytypgen

`make_backdrop.py` (veya başka bir yolla üretilen) özel `.ydr` modellerini **spawn
edilebilir** yapmak için `.ytyp` archetype üretir/günceller. Headless, CodeWalker.Core
kullanır — Blender/GTA açmaya gerek yok.

## Kullanım

```bash
cd docs/props/ytypgen
dotnet run -- <ytyp_dosya_yolu> <model1,model2,...>
```

- Dosya **varsa** yüklenir, verilen modeller **eklenir** (var olanlar bozulmaz, aynı
  isim zaten varsa atlanır — güvenle tekrar çalıştırılabilir).
- Dosya **yoksa** sıfırdan oluşturulur.
- Şablon: 20m'ye kadar düz/basit paneller için yeterli geniş bbox (`-26..26`,
  `bsRadius=45`, `lodDist=500`). Çok farklı boyutta bir prop için `Program.cs`
  içindeki bu değerleri elle güncelle.

## Örnek (bitirim_inventory backdrop renkli varyantları, 2026-08-12)

```bash
dotnet run -- "C:\Users\Luffy\Documents\GitHub\bitirim_inventory\stream\bitirim_props.ytyp" \
  bitirim_backdrop_lv1,bitirim_backdrop_lv2,bitirim_backdrop_lv3,bitirim_backdrop_lv4,bitirim_backdrop_lv5
```

## Gereksinimler

- dotnet 10 SDK
- `ytypgen.csproj` içindeki `CodeWalker.Core`/`SharpDX`/`SharpDX.Mathematics` HintPath'leri
  makinendeki CodeWalker kurulumuna göre ayarlı (varsayılan: `C:\Users\Luffy\Desktop\CodeWalker30_dev46\`).
