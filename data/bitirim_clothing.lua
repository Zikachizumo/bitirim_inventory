--[[
    Bitirim — KIYAFET / EKIPMAN eslemesi (TEK KAYNAK)
    -------------------------------------------------
    Bu dosya hem server (equipment_server.lua) hem client (equipment_client.lua)
    tarafindan `lib.load('data.bitirim_clothing')` ile okunur. Amac: "hangi panel
    slotu -> hangi GTA hedefi" ve "hangi item -> hangi slot + gorunum" bilgisini
    TEK yerde tutmak (dunya karakteri ve ileride 3D onizleme ayni veriyi kullanir).

    Iki tablo:
      slots : panel slot anahtari -> GTA hedefi
              kind = 'component' -> SetPedComponentVariation(ped, id, drawable, texture, 0)
              kind = 'prop'      -> SetPedPropIndex(ped, id, drawable, texture, true)
                                    (cikarinca ClearPedProp(ped, id))
      items : kiyafet item adi -> { slot, drawable, texture }
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

-- Kiyafet itemleri -> slot + gorunum. (ORNEK; tam katalog kullanicidan.)
-- Item ayrica data/items.lua'da (weight/label/gorsel) tanimli olmali.
local items = {
    ['mask_black']   = { slot = 'mask',    drawable = 52, texture = 0 },
    ['cap_black']    = { slot = 'hat',     drawable = 5,  texture = 0 },
    ['glasses_dark'] = { slot = 'glasses', drawable = 5,  texture = 0 },
    ['gold_chain']   = { slot = 'necklace', drawable = 1, texture = 0 },
    ['gold_watch']   = { slot = 'watch',   drawable = 12, texture = 0 },
}

return {
    slots = slots,
    items = items,
}
