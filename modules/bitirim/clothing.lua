--[[
    Bitirim — kiyafet giyme sistemi (karakter paneli slotlari)
    ---------------------------------------------------------
    Bu sunucuda kiyafet bir ITEM'dir (bitirim_clothing magazasindan alinir).
    Bu modul, item ile karakterin uzerindeki gorunum arasindaki TEK baglantiyi
    kurar ve uc seyi garanti eder:

      1) GIYME — item kullanilinca giyilir. Ayni slotta zaten bir parca varsa
         yenisi onun YERINI alir; bir slotta hep tek parca durur, yani
         kiyafetler ust uste binmez.

      2) PANEL — giyili parcalar sol karakter panelindeki ilgili slotlarda
         gorunur (NUI mesaji: setWornClothing). Gorsel item'in kendi
         metadata.imageurl'idir, yani magazadan ne aldiysan panelde onu
         gorursun.

      3) SAHIPLIK — bir parca envanterden cikarsa (at / ver / stash'e koy)
         uzerinden de cikar. Envanterdeki kiyafetlerin TAMAMI giderse karakter
         underwear'a doner.

    ox_inventory'nin KENDI mekanikleri degismez: item kullanimi yine
    ox_inventory:useItem uzerinden gecer (modules/items/client.lua), burasi
    yalnizca "uygula + kaydet + panele bildir" kismidir. Kalici kayit tutulmaz;
    relog sonrasi panel, ped'in uzerindeki gorunum ile envanterdeki item'lar
    eslestirilerek yeniden kurulur (rebuild).
]]

local RESOURCE      = GetCurrentResourceName()
local CLOTHING_ITEM = 'clothing'

---------------------------------------------------------------------------
-- SLOT ESLEMESI
-- GTA component / prop id -> karakter panelindeki slot anahtari.
-- Anahtarlar web/src/components/inventory/CharacterPanel.tsx ile BIREBIR ayni
-- olmali; eslesmeyen bir parca giyilir ama panelde gosterilmez.
---------------------------------------------------------------------------
local COMPONENT_SLOT = {
    [1]  = 'mask',      -- Maske
    [3]  = 'gloves',    -- Kollar / eldiven
    [4]  = 'pants',     -- Pantolon
    [6]  = 'shoes',     -- Ayakkabi
    [7]  = 'necklace',  -- Zincir / kolye
    [8]  = 'tshirt',    -- Tisort (alt katman)
    [9]  = 'armour',    -- Yelek
    [11] = 'jacket',    -- Ust / ceket
}

local PROP_SLOT = {
    [0] = 'hat',        -- Sapka
    [1] = 'glasses',    -- Gozluk
    [2] = 'ears',       -- Kupe / kulaklik
    [6] = 'watch',      -- Saat
    [7] = 'bracelet',   -- Bileklik
}

---------------------------------------------------------------------------
-- UNDERWEAR TABANI
-- Kaynak: illenium-appearance Config.InitialPlayerClothes (Male=Female ayni).
-- bitirim_clothing/config/config.lua -> Config.Underwear ile SENKRON TUTULMALI.
-- Burada olmayan component'lerde "yok" degeri 0'dir (maske, zincir, yelek).
---------------------------------------------------------------------------
local UNDERWEAR = {
    [3]  = 15,  -- kollar — ciplak ust
    [4]  = 21,  -- pantolon — boxer
    [6]  = 0,   -- ayakkabi — ciplak ayak
    [8]  = 15,  -- tisort — yok
    [11] = 15,  -- ust — yok
}

local function floorDrawable(component)
    return UNDERWEAR[component] or 0
end

---------------------------------------------------------------------------
-- DURUM
-- worn[slotKey] = { signature, component|prop, drawable, texture, image, label, invSlot }
-- Tek kaynak burasi: hem panel hem "uzerinden cikar" mantigi bunu okur.
---------------------------------------------------------------------------
local worn = {}

local seenInventory     = false  -- ilk envanter push'u geldi mi (giris)
local lastClothingCount = 0      -- envanterdeki kiyafet item sayisi (son bilinen)

--- Bir parcanin kimligi: ayni component/prop + drawable + texture = ayni parca.
--- Envanterde bu imzayla bir item DURDUGU surece parca giyili kalabilir.
local function signatureOf(metadata)
    if type(metadata) ~= 'table' then return nil end

    local drawable = tonumber(metadata.drawable)
    if not drawable then return nil end

    local texture = tonumber(metadata.texture) or 0

    if metadata.prop ~= nil then
        return ('p%s:%d:%d'):format(tostring(metadata.prop), drawable, texture)
    end

    if metadata.component ~= nil then
        return ('c%s:%d:%d'):format(tostring(metadata.component), drawable, texture)
    end

    return nil
end

