--[[
    Bitirim — EKIPMAN / KIYAFET CLIENT (giyili ekipmani ped'e uygula + panel)
    -------------------------------------------------------------------------
    Server (equipment_server.lua) giyili ekipmani `bitirim:client:equipment`
    ile yollar: payload = { slot = { drawable, texture } }. Bu modul:
      1) Ped'e uygular (GTA native): component -> SetPedComponentVariation,
         prop -> SetPedPropIndex. Giyili OLMAYAN slotlar temel (base) haline
         dondurulur (component) / temizlenir (prop).
      2) NUI'ye `setEquipment` yollar (karakter paneli gosterimi; ileride ayni
         veri 3D onizlemeyi besleyecek — TEK KAYNAK).
      3) Panelden cikarma (unequip) NUI callback'ini karsilar.

    illenium ile uyum: illenium temel skini spawn'da yukler; biz onun USTUNE
    uygulariz ve giyili olmayan slotlari, spawn aninda yakaladigimiz "base"e
    (illenium'un temiz skini) geri dondururuz. Boylece cikarinca oyuncunun
    kendi kiyafeti geri gelir (drawable 0 degil). NOT: oyuncu kiyafet dukkaninda
    (illenium) skinini degistirirse base bayatlar; o durumda relog/spawn'da
    yeniden yakalanir. Slot->GTA hedefi: data/bitirim_clothing.lua.
]]

local clothing = lib.load('data.bitirim_clothing')

local currentEquip = {}      -- slot -> { drawable, texture } (server'dan gelen guncel)
local base = {}              -- slot -> { drawable, texture } (temiz skin — cikarinca donus)
local baseCaptured = false
local requestedOnce = false

--- Temiz ped'ten (illenium skin, ekipman uygulanmadan once) base'i yakala.
local function captureBase(ped)
    base = {}
    for slot, def in pairs(clothing.slots) do
        if def.kind == 'component' then
            base[slot] = {
                drawable = GetPedDrawableVariation(ped, def.id),
                texture = GetPedTextureVariation(ped, def.id),
            }
        else -- prop
            base[slot] = {
                drawable = GetPedPropIndex(ped, def.id),
                texture = GetPedPropTextureIndex(ped, def.id),
            }
        end
    end
    baseCaptured = true
end

--- Giyili ekipmani ped'e uygula. Giyili slot -> item degeri; bos slot -> base.
local function applyEquip()
    local ped = PlayerPedId()
    if not baseCaptured then captureBase(ped) end

    for slot, def in pairs(clothing.slots) do
        local e = currentEquip[slot]
        local b = base[slot]

        if def.kind == 'component' then
            local d = (e and e.drawable) or (b and b.drawable) or 0
            local t = (e and e.texture) or (b and b.texture) or 0
            if IsPedComponentVariationValid(ped, def.id, d, t) then
                SetPedComponentVariation(ped, def.id, d, t, 0)
            end
        else -- prop
            if e then
                SetPedPropIndex(ped, def.id, e.drawable, e.texture, true)
            elseif b and b.drawable and b.drawable >= 0 then
                SetPedPropIndex(ped, def.id, b.drawable, b.texture, true)
            else
                ClearPedProp(ped, def.id)
            end
        end
    end
end

--- NUI'ye giyili ekipmani gonder (panel gosterimi).
local function pushToNui()
    SendNUIMessage({ action = 'setEquipment', data = currentEquip })
end

-- Server giyili ekipmani gonderdi -> uygula + panele yolla.
RegisterNetEvent('bitirim:client:equipment', function(payload)
    currentEquip = type(payload) == 'table' and payload or {}
    applyEquip()
    pushToNui()
end)

-- Panelden cikarma istegi (dolu equip slotuna tik) -> server'a ilet.
RegisterNUICallback('bitirim:unequip', function(data, cb)
    if type(data) == 'table' and type(data.slot) == 'string' then
        TriggerServerEvent('bitirim:server:unequip', data.slot)
    end
    cb(1)
end)

-- Envanter ilk acildiginda guncel ekipmani iste (ilk push kacmis olabilir).
CreateThread(function()
    while true do
        if IsNuiFocused() and not requestedOnce then
            requestedOnce = true
            CreateThread(function()
                pcall(function() lib.callback.await('bitirim:server:getEquipment', false) end)
            end)
        end
        Wait(500)
    end
end)

--- Spawn/relog: temiz skin degisti -> base'i yeniden yakala ve ekipmani
--- illenium yuklemesinden SONRA tekrar uygula (override'i geri al).
local function onFreshSpawn()
    CreateThread(function()
        Wait(2000) -- illenium temel skini kursun
        baseCaptured = false
        applyEquip()
        pushToNui()
    end)
end

AddEventHandler('playerSpawned', onFreshSpawn)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', onFreshSpawn)
RegisterNetEvent('qbx_core:client:playerLoggedIn', onFreshSpawn)
