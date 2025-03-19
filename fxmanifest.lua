fx_version   'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

name 'chiliaddb'
author 'JoeSzymkowiczFivem'
version '0.1.0'
license 'CC0 1.0 Universal (CC0 1.0)'
description 'A datastore and syntax wrapper for FiveM KVP'

dependency 'ox_lib'

shared_script '@ox_lib/init.lua'

server_scripts {
	'server/main.lua',
	'server/commands.lua',
}

client_script 'client/main.lua'

file 'init.lua'

ui_page 'web/dist/index.html'

files {
	'web/dist/index.html',
	'web/dist/**/*',
}