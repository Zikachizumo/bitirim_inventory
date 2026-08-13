fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
--[[
    DIKKAT — 'name' ve 'version' DEGISTIRILMEMELI.

    Bu kaynak Bitirim'in ozel envanteridir ama resource adi 'ox_inventory'
    OLMAK ZORUNDA. 'bitirim_inventory' olarak yeniden adlandirip yerine
    export yonlendiren bir kopru koymayi denedik ve sunucu acilmadi:

      1) ox_lib, 'ox_inventory' adli kaynagin fxmanifest'inden SURUM okur.
         qbx_core >= 2.42.1, ox_fuel >= 2.30.0 sarti koyuyor. Koprunun
         surumu (1.0.0) bu kontrolu gecemedi -> qbx_core sunucuyu kapatti.
      2) qbx_core envanterin DOSYALARINI dogrudan okuyor:
         require '@ox_inventory.data.items'. Bu bir export degil, dosya
         seviyesinde bagimlilik — kopru ile tasinamaz.

    Yani ismi degistirmek mumkun degil. GitHub reposu 'bitirim_inventory'
    olarak kalir; sunucuda dagitilan klasor adi 'ox_inventory' olur.
    Surum de bagimlilik kontrolleri gecsin diye duz '2.47.9' kalmali
    (on-surum eki semver siralamasini bozar).
]]
name 'ox_inventory'
author 'Bitirim (fork of Overextended ox_inventory)'
version '2.47.9'
repository 'https://github.com/Zikachizumo/bitirim_inventory'
description 'Bitirim envanteri — ox_inventory 2.47.9 tabanli fork (Qbox)'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
}

shared_script '@ox_lib/init.lua'

ox_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua',
    -- Bitirim: canta seviyesi backend (kalici seviye + agirlik siniri)
    'modules/bitirim/server.lua',
}

client_scripts {
    'init.lua',
    -- Bitirim: karakter panelindeki durum barlarini besler (bagimsiz calisir)
    'modules/bitirim/client.lua',
    -- Bitirim: kiyafet giyme/cikarma + karakter paneli equip slotlari
    'modules/bitirim/clothing.lua',
}

ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/images/*.png',
    'modules/**/shared.lua',
    'modules/**/client.lua',
    'modules/bridge/**/client.lua',
    'data/*.lua',
}
