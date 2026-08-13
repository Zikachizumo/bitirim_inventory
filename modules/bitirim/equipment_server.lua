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

--- Onbellegi DB'ye yaz (kalici). BLOKE ETMEZ (fire-and-forget): equip/unequip
--- use akisinin icinde cagriliyor; client `ox_inventory:useItem` callback'i
--- yalnizca 200ms bekliyor. Bloke bir DB await bu sureyi asinca ilk cift-tik
--- "olmadi" gibi gorunuyordu (+usingItem kilidi ~500ms). Onbellek zaten
--- otoriter; DB kalicilik icin arka planda yazilir.
local function saveEquipment(cid)
    local tbl = equipCache[cid] or {}
    local encoded = json.encode(tbl)
    MySQL.query(
        'INSERT INTO `bitirim_equipment` (`citizenid`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = ?',
        { cid, encoded, encoded }
    )
end

--- Client'e giyili ekipmani gonder (ped uygulamasi + panel gosterimi). Payload
--- slot -> { item, label, image, wear }. `wear` gorunum tablosudur
--- ({ slot, drawable, texture } veya { slot, male, female }); client bunu
--- oyuncunun CINSIYETINE gore uygular. `wear` yoksa (eski satir) client
--- data/bitirim_clothing.items map'inden coz. label/image panel gosterimi icin.
local function pushToClient(source)
    local tbl = loadEquipment(source)
    local payload = {}
    for slot, entry in pairs(tbl) do
        payload[slot] = {
            item = entry.item,
            label = entry.label,
            image = entry.image,
            imageurl = entry.imageurl,
            wear = entry.wear,
        }
    end
    TriggerClientEvent('bitirim:client:equipment', source, payload)
end

--- Bir DB entry'sini (giyili parca) ENVANTERE iade et. apparel ise metadata ile,
--- legacy named item ise duz. `toSlot` verilirse item O SLOTA konur (surukle-cikar
--- ile birakilan slot -> siralama yok, istenilen yere). @return boolean success
local function giveBackEntry(source, entry, toSlot)
    toSlot = tonumber(toSlot)
    -- Metadata-guдумlu parca (apparel + eski magaza 'clothing' item'i): gorunum
    -- item'in KENDI metadata'sindadir, metadatasiz iade edilirse parca olur.
    -- (`item == 'apparel'` kontrolu, fromMetadata alani eklenmeden once DB'ye
    -- yazilmis satirlar icin duruyor.)
    if entry.fromMetadata or entry.item == 'apparel' then
        local meta = {
            label = entry.label,
            image = entry.image,
            imageurl = entry.imageurl,
            rarity = entry.rarity,
            wear = entry.wear,
        }
        local ok, addOk = pcall(function() return Inventory.AddItem(source, entry.item, 1, meta, toSlot) end)
        return ok and addOk
    end
    local ok, addOk = pcall(function() return Inventory.AddItem(source, entry.item, 1, nil, toSlot) end)
    return ok and addOk
end

--- GTA hedefi (kind + id) -> panel slot anahtari. clothing.slots'un TERSI;
--- bir kez kurulur. Eski magaza item'lerini (component/prop id tasiyan) dogru
--- slota oturtmak icin.
local slotByTarget = {}
for slotKey, def in pairs(clothing.slots) do
    slotByTarget[('%s:%d'):format(def.kind, def.id)] = slotKey
end

local function slotKeyOf(kind, id)
    return slotByTarget[('%s:%d'):format(kind, id)]
end

--- Kullanilan item + metadata'dan normalize parca cikar. Metadata-guдумlu
--- (apparel) veya legacy (named item + clothing.items map). Bulunamazsa nil.
--- Donus: entry = { item, label?, image?, imageurl?, rarity?, wear = { slot, ... } }
---
--- image vs imageurl: `image` ox'un kendi web/images klasorundeki BASE ADIdir
--- (or. 'mask_ski'); `imageurl` ise tam bir URL'dir (or. bitirim_clothing'in
--- urettigi nui://bitirim_clothing/web/images/....png). Ikisi de panele ayni
--- yoldan gider, arayuz once imageurl'e bakar.
local function resolvePiece(itemName, metadata)
    -- 1) Metadata-guдумlu (apparel): gorunum item metadata'sinda.
    if type(metadata) == 'table' and type(metadata.wear) == 'table' and metadata.wear.slot then
        return {
            item = itemName,
            label = metadata.label,
            image = metadata.image,
            imageurl = metadata.imageurl,
            rarity = metadata.rarity,
            wear = metadata.wear,
            fromMetadata = true,
        }
    end

    -- 1b) ESKI bitirim_clothing magaza item'i ('clothing'): gorunum metadata'nin
    -- KOKUNDE durur (component|prop + drawable + texture), `wear` yoktur. Yeni
    -- satislar 'apparel' + metadata.wear ile geliyor; bu dal yalnizca oyuncularin
    -- cantasinda kalmis eski parcalar icin. GTA id'sinden panel slotu bulunur.
    if type(metadata) == 'table' and tonumber(metadata.drawable) then
        local kind, id
        if metadata.prop ~= nil then
            kind, id = 'prop', tonumber(metadata.prop)
        elseif metadata.component ~= nil then
            kind, id = 'component', tonumber(metadata.component)
        end

        local slotKey = id and slotKeyOf(kind, id)
        if slotKey then
            return {
                item = itemName,
                label = metadata.label,
                imageurl = metadata.imageurl,
                wear = {
                    slot = slotKey,
                    drawable = tonumber(metadata.drawable),
                    texture = tonumber(metadata.texture) or 0,
                },
                fromMetadata = true,
            }
        end
    end

    -- 2) Legacy: clothing.items map'inden.
    local map = clothing.items[itemName]
    if map then
        return {
            item = itemName,
            wear = { slot = map.slot, drawable = map.drawable, texture = map.texture, male = map.male, female = map.female, armour = map.armour },
        }
    end

    return nil
