--[[
    ox_inventory uyumluluk koprusu — SERVER
    Kaynak: bitirim_inventory (ox_inventory v2.47.9 fork) server export listesi.
]]

local TARGET = 'bitirim_inventory'
local target = exports[TARGET]

-- bitirim_inventory/modules/**/server.lua + server.lua icindeki exports() cagrilariyla birebir
local names = {
    'AddItem',
    'CanCarryAmount',
    'CanCarryItem',
    'CanCarryWeight',
    'CanSwapItem',
    'ClearInventory',
    'ConfiscateInventory',
    'CreateDropFromPlayer',
    'CreateTemporaryStash',
    'CustomDrop',
    'GetContainerFromSlot',
    'GetCurrentWeapon',
    'GetEmptySlot',
    'GetInventory',
    'GetInventoryItems',
    'GetItem',
    'GetItemCount',
    'GetItemSlots',
    'GetSlot',
    'GetSlotForItem',
    'GetSlotIdWithItem',
    'GetSlotIdsWithItem',
    'GetSlotWithItem',
    'GetSlotsWithItem',
    'InspectInventory',
    'Inventory',
    'ItemList',
    'Items',
    'RegisterShop',
    'RegisterStash',
    'RemoveInventory',
    'RemoveItem',
    'ReturnInventory',
    'Search',
    'SetDurability',
    'SetItem',
    'SetMaxWeight',
    'SetMetadata',
    'SetSlotCount',
    'SwapSlots',
    'UpdateVehicle',
    'addCash',
    'forceOpenInventory',
    'getBank',
    'getCards',
    'getCash',
    'giveCard',
    'registerHook',
    'removeCash',
    'removeHooks',
    'setContainerProperties', -- modules/items/containers.lua (server tarafinda require ediliyor)
    'setPlayerInventory',
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
