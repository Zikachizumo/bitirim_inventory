--[[
    ox_inventory uyumluluk koprusu — CLIENT
    Kaynak: bitirim_inventory (ox_inventory v2.47.9 fork) client export listesi.
]]

local TARGET = 'bitirim_inventory'
local target = exports[TARGET]

-- bitirim_inventory/modules/**/client.lua icindeki exports() cagrilariyla birebir
local names = {
    'CancelProgress',
    'GetItemCount',
    'GetPlayerItems',
    'GetPlayerMaxWeight',
    'GetPlayerWeight',
    'GetSlotIdWithItem',
    'GetSlotWithItem',
    'GetSlotsWithItem',
    'ItemList',
    'Items',
    'Keyboard',
    'Progress',
    'ProgressActive',
    'Search',
    'closeInventory',
    'displayMetadata',
    'getCurrentWeapon',
    'giveItemToTarget',
    'notify',
    'openInventory',
    'openNearbyInventory',
    'setGetPlayerNameMethod',
    'setStashTarget',
    'suppressItemNotifications',
    'useItem',
    'useSlot',
    'weaponWheel',
}

for i = 1, #names do
    local name = names[i]
    exports(name, function(...)
        return target[name](...)
    end)
end

-- Yanlis baslatma sirasini sessizce degil, acikca bildir.
CreateThread(function()
    Wait(2000)

    if GetResourceState(TARGET) ~= 'started' then
        print(('^1[ox_inventory kopru]^0 ^3%s baslatilmamis.^0 server.cfg de "ensure %s" satiri "ensure ox_inventory" ONUNDE olmali.')
            :format(TARGET, TARGET))
    end
end)
