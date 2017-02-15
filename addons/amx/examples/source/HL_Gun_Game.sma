/* AMX Mod script.
*
* GunGame for Half-Life
*  by brotalnia
*
*
* Description: A Half-Life version of the Counter-Strike plugin.
*
* Settings: amx_gungame (0/1) - enables or disables gungame
*			gg_colorchat (0/1) - query for colorchat support
*			gg_suicide (0/1) - punish players for suiciding
*			gg_runspeed (speed) - set default movement speed
*			gg_frags (level) (frags) - set required frags for level
*
*  www.brotalnia.com - Visit my website for more things by me.
*
*/

#define ADMIN_GUNGAME ADMIN_CVAR // Enable/Disable the plugin
#define ADMIN_GIVE ADMIN_BAN // To give a level
#define ADMIN_FRAG ADMIN_BAN // Frag requirements

#include <amxmod>
#include <amxmisc>
#include <fun>
#include <VexdUM>

#define MAXLEVEL 15
#define MAXWEAPONS 15
#define MAXSLOTS 32
#define S_OBJS 12
#define S_ENTS 4
#define MAX_OBJ 100

new frags[MAXLEVEL+1] = { 1, 2, 3, 3, 3, 3, 3, 3, 5, 3, 1, 1, 1, 1, 1, 1 }
new const wepId[MAXWEAPONS][] = {"weapon_9mmhandgun", "weapon_357", "weapon_shotgun", "weapon_mp5", "weapon_crossbow", "weapon_rpg", "weapon_hornetgun", "weapon_gauss", "weapon_egon", "weapon_mp5", "weapon_snark", "weapon_handgrenade", "weapon_satchel", "weapon_tripmine", "weapon_crowbar"}
new const ammoId[MAXWEAPONS][] = {"ammo_9mmclip", "ammo_357", "ammo_buckshot", "ammo_9mmAR", "ammo_crossbow", "ammo_rpgclip", "item_battery", "ammo_gaussclip", "ammo_gaussclip", "ammo_ARgrenades", "weapon_snark", "weapon_handgrenade", "weapon_satchel", "weapon_tripmine", "item_longjump"}
new const StripObjs[S_OBJS][] = {"weapon_357", "weapon_9mmAR", "weapon_crossbow", "weapon_egon", "weapon_gauss", "weapon_handgrenade", "weapon_hornetgun", "weapon_rpg", "weapon_satchel", "weapon_shotgun", "weapon_snark", "weapon_tripmine"/*, "item_longjump", "item_healthkit", "item_battery"*/}
new const StripEnts[S_ENTS][] = {"player_weaponstrip", "armoury_entity", "game_player_equip", "weaponbox"}

new bool:g_obj_removed
new Float:ObjVecs[MAX_OBJ][3]
new ObjEntsClass[MAX_OBJ][24]
new ObjEntsId[MAX_OBJ]
new objectives	// KWo
new gg_enabled, gg_colorchat, gg_suicide, gg_runspeed
new g_status
new g_level[33]=0,g_frags[33], g_lastdeath[33]
new bool:hasColorChat[MAXSLOTS + 1]
new bool:g_lead[33],bool:g_tied[33]
new g_minlevel, g_midlevel, g_toplevel, g_dominating
new g_iDeathOffset
new g_iMsgIDScoreInfo
new g_SprLightning
new g_winnername[32]
new mp_teamplay
new game_ended
new jumbot
new won

