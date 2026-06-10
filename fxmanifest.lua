fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lf-grandma'
author 'Lucifer'
description 'Configurable healing & revive NPC ("Grandma") for QBox, QBCore and ESX'
version '2.0.0'
repository 'https://github.com/luci53/lf-grandma'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/creator.lua',
}

server_scripts {
    '@ox_lib/init.lua',
    'server/bridge.lua',
    'server/locations.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
}