--- Parcanin oturacagi slot anahtari. Panelde karsiligi olmayan bir component/
--- prop icin de kararli bir anahtar uretilir ('c5', 'p3' gibi) — boylece giyme/
--- cikarma mantigi her parca icin ayni sekilde calisir, sadece panelde gorunmez.
local function slotKeyOf(metadata)
    if metadata.prop ~= nil then
        local prop = tonumber(metadata.prop)
        if not prop then return nil end
        return PROP_SLOT[prop] or ('p%d'):format(prop)
    end

    local component = tonumber(metadata.component)
    if not component then return nil end
    return COMPONENT_SLOT[component] or ('c%d'):format(component)
end

---------------------------------------------------------------------------
-- ARAYUZ
---------------------------------------------------------------------------
--- Giyili parcalari karakter paneline gonderir. Lua bos tabloyu JSON dizisi
--- olarak serilestirir; arayuz tarafi bunu bos nesneye cevirir (store/clothing.ts).
local function pushToUi()
    local payload = {}

    for key, entry in pairs(worn) do
        payload[key] = {
            image    = entry.image,
            label    = entry.label,
            drawable = entry.drawable,
            texture  = entry.texture,
            slot     = entry.invSlot,
        }
    end

    SendNUIMessage({ action = 'setWornClothing', data = payload })
end

---------------------------------------------------------------------------
-- PED UZERINDE UYGULA / KALDIR
---------------------------------------------------------------------------
local function applyMetadata(metadata)
    local ped      = PlayerPedId()
    local drawable = tonumber(metadata.drawable)
    local texture  = tonumber(metadata.texture) or 0

    if metadata.prop ~= nil then
        SetPedPropIndex(ped, tonumber(metadata.prop), drawable, texture, false)
    else
        SetPedComponentVariation(ped, tonumber(metadata.component), drawable, texture, 0)
    end
end

--- Slotu bosaltir: component underwear tabanina duser, prop tamamen kaldirilir.
local function clearSlot(key)
    local entry = worn[key]
    if not entry then return false end

    local ped = PlayerPedId()

    if entry.prop ~= nil then
        ClearPedProp(ped, entry.prop)
    else
        SetPedComponentVariation(ped, entry.component, floorDrawable(entry.component), 0, 0)
    end

    worn[key] = nil
    return true
end

--- Yonetilen TUM slotlari underwear tabanina indirir. "Cantadaki kiyafetlerin
--- hepsi gitti" durumunda cagrilir: karakter uzerinde yalnizca underwear kalir.
local function stripToUnderwear()
    local ped = PlayerPedId()

    for component in pairs(COMPONENT_SLOT) do
        SetPedComponentVariation(ped, component, floorDrawable(component), 0, 0)
    end

    for prop in pairs(PROP_SLOT) do
        ClearPedProp(ped, prop)
    end

    worn = {}
    pushToUi()
end

---------------------------------------------------------------------------
-- ENVANTER OKUMA
---------------------------------------------------------------------------
--- Oyuncunun envanterindeki kiyafet item'lari: imza -> envanter slotu.
--- Envanter okunamazsa nil doner (bu durumda HICBIR sey cikarilmaz).
local function ownedClothing()
    local ok, items = pcall(function()
        return exports[RESOURCE]:GetPlayerItems()
    end)

    if not ok or type(items) ~= 'table' then return nil, 0 end

    local owned, count = {}, 0

    for _, item in pairs(items) do
        if type(item) == 'table' and item.name == CLOTHING_ITEM then
            count = count + 1

            local signature = signatureOf(item.metadata)
            if signature and not owned[signature] then
                owned[signature] = item
            end
        end
    end

    return owned, count
end

---------------------------------------------------------------------------
-- GIY / CIKAR  (item kullanimi buraya duser)
---------------------------------------------------------------------------
--- Kiyafet item'i kullanildiginda cagrilir (modules/items/client.lua).
--- Ayni parca zaten giyiliyse cikarir, degilse giyer ve o slottaki eski
--- parcanin YERINI alir.
local function toggleClothing(slotData)
    local metadata = type(slotData) == 'table' and slotData.metadata

    if type(metadata) ~= 'table' then return false end

    local signature = signatureOf(metadata)
    local key       = signature and slotKeyOf(metadata)

    if not key then return false end

    -- Ayni parca tekrar kullanildi -> uzerinden cikar.
    if worn[key] and worn[key].signature == signature then
        clearSlot(key)
        pushToUi()
        return true
    end

    -- Yeni parca: slotta ne varsa onun yerini alir (tek slot = tek parca).
    applyMetadata(metadata)

    worn[key] = {
        signature = signature,
        component = metadata.component and tonumber(metadata.component) or nil,
        prop      = metadata.prop and tonumber(metadata.prop) or nil,
        drawable  = tonumber(metadata.drawable),
        texture   = tonumber(metadata.texture) or 0,
        image     = metadata.imageurl,
        label     = metadata.label,
        invSlot   = slotData.slot,
    }

    pushToUi()
    return true
end

exports('bitirimToggleClothing', toggleClothing)

