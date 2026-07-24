fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
name 'bitirim_inventory'
author 'Bitirim (fork of Overextended ox_inventory)'
version '2.47.9-bitirim.1'
repository 'https://github.com/Zikachizumo/inventory'
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
    'init.lua'
}

client_script 'init.lua'

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
