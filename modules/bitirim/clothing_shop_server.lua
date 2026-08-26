--[[
    Bitirim — KIYAFET MAGAZASI BACKEND (satin alma, server-authoritative)
    -----------------------------------------------------------------------
    Katalog: data/bitirim_clothing_shop.lua (TEK KAYNAK, client de AYNI dosyayi
    okur ama fiyat/varlik dogrulamasi SADECE burada yapilir -- client'tan gelen
    fiyata ASLA guvenilmez).

    Akis (modules/shops/server.lua'daki 'ox_inventory:buyItem' deseniyle AYNI
    para dusme yontemi; item verme modules/bitirim/equipment_server.lua'daki
    '/kiyafetver' komutuyla BIREBIR AYNI, kanitlanmis uctan uca calisan yol):
      1) 'bitirim:server:buyClothing' -- cart = {{id=itemId, qty=n}, ...}
      2) Her satiri SERVER'IN KENDI catalog kopyasindan dogrula.
      3) Toplam fiyati hesapla, Inventory.GetItemCount(inv,'money') ile karsilastir.
      4) Yetmiyorsa hata bildirimi + dur. Yetiyorsa Inventory.RemoveItem + server.syncInventory
         (qbx cash HUD'unu senkronlar -- server global'i modules/shops/server.lua'daki
         AYNI ambient tablo, require gerekmez).
      5) Her satir icin Inventory.AddItem(source, 'apparel', qty, { label=, wear={slot,
         male=, female=} }) -- wear'da male/female birlikte tasinabilir, client
         (equipment_client.lua -> resolveWear) cinsiyete gore kendisi cozer.
]]

local Inventory = require 'modules.inventory.server'
local catalog = lib.load('data.bitirim_clothing_shop')

local itemsById = {}
for _, item in ipairs(catalog.items) do
    itemsById[item.id] = item
end

local function notify(source, ntype, description)
    TriggerClientEvent('ox_lib:notify', source, { type = ntype, description = description })
end

RegisterNetEvent('bitirim:server:buyClothing', function(cart)
    local source = source

    if type(cart) ~= 'table' or #cart == 0 then return end

    -- 1-2) Her satiri dogrula + toplam fiyati SERVER-SIDE hesapla.
    local lines = {}
    local total = 0

    for _, line in ipairs(cart) do
        local item = type(line) == 'table' and itemsById[line.id]
        local qty = type(line) == 'table' and math.floor(tonumber(line.qty) or 0) or 0

        if not item or qty <= 0 then
            return notify(source, 'error', 'Gecersiz sepet satiri.')
        end

        total = total + item.price * qty
        lines[#lines + 1] = { item = item, qty = qty }
    end

    local playerInv = Inventory(source)
    if not playerInv then return end

    -- 3) Bakiye kontrolu (money = ox_inventory'nin izledigi para item'i).
    if Inventory.GetItemCount(playerInv, 'money') < total then
        return notify(source, 'error', ('Yetersiz bakiye. Gereken: $%d'):format(total))
    end

    -- 4) Parayi dus + qbx hesabini senkronla.
    Inventory.RemoveItem(playerInv, 'money', total)
    if server.syncInventory then server.syncInventory(playerInv) end

    -- 5) Her satir icin 'apparel' item'ini metadata.wear ile ver.
    for _, line in ipairs(lines) do
        local item = line.item
        local metadata = {
            label = item.label,
            wear = { slot = item.slot, male = item.male, female = item.female },
        }
        Inventory.AddItem(source, 'apparel', line.qty, metadata)
    end

    notify(source, 'success', ('Satin alma tamamlandi. Toplam: $%d'):format(total))
    TriggerClientEvent('bitirim:clothingPurchaseResult', source, { ok = true, cart = cart })
end)
