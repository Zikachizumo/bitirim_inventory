--[[
    Bitirim — canta seviyesi BACKEND (kalici seviye + gercek agirlik siniri)
    -----------------------------------------------------------------------
    - Seviye her karakter icin `bitirim_backpack` tablosunda saklanir (0-5).
      Yeni oyuncu 0 (cantasiz) baslar.
    - Seviyeye gore GERCEK agirlik siniri uygulanir (Inventory.SetMaxWeight).
    - Seviye client'e gonderilir; client NUI'ye setBagLevel yollar (renk +
      kilitli slot gorseli).
    - Sunucu tarafi KILIT KORUMASI: canta seviyesiyle kilitli bir slota item
      konmasini reddeden swapItems hook'u (asagida). UI zaten engelliyor; bu
      sunucu-otoriter emniyet. FAIL-OPEN: seviye kesin bilinemezse izin verir.

    HENUZ YOK (sonraki adim): 724 Market satisi + giyme; L3-5 kraft.
    Fiyat/tarif kullanicidan.

    Not: Bu modul ADDITIVE — ox core dosyalarina dokunmaz. Tum framework
    cagrilari pcall/guard ile korunur; hata olsa bile sunucuyu kirmaz.
]]

local Inventory = require 'modules.inventory.server'

-- Seviye -> agirlik kapasitesi (KG). index = seviye. L0 (cantasiz) placeholder 10.
local CAP_KG = { [0] = 10, [1] = 20, [2] = 35, [3] = 50, [4] = 70, [5] = 90 }
local MAX_LEVEL = 5

-- Kilit hesabi (frontend store/backpack.ts ile AYNI olmali):
--   Player envanteri = 5 makro (1-5) + 40 grid (6-45).
--   Her seviye +8 grid slotu acar. Acik toplam = 5 + seviye*8.
--   slot > 5 + seviye*8 => KILITLI.
local HOTBAR_SLOTS = 5     -- makro slotlari (1-5) her seviyede aciktir
local SLOTS_PER_LEVEL = 8  -- her seviye acilan grid slotu sayisi

-- citizenid -> level (bellek onbellegi)
local levelCache = {}

