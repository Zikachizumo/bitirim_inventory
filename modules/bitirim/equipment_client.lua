--[[
    Bitirim — EKIPMAN / KIYAFET CLIENT (giyili ekipmani ped'e uygula + panel)
    -------------------------------------------------------------------------
    Server (equipment_server.lua) giyili ekipmani `bitirim:client:equipment`
    ile yollar: payload = { slot = { drawable, texture } }. Bu modul:
      1) Ped'e uygular (GTA native): component -> SetPedComponentVariation,
         prop -> SetPedPropIndex. Giyili OLMAYAN slotlar underwear tabanina
         indirilir (component) / temizlenir (prop).
      2) NUI'ye `setEquipment` yollar (karakter paneli gosterimi; ileride ayni
         veri 3D onizlemeyi besleyecek — TEK KAYNAK).
      3) Panelden cikarma (unequip) NUI callback'ini karsilar.

    illenium ile uyum: illenium temel skini (yuz/sac/vucut) spawn'da yukler; biz
    onun USTUNE yalnizca KIYAFET slotlarini uygulariz.

    BOS SLOT = CIPLAK. Bu sunucuda giyilen her sey bir item'dir, o yuzden bos bir
    slot illenium'un kaydettigi kiyafete DEGIL, underwear tabanina doner
    (data/bitirim_clothing.lua -> underwear). Boylece oyuncu tum kiyafetlerini
    cikardiginda karakterde yalnizca ic camasiri kalir; sahip olmadigi bir kiyafet
    uzerinde asla gorunmez. Prop slotlari bosaldiginda tamamen temizlenir.
    Slot->GTA hedefi ve underwear tablosu: data/bitirim_clothing.lua.
]]

local clothing = lib.load('data.bitirim_clothing')

