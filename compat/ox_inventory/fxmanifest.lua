fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox_inventory'
author 'Bitirim'
version '1.0.0'
description 'Uyumluluk koprusu — exports.ox_inventory:* cagrilarini bitirim_inventory e yonlendirir'

--[[
    Bitirim — ox_inventory uyumluluk koprusu
    ---------------------------------------
    Envanterimiz "bitirim_inventory" adiyla calisiyor. Ancak sunucudaki diger
    kaynaklar (qbx_core, marketler, silah scriptleri, is scriptleri...) hala
    "exports.ox_inventory:X(...)" seklinde cagiri yapiyor.

    Bu minik kaynak SADECE bir yonlendiricidir. Icinde envanter mantigi YOKTUR;
    her export cagrisini oldugu gibi bitirim_inventory e devreder.

    ONEMLI — server.cfg sirasi (once hedef, sonra kopru):
        ensure bitirim_inventory
        ensure ox_inventory

    NOT: Event isimleri (ox_inventory:*) fork ta bilerek korundu; eventler
    global string oldugu icin kopruye ihtiyac duymaz, dogrudan calisir.
]]

client_script 'client.lua'
server_script 'server.lua'
