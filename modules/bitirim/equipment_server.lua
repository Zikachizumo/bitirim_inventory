--[[
    Bitirim — EKIPMAN / KIYAFET BACKEND (kalici giyili itemler + ped uygulama)
    --------------------------------------------------------------------------
    TEK ekipman sistemi. Doğruluk kaynağı: `bitirim_equipment` DB tablosu
    (her karakter icin tek satir, JSON). Giyili her parca bir SLOT tutar
    (hat/mask/jacket/...). Bu tablo hem dunya ped'ini surer (client uygular)
    hem de ileride 3D onizlemeyi besleyecek (ayni veri).

    Akis:
      - GIYME (use): kiyafet item'i use edilince (Kullan / cift tik / sag tik)
        item envanterden CIKAR, slota yazilir, DB'ye kaydedilir, client'e
        uygulanmasi icin gonderilir. Slot doluysa eski parca once envantere iade.
      - CIKARMA (unequip): panelden -> item envantere IADE, slottan silinir,
        DB guncellenir, client ped'i eski haline dondurur.

    Slot + gorunum eslemesi: data/bitirim_clothing.lua (TEK KAYNAK).
    Desen: modules/bitirim/server.lua (canta backend) ile ayni yapi taslagi.
    ADDITIVE + pcall guard: qbx/MySQL hazir degilse boot kirilmaz.
]]

local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'
local clothing = lib.load('data.bitirim_clothing')

-- citizenid -> { slot = { item, drawable, texture } }  (bellek onbellegi)
local equipCache = {}

--- Tablo (yoksa olustur).
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `bitirim_equipment` (
            `citizenid` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL,
            PRIMARY KEY (`citizenid`)
        )
    ]])
end)

--- qbx oyuncusundan citizenid.
local function citizenidOf(source)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    if not ok or not player then return nil end
    return player.PlayerData and player.PlayerData.citizenid or nil
end

--- Kisa bildirim yardimcisi (ox_lib).
local function notify(source, ntype, description)
    TriggerClientEvent('ox_lib:notify', source, { type = ntype, description = description })
end

--- Karakterin giyili ekipmanini DB'den yukle (onbellege al). Dondurdugu tablo
--- slot -> { item, drawable, texture }.
local function loadEquipment(source)
    local cid = citizenidOf(source)
    if not cid then return {} end

    if equipCache[cid] ~= nil then return equipCache[cid] end

    local tbl = {}
    local row = MySQL.single.await('SELECT `data` FROM `bitirim_equipment` WHERE `citizenid` = ?', { cid })
    if row and row.data then
        local ok, decoded = pcall(json.decode, row.data)
        if ok and type(decoded) == 'table' then tbl = decoded end
    end

    equipCache[cid] = tbl
    return tbl
end

--- Onbellegi DB'ye yaz (kalici).
local function saveEquipment(cid)
    local tbl = equipCache[cid] or {}
    MySQL.query.await(
        'INSERT INTO `bitirim_equipment` (`citizenid`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = ?',
        { cid, json.encode(tbl), json.encode(tbl) }
    )
end

--- Client'e giyili ekipmani gonder (ped uygulamasi + panel gosterimi). Payload
--- slot -> { drawable, texture }; client kind/id'yi data/bitirim_clothing'den cozer.
local function pushToClient(source)
    local tbl = loadEquipment(source)
    local payload = {}
    for slot, entry in pairs(tbl) do
        payload[slot] = { item = entry.item, drawable = entry.drawable, texture = entry.texture }
    end
    TriggerClientEvent('bitirim:client:equipment', source, payload)
end

--[[
    GIYME — kiyafet item'i use edilince cagrilir.
    itemName data/bitirim_clothing.items'ta tanimli olmali (degilse "kiyafet"
    sayilmaz, dokunulmaz). useData = qbx use verisi ({ name, slot, ... }).
]]
local function equip(source, itemName, useData)
    local map = clothing.items[itemName]
    if not map then return end -- kiyafet degil

    local slotDef = clothing.slots[map.slot]
    if not slotDef then
        return notify(source, 'error', 'Bu parca icin gecerli bir ekipman slotu tanimli degil.')
    end

    local cid = citizenidOf(source)
    if not cid then return end

    local tbl = loadEquipment(source)
    local old = tbl[map.slot]

    -- Ayni item zaten bu slotta takiliysa bir sey yapma (spam korumasi).
    if old and old.item == itemName then
        return notify(source, 'inform', 'Bu parca zaten takili.')
    end

    -- Slot doluysa ONCE eski parcayi envantere iade et (yer yoksa giyme iptal).
    if old then
        local ok, addOk = pcall(function()
            return Inventory.AddItem(source, old.item, 1)
        end)
        if not (ok and addOk) then
            return notify(source, 'error', 'Envanterde yer yok; once yer ac.')
        end
    end

    -- Yeni parcayi envanterden cikar (kullanilan slottan).
    local rok, removed = pcall(function()
        return Inventory.RemoveItem(source, itemName, 1, nil, useData and useData.slot)
    end)
    if not (rok and removed) then
        -- Eski parca zaten iade edildi; slot bos kaldi. Kayip yok.
        tbl[map.slot] = nil
        equipCache[cid] = tbl
        saveEquipment(cid)
        pushToClient(source)
        return notify(source, 'error', 'Parca takilamadi, tekrar dene.')
    end

    -- Slota yaz + kaydet + uygula.
    tbl[map.slot] = { item = itemName, drawable = map.drawable, texture = map.texture }
    equipCache[cid] = tbl
    saveEquipment(cid)
    pushToClient(source)

    local label = (Items and Items(itemName) and Items(itemName).label) or itemName
    notify(source, 'success', ('%s takildi.'):format(label))
