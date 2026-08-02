--[[
    Bitirim — karakter panelindeki durum barlari
    -------------------------------------------
    Envanter aciklen CAN / ZIRH / ACLIK / SUSUZLUK degerlerini NUI'ye gonderir.
    Arayuz tarafinda store/playerStatus.ts bunu dinler; veri gelmezse panel
    durum blogunu hic gostermez (uydurma deger gosterilmez).

    Aclik/susuzluk framework'e (qbx_core) bagli oldugu icin pcall ile korunur;
    yoksa sadece can ve zirh gonderilir.
]]

local SEND_INTERVAL = 500 -- ms, yalnizca arayuz acikken
local IDLE_INTERVAL = 1000

--[[ ---------------------------------------------------------------------------
    GECICI TEST — canta seviyesi
    Gercek seviye markette satin alma / kraft ile belirlenecek ve DB'de
    saklanacak (sonraki adim). Su an tasarimi oyunda gormek icin client
    komutu: /cantatest <1-5>. NUI'ye setBagLevel gonderir (renk + kilitli
    slotlar). Backend baglaninca bu komut kaldirilacak.
-------------------------------------------------------------------------------]]
-- Gercek seviye: server 'bitirim:client:bagLevel' ile gonderir (DB'den).
-- Varsayilan 0 (cantasiz). /cantatest sadece GORSEL testtir (sunucuyu degistirmez).
local currentBagLevel = 0
local requestedFromServer = false

RegisterNetEvent('bitirim:client:bagLevel', function(level)
    level = tonumber(level) or 0
    currentBagLevel = level
    if IsNuiFocused() then
        SendNUIMessage({ action = 'setBagLevel', data = level })
    end
end)

-- Sadece gorsel test — gercek seviyeyi/agirligi degistirmez. Gercek icin /setcanta (server).
RegisterCommand('cantatest', function(_, args)
    local lvl = tonumber(args[1])

    if not lvl or lvl < 0 or lvl > 5 then
        return lib.notify({ type = 'error', description = 'Kullanim: /cantatest <0-5> (sadece gorsel test)' })
    end

    currentBagLevel = math.floor(lvl)
    SendNUIMessage({ action = 'setBagLevel', data = currentBagLevel })
    lib.notify({ type = 'inform', description = ('Canta seviyesi (GORSEL test): %d'):format(currentBagLevel) })
end, false)

--- Oyuncu canini 0-100 araligina cevirir (GTA'da 100 = olu, 200 = tam).
local function healthPercent(ped)
    local hp = GetEntityHealth(ped)
    local maxHp = GetEntityMaxHealth(ped)
    local span = maxHp - 100

    if span <= 0 then return 0 end

    local pct = ((hp - 100) / span) * 100

    return math.max(0, math.min(100, pct))
end

--- qbx_core metadata'sindan aclik/susuzluk okur. Yoksa nil doner.
local function survivalStats()
    local ok, data = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)

    if not ok or type(data) ~= 'table' then return nil, nil end

    local metadata = data.metadata

    if type(metadata) ~= 'table' then return nil, nil end

    return tonumber(metadata.hunger), tonumber(metadata.thirst)
end

--- qbx nakit (cash). Nakit artik envanter item'i DEGIL (GrandRP mantigi) ->
--- ust bar bunu qbx'ten okur. Yoksa nil.
local function cashAmount()
    local ok, data = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    if not ok or type(data) ~= 'table' or type(data.money) ~= 'table' then return nil end
    return tonumber(data.money.cash)
end

--- O an kusanili silahin slotunu dondurur (yoksa nil).
--- ox client'inin getCurrentWeapon export'unu kullanir (kendi kaynagimiz).
local function equippedWeaponSlot()
    local ok, weapon = pcall(function()
        return exports[GetCurrentResourceName()]:getCurrentWeapon()
    end)

    if not ok or type(weapon) ~= 'table' then return nil end

    return weapon.slot
end

CreateThread(function()
    local last
    local lastEquipped = false -- 'false' = henuz gonderilmedi (nil'den ayirt icin)
    local lastBagSent
    local lastCash

    while true do
        local wait = IDLE_INTERVAL

        -- Envanter acikken NUI odakli olur; sadece o zaman gonderiyoruz.
        if IsNuiFocused() then
            wait = SEND_INTERVAL

            -- Ilk acilista sunucudan gercek seviyeyi iste (push kacmis olabilir).
            if not requestedFromServer then
                requestedFromServer = true
                CreateThread(function()
                    local lvl = lib.callback.await('bitirim:server:getBagLevel', false)
                    if type(lvl) == 'number' then currentBagLevel = lvl end
                end)
            end

            -- Canta seviyesi — envanter her acildiginda tekrar gonderilir.
            if currentBagLevel ~= lastBagSent then
                lastBagSent = currentBagLevel
                SendNUIMessage({ action = 'setBagLevel', data = currentBagLevel })
            end

            -- Nakit (qbx cash) — artik envanter item'i degil, ust bar bunu gosterir.
            local cash = cashAmount()
            if cash ~= lastCash then
                lastCash = cash
                SendNUIMessage({ action = 'setCash', data = cash or 0 })
            end

            -- Kusanili slot (sag tik menusunde Use/Unequip etiketi icin)
            local equipped = equippedWeaponSlot()

            if equipped ~= lastEquipped then
                lastEquipped = equipped
                SendNUIMessage({ action = 'setEquippedSlot', data = equipped })
            end

            local ped = PlayerPedId()
            local hunger, thirst = survivalStats()

            local payload = {
                health = healthPercent(ped),
                armour = math.max(0, math.min(100, GetPedArmour(ped))),
                hunger = hunger,
                thirst = thirst,
            }

            -- Ayni degerleri tekrar tekrar gondermeyelim.
            local signature = ('%d|%d|%s|%s'):format(
                math.floor(payload.health),
                math.floor(payload.armour),
                tostring(hunger and math.floor(hunger)),
                tostring(thirst and math.floor(thirst))
            )

            if signature ~= last then
                last = signature
                SendNUIMessage({ action = 'setPlayerStatus', data = payload })
            end
        else
            last = nil
            lastEquipped = false
            lastBagSent = nil
        end

        Wait(wait)
    end
end)
