// ytypgen — make_backdrop.py ile uretilen .ydr modellerini SPAWN EDILEBILIR yapmak
// icin bir .ytyp'e CBaseArchetypeDef ekler/gunceller. Headless, CodeWalker.Core kullanir.
//
// Kullanim:
//   dotnet run -- <ytyp_dosya_yolu> <model1,model2,model3,...>
//
// - ytyp dosyasi VARSA yuklenir ve verilen modeller EKLENIR (var olanlar bozulmaz,
//   ayni isimli model zaten varsa GUNCELLENMEZ - script atlar).
// - ytyp dosyasi YOKSA sifirdan olusturulur.
// - Her archetype ayni sablonu kullanir: 20m kare panel gibi duz/basit propler icin
//   yeterli genis bbox (-26..26, bsRadius 45, lodDist 500) -> culling/streaming sorunu
//   olmaz. Farkli boyutta bir prop icin bu degerleri asagida elle degistir.
//
// Ornek (bitirim_inventory backdrop renkli varyantlari icin kullanildi, 2026-08-12):
//   dotnet run -- "C:\...\stream\bitirim_props.ytyp" bitirim_backdrop_lv1,bitirim_backdrop_lv2

using CodeWalker.GameFiles;
using SharpDX;

if (args.Length < 2)
{
    Console.WriteLine("Kullanim: dotnet run -- <ytyp_yolu> <model1,model2,...>");
    return 1;
}

string ytypPath = args[0];
string[] models = args[1].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

YtypFile ytyp;
if (File.Exists(ytypPath))
{
    var bytes = File.ReadAllBytes(ytypPath);
    ytyp = new YtypFile();
    RpfFile.LoadResourceFile(ytyp, bytes, 2);
    Console.WriteLine($"Yuklendi: {ytypPath} ({ytyp.AllArchetypes.Length} archetype)");
}
else
{
    ytyp = new YtypFile();
    ytyp.AllArchetypes = Array.Empty<Archetype>();
    var ytypName = Path.GetFileNameWithoutExtension(ytypPath);
    ytyp.NameHash = JenkHash.GenHash(ytypName);
    Console.WriteLine($"Yeni ytyp olusturuluyor: {ytypName}");
}

var existing = (ytyp.AllArchetypes ?? Array.Empty<Archetype>()).Select(a => a._BaseArchetypeDef.name).ToHashSet();

foreach (var modelName in models)
{
    uint hash = JenkHash.GenHash(modelName);
    if (existing.Contains(hash))
    {
        Console.WriteLine($"atlandi (zaten var): {modelName}");
        continue;
    }

    var arch = ytyp.AddArchetype();
    arch.Hash = hash;
    arch._BaseArchetypeDef.name = hash;
    arch._BaseArchetypeDef.assetName = hash;
    arch._BaseArchetypeDef.assetType = rage__fwArchetypeDef__eAssetType.ASSET_TYPE_DRAWABLE;
    arch._BaseArchetypeDef.flags = 0;
    // Basit/duz prop sablonu (20m panel icin dogrulandi). Farkli boy/en icin degistir.
    arch._BaseArchetypeDef.bbMin = new Vector3(-26, -26, -26);
    arch._BaseArchetypeDef.bbMax = new Vector3(26, 26, 26);
    arch._BaseArchetypeDef.bsCentre = Vector3.Zero;
    arch._BaseArchetypeDef.bsRadius = 45f;
    arch._BaseArchetypeDef.lodDist = 500f;
    arch._BaseArchetypeDef.textureDictionary = 0;
    arch._BaseArchetypeDef.physicsDictionary = 0;
    Console.WriteLine($"eklendi: {modelName} hash={hash}");
}

var outBytes = ytyp.Save();
Directory.CreateDirectory(Path.GetDirectoryName(ytypPath)!);
File.WriteAllBytes(ytypPath, outBytes);
Console.WriteLine($"Yazildi: {ytypPath} ({outBytes.Length} bytes, {ytyp.AllArchetypes.Length} archetype toplam)");
return 0;
