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

CreateThread(function()
    local last

    while true do
        local wait = IDLE_INTERVAL

        -- Envanter acikken NUI odakli olur; sadece o zaman gonderiyoruz.
        if IsNuiFocused() then
            wait = SEND_INTERVAL

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
        end

        Wait(wait)
    end
end)
