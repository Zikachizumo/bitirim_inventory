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

--- Bir kiyafet item'inin gorunumunu oyuncunun cinsiyetine gore coz.
--- Duz { drawable, texture } veya { male = {...}, female = {...} } destekler.
--- Donus: drawable, texture (bulunamazsa nil).
local function resolveVariant(itemName, isFemale)
    local map = itemName and clothing.items[itemName]
    if not map then return nil end

    if map.male or map.female then
        local v = (isFemale and map.female) or map.male or map.female
        if type(v) == 'table' then return v.drawable, v.texture end
        return nil
    end

    return map.drawable, map.texture
end

--- Giyili ekipmani ped'e uygula. Giyili slot -> item gorunumu (cinsiyete gore);
--- bos slot -> spawn'da yakalanan temiz base. (drawable 0 gecerlidir; Lua'da 0
--- truthy oldugu icin `or` zincirleri yalniz nil'de base'e duser.)
local function applyEquip()
    local ped = PlayerPedId()
    if not baseCaptured then captureBase(ped) end
    local isFemale = GetEntityModel(ped) == `mp_f_freemode_01`

    for slot, def in pairs(clothing.slots) do
        local e = currentEquip[slot]
        local b = base[slot]
        local ed, et
        if e and e.item then ed, et = resolveVariant(e.item, isFemale) end

        if def.kind == 'component' then
            local d = ed or (b and b.drawable) or 0
            local t = et or (b and b.texture) or 0
            if IsPedComponentVariationValid(ped, def.id, d, t) then
                SetPedComponentVariation(ped, def.id, d, t, 0)
            end
        else -- prop
            if ed then
                SetPedPropIndex(ped, def.id, ed, et or 0, true)
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

--[[
    /kiyafetbak — KATALOG YARDIMCISI.
    Su an giyili tum ekipman slotlarinin GTA degerlerini (component/prop id +
    drawable + texture) ve oyuncunun cinsiyetini F8 konsoluna yazar. Kullanim:
    kiyafet dukkaninda parcayi giy -> /kiyafetbak -> cikan drawable/texture'i
    data/bitirim_clothing.lua'daki items tablosuna gecir.
    NOT: bu komut hicbir seyi degistirmez, sadece OKUR.
]]
RegisterCommand('kiyafetbak', function()
    local ped = PlayerPedId()
    local isFemale = GetEntityModel(ped) == `mp_f_freemode_01`
    local gender = isFemale and 'kadin (female)' or 'erkek (male)'

    print(('^3[bitirim] Su an giyili degerler — cinsiyet: %s^7'):format(gender))
    print('^3  slot      | tip        id | drawable texture^7')
    for slot, def in pairs(clothing.slots) do
        local d, t
        if def.kind == 'component' then
            d, t = GetPedDrawableVariation(ped, def.id), GetPedTextureVariation(ped, def.id)
        else
            d, t = GetPedPropIndex(ped, def.id), GetPedPropTextureIndex(ped, def.id)
        end
        print(('  %-9s | %-9s %2d | drawable=%d texture=%d'):format(slot, def.kind, def.id, d, t))
    end
    print('^3[bitirim] Bu degerleri data/bitirim_clothing.lua > items tablosuna gecir.^7')

    lib.notify({ type = 'inform', description = 'Kiyafet degerleri F8 konsoluna yazildi.' })
end, false)
