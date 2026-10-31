fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-animations'
version '3.0.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/versionchecker.lua',
}

dependencies {
    'rsg-core',
    'oxmysql',
}

files {
    'ui/**/*',
    'locales/*.json',
}

ui_page 'ui/index.html'

lua54 'yes'
