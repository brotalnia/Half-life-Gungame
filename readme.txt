This is gungame plugin for AMX Mod based on the original gungame for CS. Supports both Steam and WON versions of the game. Can be played with any kind of bots, including Jumbot.

Gameplay video: https://www.youtube.com/watch?v=KthOVxloKAc

Commands:
amx_gungame <0/1> - disable or enable gungame.
gg_give <player> <level> - sets a player's level to the one specified.
gg_frags <level> <frags> - change the needed frags to pass a given level.
gg_suicide <0/1> - whether players lose a level for killing themselves.
gg_runspeed <speed> - set the default running speed.
gg_colorchat <0/1> - disable or enable color chat support.

Installation instructions:

1. Install Metamod.
http://metamod.org/

2. Install AMX or AMXX.
http://www.amxmod.net/
http://www.amxmodx.org/

3. Extract this archive to the valve folder, overwriting files when prompted.

4. Open your plugins.ini file with notepad and add the plugin at the bottom:

For AMX:
-Open addons\amx\config\plugins.ini
-Add HL_Gun_Game.amx

For AMXX:
-Open addons\amxmodx\config\plugins.ini
-Add HL_Gun_Game.amxx

5. Create a server and type 'amx_gungame 1' in the console to enable Gun Game.