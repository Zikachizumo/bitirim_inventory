--[[
    Bitirim — KIYAFET / EKIPMAN eslemesi (TEK KAYNAK)
    -------------------------------------------------
    Bu dosya hem server (equipment_server.lua) hem client (equipment_client.lua)
    tarafindan `lib.load('data.bitirim_clothing')` ile okunur. Amac: "hangi panel
    slotu -> hangi GTA hedefi" ve "hangi item -> hangi slot + gorunum" bilgisini
    TEK yerde tutmak (dunya karakteri ve ileride 3D onizleme ayni veriyi kullanir).

    Uc tablo:
      slots     : panel slot anahtari -> GTA hedefi
                  kind = 'component' -> SetPedComponentVariation(ped, id, drawable, texture, 0)
                  kind = 'prop'      -> SetPedPropIndex(ped, id, drawable, texture, true)
                                        (cikarinca ClearPedProp(ped, id))
      underwear : BOS component slotunun donecegi taban gorunum
      items     : kiyafet item adi -> { slot, drawable, texture }
                  Bir item BURADA tanimli degilse "kiyafet" SAYILMAZ; equip sistemi
                  ona dokunmaz (normal item gibi davranir).

    NOT (cinsiyet): drawable/texture indeksleri PED MODELINE gore degisir
    (freemode erkek != kadin). Asagidaki ornek degerler test icindir; TAM
    KATALOG (dogru drawable'lar, gerekiyorsa cinsiyet ayrimi) kullanicidan
    gelecek. Client uygulamada IsPedComponentVariationValid ile dogrulanir;
    gecersizse sessizce atlanir (kirilmaz).

    Ozel slotlar (bu tabloda YOK, ayri yonetilir):
      bag    -> canta seviye sistemi (modules/bitirim/server.lua) — DOKUNULMAZ
      weapon -> ox getCurrentWeapon (kusanili silah) — sadece gosterim
      ammo   -> gorunum hedefi yok
]]

-- Panel slot anahtari -> GTA hedefi. (Anahtarlar CharacterPanel.tsx ile ayni.)
local slots = {
    -- proplar (aksesuar): SetPedPropIndex / ClearPedProp
    hat      = { kind = 'prop',      id = 0 },
    glasses  = { kind = 'prop',      id = 1 },
    ears     = { kind = 'prop',      id = 2 },
    watch    = { kind = 'prop',      id = 6 },
    ring     = { kind = 'prop',      id = 7 },

    -- componentler (giysi): SetPedComponentVariation
    mask     = { kind = 'component', id = 1 },
    gloves   = { kind = 'component', id = 3 },  -- kol/eldiven texture'i (edge-case)
    pants    = { kind = 'component', id = 4 },
    shoes    = { kind = 'component', id = 6 },
    necklace = { kind = 'component', id = 7 },  -- zincir/chains
    tshirt   = { kind = 'component', id = 8 },  -- undershirt
    armour   = { kind = 'component', id = 9 },  -- gorsel yelek (deger ayri: SetPedArmour)
    jacket   = { kind = 'component', id = 11 }, -- ust/tops
}

--[[
    UNDERWEAR — bos slotun taban gorunumu.
    -------------------------------------------------------------------------
    Bu sunucuda giyilen HER SEY bir item'dir: bir slotta parca yoksa oyuncunun
    orasi CIPLAK olmalidir. Bu tablo o "hicbir sey giymiyor" halini tanimlar
    (component'lerde -1/None yoktur, taban bir drawable secilmek zorundadir).

    Kaynak: illenium-appearance `Config.InitialPlayerClothes` (erkek=kadin ayni).
    bitirim_clothing/config/config.lua -> `Config.Underwear` ile SENKRON.
    Burada YAZMAYAN component slotu 0'a duser (maske/zincir/yelek = "yok").
    Prop slotlari bu tabloda yoktur: bos prop = ClearPedProp.
]]
local underwear = {
    gloves = { drawable = 15, texture = 0 },  -- component 3  — ciplak kol
    pants  = { drawable = 21, texture = 0 },  -- component 4  — boxer / kulot
    -- component 6 — YALIN AYAK. drawable 0 DEGIL: 0 bu ped'de damali bir
    -- ayakkabi (oyunda gorulup duzeltildi). 34 illenium'un
    -- Config.InitialPlayerClothes'undaki degerdir (yeni karakterin ic camasiri
    -- gorunumu). Yine de ayakkabili gorunuyorsa: illenium dukkaninda yalin
    -- ayagi sec, /kiyafetbak yaz, F8'deki shoes drawable'ini buraya gecir.
    shoes  = { drawable = 34, texture = 0 },
    tshirt = { drawable = 15, texture = 0 },  -- component 8  — yok
    jacket = { drawable = 15, texture = 0 },  -- component 11 — yok
}

--[[
    Kiyafet itemleri -> slot + gorunum. (ORNEK; tam katalog kullanicidan.)
    Item ayrica data/items.lua'da (weight/label/gorsel) tanimli olmali.

    Gorunum iki bicimde yazilabilir:
      1) DUZ  : { slot = 'mask', drawable = 52, texture = 0 }
                (erkek ve kadin AYNI drawable — basit parcalar icin.)
      2) CINSIYETE GORE (drawable erkek/kadin farkliysa — cogu giysi boyle):
                { slot = 'mask', male = { drawable = 52, texture = 0 },
                                 female = { drawable = 33, texture = 0 } }

    Dogru drawable/texture sayilarini bulmak icin: kiyafet dukkaninda parcayi
    giy, sonra oyunda `/kiyafetbak` yaz -> F8 konsoluna su an giyili tum
    slotlarin degerlerini + cinsiyetini yazar. O sayilari buraya gecir.
]]
--[[
    ZIRH: armour slotu (component 9) hem GORSEL yelek (drawable/texture) hem GERCEK
    zirh degeri tasir. `armour = 0..100` alani eklenirse parca giyilince client
    SetPedArmour ile o kadar zirh verir, cikarinca 0'lar. `armour` yoksa slot sadece
    gorsel yelektir. Deger CINSIYETTEN bagimsizdir (wear kokune yazilir).
    Vanilla 'armour' item'i (Bulletproof Vest) buradan armour slotuna baglanir.
]]
local items = {
    ['mask_black']   = { slot = 'mask',     drawable = 52, texture = 0 },
    ['cap_black']    = { slot = 'hat',      drawable = 5,  texture = 0 },
    ['glasses_dark'] = { slot = 'glasses',  drawable = 5,  texture = 0 },
    ['gold_chain']   = { slot = 'necklace', drawable = 1,  texture = 0 },
    ['gold_watch']   = { slot = 'watch',    drawable = 12, texture = 0 },
    -- Bulletproof Vest -> armour slotu: gorsel yelek (component 9 drawable) + 100 zirh.
    -- drawable/texture'i kendi ped'inde /kiyafetbak ile dogrula ve gerekirse degistir.
    ['armour']       = { slot = 'armour',   drawable = 1,  texture = 0, armour = 100 },
}

--[[
    UST GIYSI <-> KOL ESLESMESI.
    GTA'da ust giysi (component 11) tek basina yetmez; uyumsuz bir kol
    (component 3) omuzda ten gorunmesine yol acar. Acikken, KOL slotu bos olan
    bir oyuncuda ust giyilince oyunun kendi "zorunlu bilesen" verisinden dogru
    kol otomatik uygulanir. Sorun cikarirsa tek satir: false yap.
]]
local autoMatchArms = true

return {
    slots = slots,
    underwear = underwear,
    autoMatchArms = autoMatchArms,
    items = items,
}