---------------------------------------------------------------------------
-- ENVANTERLE ESITLEME
---------------------------------------------------------------------------
--- Giyili parcalarin hepsi hala envanterde mi? Olmayan varsa uzerinden cikar.
--- Bir sey degistiyse true doner.
local function validateWorn(owned)
    if not owned then return false end

    local changed = false

    for key, entry in pairs(worn) do
        local item = owned[entry.signature]

        if not item then
            clearSlot(key)
            changed = true
        elseif item.slot ~= entry.invSlot then
            -- Item baska slota tasinmis: giyili kalir, yalnizca referans guncellenir.
            entry.invSlot = item.slot
            changed = true
        end
    end

    return changed
end

--- Paneli ped'in MEVCUT gorunumunden yeniden kurar: envanterdeki bir kiyafet
--- item'i, ped'in uzerinde birebir duruyorsa o slot "giyili" sayilir.
--- Kalici kayit tutmadan relog sonrasi paneli doldurmayi saglar. Underwear
--- tabanindaki degerler giyim SAYILMAZ (ciplak gorunum item'a baglanmasin).
---
--- Yalnizca BOS slotlari doldurur, hicbir zaman uzerine yazmaz — bu yuzden her
--- envanter guncellemesinde cagrilabilir (girise illenium'un gorunumu gec
--- uygularsa panel bir sonraki guncellemede kendini toparlar).
--- Bir sey eklendiyse true doner.
local function rebuildFromPed(owned)
    if not owned then return false end

    local ped     = PlayerPedId()
    local changed = false

    for signature, item in pairs(owned) do
        local metadata = item.metadata
        local key      = slotKeyOf(metadata)

        if key and not worn[key] then
            local drawable = tonumber(metadata.drawable)
            local texture  = tonumber(metadata.texture) or 0
            local matches, isFloor

            if metadata.prop ~= nil then
                local prop = tonumber(metadata.prop)
                matches = GetPedPropIndex(ped, prop) == drawable
                      and GetPedPropTextureIndex(ped, prop) == texture
                isFloor = drawable < 0
            else
                local component = tonumber(metadata.component)
                matches = GetPedDrawableVariation(ped, component) == drawable
                      and GetPedTextureVariation(ped, component) == texture
                isFloor = drawable == floorDrawable(component) and texture == 0
            end

            if matches and not isFloor then
                worn[key] = {
                    signature = signature,
                    component = metadata.component and tonumber(metadata.component) or nil,
                    prop      = metadata.prop and tonumber(metadata.prop) or nil,
                    drawable  = drawable,
                    texture   = texture,
                    image     = metadata.imageurl,
                    label     = metadata.label,
                    invSlot   = item.slot,
                }
                changed = true
            end
        end
    end

    return changed
end

--- Envanter her degistiginde (al / ver / at / tasi) calisir.
AddEventHandler('ox_inventory:updateInventory', function()
    local owned, count = ownedClothing()
    if not owned then return end

    -- Girise ait ilk push: hicbir sey cikarilmaz, yalnizca panel kurulur.
    if not seenInventory then
        seenInventory     = true
        lastClothingCount = count
        rebuildFromPed(owned)
        pushToUi()
        return
    end

    local changed = validateWorn(owned)

    -- Cantadaki kiyafetlerin HEPSI cikarildi -> karakterde yalnizca underwear
    -- kalir (yalnizca "vardi, artik yok" gecisinde; hic kiyafeti olmayan bir
    -- oyuncu girise soyulmaz). Bu, oyuncunun karakter olusturucudan gelen
    -- kiyafetlerini de temizler: bu sunucuda giyilen her sey bir item'dir.
    if count == 0 and lastClothingCount > 0 then
        stripToUnderwear()
        changed = false -- stripToUnderwear kendi push'unu yapti
    else
        changed = rebuildFromPed(owned) or changed
    end

    if changed then pushToUi() end

    lastClothingCount = count
end)

---------------------------------------------------------------------------
-- ARAYUZDEN CIKARMA — karakter panelindeki dolu slota tiklayinca
---------------------------------------------------------------------------
--- Envanter her acildiginda arayuz paneli tazeler. Lua tarafi dogruluk kaynagi
--- oldugu icin NUI yeniden yuklense de (resource restart) panel bos kalmaz.
RegisterNUICallback('bitirimRequestWornClothing', function(_, cb)
    pushToUi()
    cb(1)
end)

RegisterNUICallback('bitirimUnequipClothing', function(data, cb)
    local key = type(data) == 'table' and data.key

    if type(key) == 'string' and worn[key] then
        clearSlot(key)
        pushToUi()
    end

    cb(1)
end)

---------------------------------------------------------------------------
-- ISTEGE BAGLI YARDIMCI — baska kaynaklar icin
---------------------------------------------------------------------------
exports('bitirimGetWornClothing', function() return worn end)
exports('bitirimStripToUnderwear', stripToUnderwear)