end

--[[
    CIKARMA — panelden slot cikarilir. Item envantere iade edilir.
]]
local function unequip(source, slot)
    local cid = citizenidOf(source)
    if not cid then return false end

    local tbl = loadEquipment(source)
    local entry = tbl[slot]
    if not entry then return false end

    -- Item'i envantere iade et; yer yoksa cikarma iptal (parca ustunde kalir).
    local ok, addOk = pcall(function()
        return Inventory.AddItem(source, entry.item, 1)
    end)
    if not (ok and addOk) then
        notify(source, 'error', 'Envanterde yer yok; parca cikarilamadi.')
        return false
    end

    tbl[slot] = nil
    equipCache[cid] = tbl
    saveEquipment(cid)
    pushToClient(source)

    local label = (Items and Items(entry.item) and Items(entry.item).label) or entry.item
    notify(source, 'inform', ('%s cikarildi.'):format(label))
    return true
end

--- Kiyafet itemlerini qbx kullanilabilir-item sistemine kaydet (use = giy).
CreateThread(function()
    for itemName in pairs(clothing.items) do
        local name = itemName -- closure icin sabitle
        local ok, err = pcall(function()
            exports.qbx_core:CreateUseableItem(name, function(src, data)
                equip(src, name, data)
            end)
        end)
        if not ok then
            print(('[bitirim] %s kullanilabilir item kaydedilemedi: %s'):format(name, tostring(err)))
        end
    end
end)

-- Panelden gelen cikarma istegi (client NUI -> server).
RegisterNetEvent('bitirim:server:unequip', function(slot)
    local source = source
    if type(slot) ~= 'string' then return end
    unequip(source, slot)
end)

-- Envanter acilinca giyili ekipmani iste (relog/timing emniyeti).
lib.callback.register('bitirim:server:getEquipment', function(source)
    pushToClient(source)
    return true
end)

exports('BitirimGetEquipment', function(source) return loadEquipment(source) end)
exports('BitirimEquip', function(source, itemName) return equip(source, itemName, nil) end)
exports('BitirimUnequip', function(source, slot) return unequip(source, slot) end)

--- Oyuncu envanteri hazir oldugunda (ox ile ayni state bag) ekipmani uygula.
--- illenium temel skini yukledikten SONRA uygulanmali diye kisa gecikme
--- (canta backend'iyle ayni 1500ms; client base'i yakalayip ustune uygular).
AddStateBagChangeHandler('loadInventory', nil, function(bagName, _, value)
    if not value then return end
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end

    CreateThread(function()
        Wait(2000) -- illenium skin + ox envanteri kursun
        pushToClient(src)
    end)
end)

--- Onbellek temizligi.
AddEventHandler('qbx_core:server:playerLoggedOut', function(source)
    local cid = citizenidOf(source)
    if cid then equipCache[cid] = nil end
end)

--- Admin/test: /setkiyafet <itemName>  (kendine giy) | /setkiyafet clear <slot>
--- ACE: bitirim.admin (konsol serbest degil — source gerekli).
RegisterCommand('setkiyafet', function(source, args)
    if source == 0 then return print('setkiyafet oyuncudan calistirilmali') end
    if not IsPlayerAceAllowed(source, 'bitirim.admin') then
        return notify(source, 'error', 'Yetkisiz.')
    end

    local a1 = args[1]
    if a1 == 'clear' and args[2] then
        unequip(source, args[2])
        return
    end

    if not a1 or not clothing.items[a1] then
        return notify(source, 'error', 'Kullanim: /setkiyafet <kiyafet_item> | /setkiyafet clear <slot>')
    end

    -- Test icin: envanterde yoksa bile bir tane ver, sonra giy.
    pcall(function() Inventory.AddItem(source, a1, 1) end)
    equip(source, a1, nil)
end, false)
