--[[
    Bitirim — KIYAFET MAGAZASI CLIENT KOPRUSU (NUI olaylari + on-izleme)
    -----------------------------------------------------------------------
    GrandRP tarzi kategori+sepet magaza ekrani icin previewPed'i (character_client.lua
    ile AYNI, modules/bitirim/preview_manager.lua export'lari uzerinden) yeniden
    kullanir -- hicbir kamera/klon kodu tekrar yazilmaz.

    Acilis (MVP): /magaza komutu. Gercek bir NPC/ox_target noktasina baglamak
    icin modules/shops/client.lua'daki blip/target kurulum deseni kopyalanip
    kullanici fiziksel konumu belirleyince eklenebilir.
]]

local Preview = exports[GetCurrentResourceName()]
local catalog = lib.load('data.bitirim_clothing_shop')
local clothing = lib.load('data.bitirim_clothing')

local shopOpen = false

local function openShop()
    if shopOpen then return end
    shopOpen = true

    if Preview:IsPreviewActive() then Preview:DestroyPreview() end
    Preview:CreatePreview(true)

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'setShopVisible', data = { visible = true, catalog = catalog } })
end

local function closeShop()
    if not shopOpen then return end
    shopOpen = false

    SetNuiFocus(false, false)
    Preview:DestroyPreview()
    SendNUIMessage({ action = 'setShopVisible', data = { visible = false } })
end

RegisterCommand('magaza', function()
    openShop()
end, false)

RegisterNUICallback('bitirim:clothingClose', function(_, cb)
    cb(1)
    closeShop()
end)

--- Vitrindeki secili urunu previewPed uzerinde dener (SATIN ALMAZ, giydirmez —
--- sadece gorsel onizleme). data = { slot, male={drawable,texture}, female={...} }.
RegisterNUICallback('bitirim:clothingPreview', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or not data.slot then return end

    local def = clothing.slots[data.slot]
    if not def then return end

    local isFemale = GetEntityModel(PlayerPedId()) == `mp_f_freemode_01`
    local wear = (isFemale and data.female) or data.male or data.female
    if type(wear) ~= 'table' then return end

    if def.kind == 'component' then
        Preview:UpdateComponent(def.id, wear.drawable, wear.texture)
    else
        Preview:UpdateProp(def.id, wear.drawable, wear.texture)
    end
end)

--- Sepet checkout -> server-authoritative satin alma. data = { cart = {{id,qty},...} }.
RegisterNUICallback('bitirim:clothingCheckout', function(data, cb)
    cb(1)
    if type(data) == 'table' and type(data.cart) == 'table' then
        TriggerServerEvent('bitirim:server:buyClothing', data.cart)
    end
end)

-- Server satin almayi isledi (basarili/basarisiz) -> NUI'ye ilet (sepeti temizle).
RegisterNetEvent('bitirim:clothingPurchaseResult', function(result)
    SendNUIMessage({ action = 'clothingPurchaseResult', data = result })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and shopOpen then closeShop() end
end)