public plugin_precache()
{
	g_SprLightning = precache_model("sprites/lgtning.spr")
	precache_sound("misc/firstblood.wav")
	precache_sound("misc/tiedlead.wav")
	precache_sound("misc/takenlead.wav")
	precache_sound("misc/lostlead.wav")	
	precache_sound("misc/teamkiller.wav")
	precache_sound("misc/humiliation.wav")
	precache_sound("gungame/ggwelcome.wav")	
	precache_sound("gungame/ggdominate.wav")
	precache_sound("gungame/gglevel.wav")
	precache_sound("gungame/ggbeep.wav")
	precache_generic("sound/gungame/ggwinner.mp3")
	precache_generic("sound/gungame/ggloser.mp3")
	//use wav instead of mp3 for won
	//precache_sound("gungame/ggwinner.wav")
	//precache_sound("gungame/ggloser.wav")
}
public plugin_init()
{
	register_plugin("HL Gun Game","1.3","brotalnia")
	register_event("ResetHUD", "eResetHud", "be")
	register_event("DeathMsg","eDeathMsg","a")
	register_event("CurWeapon","eCurWeapon","be","1=1")
	register_concmd("amx_gungame", "toggleCmd", ADMIN_GUNGAME, "<1/0> - Enables/Disables GunGame mod")
	register_concmd("gg_give", "giveCmd", ADMIN_GIVE, "<name|#userid|authid> <level> - Gives a level")
	register_concmd("gg_frags", "fragsCmd", ADMIN_FRAG, "<level> <frags> - Sets frag requirement for a given level")
	
	gg_enabled = register_cvar("gg_enabled","0")
	gg_suicide = register_cvar("gg_suicide","0")
	gg_colorchat = register_cvar("gg_colorchat","1")
	gg_runspeed = register_cvar("gg_runspeed","400")
	
	g_iMsgIDScoreInfo = get_user_msgid("ScoreInfo")
	
	register_clcmd("fullupdate", "prevent_resethud")
	register_clcmd("record", "prevent_resethud")
	
	check_jumbot()
	
	// first cvar exists only in won, second one only in steam version of half-life
	if(cvar_exists("cl_latency") || !cvar_exists("sv_version"))
	{
		won = 1
		set_cvarptr_num(gg_colorchat, 0)
	}
	
	mp_teamplay = get_cvar_pointer("mp_teamplay")
	
	game_ended = false
	g_toplevel = 0
	g_midlevel = 0
	g_status = 0
	g_dominating = 0
	
	if (jumbot)
		g_iDeathOffset = 554
	else if (won)
		g_iDeathOffset = 372
	else
		g_iDeathOffset = 377
		
	set_task(15.0, "load_settings")
	
	if (get_cvarptr_num(gg_enabled))
	{
		g_status = 1
		hideObjects()
		destroyEntities()
	}
}
public toggleCmd(id,level,cid)
{
	// used to enable or disable gungame
	// called when user uses amx_gungame
	
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	new status[2]
	read_argv(1, status, 2)

	if(equal(status,"0",1)) {
		if(!get_cvarptr_num(gg_enabled))
			client_print(id, print_console,"Gun Game is already disabled!!")
		else {
			set_cvarptr_num(gg_enabled,0)
			ResetScore()
			reset_all()
			client_print(id, print_console,"Gun Game has been disabled.")
		}
	}
	else if(equal(status,"1",1)) {
		if(get_cvarptr_num(gg_enabled))
			client_print(id, print_console,"Gun Game is already enabled!!")
		else {
			set_cvarptr_num(gg_enabled,1)
			ResetScore()
			client_print(id, print_console,"Gun Game has been enabled.")
		}
	}
	else {
		console_print(id, "Usage: amx_gungame <1/0> to enable/disable Gun Game")
	}
	check_active()
	return PLUGIN_HANDLED
}
public load_settings()
{
	// loads settings from the config fille
	// called on plugin_init if gungame is enabled
	
	if(get_cvarptr_num(gg_enabled))
	{
		new cfgpath[64]
		get_localinfo("amx_configdir", cfgpath, 63)
		add(cfgpath, 63, "/gg_on.cfg")
		new execcfgpath[64]
		copy(execcfgpath, 63, "exec ")
		add(execcfgpath, 63, cfgpath)
	
		if(file_exists(cfgpath)) {
			server_cmd(execcfgpath)
			server_exec()
			new spd = get_cvarptr_num(gg_runspeed)+200
			if (get_cvar_num("sv_maxspeed") < spd)
			{
				set_cvar_num("sv_maxspeed", spd)
			}
		}
		else {
			set_cvar_num("mp_timelimit",0)
			set_cvar_num("mp_fraglimit",0)
			new spd = get_cvarptr_num(gg_runspeed)+200
			if (get_cvar_num("sv_maxspeed") < spd)
			{
				set_cvar_num("sv_maxspeed", spd)
			}
		}
	}
}
check_jumbot()
{
	// checks the metamod config file and localinfo cvar to see if jumbot is enabled because offsets are different
	// called once from plugin_init
	
	if (file_exists("addons/metamod/config.ini"))
	{
		new szData[33], iTextLength, iLine
		while (read_file("addons/metamod/config.ini", iLine, szData, 32, iTextLength) != 0)
		{
			if (contain(szData, "gamedll")!=-1 && contain(szData, ";gamedll")==-1 && contain(szData, "jumbot.dll")!=-1 && cvar_exists("wp_autoplace"))
			{
				jumbot = 1
				console_print(0, "Gun Game: Jumbot has been detected. Using appropriate offsets.")
			}		
			iLine++
		}
	}
	if (!jumbot)
	{
		new localinfo[64]
		get_localinfo("mm_gamedll",localinfo,63)
		if (contain(localinfo, "jumbot.dll")!=-1 && cvar_exists("wp_autoplace"))
		{
			jumbot = 1
			console_print(0, "Gun Game: Jumbot has been detected. Using appropriate offsets.")
		}
	}
}
check_active()
{
	// loads settings from the config files
	// called from toggleCmd (amx_gungame)
	
	new cfgpath[64]
	new execcfgpath[64]
	get_localinfo("amx_configdir", cfgpath, 63)
	
	if(get_cvarptr_num(gg_enabled) > 0)
	{
		if(g_status == 1)
			return
		
		add(cfgpath, 63, "/gg_on.cfg")
		copy(execcfgpath, 63, "exec ")
		add(execcfgpath, 63, cfgpath)
		
		if(file_exists(cfgpath)) {
			server_cmd(execcfgpath)
			server_exec()
			new spd = get_cvarptr_num(gg_runspeed)+200
			if (get_cvar_num("sv_maxspeed") < spd)
			{
				set_cvar_num("sv_maxspeed", spd)
			}
		}
		else {
			set_cvar_num("mp_timelimit",0)
			set_cvar_num("mp_fraglimit",0)
			set_cvar_num("mp_friendlyfire",0)
			new spd = get_cvarptr_num(gg_runspeed)+200
			if (get_cvar_num("sv_maxspeed") < spd)
			{
				set_cvar_num("sv_maxspeed", spd)
			}
		}
		g_status = 1
		hideObjects()
		destroyEntities()

		set_task(1.0, "notify_activated")
	}
	else
	{
		
		if(g_status == 0)
			return
		
		add(cfgpath, 63, "/gg_off.cfg")
		copy(execcfgpath, 63, "exec ")
		add(execcfgpath, 63, cfgpath)
		
		if(file_exists(cfgpath)) {
			set_cvar_num("sv_maxspeed", 320)
			server_cmd(execcfgpath)
			server_exec()
		}
		else {
			set_cvar_num("mp_timelimit",20)
			set_cvar_num("mp_fraglimit",100)
			set_cvar_num("sv_maxspeed", 320)
		}
		g_status = 0
		set_hudmessage(200,100,0,-1.0,0.35,0,6.0,12.0,0.1,0.2,4)
		show_hudmessage(0,"Gun Game has been deactivated!")
		restoreObjectives()
	}
	set_task(1.0, "MakeSolid")
}
public notify_activated() {
	set_hudmessage(200,100,0,-1.0,0.3,0,6.0,12.0,0.1,0.2,4)
	show_hudmessage(0,"Gun Game has been activated!")
}
public giveCmd(id, level, cid)
{
	// used to set players at a certain level
	// called when user uses gg_give command
	
	if(!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED	

	new target[24], arg[3]
	read_argv(1, target, 23)
	new player = cmd_target(id, target, 3)
	if(!player)
		return PLUGIN_HANDLED

	read_argv(2, arg, 2)
	new level = strtonum(arg)
	if(level < 0)
		level = 0
	if(level > MAXLEVEL-1)
		level = MAXLEVEL-1
	g_level[player] = level
	g_lastdeath[player] = level
	if (level>g_toplevel)
	{
		check_toplevel()
		status_display(player)
	}	
	set_midlevel()
	Equip_Player(player)
	return PLUGIN_HANDLED
}
public fragsCmd(id, level, cid)
{
	// changes the frags requirement for a given level
	// called when user uses gg_frags command
	
	if(!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED	

	new arg1[3], arg2[3]
	read_argv(1, arg1, 2)
	read_argv(2, arg2, 2)
	new level = strtonum(arg1)
	if (0 <= level <= MAXLEVEL-1)
	{
		new fragreq = strtonum(arg2)
		if (fragreq>0)
		{
			frags[level] = fragreq
		}
		else
			client_print(id, print_console,"Invalid frags value. Must be greater than zero.")
	}
	else
		client_print(id, print_console,"Invalid level value. Must be between 0 and %i.", MAXLEVEL-1)
	
	return PLUGIN_HANDLED
}
ResetScore()
{
	// resets frags and deaths and respawns players
	// called from toggleCmd when amx_gungame changes
	
	new players[32], inum, player
	get_players(players, inum, "h")
	for(new i=0; i<inum; ++i)
	{
		player = players[i]
		strip_user_weapons(player)
		user_spawn(player)
		set_user_frags(player, 0)
		set_offset_int(player, g_iDeathOffset, 0)
		entity_set_int(player, EV_INT_solid, 0)
		
		message_begin(MSG_BROADCAST, g_iMsgIDScoreInfo, {0, 0, 0}, 0)
		write_byte(player)
		write_short(0)
		write_short(0)
		// ScoreInfo size is only 5 bytes when Jumbot is enabled
		if (!jumbot) {
			write_short(0)
			write_short(get_user_team(player))
		}
		message_end()
	}
}
public MakeSolid()
{
	// makes players solid again
	// called from check_active
	
	new players[32], inum, player
	get_players(players, inum, "h")
	for(new i=0; i<inum; ++i)
	{
		player = players[i]
		entity_set_int(player, EV_INT_solid, 3)
	}
}
reset_all()
{
	// resets gungame related stats
	// called from toggleCmd when gungame is disabled
	
	new players[32], inum, player
	get_players(players, inum, "h")
	for(new i=0; i<inum; ++i) {
		player = players[i]
		g_level[player] = 0
		g_frags[player] = 0
		g_lastdeath[player] = 0
		g_lead[player] = false
		g_tied[player] = false
	}
	game_ended = false
	g_toplevel = 0
	g_midlevel = 0
	g_dominating = 0
}
set_midlevel()
{
	// calculates the average level so that new players can start from it
	// called from check_level, check_toplevel and giveCmd
	
	new players[32], inum, player
	get_players(players, inum, "h")
	g_minlevel = g_toplevel
	for(new i=0; i<inum; ++i)
	{
		player = players[i]

		if(g_level[player] < g_minlevel) {
			g_minlevel = g_level[player]
		}
	}
	if(g_toplevel - g_minlevel <= 4) {
		g_midlevel = g_minlevel
	}
	else if(g_toplevel - g_minlevel <= 8) {
		new mid = floatround((g_toplevel + 0.0)/2)
		new mid2 = g_minlevel + floatround((g_toplevel - g_minlevel + 0.0)/2) - 1
		if(mid < mid2) {
			if(mid < g_minlevel)
				mid = g_minlevel
			g_midlevel = mid
		}
		else
			g_midlevel = mid2
	}
	else {
		g_midlevel = g_minlevel + floatround((g_toplevel - g_minlevel + 0.0)/2) - 1
	}
}
public eResetHud(id)
{
	// equips players, sets their speed, and shows information about their level
	// called when the hud resets (when a player respawns)
	
	if(!get_cvarptr_num(gg_enabled))
		return
		
	new level = g_level[id]
	new step = frags[level]
	
	Equip_Player(id)

	// removing "weapon_" from the start of weapon names and changing some of them
	new wepname[32]
	if ((level!=0) && (level!=9)){
		copy(wepname, 31, wepId[level])
		replace(wepname, 31, "weapon_", "")
	}
	else if (level==9)
	{
		copy(wepname, 31, "ar grenade")
	}
	else if (level==0)
	{
		copy(wepname, 31, "glock")
	}
	
	// print level information in chat
	if (level<MAXLEVEL-1)
	{
		if (step - g_frags[id]!=1)
			ColorChat(id, id, "^^2[GunGame] ^^9: You are at level ^^8%i^^9 (^^5%s^^9) and you need ^^8%i^^9 frags to advance.", level, wepname, step - g_frags[id])
		else
			ColorChat(id, id, "^^2[GunGame] ^^9: You are at level ^^8%i^^9 (^^5%s^^9) and you need ^^8%i^^9 frag to advance.", level, wepname, step - g_frags[id])
	}
	else
	{
		if (step - g_frags[id]!=1)
			ColorChat(id, id, "^^2[GunGame] ^^9: You are at level ^^8%i^^9 (^^5%s^^9) and you need ^^8%i^^9 frags to win the game.", level, wepname, step - g_frags[id])
		else
			ColorChat(id, id, "^^2[GunGame] ^^9: You are at level ^^8%i^^9 (^^5%s^^9) and you need ^^8%i^^9 frag to win the game.", level, wepname, step - g_frags[id])
	}
	
	set_user_maxspeed(id, get_cvarptr_float(gg_runspeed))
	status_display(id)
}
Equip_Player(id)
{
	// gives players weapons and ammo and switches to new weapon
	// called from eResetHud, giveCmd, level_up and level_down
	
	if(!get_cvarptr_num(gg_enabled) || !is_user_alive(id))
		return
	
	new level = g_level[id]
	strip_user_weapons(id)
	
	// no crowbar for some levels
	if ((level!=9 && !(level>11)) || is_user_bot(id))
		give_item(id,"weapon_crowbar")
	
	// give weapon and ammo
	give_item(id,wepId[level])
	give_item(id,ammoId[level])
	give_item(id,ammoId[level])
	give_item(id,ammoId[level])
	give_item(id,ammoId[level])
	
	// switch to the new weapon
	new switchname[32]
	copy(switchname, 31, wepId[level])
	replace(switchname, 31, "mp5", "9mmAR")
	engclient_cmd(id,switchname)
	
	// set bp ammo to 99 for ar grenade, satchel and tripmine levels
	if (level==9)
	{		
		if (jumbot)
			set_offset_int(id, 489, 99, 5)
		else if (won)
			set_offset_int(id, 307, 99, 5)
		else
			set_offset_int(id, 312, 99, 5)
	}
	else if (level==12)
	{			
		if (jumbot)
			set_offset_int(id, 495, 99, 5)
		else if (won)
			set_offset_int(id, 313, 99, 5)
		else
			set_offset_int(id, 318, 99, 5)
	}
	else if (level==13)
	{
		if (jumbot)
			set_offset_int(id, 494, 99, 5)
		else if (won)
			set_offset_int(id, 312, 99, 5)
		else
			set_offset_int(id, 317, 99, 5)
	}
}
public eDeathMsg()
{
	// reward or punish kills and deaths
	// called when a player dies
	
	if(!get_cvarptr_num(gg_enabled))
		return

	static victim
	static killer
	victim = read_data(2)
	killer = read_data(1)
	
	if((victim != killer) && is_user_connected(victim) && (killer != 0))
	{
		new victimteam[32]
		get_user_team(victim, victimteam, 31)
		new killerteam[32]
		get_user_team(killer, killerteam, 31)
		
		if (!((get_cvarptr_num(mp_teamplay)==1) && (equal(victimteam, killerteam))))
		{
			new victim_name[32]
			get_user_name(victim, victim_name, 31)
			new killer_name[32]
			get_user_name(killer, killer_name, 31)
			
			if (victim != g_dominating)
			{
				// normal kill
				ColorChat(victim, killer, "^^2[GunGame] ^^9: You were killed by ^x03%s^^9 who is at level ^^8%i^^9.", killer_name, g_level[killer])
				static weapon_name[32]
				read_data(3, weapon_name, 31)
				if ((g_level[killer]<MAXLEVEL-1) || equal(weapon_name,"crowbar"))
				{
					// prevent skipping of last level
					ColorChat(killer, victim, "^^2[GunGame] ^^9: You killed ^x03%s^^9 who is at level ^^8%i^^9.", victim_name, g_level[victim])
					frag_up(killer)
				}
			}
			else
			{
				// killed the player that is dominating
				ColorChat(killer, victim, "^^2[GunGame] ^^9: You have slain ^x03%s^^9 and earned a level!", victim_name)
				set_hudmessage(0, 120, 220,-1.0,0.15,1,20.0,30.0,0.1,0.2,4)
				show_hudmessage(0, "All hail your saviour %s! ^n^n He has ended %s's killing spree!", killer_name, victim_name)
				level_up(killer)
				client_cmd(0, "spk misc/humiliation.wav")
			}
		}
		else
			level_down(killer, 2) // punish team killers
	}
	else if ((victim==killer) && (get_cvarptr_num(gg_suicide)) && is_user_connected(victim))
		level_down(victim, 1) // punish suicide

	// related to domination mechanic
	g_lastdeath[victim] = g_level[victim]
	if (victim == g_dominating)
		g_dominating = 0
}
public set_model(ent, const model[])
{
	// checks for weaponboxes and removes them
	// called when a new model is created
	
	if (!get_cvarptr_num(gg_enabled) || !is_entity(ent) || !equali(model, "models/w_weaponbox.mdl"))
		return
	
	static class[32]
	entity_get_string(ent, EV_SZ_classname, class, 31)
	if (!equal(class, "weaponbox"))
		return
	
	set_task(0.1, "destroyWeaponbox", ent)
	
	return
}
status_display(id)
{
	// displays current match status on the hud when a player spawns, when they get a frag or the top level changes
	// called from eResetHud, giveCmd, check_level, frag_up, level_up and level_down
	
	if(id && (!is_user_alive(id)))
		return
		
	new message[192]
	if (!game_ended)
	{
		formatex(message, 191, "Frags: %i/%i^nYour level: %i | Top level: %i", g_frags[id], frags[g_level[id]], g_level[id], g_toplevel)
		set_hudmessage(128, 255, 0, -1.0, 0.97, 0, 0.1, 30.0, 0.1, 0.2, 3)
		show_hudmessage(id,message)
	}
	else
	{
		formatex(message, 191, "Congratulations to %s ^n^nHe has won the game!", g_winnername)
		set_hudmessage(0, 120, 220,-1.0,0.15,1,20.0,30.0,0.1,0.2,4)
		show_hudmessage(id,message)
	}
}/*
public Task_GivePeriodic(iPlayerID)
{
	// periodically refill ammo, not used anymore
	
	new level = g_level[iPlayerID]
	if(!is_user_alive(iPlayerID) || !((level == 13) || (level == 12)))
		return

	give_item(iPlayerID, ammoId[level])
	give_item(iPlayerID, ammoId[level])
	set_task(1.0, "Task_GivePeriodic", iPlayerID)
}*/
public eCurWeapon(id)
{
	// check what weapon the player is using and change it if it is not for his level
	// called when switching weapons, reloading or picking up ammo
	
	if(!get_cvarptr_num(gg_enabled) || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	new level = g_level[id]
	new weaponname[32]
	new currentweapon
	new cclip
	new aammo
	currentweapon = get_user_weapon(id, cclip, aammo)
	get_weaponname(currentweapon,weaponname,31)
	new lvlname[32]
	copy(lvlname, 31, wepId[level])
	strtolower(lvlname)
	strtolower(weaponname)
	replace(weaponname, 31, "9mmar", "mp5") // mp5 has two different names
	new switchname[32]
	copy(switchname, 31, wepId[level])
	replace(switchname, 31, "mp5", "9mmAR")
	
	if (cclip==0)
		give_item(id,ammoId[level]) // make sure there is ammo so the weapon is usable
		
	if (!(equal(weaponname,lvlname) || equal(weaponname,"weapon_crowbar")))
	{
		engclient_cmd(id,"weapon_crowbar")
		engclient_cmd(id,switchname)
	}
	
	if ((level > 9) && (level < 12))
		give_item(id,ammoId[level]) // refill ammo when switching weapon on grenade and snark levels
	
	return PLUGIN_HANDLED
}
public client_connect(id)
{
	// sets the level of new players to the average level of all players
	// called when a client establishes a connection with the server
	
	if(!get_cvarptr_num(gg_enabled))
		return

	if(g_toplevel > 4)
		g_level[id] = g_midlevel
	else
		g_level[id] = 0
		
	g_frags[id] = 0
	g_lastdeath[id] = g_level[id]
}
public client_putinserver(player)
{
	// tasks that need to be done on new players
	// called when a player joins the game
	
	// stop endgame music or it will play again after map change
	if (!won)
		set_task(0.1,"StopMusic", player)
	// check if player has aghl color chat support
	if(get_cvarptr_num(gg_colorchat) && !is_user_bot(player))
		set_task(1.0,"QuaryColorChat", player)
	else
		hasColorChat[player] = false
	// play the gungame welcome sound
	if(get_cvarptr_num(gg_enabled))
		set_task(1.0,"play_welcome",player)
}
public StopMusic (player) {
	client_cmd(player, "mp3 stop")
}
public QuaryColorChat(player) {
	query_client_cvar(player,"hud_colortext","SetColorChat")
}
public SetColorChat(id,cvar[],value[]) {
	hasColorChat[id] = str_to_num(value) == 1
}
public play_welcome(id) {
	client_cmd(id, "spk gungame/ggwelcome.wav")
}
public client_disconnect(id)
{
	// resets gungame related stats and makes sure the top level is recalculated
	// called when a player leaves the server
	
	if(!get_cvarptr_num(gg_enabled))
		return

	g_level[id] = 0
	g_frags[id] = 0
	g_lastdeath[id] = 0
	if(g_lead[id])
		check_toplevel()
	if (g_dominating==id)
		g_dominating=0
	g_lead[id] = false
	g_tied[id] = false
	hasColorChat[id] = false
}
check_level(id)
{
	// tracks if a player is leading, tied for the lead, or has lost the lead
	// called only from level_up
	
	if(g_level[id] > g_toplevel) {
		if(g_tied[id])
			g_tied[id] = false
		if(!g_lead[id]) {
			g_lead[id] = true
			if (g_toplevel==0)
				client_cmd(id, "spk misc/firstblood.wav")
			else if (id!=g_dominating)
				client_cmd(id, "spk misc/takenlead.wav")
			new name[32]
			get_user_name(id, name, 31)
			message_lead(id, name, 1)
		}
		g_toplevel=g_level[id]
		
		new players[32], inum, player
		get_players(players, inum, "ch")
		for(new i=0; i<inum; ++i) {
			player = players[i]
			if(player != id) {
				if(g_lead[player]) {  // shouldn't be
					g_lead[player] = false
					client_cmd(player, "spk misc/lostlead.wav")
				}
				if(g_tied[player]) {
					g_tied[player] = false
					client_cmd(player, "spk misc/lostlead.wav")
				}
			}
			status_display(player)
		}
		
	}
	else if(g_level[id] == g_toplevel) {
		g_tied[id] = true
		client_cmd(id, "spk misc/tiedlead.wav")
		new name[32]
		get_user_name(id, name, 31)
		message_lead(id, name, 0)
		new players[32], inum, player
		get_players(players, inum, "h")
		for(new i=0; i<inum; ++i) {
			player = players[i]
			if(g_lead[player]) {
				g_lead[player] = false
				g_tied[player] = true
			}
		}
	}
	set_midlevel()
}
get_user_weapon_entity(iPlayerID, szClassName[])
{
	// returns a weapon owned by a specific player
	// called from FillClipAmmo
	
	new iEntityID = -1;
	while((iEntityID = find_entity(iEntityID, szClassName)) > 0) { // class name
		if(entity_get_edict(iEntityID, EV_ENT_owner) == iPlayerID) {
			return iEntityID;
		}
	}
	return 0;
}
FillClipAmmo(id)
{
	// fills a player's clip when they get a kill
	// called from frag_up
	
	new level = g_level[id]
	if (level<5)
	{
		new weaponName[32]
		copy(weaponName, 31, wepId[level])
		replace(weaponName, 31, "mp5", "9mmAR")
		new weaponEntity = get_user_weapon_entity(id, weaponName)
		if (weaponEntity!=0)
		{
			new ammoOffset
			if (!jumbot)
				ammoOffset = 40
			else
				ammoOffset = 150
			switch (level)
			{
				case 0:
					set_offset_int(weaponEntity, ammoOffset, 17, 4)
				case 1:
					set_offset_int(weaponEntity, ammoOffset, 6, 4)
				case 2:
					set_offset_int(weaponEntity, ammoOffset, 8, 4)
				case 3:
					set_offset_int(weaponEntity, ammoOffset, 50, 4)
				case 4:
					set_offset_int(weaponEntity, ammoOffset, 5, 4)
			}
		}
	}
}
ColorChat(id, plrname, const msg[], {Float,Sql,Result,_}:...)
{
	// handles color chat messages
	// replaces the team tag "^x03" with the appropriate color tag
	// removes color chat tags for players that don't support color chat
	
	static message[192]
	
	if(numargs() > 3)
		format_args(message, 191, 2)
	else
		copy(message, 191, msg)
		
	message[191] = 0
	
	if (id==0) // send message to everyone
	{
		new players[32], inum, player
		get_players(players, inum, "ch")
		for(new i=0; i<inum; ++i) {
			player = players[i]
			static messaga[256]
			copy(messaga, 251, message)
			if (hasColorChat[player])
			{
				if (plrname)
				{
					switch(get_user_team(plrname))
					{
						case 1:
							replace_all(messaga, 251, "^x03", "^^4");
						case 2:
							replace_all(messaga, 251, "^x03", "^^1");
						case 3:
							replace_all(messaga, 251, "^x03", "^^7");
						default:
							replace_all(messaga, 251, "^x03", "^^3");
					}
				}
				client_print(player, print_chat, messaga)
			}
			else
			{
				replace_all(messaga, 251, "^^1", "")
				replace_all(messaga, 251, "^^2", "")
				replace_all(messaga, 251, "^^3", "")
				replace_all(messaga, 251, "^^4", "")
				replace_all(messaga, 251, "^^5", "")
				replace_all(messaga, 251, "^^6", "")
				replace_all(messaga, 251, "^^7", "")
				replace_all(messaga, 251, "^^8", "")
				replace_all(messaga, 251, "^^9", "")
				replace_all(messaga, 251, "^x03", "")
				client_print(player, print_chat, messaga)
			}
		}
	}
	else if (!is_user_bot(id)) // send message to specific player only
	{
		if (hasColorChat[id])
			{
				if (plrname)
				{
					switch(get_user_team(plrname))
					{
						case 1:
							replace_all(message, 251, "^x03", "^^4");
						case 2:
							replace_all(message, 251, "^x03", "^^1");
						case 3:
							replace_all(message, 251, "^x03", "^^7");
						default:
							replace_all(message, 251, "^x03", "^^3");
					}
				}
				client_print(id, print_chat, message)
			}
			else
			{
				replace_all(message, 251, "^^1", "")
				replace_all(message, 251, "^^2", "")
				replace_all(message, 251, "^^3", "")
				replace_all(message, 251, "^^4", "")
				replace_all(message, 251, "^^5", "")
				replace_all(message, 251, "^^6", "")
				replace_all(message, 251, "^^7", "")
				replace_all(message, 251, "^^8", "")
				replace_all(message, 251, "^^9", "")
				replace_all(message, 251, "^x03", "")
				client_print(id, print_chat, message)
			}
	}
}
message_lead(id, name[], witch)
{
	// announces when a player has taken the lead or is tied for the lead
	// called from check_level if a change in leadership has occurred
	
	new wepname[32]
	
	if ((g_level[id]!=0) && (g_level[id]!=9))
	{
		copy(wepname, 31, wepId[g_level[id]])
		replace(wepname, 31, "weapon_", "")
	}
	else if (g_level[id]==9)
	{
		copy(wepname, 31, "ar grenade")
	}
	else if (g_level[id]==0)
	{
		copy(wepname, 31, "glock")
	}

	if(witch)
		ColorChat(0, id, "^^2[GunGame] ^^9: ^x03%s^^9 has taken the lead at level ^^8%i^^9 (^^5%s^^9).", name, g_level[id], wepname)
	else
		ColorChat(0, id, "^^2[GunGame] ^^9: ^x03%s^^9 is tied for the lead at level ^^8%i^^9 (^^5%s^^9).", name, g_level[id], wepname)
}
check_toplevel()
{
	// determines the top level at the given moment
	// called from giveCmd, client_disconnect and level_down
	
	g_toplevel = 0
	new players[32], inum, player
	get_players(players, inum, "h")
	for(new i=0; i<inum; ++i) {
		player = players[i]
		g_lead[player] = false
		g_tied[player] = false
		if(g_level[player] > g_toplevel) {
			g_toplevel = g_level[player]
		}
	}
	for(new i=0; i<inum; ++i) {
		new lead = 0, tied = 0
		player = players[i]
		if(g_level[player] == g_toplevel) {
			if(!lead) {
				g_lead[player] = true
				lead = i
			}
			else {
				g_tied[player] = true
				if(!tied) {
					tied = 1
					g_lead[players[lead]] = false
					g_tied[players[lead]] = true
				}
			}
		}
	}
	set_midlevel()
}
display_level(id)
{
	// gives players information about their current level
	// called from frag_up and level_up
	
	if(!get_cvarptr_num(gg_enabled))
		return PLUGIN_CONTINUE

	new level = g_level[id]
	new step
	step = frags[level]
	
	if(level < MAXLEVEL-1)
	{
		if (step - g_frags[id]!=1)
			ColorChat(id, id, "^^2[GunGame] ^^9: You need ^^8%i^^9 frags to reach level ^^8%i^^9.", step - g_frags[id], level + 1)
		else
			ColorChat(id, id, "^^2[GunGame] ^^9: You need ^^8%i^^9 frag to reach level ^^8%i^^9.", step - g_frags[id], level + 1)
	}
	else
	{
		if (step - g_frags[id]!=1)
			ColorChat(id, id, "^^2[GunGame] ^^9: Wow, last level,^^8 %i^^9 frags and you win the Gun Game!", step - g_frags[id])
		else
			ColorChat(id, id, "^^2[GunGame] ^^9: Wow, last level,^^8 %i^^9 frag and you win the Gun Game!", step - g_frags[id])
	}
		
	return PLUGIN_HANDLED
}
public prevent_resethud(id) {
	return PLUGIN_HANDLED
}
frag_up(id)
{
	// increments the number of frags the player has for the current level and replenishes his ammo
	// if he has reached the required amount, it calls either level_up or endgame if it was the last level
	// called from eDeathMsg
	
	new level = g_level[id]
	new step
	step = frags[level]
	
	if(step - g_frags[id] > 1) {
		++g_frags[id]
		FillClipAmmo(id)
		give_item(id,ammoId[level])
		give_item(id,ammoId[level])
		//client_cmd(id, "spk fvox/beep.wav")
		client_cmd(id, "spk gungame/ggbeep.wav")
		display_level(id)
		if (!game_ended)
			status_display(id)
	}
	else
	{
		if(level < MAXLEVEL)
			level_up(id)
		else
			endgame(id)
	}
}
level_up(id)
{
	// increases the level of a player or calls endgame if he was on the last level
	// also heals the player, makes sure he is equipped, and makes him the dominator if he qualifies
	// called from eDeathMsg and frag_up
	
	new level = g_level[id]
	++g_level[id]
	if (level+1!=MAXLEVEL)
	{
		check_level(id)
		g_frags[id] = 0
		display_level(id)
		Equip_Player(id)
		if (get_user_health(id)<100)
			set_user_health(id, 100)
		if (!game_ended)
			status_display(id)
		if ((g_dominating==0) && ((g_level[id]-g_lastdeath[id])>3) && (g_level[id]==g_toplevel))
			make_dominator(id)
		else
			emit_sound(id, CHAN_AUTO, "gungame/gglevel.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	else
	{
		endgame(id)
	}
}
level_down(id, reason)
{
	// decreases a player's level and informs him of the reason if it was specified
	// called from eDeathMsg
	
	if(g_level[id] > 0) {
		--g_level[id]
		g_frags[id] = 0
		Equip_Player(id)
		if(g_lead[id])
			check_toplevel()
		status_display(id)
	}
	else
		g_frags[id] = 0
	
	switch (reason)
	{
		case 1:
		{
			ColorChat(id, 0, "^^2[GunGame] ^^9: You have lost a level! (^^6suicide^^9)");
			client_cmd(id, "spk vox/failure.wav");
		}
		case 2: 
		{
			ColorChat(id, 0, "^^2[GunGame] ^^9: You have lost a level! (^^6teamkill^^9)");
			client_cmd(id, "spk misc/teamkiller.wav");
		}
		default:
			ColorChat(id, 0, "^^2[GunGame] ^^9: You have lost a level!");
	}
}
shake_screen(id)
{
	// makes a player's screen shake
	// called from make_dominator
	
	new gmsgShake = get_user_msgid("ScreenShake")
	message_begin(MSG_ONE, gmsgShake, {0,0,0}, id)
	write_short(255<< 14 ) //amount
	write_short(1 << 14) //duration
	write_short(255<< 14) //frequency
	message_end()
}
lightning_strike(id)
{
	// hits a player with lightning
	// called from make_dominator
	
	new vec2[3], vec1[3]
	get_user_origin(id,vec2)
	vec2[2] -= 26
	vec1[0]=vec2[0]+100
	vec1[1]=vec2[1]+100
	vec1[2]=vec2[2]+300
	
	message_begin( MSG_BROADCAST,SVC_TEMPENTITY) 
	write_byte( 0 ) 
	write_coord(vec1[0]) 
	write_coord(vec1[1]) 
	write_coord(vec1[2]) 
	write_coord(vec2[0]) 
	write_coord(vec2[1]) 
	write_coord(vec2[2]) 
	write_short( g_SprLightning ) 
	write_byte( 1 ) // framestart 
	write_byte( 5 ) // framerate 
	write_byte( 4 ) // life 
	write_byte( 150 ) // width 
	write_byte( 30 ) // noise 
	write_byte( 200 ) // r, g, b 
	write_byte( 200 ) // r, g, b 
	write_byte( 200 ) // r, g, b 
	write_byte( 200 ) // brightness 
	write_byte( 200 ) // speed 
	message_end()
}
make_dominator(id)
{
	// if a player passes more than 3 levels without dying and is currently leading he is dominating
	// when someone is dominating it gets announced to everyone and he is rewarded with extra health and increased movement speed
	// called from level_up
	
	new dominator_name[32]
	get_user_name(id, dominator_name, 31)
	g_dominating=id
	lightning_strike(id)
	shake_screen(id)
	set_user_maxspeed(id, get_cvarptr_float(gg_runspeed)+200.0)
	set_user_health(id,200)
	ColorChat(0, id, "^^2[GunGame] ^^9: ^x03%s^^9 is dominating! Killing him will grant a level!", dominator_name)
	set_hudmessage(255, 10, 10,-1.0,0.15,1,5.0,10.0,0.1,0.2,4)
	show_hudmessage(0, "%s IS DOMINATING! ^n^nSlay him to gain a level!", dominator_name)
	show_hudmessage(id, "YOU ARE DOMINATING! ^n^nFeel the power flow through you!")
	emit_sound(id, CHAN_AUTO, "gungame/ggdominate.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	switch(get_user_team(id))
	{
		case 1:
			set_user_rendering(id, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 30);
		case 2:
			set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 30);
		default:
			set_user_rendering(id, kRenderFxGlowShell, 211, 211, 211, kRenderNormal, 30);
	}
}
endgame(id)
{
	// ends the game, announces the winner and schedules a map change
	// called from frag_up and level_up
	
	if(!game_ended)
	{
		game_ended = true
		
		new name[32]
		get_user_name(id, name, 31)
		copy(g_winnername, 31, name)
		
		ColorChat(0, id, "^^2[GunGame] ^^9: ^x03%s^^9 has won the Gun Game!", name)
		
		if (!won)
			client_cmd(id, "mp3 play sound/gungame/ggwinner.mp3")
		else
			client_cmd(id, "spk gungame/ggwinner.wav")
		
		set_user_rendering(id,kRenderFxGlowShell,200,100,0,kRenderTransAlpha,200)
		set_user_godmode(id, 1)
		
		new players[32], inum, player
		get_players(players, inum)
		for(new i; i<inum; ++i) {
			player = players[i]
			
			g_level[player] = 0
			g_frags[player] = 0
			g_lastdeath[player] = 0
			
			strip_user_weapons(player)
			give_item(player, "weapon_crowbar")
			
			set_hudmessage(128, 255, 0, -1.0, 0.97, 0, 0.1, 1.0, 0.1, 0.2, 3)
			show_hudmessage(player," ")
			
			if (player!=id)
			{
				if (!won)
					client_cmd(player, "mp3 play sound/gungame/ggloser.mp3")
				else
					client_cmd(player, "spk gungame/ggloser.wav")
			}
		}
		
		set_hudmessage(0, 120, 220,-1.0,0.15,1,20.0,30.0,0.1,0.2,4)
		show_hudmessage(0, "Congratulations to %s ^n^nHe has won the game!", name)
		
		set_task(1.0,"actionChangemap")
	}
}
public actionChangemap()
{
	// checks if a plugin is present to have a vote for next map
	// called from endgame
	
	if (is_plugin_running("mapchooser.amx") || is_plugin_running("mapchooser5.amx") ) {
		if (is_plugin_running("mapchooser.amx"))
			server_cmd("amx_votenextmap 5")
		else
			server_cmd("amx_launchvotemap")
	}
	else {
		set_task(15.0,"changemap")
	}
}
public changemap()
{
	// shows the scoreboard to all players and schedules a manual map change
	// called from actionChangemap when a votemap plugin is not present
	
	new modName[8]	
	get_modname(modName, 7)	
	if(!equal(modName, "zp")) {
		message_begin(MSG_ALL, SVC_INTERMISSION)
		message_end()		
	}
	set_task(2.0,"delay_change")
}
public delay_change()
{
	// manually changes the map to the next one
	// called from changemap
	
	new nextmap[32]
	get_cvar_string("amx_nextmap", nextmap, 31)
	server_cmd("changelevel %s", nextmap)
}
hideObjects() // BAILOPAN org + tweaks KWo and KRoT@L
{
	// removes weapons from the floor to prevent players from picking them up
	// called from plugin_init and check_active if gungame is enabled

	if (g_obj_removed) return	// KWo
	objectives = 0
	new tEnt, tfEnt

	for (new i=0; i<S_OBJS; i++) {	

		tEnt = find_entity(-1, StripObjs[i])
		while (tEnt > 0) {
			tfEnt = find_entity(tEnt, StripObjs[i])
			if (objectives == MAX_OBJ - 1)   // KWo
				objectives = 0
			else
				objectives++
			if (is_entity(tEnt)) {
				entity_get_vector(tEnt, EV_VEC_origin, ObjVecs[objectives])
				ObjEntsId[objectives] = tEnt
				ObjEntsClass[objectives][0] = '^0'
				copy(ObjEntsClass[objectives], 23, StripObjs[i])
				hideEnt(tEnt)		// KWo
			}
			tEnt = tfEnt
		}
	}
	g_obj_removed=true		// KWo

}
destroyEntities()
{
	// removes non-weapon entities from the map
	// called from plugin_init and check_active if gungame is enabled
 
	new tEnt, tfEnt
	for (new i=0; i<S_ENTS; i++) {	
		tEnt = find_entity(-1, StripEnts[i])
		while (tEnt > 0) {
			tfEnt = find_entity(tEnt, StripEnts[i])
			if (is_entity(tEnt))
				remove_entity(tEnt)		// KWo
			tEnt = tfEnt
		}
	}
}
public destroyWeaponbox(ent)
{
	// removes the weaponbox that players drops when they die
	// called from set_model when a weaponbox is created

	call_think(ent)
}
hideEnt(ent)
{
	// hides an entity
	// called from hideObjects
	
	new Float:Vec[3] = {10000.0,10000.0,10000.0}
	entity_set_int(ent, EV_INT_rendermode, kRenderTransTexture)
	entity_set_origin(ent, Vec)
}
restoreObjectives()   // KWo
{
	// restores weapons on the floor when gungame is disabled
	// called from check_active
	
	new i
	for (i=1; i<=objectives; i++) {
		if (is_entity(ObjEntsId[i]))
		{
			entity_set_int(ObjEntsId[i], EV_INT_rendermode, kRenderNormal)
			entity_set_origin(ObjEntsId[i], ObjVecs[i])
		}
	}
	objectives = 0
	g_obj_removed = false	// KWo
}
