if not lib then return end

local Items = require 'modules.items.shared' --[[@as table<string, OxClientItem>]]

local function sendDisplayMetadata(data)
    SendNUIMessage({
		action = 'displayMetadata',
		data = data
	})
end

--- use array of single key value pairs to dictate order
---@param metadata string | table<string, string> | table<string, string>[]
---@param value? string
local function displayMetadata(metadata, value)
	local data = {}

	if type(metadata) == 'string' then
        if not value then return end

        data = { { metadata = metadata, value = value } }
	elseif table.type(metadata) == 'array' then
		for i = 1, #metadata do
			for k, v in pairs(metadata[i]) do
				data[i] = {
					metadata = k,
					value = v,
				}
			end
		end
	else
		for k, v in pairs(metadata) do
			data[#data + 1] = {
				metadata = k,
				value = v,
			}
		end
	end

    if client.uiLoaded then
        return sendDisplayMetadata(data)
    end

    CreateThread(function()
        repeat Wait(100) until client.uiLoaded

        sendDisplayMetadata(data)
    end)
end

exports('displayMetadata', displayMetadata)

---@param _ table?
---@param name string?
---@return table?
local function getItem(_, name)
    if not name then return Items end

	if type(name) ~= 'string' then return end

    name = name:lower()

    if name:sub(0, 7) == 'weapon_' then
        name = name:upper()
    end

    return Items[name]
end

setmetatable(Items --[[@as table]], {
	__call = getItem
})

---@cast Items +fun(itemName: string): OxClientItem
---@cast Items +fun(): table<string, OxClientItem>

local function Item(name, cb)
	local item = Items[name]
	if item then
		if not item.client?.export and not item.client?.event then
			item.effect = cb
		end
	end
end

local ox_inventory = exports[shared.resource]
-----------------------------------------------------------------------------------------------
-- Clientside item use functions
-----------------------------------------------------------------------------------------------

Item('bandage', function(data, slot)
	local maxHealth = GetEntityMaxHealth(cache.ped)
	local health = GetEntityHealth(cache.ped)
	ox_inventory:useItem(data, function(data)
		if data then
			SetEntityHealth(cache.ped, math.min(maxHealth, math.floor(health + maxHealth / 16)))
			lib.notify({ description = 'You feel better already' })
		end
	end)
end)

Item('armour', function(data, slot)
	if GetPedArmour(cache.ped) < 100 then
		ox_inventory:useItem(data, function(data)
			if data then
				SetPlayerMaxArmour(PlayerData.id, 100)
				SetPedArmour(cache.ped, 100)
			end
		end)
	end
end)

client.parachute = false
Item('parachute', function(data, slot)
	if not client.parachute then
		ox_inventory:useItem(data, function(data)
			if data then
				local chute = `GADGET_PARACHUTE`
				SetPlayerParachuteTintIndex(PlayerData.id, -1)
				GiveWeaponToPed(cache.ped, chute, 0, true, false)
				SetPedGadget(cache.ped, chute, true)
				lib.requestModel(1269906701)
				client.parachute = {CreateParachuteBagObject(cache.ped, true, true), slot?.metadata?.type or -1}
				if slot.metadata.type then
					SetPlayerParachuteTintIndex(PlayerData.id, slot.metadata.type)
				end
			end
		end)
	end
end)

Item('phone', function(data, slot)
	local success, result = pcall(function()
		return exports.npwd:isPhoneVisible()
	end)

	if success then
		exports.npwd:setPhoneVisible(not result)
	end
end)

--[[
	BITIRIM: ox'un jenerik 'clothing' item'i ped'i DOGRUDAN degistiriyordu
	(SetPedComponentVariation / SetPedPropIndex). Artik kiyafet, ekipman
	slotlarindan yonetiliyor (modules/bitirim/equipment_server.lua): parca
	envanterden cikip slota girer, panelde gorunur, cikarinca envantere doner
	ve bos slot underwear'a duser.

	Iki sistem ayni ped'e yazarsa carpisirlar — bu yuzden buradaki eski yol
	kaldirildi ve item, sunucudaki equip akisina yonlendirildi. Sunucu, o
	envanter slotundaki item'i OTORITER okur (client'tan gorunum bilgisi
	gelmez), metadata'sindan (component|prop + drawable + texture) hangi panel
	slotuna ait oldugunu cozer.

	NOT: yeni satislar 'apparel' + metadata.wear ile geliyor; 'clothing' yalnizca
	oyuncularin cantasinda kalmis ESKI parcalar icin duruyor.
]]
Item('clothing', function(data, slot)
	-- Görünüm burada ÇÖZÜLMEZ: sunucu o envanter slotundaki item'ı kendisi
	-- okuyup metadata'sından parçayı çıkarır (hem eski kök alanları hem yeni
	-- `wear` biçimi desteklenir). Böylece bir kez çıkarılıp envantere dönen
	-- eski parça da çalışmaya devam eder.
	if type(slot.metadata) ~= 'table' then
		return print('Clothing is missing metadata')
	end

	TriggerServerEvent('bitirim:server:equipSlot', slot.slot)
end)

-----------------------------------------------------------------------------------------------

exports('Items', function(item) return getItem(nil, item) end)
exports('ItemList', function(item) return getItem(nil, item) end)

return Items