end

--[[
    GIYME — kiyafet item'i use edilince cagrilir. itemName + metadata'dan parca
    cozulur (apparel -> metadata.wear; legacy -> clothing.items map). Kiyafet
    degilse dokunulmaz. useData = qbx use verisi ({ name, slot, metadata, ... }).
]]
local function equip(source, itemName, useData)
    local metadata = type(useData) == 'table' and useData.metadata or nil
    local piece = resolvePiece(itemName, metadata)
    if not piece then return end -- kiyafet degil

    local slotKey = piece.wear.slot
    if not clothing.slots[slotKey] then
        return notify(source, 'error', 'Bu parca icin gecerli bir ekipman slotu tanimli degil.')
    end

    local cid = citizenidOf(source)
    if not cid then return end

    local tbl = loadEquipment(source)
    local old = tbl[slotKey]

    -- Slot doluysa ONCE eski parcayi envantere iade et (yer yoksa giyme iptal).
    if old then
        if not giveBackEntry(source, old) then
            return notify(source, 'error', 'Envanterde yer yok; once yer ac.')
        end
    end

    -- Yeni parcayi envanterden cikar (kullanilan slottan).
    local rok, removed = pcall(function()
        return Inventory.RemoveItem(source, itemName, 1, nil, useData and useData.slot)
    end)
    if not (rok and removed) then
        -- Eski parca zaten iade edildi; slot bos kaldi. Kayip yok.
        tbl[slotKey] = nil
        equipCache[cid] = tbl
        pushToClient(source)
        saveEquipment(cid)
        return notify(source, 'error', 'Parca takilamadi, tekrar dene.')
    end

    -- Geldigi envanter slotunu sakla -> cikarinca (tik) AYNI slota doner (siralama yok).
    piece.fromSlot = useData and tonumber(useData.slot) or nil

    -- Slota yaz -> ONCE uygula/gonder (aninda giyilsin), SONRA DB'ye yaz (bloke etmez).
    tbl[slotKey] = piece
    equipCache[cid] = tbl
    pushToClient(source)
    saveEquipment(cid)

    local label = piece.label or (Items and Items(itemName) and Items(itemName).label) or itemName
    notify(source, 'success', ('%s takildi.'):format(label))
