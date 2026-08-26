--[[
    Bitirim — KIYAFET MAGAZASI KATALOGU (TEK KAYNAK)
    -------------------------------------------------
    Hem client (modules/bitirim/clothing_shop_client.lua) hem server
    (modules/bitirim/clothing_shop_server.lua) tarafindan `lib.load('data.bitirim_clothing_shop')`
    ile okunur. GrandRP tarzi magaza ekraninin kategori + urun listesini besler.

    `slot` alani data/bitirim_clothing.lua -> slots ile AYNI anahtar olmali (hat/
    glasses/mask/jacket/tshirt/gloves/pants/shoes/necklace/watch/ring/ears/armour) —
    satin alma sonucu verilen 'apparel' item'i equipment_server.lua'nin ZATEN
    calisan pipeline'ina (metadata.wear.slot) dogrudan baglanir.

    drawable/texture DEGERLERI SU AN PLACEHOLDER (0)! Gercek GTA katalog
    degerlerini bulmak icin: kiyafeti (herhangi bir kaynaktan) giy, oyunda
    `/kiyafetbak` yaz, F8 konsoluna cikan drawable/texture'i buraya gecir
    (bkz docs/KIYAFET_EKLEME.md). Cinsiyet farkli ise male/female AYRI yazilir;
    ayni ise sadece `male` yazip `female = male` da denebilir (asagida ayri
    birakildi, netlik icin).
]]

local categories = {
    { id = 'headwear',  label = 'Headwear',  icon = 'IconCap' },
    { id = 'outerwear', label = 'Outerwear', icon = 'IconJacket' },
    { id = 'tshirts',   label = 'T-Shirts',  icon = 'IconTshirt' },
    { id = 'pants',     label = 'Pants',     icon = 'IconPants' },
    { id = 'shoes',     label = 'Shoes',     icon = 'IconShoes' },
    { id = 'glasses',   label = 'Glasses',   icon = 'IconGlasses' },
}

-- Kategori basina birkac placeholder item. drawable/texture = 0 (TODO: gercek ID).
local items = {
    -- HEADWEAR (slot='hat', prop)
    { id = 'hw_beanie_01', category = 'headwear', label = 'Muska kapa (Bere)', price = 900,
      slot = 'hat', male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
    { id = 'hw_cap_01', category = 'headwear', label = 'Muska kapa (Sapka)', price = 750,
      slot = 'hat', male = { drawable = 1, texture = 0 }, female = { drawable = 1, texture = 0 } },
    { id = 'hw_dunce_01', category = 'headwear', label = 'Dunce Hat', price = 1500,
      slot = 'hat', male = { drawable = 2, texture = 0 }, female = { drawable = 2, texture = 0 } },

    -- OUTERWEAR (slot='jacket', component)
    { id = 'ow_bomber_01', category = 'outerwear', label = 'Muska vanjska odeca', price = 2025,
      slot = 'jacket', male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
    { id = 'ow_varsity_01', category = 'outerwear', label = 'Varsity Ceket', price = 2400,
      slot = 'jacket', male = { drawable = 1, texture = 0 }, female = { drawable = 1, texture = 0 } },

    -- T-SHIRTS (slot='tshirt', component)
    { id = 'ts_basic_01', category = 'tshirts', label = 'Muska majica', price = 1500,
      slot = 'tshirt', male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
    { id = 'ts_tank_01', category = 'tshirts', label = 'Atlet', price = 900,
      slot = 'tshirt', male = { drawable = 1, texture = 0 }, female = { drawable = 1, texture = 0 } },
    { id = 'ts_vest_01', category = 'tshirts', label = 'Yelek', price = 1200,
      slot = 'tshirt', male = { drawable = 2, texture = 0 }, female = { drawable = 2, texture = 0 } },

    -- PANTS (slot='pants', component)
    { id = 'pt_jeans_01', category = 'pants', label = 'Muske pantalone', price = 900,
      slot = 'pants', male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
    { id = 'pt_chino_01', category = 'pants', label = 'Chino Pantolon', price = 1100,
      slot = 'pants', male = { drawable = 1, texture = 0 }, female = { drawable = 1, texture = 0 } },

    -- SHOES (slot='shoes', component)
    { id = 'sh_sneaker_01', category = 'shoes', label = 'Muske cipele', price = 1275,
      slot = 'shoes', male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
    { id = 'sh_boot_01', category = 'shoes', label = 'Bot', price = 1600,
      slot = 'shoes', male = { drawable = 1, texture = 0 }, female = { drawable = 1, texture = 0 } },

    -- GLASSES (slot='glasses', prop)
    { id = 'gl_dark_01', category = 'glasses', label = 'Muske naocare', price = 1500,
      slot = 'glasses', male = { drawable = 0, texture = 0 }, female = { drawable = 0, texture = 0 } },
    { id = 'gl_clear_01', category = 'glasses', label = 'Seffaf Gozluk', price = 950,
      slot = 'glasses', male = { drawable = 1, texture = 0 }, female = { drawable = 1, texture = 0 } },
}

return {
    categories = categories,
    items = items,
}