local currentEquip = {}      -- slot -> { drawable, texture } (server'dan gelen guncel)
local requestedOnce = false
local lastArmour = nil       -- son uygulanan zirh degeri; SADECE armour slotu degisince yenilenir

--- Bos bir component slotunun taban (ciplak) gorunumu. Tabloda yoksa 0 =
--- "hicbir sey yok" (maske / zincir / yelek boyle davranir).
local function underwearOf(slot)
    local u = clothing.underwear and clothing.underwear[slot]
    if type(u) ~= 'table' then return 0, 0 end
    return u.drawable or 0, u.texture or 0
end

--- Bir `wear` gorunum tablosunu oyuncunun cinsiyetine gore coz.
--- wear: { drawable, texture } veya { male = {...}, female = {...} }.
--- Donus: drawable, texture (bulunamazsa nil).
local function resolveWear(wear, isFemale)
    if type(wear) ~= 'table' then return nil end

    if wear.male or wear.female then
        local v = (isFemale and wear.female) or wear.male or wear.female
        if type(v) == 'table' then return v.drawable, v.texture end
        return nil
    end

    return wear.drawable, wear.texture
end

--- Giyili ekipmani ped'e uygula. Giyili slot -> parca gorunumu (cinsiyete gore);
--- BOS slot -> underwear tabani (component) / tamamen temiz (prop).
--- Gorunum server payload'inda `e.wear`'da gelir; yoksa (eski satir) legacy
--- clothing.items map'inden cozulur.
--- (drawable 0 gecerlidir; Lua'da 0 truthy oldugu icin `or` yalniz nil'de tabana duser.)
local function applyEquip()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isFemale = model == `mp_f_freemode_01`

    -- Underwear tablosu YALNIZCA freemode ped'ler icin anlamlidir (kaynak da o:
    -- illenium'un freemode varsayilanlari). Oyuncu bir is/hikaye skinindeyse bos
    -- slotlara DOKUNULMAZ — yoksa uniformanin parcalarini silerdik.
    local isFreemode = isFemale or model == `mp_m_freemode_01`

    for slot, def in pairs(clothing.slots) do
        local e = currentEquip[slot]
        local ed, et
        if e then
            local wear = e.wear or (e.item and clothing.items[e.item])
            ed, et = resolveWear(wear, isFemale)
        end

        if def.kind == 'component' then
            if ed then
                if IsPedComponentVariationValid(ped, def.id, ed, et or 0) then
                    SetPedComponentVariation(ped, def.id, ed, et or 0, 0)
                end
            elseif isFreemode then
                local ud, ut = underwearOf(slot)
                if IsPedComponentVariationValid(ped, def.id, ud, ut) then
                    SetPedComponentVariation(ped, def.id, ud, ut, 0)
                end
            end
        else -- prop
            if ed then
                SetPedPropIndex(ped, def.id, ed, et or 0, true)
            elseif isFreemode then
                ClearPedProp(ped, def.id)
            end
        end
    end

    -- ZIRH DEGERI (gorsel component 9'a EK). armour slotundaki parca `wear.armour`
    -- tasiyorsa gercek zirhi (SetPedArmour) uygular. SADECE armour slotu DEGISINCE
    -- yazariz -> baska kaynaktan (medkit/harici yelek) gelen zirhi, alakasiz bir
    -- ekipman degisikligi (or. sapka giyme) her applyEquip'i tetiklediginde SILMEYIZ.
    local armourVal = nil
    local ae = currentEquip['armour']
    if ae and type(ae.wear) == 'table' and ae.wear.armour ~= nil then
        armourVal = tonumber(ae.wear.armour)
    end
    if armourVal ~= lastArmour then
        lastArmour = armourVal
        SetPedArmour(ped, armourVal or 0)
    end
end

--- NUI'ye giyili ekipmani gonder (panel gosterimi).
local function pushToNui()
    SendNUIMessage({ action = 'setEquipment', data = currentEquip })
end

--- Legacy named kiyafet item'i -> slot haritasini NUI'ye gonder. apparel item'leri
--- slotu metadata.wear.slot'ta tasir; legacy item'ler (or. 'armour') tasimaz -> panel
--- surukle-giy highlight'i (canEquipHere) icin bu haritaya bakar.
local function pushClothingMap()
    local map = {}
    for name, def in pairs(clothing.items) do map[name] = def.slot end
    SendNUIMessage({ action = 'setClothingMap', data = map })
end

-- Server giyili ekipmani gonderdi -> uygula + panele yolla.
RegisterNetEvent('bitirim:client:equipment', function(payload)
    currentEquip = type(payload) == 'table' and payload or {}
    applyEquip()
    pushToNui()
end)

-- Panelden cikarma istegi (dolu equip slotuna tik / envantere surukle) -> server.
-- data.toSlot: envantere SURUKLENIP birakilan hedef slot (varsa item oraya gider).
RegisterNUICallback('bitirim:unequip', function(data, cb)
    if type(data) == 'table' and type(data.slot) == 'string' then
        TriggerServerEvent('bitirim:server:unequip', data.slot, tonumber(data.toSlot))
    end
    cb(1)
end)

-- HIZLI GIYME (cift-tik / surukle-giy): ox useItem gecikmesini atlar.
RegisterNUICallback('bitirim:equip', function(data, cb)
    if type(data) == 'table' and data.slot then
        TriggerServerEvent('bitirim:server:equipSlot', data.slot)
    end
    cb(1)
end)

--- ZIRH item'i (Bulletproof Vest 'armour') KULLANIMI -> bizim equip sistemimize.
--- data/items.lua 'armour'.client.event = 'bitirim:client:useArmour' ile baglandi;
--- boylece ox'un DAHILI Item('armour') effect'i (sadece SetPedArmour 100; gorsel/panel
--- YOK, item'i tuketir) devre disi kalir. ox use dispatch'i `TriggerEvent(event, data,
--- {name,slot,metadata})` cagirir -> `info.slot` = kullanilan envanter slotu. equipSlot
--- server'da o slottaki 'armour' item'ini armour slotuna equip eder (gorsel yelek
--- component 9 + zirh degeri wear.armour + panelde gozukur). Cikarinca item geri doner.
AddEventHandler('bitirim:client:useArmour', function(_, info)
    if type(info) == 'table' and info.slot then
        TriggerServerEvent('bitirim:server:equipSlot', info.slot)
    end
end)

-- Envanter ilk acildiginda guncel ekipmani iste (ilk push kacmis olabilir).
CreateThread(function()
    while true do
        if IsNuiFocused() and not requestedOnce then
            requestedOnce = true
            pushClothingMap() -- legacy kiyafet -> slot haritasi (surukle-giy highlight)
            CreateThread(function()
                pcall(function() lib.callback.await('bitirim:server:getEquipment', false) end)
            end)
        end
        Wait(500)
    end
end)

--- Spawn/relog: illenium temel skini kurduktan SONRA ekipmani tekrar uygula.
--- Bu ayni zamanda "sahip olmadigin kiyafeti giyemezsin" kuralini girise de
--- tasir: illenium'un kaydettigi kiyafetlerden ekipman slotunda karsiligi
--- olmayanlar underwear'a duser.
local function onFreshSpawn()
    CreateThread(function()
        Wait(2000) -- illenium temel skini kursun
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