--- Tablo (yoksa olustur). oxmysql hazir (server_scripts'te @oxmysql yuklu).
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `bitirim_backpack` (
            `citizenid` VARCHAR(64) NOT NULL,
            `level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
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

--- Seviyeyi 0..MAX_LEVEL araligina kirp.
local function clampLevel(n)
    n = tonumber(n) or 0
    if n < 0 then return 0 end
    if n > MAX_LEVEL then return MAX_LEVEL end
    return math.floor(n)
end

--- targetSrc oyuncusunun canta seviyesine gore `slot` KILITLI mi?
--- ONEMLI: FAIL-OPEN. Seviyeyi kesin bilemedigimiz (oyuncu cozulemedi / seviye
--- henuz onbellege alinmadi / slot gecersiz) her durumda `false` doner ki mesru
--- item hareketi ASLA kesilmesin. Yalniz seviye kesin biliniyorken reddeder.
--- Not: DB sorgusu YAPMAZ — sadece onbellege bakar (her swap'ta calisir).
local function isSlotLockedForSource(targetSrc, slot)
    slot = tonumber(slot)
    if not slot then return false end

    local cid = citizenidOf(targetSrc)
    if not cid then return false end          -- oyuncu cozulemedi -> engelleme yok

    local level = levelCache[cid]
    if level == nil then return false end     -- seviye henuz yuklenmedi -> engelleme yok

    return slot > HOTBAR_SLOTS + level * SLOTS_PER_LEVEL
end

--- Seviyeye gore gercek agirlik sinirini uygula + client'e seviyeyi bildir.
local function applyLevel(source, level)
    level = clampLevel(level)

    -- Gercek agirlik siniri (gram). pcall: envanter henuz hazir degilse patlamasin.
    pcall(function()
        Inventory.SetMaxWeight(source, (CAP_KG[level] or 10) * 1000)
    end)

    -- KULLANILABILIR slot ust siniri: 5 makro + seviye*8 grid. Otomatik yerlestirme
    -- (AddItem/give/kraft/pickup) bu sinirin ustune (kilitli slota) item koymaz.
    -- inv.slots 45 kalir (client gorseli); yalniz bu alan sinirlar. Bkz. core usableSlots().
    pcall(function()
        local inv = Inventory(source)
        if inv then
            inv.bitirimUsableSlots = HOTBAR_SLOTS + clampLevel(level) * SLOTS_PER_LEVEL
        end
    end)

    -- Client: NUI'ye setBagLevel gitsin (renk + kilitli slotlar).
    TriggerClientEvent('bitirim:client:bagLevel', source, level)
end

--- Karakterin seviyesini DB'den yukle (onbellege al).
local function loadLevel(source)
    local cid = citizenidOf(source)
    if not cid then return 0 end

    if levelCache[cid] ~= nil then return levelCache[cid] end

    local row = MySQL.single.await('SELECT `level` FROM `bitirim_backpack` WHERE `citizenid` = ?', { cid })
    local level = clampLevel(row and row.level or 0)
    levelCache[cid] = level
    return level
end

--- Seviyeyi ayarla (kalici) + uygula. Market/kraft/admin buradan cagirir.
--- @return boolean success
local function setLevel(source, level)
    local cid = citizenidOf(source)
    if not cid then return false end

    level = clampLevel(level)
    levelCache[cid] = level

    MySQL.query.await(
        'INSERT INTO `bitirim_backpack` (`citizenid`, `level`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `level` = ?',
        { cid, level, level }
    )

    applyLevel(source, level)
    return true
end

exports('BitirimGetBagLevel', function(source) return loadLevel(source) end)
exports('BitirimSetBagLevel', function(source, level) return setLevel(source, level) end)

--- Oyuncu envanteri hazir oldugunda (ox ile ayni state bag) seviyeyi uygula.
--- ox'un setupPlayer'i once calissin diye kisa bir gecikme.
AddStateBagChangeHandler('loadInventory', nil, function(bagName, _, value)
    if not value then return end
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end

    CreateThread(function()
        Wait(1500) -- ox envanteri kursun
        applyLevel(src, loadLevel(src))
    end)
end)

--- Client envanteri actiginda seviyeyi ister (relog/timing emniyeti).
lib.callback.register('bitirim:server:getBagLevel', function(source)
    local level = loadLevel(source)
    applyLevel(source, level)
    return level
end)

--- Onbellek temizligi.
AddEventHandler('qbx_core:server:playerLoggedOut', function(source)
    local cid = citizenidOf(source)
    if cid then levelCache[cid] = nil end
end)

--- Admin/test: /setcanta [id] [level]  (0-5). ACE: bitirim.admin (konsol serbest).
RegisterCommand('setcanta', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'bitirim.admin') then
        return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Yetkisiz.' })
    end

    local targetId = tonumber(args[1])
    local level = clampLevel(args[2])

    -- id verilmezse ve komut oyuncudan geliyorsa kendine uygula.
    if not targetId and source ~= 0 then targetId = source end
    if not targetId then return print('kullanim: setcanta <id> <0-5>') end

    if setLevel(targetId, level) then
        local msg = ('Canta seviyesi ayarlandi: oyuncu %d -> %d'):format(targetId, level)
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = msg }) end
    else
        local msg = ('Oyuncu %s bulunamadi/yuklenmedi.'):format(tostring(targetId))
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = msg }) end
    end
end, false)

--[[
    KILITLI SLOT SUNUCU KORUMASI (swapItems hook)
    ---------------------------------------------
    Oyuncunun KENDI envanterine, canta seviyesiyle kilitli bir slota item
    konmasini (tasi/degistir/yigin) sunucuda reddeder. UI zaten engelliyor;
    bu sunucu-otoriter emniyet katmani.

    Kayit yontemi: registerHook export'u `ref.resource = ...` yaptigi icin ref'in
    INDEKSLENEBILIR olmasi gerekir. Cross-resource'ta FiveM fonksiyonu funcref
    tablosuna sarar; ama ox ICINDEN (self-export) ham fonksiyon sarilmayabilir ->
    indeksleme patlar. Bu yuzden ref olarak metatable'li CALLABLE TABLE veriyoruz
    (__call). Boylece hem `hook.__call` kontrolu gecer hem alan atamalari calisir.
    __call imzasi: (self, payload).

    Kapsam: yalnizca `toType == 'player'` (oyuncunun kendi envanteri). 'give'
    payload'inda toSlot yok -> slot bilinemez -> izin verilir (ayri is: Ver bari).
    Kaplar/araclar (stash/trunk/glovebox/drop) kilit kapsami disinda.
]]
local lockHook = setmetatable({}, {
    __call = function(_, payload)
        -- Sadece oyuncunun kendi envanterine tasima ile ilgileniyoruz.
        if payload.toType ~= 'player' then return end

        -- Player envanterinde inv.id == server id. Hedef oyuncunun seviyesini
        -- bu id ile cozeriz. ('give' disinda bu, kaynagin kendi id'sidir.)
        local targetSrc = payload.toInventory
        if targetSrc == nil then return end

        -- Hedef slot numarasi: dolu slotta item tablosu (.slot), bos slotta ham
        -- numara. 'give' payload'inda toSlot yok -> nil -> asagida izin verilir.
        local slot = type(payload.toSlot) == 'table' and payload.toSlot.slot or payload.toSlot

        if isSlotLockedForSource(targetSrc, slot) then
            return false -- kilitli slot: swap'i reddet
        end
    end
})

CreateThread(function()
    local ok, err = pcall(function()
        exports.ox_inventory:registerHook('swapItems', lockHook)
    end)

    if not ok then
        print(('[bitirim] swapItems kilit hook kaydedilemedi: %s'):format(tostring(err)))
    end
end)
