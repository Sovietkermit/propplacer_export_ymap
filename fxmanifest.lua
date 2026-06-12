fx_version 'cerulean'
games { 'gta5' }

author      'Sovietkermit'
name        'sk_kq_ymap_exporter'
description 'Export kq_propplacer DB entries to .ymap.xml format'
version     '1.0.0'

dependencies {
    'oxmysql',
}

server_scripts {
    'server.lua',
}

# -- extension of
# -- https://kuzquality.com/package/6697203