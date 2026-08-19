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
local equipmentReceived = false -- sunucudan ilk ekipman payload'i geldi mi (spawn akisi)

-- Basit log yardimcisi (Utils namespace'i yok, lib.print/print kullan)
local Utils = {
    log = function(...)
        print('[bitirim_equipment]', ...)
    end
}

-- Global drawable index -> sleevesOnly (fallback when collection natives unavailable)
-- Fill via /bc_arms_debug: [global_drawable] = true/false
local globalSleevesOnly = {
    -- Male global drawable indices (mp_m_freemode_01) - fill via /bc_arms_debug
    -- [14] = false,  -- gloves 14 = govde var
    -- [15] = true,   -- gloves 15 = sleevesOnly
}

--- Bos bir component slotunun taban (ciplak) gorunumu. Tabloda yoksa 0 =
--- "hicbir sey yok" (maske / zincir / yelek boyle davranir).
local function underwearOf(slot)
    local u = clothing.underwear and clothing.underwear[slot]
    if type(u) ~= 'table' then return 0, 0 end
    return u.drawable or 0, u.texture or 0
end

---------------------------------------------------------------------------
-- UST GIYSI <-> KOL ESLESMESI  ("kiyafette ten gorunuyor")
--
-- GTA'da ust giysi (component 11) tek basina yetmez: her ustun birlikte
-- calistigi bir kol degeri (component 3) vardir. Kol uyusmazsa omuzda/kolda
-- ten gorunur, bazen omuz tamamen kaybolur. Bu bir doku hatasi degil, eksik
-- eslestirme.
--
-- Oyunun kendi verisi bunu biliyor: "zorunlu bilesenler" (forced components)
-- bir parcayla birlikte gelmesi gerekenleri soyler. Native yoksa hicbir sey
-- yapilmaz — davranis eskisi gibi kalir.
--
-- Oyuncunun KOL slotu doluysa (kendi sectigi bir parca) dokunulmaz.
---------------------------------------------------------------------------
local ARMS_COMPONENT = 3
local TOPS_COMPONENT = 11

local function forcedArmsFor(model, topDrawable)
    if clothing.autoMatchArms == false then return nil end
    if not GetNumForcedComponents or not GetForcedComponent then return nil end

    local ok, count = pcall(GetNumForcedComponents, model, TOPS_COMPONENT, topDrawable, 0)
    if not ok or type(count) ~= 'number' or count <= 0 then return nil end

    for i = 0, count - 1 do
        -- Native uc deger dondurur: nameHash, enumValue (drawable), componentType
        local ok2, _, enumValue, componentType = pcall(GetForcedComponent, model, TOPS_COMPONENT, topDrawable, i)
        if ok2 and componentType == ARMS_COMPONENT and type(enumValue) == 'number' and enumValue >= 0 then
            return enumValue
        end
    end

    return nil
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

    -- UST GIYSI -> KOL. Kol slotu bossa kol underwear'da (CIPLAK) kalir; bu
    -- ustsuzken dogru ama bir ust giyilince kiyafet kolsuz/eksik gorunur.
    -- Ust varsa kol icin uc kaynak SIRAYLA denenir:
    --   1) Parcanin KENDI kaydettigi kol (wear.arms) — magazada denenirken
    --      secilen deger. GTA bu eslesmeyi vermedigi icin asil kaynak budur.
    --   2) Oyunun "zorunlu bilesen" verisi — freemode kiyafetlerinde cogunlukla
    --      bos, yine de bedava bir ihtimal.
    --   3) data/bitirim_clothing.lua -> defaultArms (giyinik varsayilan).
    -- Oyuncu KOL slotuna kendi bir parca taktiysa hicbirine bakilmaz.
    -- EK: sleevesOnly (govde icermeyen kol) kontrolu — bu tipleri uygulama.

    --- Kol drawable'in image key'ini uretir (collection native'lere dayali).
    --- Ayni mantik bitirim_clothing/client/appearance.lua -> Appearance.getImageKey
    local function getArmsImageKey(ped, drawable, isFemale)
        if not GetPedCollectionNameFromDrawable or not GetPedCollectionLocalIndexFromDrawable then
            return nil
        end
        if not drawable or drawable < 0 then return nil end

        local gender = isFemale and 'f' or 'm'
        local collection = GetPedCollectionNameFromDrawable(ped, ARMS_COMPONENT, drawable)
        local localIndex = GetPedCollectionLocalIndexFromDrawable(ped, ARMS_COMPONENT, drawable)

        if not collection or not localIndex then return nil end

        -- Base collection icin bos string doner; dosya adinda 'base' kullanilir.
        if collection == '' then collection = 'base' end

        return ('%s_c%d_%s_%d'):format(gender, ARMS_COMPONENT, collection, tonumber(localIndex) or 0)
    end

    --- Bu kol parcasi govde icermiyor mu? (sleevesOnly)
    local function isSleevesOnly(ped, drawable, isFemale)
        -- 1. Collection-based key dene (tercihli)
        local key = getArmsImageKey(ped, drawable, isFemale)
        if key then
            local result = clothing.sleevesOnly and clothing.sleevesOnly[key] == true
            -- Debug log
            if result then
                Utils.log(('isSleevesOnly: %s -> TRUE (collection key)'):format(key))
            end
            return result
        end

        -- 2. Fallback: global drawable index lookup
        if globalSleevesOnly[drawable] ~= nil then
            Utils.log(('isSleevesOnly: global index %d -> %s'):format(drawable, tostring(globalSleevesOnly[drawable])))
            return globalSleevesOnly[drawable]
        end

        -- 3. Bulunamadi: false don (engelleme, guvenli tarafta kal)
        return false
    end

    local function applyGlovesSlot()
        if not isFreemode then return end
        if currentEquip['gloves'] then return end -- Oyuncu kendi eldiven takmis, dokunma

        local top = currentEquip['jacket'] or currentEquip['tshirt']
        if not top then return end

        local jacket = currentEquip['jacket']
        local wear = jacket and (jacket.wear or (jacket.item and clothing.items[jacket.item]))
        local armsDrawable, armsTexture

        if type(wear) == 'table' and type(wear.arms) == 'table' then
            armsDrawable = tonumber(wear.arms.drawable)
            armsTexture  = tonumber(wear.arms.texture) or 0
        end

        if not armsDrawable and wear then
            local topDrawable = resolveWear(wear, isFemale)
            if topDrawable then
                armsDrawable = forcedArmsFor(model, topDrawable)
                armsTexture  = 0
            end
        end

        if not armsDrawable and type(clothing.defaultArms) == 'table' then
            local def = clothing.defaultArms[isFemale and 'female' or 'male']
            if type(def) == 'table' then
                local d = tonumber(def.drawable)
                if d and d >= 0 then
                    armsDrawable = d
                    armsTexture  = tonumber(def.texture) or 0
                end
            end
        end

        -- sleevesOnly kontrolu: govde icermeyen kol uygulanmasin
        if armsDrawable and isSleevesOnly(ped, armsDrawable, isFemale) then
            armsDrawable = nil
        end

        -- Eger ilk secim sleevesOnly ise, defaultArms'i dene (eger sleevesOnly degilse)
        if not armsDrawable and type(clothing.defaultArms) == 'table' then
            local def = clothing.defaultArms[isFemale and 'female' or 'male']
            if type(def) == 'table' then
                local d = tonumber(def.drawable)
                if d and d >= 0 and not isSleevesOnly(ped, d, isFemale) then
                    armsDrawable = d
                    armsTexture  = tonumber(def.texture) or 0
                end
            end
        end

        -- Son fallback: underwear (ciplak kol)
        if not armsDrawable then
            local ud, ut = underwearOf('gloves')
            if IsPedComponentVariationValid(ped, ARMS_COMPONENT, ud, ut) then
                armsDrawable, armsTexture = ud, ut
            end
        end

        if armsDrawable and IsPedComponentVariationValid(ped, ARMS_COMPONENT, armsDrawable, armsTexture) then
            SetPedComponentVariation(ped, ARMS_COMPONENT, armsDrawable, armsTexture, 0)
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

    -- Gloves slot icin ust giyisi varsa kol eslestir (sleevesOnly kontrol dahil)
    applyGlovesSlot()
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
    Utils.log(('bitirim:client:equipment alindi: %s slot'):format(payload and 'dolu' or 'bos'))
    if payload then
        for slot, data in pairs(payload) do
            Utils.log(('  slot=%s item=%s wear=%s'):format(slot, data.item or '?', data.wear and 'var' or 'yok'))
        end
    end
    currentEquip = type(payload) == 'table' and payload or {}
    equipmentReceived = true
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

--[[
    Spawn/relog: illenium temel skini kurduktan SONRA ekipmani uygula.

    ESKI HALI TEK SEFERDE 2 SN BEKLIYORDU ve oyuncu o sure boyunca illenium'un
    kaydettigi kiyafetle (pantolon + tisort) goruluyordu; ekipman ancak ondan
    sonra biniyordu. Iki degisiklik:

      1) Ekipman SUNUCUDAN HEMEN istenir (server'in kendi gecikmeli push'unu
         beklemeden) — veri erken gelir.
      2) Uygulama kisa araliklarla ~4 sn TEKRARLANIR. illenium skini hangi
         karede kurarsa kursun bir sonraki tekrarda uzerine yaziyoruz, yani
         yanlis gorunum en fazla bir-iki kare kaliyor.

    Veri gelmeden UYGULAMIYORUZ: aksi halde bu sefer de ciplak bir flash olurdu.
]]
local function onFreshSpawn()
    CreateThread(function()
        -- Ekipmani sunucudan hemen iste (server'in 1.5 sn'lik push'unu bekleme).
        CreateThread(function()
            pcall(function() lib.callback.await('bitirim:server:getEquipment', false) end)
        end)

        -- Veri gelene kadar bekle (en fazla 5 sn), sonra ~4 sn boyunca tekrarla.
        local waited = 0
        while not equipmentReceived and waited < 5000 do
            Wait(100)
            waited = waited + 100
        end

        local elapsed = 0
        while elapsed <= 4000 do
            applyEquip()
            Wait(250)
            elapsed = elapsed + 250
        end

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

-- DEBUG: Su anki kol drawable icin sleevesOnly kontrol sonucunu goster
RegisterCommand('bc_arms_debug', function()
    local ped = PlayerPedId()
    local isFemale = GetEntityModel(ped) == `mp_f_freemode_01`
    local gender = isFemale and 'f' or 'm'
    local armsDrawable = GetPedDrawableVariation(ped, ARMS_COMPONENT)
    local armsTexture = GetPedTextureVariation(ped, ARMS_COMPONENT)

    print(('^3[bc_arms_debug] cinsiyet=%s kol(3) drawable=%d texture=%d^7'):format(gender, armsDrawable, armsTexture))

    -- Collection native var mi?
    local hasColl = GetPedCollectionNameFromDrawable and GetPedCollectionLocalIndexFromDrawable
    print(('^3[bc_arms_debug] Collection natives: %s^7'):format(hasColl and 'VAR' or 'YOK'))

    if hasColl then
        local collection = GetPedCollectionNameFromDrawable(ped, ARMS_COMPONENT, armsDrawable)
        local localIndex = GetPedCollectionLocalIndexFromDrawable(ped, ARMS_COMPONENT, armsDrawable)
        print(('^3[bc_arms_debug] collection="%s" localIndex=%s^7'):format(tostring(collection), tostring(localIndex)))

        local key = nil
        if collection and localIndex then
            if collection == '' then collection = 'base' end
            key = ('%s_c%d_%s_%d'):format(gender, ARMS_COMPONENT, collection, tonumber(localIndex) or 0)
            print(('^3[bc_arms_debug] KEY: %s^7'):format(key))

            if clothing.sleevesOnly and clothing.sleevesOnly[key] then
                print('^3[bc_arms_debug] sleevesOnly: TRUE (bu kol govde ICERMIYOR)^7')
            else
                print('^3[bc_arms_debug] sleevesOnly: FALSE (bu kol govde ICERIYOR)^7')
            end
        end
    end

    -- Global fallback
    if globalSleevesOnly[armsDrawable] ~= nil then
        print(('^3[bc_arms_debug] Global fallback: %s^7'):format(tostring(globalSleevesOnly[armsDrawable])))
    end

    lib.notify({ type = 'inform', description = ('bc_arms_debug: kol drawable=%d'):format(armsDrawable) })
end, false)

-- DEBUG: currentEquip icerigini F8'e yaz
RegisterCommand('bc_equip_debug', function()
    print('^3[bc_equip_debug] currentEquip:^7')
    if not currentEquip or next(currentEquip) == nil then
        print('  (bos)')
        return
    end
    for slot, data in pairs(currentEquip) do
        local item = data.item or '?'
        local label = data.label or '?'
        local wear = data.wear
        local wearStr = 'yok'
        if wear then
            if wear.slot then
                wearStr = string.format('slot=%s drawable=%s texture=%s', wear.slot, tostring(wear.drawable), tostring(wear.texture))
            elseif wear.male or wear.female then
                wearStr = 'cinsiyete gore'
            else
                wearStr = string.format('drawable=%s texture=%s', tostring(wear.drawable), tostring(wear.texture))
            end
        end
        print(string.format('  %s: item=%s label=%s wear=%s', slot, item, label, wearStr))
    end
end, false)
