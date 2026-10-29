fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

name 'zyrnex_gizmo'
author 'Lucas M., based on object_gizmo by DemiAutomatic'
description '3D gizmo with orbit camera to move and rotate objects'
version '1.0.0'
repository 'https://github.com/lucasm6195/zyrnex_gizmo'

ui_page 'ui/index.html'

client_scripts {
    'config.lua',
    'hud.lua',
    'client.lua'
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/hint.js',
    'web/dist/assets/*.js'
}