end

--[[
    CIKARMA — panelden slot cikarilir. Item (apparel ise metadata'siyla) envantere
    iade. `toSlot` verilirse (envantere surukle-birak) item o slota konur.
]]
local function unequip(source, slot, toSlot)
    local cid = citizenidOf(source)
    if not cid then return false end

    local tbl = loadEquipment(source)
    local entry = tbl[slot]
    if not entry then return false end

    -- Hedef slot: surukle-birak slotu (toSlot) > yoksa geldigi slot (fromSlot) >
    -- yoksa ilk bos. Boylece item "siralanmaz", eski/istenen yerine doner.
    toSlot = tonumber(toSlot) or entry.fromSlot

    -- Item'i envantere iade et (varsa birakilan/geldigi slota); yer yoksa iptal.
    if not giveBackEntry(source, entry, toSlot) then
        notify(source, 'error', 'Envanterde yer yok; parca cikarilamadi.')
        return false
    end

    tbl[slot] = nil
    equipCache[cid] = tbl
    pushToClient(source)
    saveEquipment(cid)

    local label = entry.label or (Items and Items(entry.item) and Items(entry.item).label) or entry.item
    notify(source, 'inform', ('%s cikarildi.'):format(label))
    return true
end

--- Kiyafet itemlerini qbx kullanilabilir-item sistemine kaydet (use = giy).
--- 'apparel' = generic base item (metadata-guдумlu katalog); ayrica legacy
--- named itemler (clothing.items). Hepsi ayni equip() yoluna gider.
CreateThread(function()
    local names = { 'apparel' }
    for itemName in pairs(clothing.items) do names[#names + 1] = itemName end

    for i = 1, #names do
        local name = names[i] -- closure icin sabitle
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
RegisterNetEvent('bitirim:server:unequip', function(slot, toSlot)
    local source = source
    if type(slot) ~= 'string' then return end
    unequip(source, slot, toSlot)
end)

-- HIZLI GIYME yolu: cift-tik / surukle-giy bunu cagirir. ox'un `useItem` akisini
-- (200ms callback + 500ms usingItem kilidi) ATLAR -> aninda giyer. Client sadece
-- slot no yollar; sunucu o slottaki item'i OTORITER okuyup equip eder (guvenli).
RegisterNetEvent('bitirim:server:equipSlot', function(slot)
    local source = source
    slot = tonumber(slot)
    if not slot then return end

    local inv = Inventory(source)
    local item = inv and inv.items and inv.items[slot]
    if not item or not item.name then return end

    equip(source, item.name, { slot = slot, metadata = item.metadata })
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

--- Admin/test: /kiyafetver <slot> <drawable> <texture> [etiket...]
--- Metadata'li bir 'apparel' itemi ENVANTERE verir (giydirmez — dukkan gibi).
--- Oyuncu use ile giyer. Dukkansiz uctan uca test icin.
RegisterCommand('kiyafetver', function(source, args)
    if source == 0 then return print('kiyafetver oyuncudan calistirilmali') end
    if not IsPlayerAceAllowed(source, 'bitirim.admin') then
        return notify(source, 'error', 'Yetkisiz.')
    end

    local slot = args[1]
    local drawable = tonumber(args[2])
    local texture = tonumber(args[3])

    if not slot or not clothing.slots[slot] or not drawable or not texture then
        return notify(source, 'error', 'Kullanim: /kiyafetver <slot> <drawable> <texture> [etiket]')
    end

    -- 4. arg ve sonrasi = etiket.
    local label = nil
    if args[4] then
        label = table.concat(args, ' ', 4)
    end

    local metadata = {
        label = label,
        wear = { slot = slot, drawable = drawable, texture = texture },
    }

    local ok, addOk = pcall(function() return Inventory.AddItem(source, 'apparel', 1, metadata) end)
    if ok and addOk then
        notify(source, 'success', ('Kiyafet verildi (%s). Use ile giy.'):format(label or slot))
    else
        notify(source, 'error', 'Kiyafet verilemedi (envanterde yer yok?).')
    end
end, false)
