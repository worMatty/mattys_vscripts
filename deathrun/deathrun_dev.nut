/*
	Deathrun Dev v0.2 by worMatty
	Depends on matty/stock2.nut v2.1.4

	Commands and convenient automations to aid you in deathrun map development.
	Intended for use while running the map in a listen server, but it is safe to leave the script in the map
	when running it on a dedicated server, as none of its features will be enabled by default.

	Features:
		Enable cheats
			The script will enable cheats on round restart, making it easier to control puppet bots and use dev commands/convars.
			This feature is enabled by default in a listen server.
			To disable: script deathrun_dev.enable_cheats = false
		Deathrun team sorting
			The script will put one player on blue and the rest on red.
			The host player will be put on red, but there is an option to be put on blue if you wish to test the activator experience.
			This feature is enabled by default in a listen server, as it is assumed you are not using a deathrun plugin.
			To disable: script deathrun_dev.sort_teams = false
			To always be the activator: script deathrun_dev.make_me_activator = true
		Make round restarts faster
			This works by changing console variables that control the wait periods during the start and end of rounds.
			The Waiting for Players time is also cancelled.
			This feature is enabled by default on a listen server.
			To disable: script deathrun_dev.faster_round_restart = false
		Development commands
			Commands you can type in chat to do stuff like resurrecting, controlling bot numbers and teleporting.
			This feature is always enabled but only authorised users can use commands.
			Authorisation is controlled by adding Steam3 ids to an array. There is information on how to do this later.
			To disable: script deathrun_dev.dev_commands = false

	Commands:
		Commands are used in chat by typing the word and any arguments without a prefix.
		If you are running a listen server, you can use them in your client console by prefixing them with 'say'. e.g. say restart.
		If you are running a dedicated/'online' server, you can use most of them in the server console by prefixing them with 'say'.
		Note that commands that work upon the player entity that used them, such as teleportation, will not run when executed from a dedi server console.

		Bots
			bot - spawn a puppet bot
			bots <number> - set the number of puppet bots
			tfbots <number> - set the TFBot quota (these bots use nav and can fight)
		Players
			heal [name/@red/@blue/@all] - heal yourself or players matching a given criterion or partial name string
			slay <name/@me/@red/@blue/@all> - kill players matching a given criterion or partial name string
			res - resurrect yourself in spawn
			raise - resurrect and teleport yourself to where you are spectating
		Transportation
			goto - teleport yourself to a given targetname. supports wildcard character *
			savepos - save your current position so you can teleport to it later
			back - teleport to your saved position
			stay <on/off> - when on, if alive just before the round restarts, you will be teleported back to the same place afterwards
			bring <name/@me/@red/@blue/@all> - teleport targets to your position
		Entities
			soundfrom <sound> [soundlevel] [volume] [channel] - play a sound from where you are looking. lets you find the right falloff distance
		Round/game
			restart - restart the game, or in Arena mode, slay everyone but yourself to cause a round restart

	How to use the script:
		Add the script to a named logic_script entity's vscripts field. You do not need to add matty/stocks2.nut.
		You will need to add your Steam3 id to the command user list. You can do this using Hammer I/O, or via the console at run-time.
		When running the map, you can type commands in chat.
		The options specified in the Features list can be turned on or off by typing the included command line in the listen server console.

	Setting options:
		You can type the commands listed under each feature in server console, changing values to true or false as you wish.
		Options are stored in global scope, which means they will not get reset when the round restarts.
		Alternatively, you can do it using outputs in Hammer. Simply send an input like this to any entity:
			RunScriptCode > worldspawn > deathrun_dev.option = true

	Adding and removing Steam3 ids to/from the command user list:
		Using Hammer I/O from an entity:
			Add a logic_relay and give it an OnSpawn output directed at any entity, such as the logic_script or worldspawn.
			The Steam3 id is a string, so it must be surrounded by backtick characters `. Add or remove an id using either of these inputs:
				RunScriptCode > deathrun_dev.AddCommandUser(`[U:1:1047392]`)
				RunScriptCode > deathrun_dev.RemoveCommandUser(`[U:1:1047392]`)
			Note that this output will be fired at the start of every round, so any changes you make during it are likely to be reset.
		Using the server console:
			You can type these commands into your client console when running the map locally in a listen server,
			or into the server console should you be running a dedicated server. Note the use of double quotes around ids:
				script deathrun_dev.AddCommandUser("[U:1:1047392]")
				script deathrun_dev.RemoveCommandUser("[U:1:1047392]")
			To list the contents of the id array in console, type:
				script DumpObject(deathrun_dev.command_user_ids)

	Running the map on a dedicated server, and distributing the map
		If running the map on a dedicated server, some options are not enabled by default.
		This is for convenience so you can distribute the map and not have to worry about features interfering with gameplay or being abused.
		You are still free to use the dev commands, but I strongly recommend against using them to cause a nuisance.
		It will likely annoy the server owner and break trust. It's not possible to change options without access to the server console.

	Notes:
		If a user is on the command user list, a reminder of the commands available to them will be printed in their console on round restart.
		The list is also printed to the dedicated server console.
		Effectiveness of the script's ability to change console variables and run console commands varies depending on
		whether the server is a dedicated or client/listen type, and how it's configured. Some things are less likely to work online.
*/

IncludeScript("matty/stocks2.nut");

if (!("deathrun_dev" in ROOT)) {
	ROOT.deathrun_dev <- {
		// take effect on round restart
		enable_cheats = !IsDedicatedServer() // enable cheats in a listen server
		sort_teams = !IsDedicatedServer() // sort teams on round restart. disabled for dedi servers that are assumed to be using a dr plugin
		make_me_activator = false
		faster_round_restart = !IsDedicatedServer() // shorten wait times at the start and end of rounds. disabled for dedis as it's assumed you want a real experience

		// take effect immediately
		dev_commands = true
		command_steam_ids = ["[U:1:1047392]"] // restrict debug commands to these steam ids

		CheckIdString = function(id) {
			if (typeof id != "string") {
				error("CheckIdString: id needs to be a string type. You gave a " + typeof id + "\n");
				return false;
			}
			if (!(startswith(id, "[U:1:") && endswith(id, "]"))) {
				error("CheckIdString: Not a valid id: " + id + ". Needs to be a Steam3 id format like [U:1:1047392]\n");
				return false;
			}
			return true;
		}
		AddCommandUser = function(id) {
			if (!CheckIdString(id)) return;
			local index = command_steam_ids.find(id);
			if (index == null) {
				command_steam_ids.append(id);
				printl("Added user id to debug commands authorised list: " + id);
			}
		}
		RemoveCommandUser = function(id) {
			if (!CheckIdString(id)) return;
			local index = command_steam_ids.find(id);
			printl("id: " + id + " index: " + index);
			if (index != null) {
				command_steam_ids.remove(index);
				printl("Removed user id from debug commands authorised list: " + id);
			}
		}

		// internal stuff
		events = {
			// debugging chat commands
			OnGameEvent_player_say = function(params) {
				if (!::deathrun_dev.dev_commands) return;
				local player = GetPlayerFromUserID(params.userid);
				local text = params.text;
				local args = split(text, " ", true);
				CheckCommand(player, args.remove(0), args, deathrun_dev_commands);
			}

			// store live player location on round end
			OnGameEvent_scorestats_accumulated_update = function(_) {
				local players = GetPlayers();
				foreach(player in players) {
					local data = GetDeathrunDevTable(player);
					if (!data.is_staying) continue;
					if (player.IsAlive()) {
						data.staying_pos = {
							pos = player.GetOrigin()
							ang = player.EyeAngles()
						}
					} else data.staying_pos = null;
				}
			}
		}
	}

	// hook events
	__CollectGameEventCallbacks(::deathrun_dev.events);
}

// bind events to script scope each round
foreach(name, callback in ::deathrun_dev.events) {
	::deathrun_dev.events[name] = callback.bindenv(this)
}

function OnPostSpawn() {
	// teleport stayers to their previous pos
	local players = GetPlayers();
	foreach(player in players) {
		local data = GetDeathrunDevTable(player);
		if (data.is_staying && data.staying_pos) {
			player.Teleport(true, data.staying_pos.pos, true, data.staying_pos.ang, false, Vector());
			ChatMsg(player, "Teleported you to your last position on the previous round");
		}
	}
}

// script functions
function CheatsEnabled() {
	return Convars.GetInt("sv_cheats");
}

/**
 * Attempt to set cheats on or off.
 * If the convar is not on the whitelist, the function will attempt to change the value by sending
 * a server command. It will return true if the command was sent. This should not be used as
 * confirmation that the convar has changed, as there will be a delat before it takes effect.
 * @param {bool} set Set to on or off
 * @return {bool} True if convar is on allow list and was changed, or if a command was sent
 */
function SetCheats(set) {
	local value = set ? 1 : 0;
	if (Convars.IsConVarOnAllowList("sv_cheats")) {
		Convars.SetValue("sv_cheats " + value);
		return true;
	} else {
		return ServerCommand("sv_cheats " + value); // note: server commands take a little while to change
	}
}

function SetConvar(convar, value) {
	// local old_value = Convars.GetStr(convar);
	// if (value.tostring() == old_value) return value; // no change needed

	if (Convars.IsConVarOnAllowList(convar)) {
		Convars.SetValue(convar, value); // set convar directly
		if (developer()) printl(__FILE__ + " Set ConVar " + convar + " to " + value + " directly");
	} else if (IsDedicatedServer()) {
		if (Convars.GetStr("sv_allow_point_servercommand") == "always") {
			SendToServerConsole(convar, value); // set convar via server command
			if (developer()) printl(__FILE__ + " Set ConVar " + convar + " to " + value + " via server command");
		} else {
			return false; // not allowed to send server commands
		}
	} else {
		SendToConsole(convar, value); // set convar on listen server
		if (developer()) printl(__FILE__ + " Set ConVar " + convar + " to " + value + " via client console command");
	}

	// local set_value = null;
	// if (typeof value == "integer") set_value = Convars.GetInt(convar);
	// else if (typeof value == "float") set_value = Convars.GetFloat(convar);
	// else if (typeof value == "string") set_value = Convars.GetString(convar);
	// else if (typeof value == "bool") set_value = Convars.GetBool(convar);
	// else set_value = Convars.GetStr(convar);
	// return value;

	return Convars.GetStr(convar) == value.tostring(); // return true if convar value is same as supplied value
}

/**
 * Send a command to dedicated or listen server console.
 * Note there is a delay after sending a command before the value is changed, so if you check
 * convar values immediately after setting them using a command, they may not have changed yet.
 * @param {string} command Command string including arguments
 * @return {bool} False if not allowed to send commands on a dedi server. True if you are allowed, or command was sent to client console
 */
function ServerCommand(command) {
	if (IsDedicatedServer()) {
		if (Convars.GetStr("sv_allow_point_servercommand") == "always") {
			SendToServerConsole(command);
		} else {
			return false; // not allowed to send server commands
		}
	} else {
		SendToConsole(command);
	}
	return true;
}
function GetDeathrunDevTable(player) {
	player.ValidateScriptScope();
	local scope = player.GetScriptScope();
	if (!("deathrun_dev" in scope)) {
		scope.deathrun_dev <- {
			saved_pos = null
			is_staying = false
			staying_pos = null
		}
	}
	return scope.deathrun_dev;
}

// teams stuff
function SwitchTeam(player, new_team) {
	player.ForceChangeTeam(new_team, true); // switch player to new team
	for (local child = player.FirstMoveChild(); child != null; child = child.NextMovePeer()) {
		if (child instanceof CEconEntity && child instanceof CBaseCombatWeapon == false) child.SetTeam(new_team); // change equipped cosmetic team
	}
}
function SortTeams(dr_activator) {
	local players = GetPlayers();
	foreach(player in players) {
		if (player.GetTeam() <= TEAM_SPECTATOR) continue;
		if (player == dr_activator) SwitchTeam(player, TF_TEAM_BLUE);
		else SwitchTeam(player, TF_TEAM_RED);
	}
}

// round restart stuff
if (deathrun_dev.enable_cheats) SetCheats(true);
if (deathrun_dev.sort_teams) {
	local dr_activator = null;
	local host_player = IsDedicatedServer() ? PlayerInstanceFromIndex(1) : GetListenServerHost();
	if (deathrun_dev.make_me_activator) {
		dr_activator = host_player;
	} else {
		local players = GetPlayers({
			participating = true
			sort = "userid"
		});
		local index = players.find(host_player);
		if (index != null) players.remove(index);
		if (players.len()) dr_activator = players[0]; // always choose the first player to make them easier to target
	}
	SortTeams(dr_activator);
	if (dr_activator) ChatMsg(null, dr_activator.CName() + " has been put in the activator's position");
}
if (deathrun_dev.faster_round_restart) {
	ServerCommand("mp_waitingforplayers_cancel 1"); // cancel waiting for players time
	SetConvar("tf_arena_preround_time", 5); // countdown at start of arena match
	SetConvar("mp_bonusroundtime", 5); // victory time
}
// note:
// script_wipeout executing script: deathrun/deathrun_dev.nut
// Cannot execute "sv_cheats 1", no player
// Cannot execute "mp_waitingforplayers_cancel 1", no player

function OnPostSpawn() {
	if (!IsDedicatedServer() && IsInArenaMode()) {
		printl(__FILE__ + " Setting deathrun appropriate ConVars");
		SetConvar("mp_teams_unbalance_limit", 0); // disable team balancing
		SetConvar("tf_arena_use_queue", 0); // disable arena queue
		SetConvar("tf_avoidteammates_pushaway", 0); // disable teammate pushaway solidity
	}
}
// note:
// IsInArenaMode() returns false when run on the first round of a map, on script run and in Precache.
// need to put it in OnPostSpawn. Maybe it relies on tf_gamerules.

// development commands
deathrun_dev_commands <- {
	// spawn a puppet bot
	bot = function(player, args) {
		local quantity = args.len() ? args[0].tointeger() : 1;
		quantity = quantity < 1 ? 1 : quantity; // clamp min

		local cheats_enabled = CheatsEnabled();
		if (!cheats_enabled) SetCheats(true); // no time to check for restult. assume cheats will turn on

		for (local i = 1; i <= quantity; i++) {
			ServerCommand("bot");
		}

		ReplyToCommand(player, "Attempting to spawn " + quantity + " puppet bots");
		if (!cheats_enabled) SetCheats(cheats_enabled);
	}

	// control puppet bot quota - bots <number>
	// todo: balance teams so it doesn't cause a round end when reducing
	bots = function(player, args) {
		if (!args.len()) {
			ReplyToCommand(player, "Usage: bots <quota>");
			return;
		}

		local cheats_enabled = CheatsEnabled();
		// if (!cheats_enabled && !SetCheats(true)) {
		// 	ReplyToCommand(player, "Unable to turn on cheats");
		// 	return;
		// }
		if (!cheats_enabled) SetCheats(true); // no time to check for restult. assume cheats will turn on

		local quantity = args[0].tointeger();
		quantity = quantity < 0 ? 0 : quantity; // clamp min

		local puppet_bots = [];
		for (local i = 1; i <= maxclients; i++) {
			local player = PlayerInstanceFromIndex(i);
			if (player && player.IsFakeClient() && !player.IsBotOfType(TF_BOT_TYPE)) puppet_bots.append(player);
		}

		local num_bots = puppet_bots.len();
		if (quantity == num_bots) return;
		if (quantity > num_bots) {
			local count = 0;
			for (local i = num_bots; i < quantity; i++) {
				if (ServerCommand("bot")) count++;
			}
			ReplyToCommand(player, "Attempting to spawn " + count + " puppet bots");
		} else if (quantity < num_bots) {
			local count = 0;
			while (puppet_bots.len() > quantity) {
				local bot = puppet_bots.pop();
				if (ServerCommand("bot_kick " + bot.Name())) count++;
			}
			ReplyToCommand(player, "Attempting to remove " + count + " puppet bots");
		}

		if (!cheats_enabled) SetCheats(false);
	}
	// tfbot (navbot) quote - tfbot <number>
	tfbots = function(player, args) {
		local quantity = args.len() ? args[0].tointeger() : 1;
		quantity = quantity < 0 ? 0 : quantity; // clamp min
		if (SetConvar("tf_bot_quota", quantity)) {
			ReplyToCommand(player, "Set TFBot quota to " + quantity);
		}
	}

	// heal yourself or given targets to full - heal [name/@red/@blue/@all]
	heal = function(player, args) {
		local heal_these = [];

		if (!args.len()) {
			heal_these.append(player); // heal command user when no args
		} else {
			heal_these = FindPlayersByName(args[0]);
			if (!heal_these.len()) {
				ReplyToCommand(player, "No player names found that matched the search string '" + args[0] + "'");
				return;
			}
		}

		local count = 0;
		heal_these = heal_these.filter(function(index, player) {
			if (!player.IsAlive()) return false;
			player.SetHealth(player.GetMaxHealth());
			ChatMsg(player, "You were healed to full");
			return true;
		});
		ReplyToCommand(player, "Healed " + heal_these.len() + " players");
	}
	// slay given targets - slay <name/@me/@red/@blue/@all>
	slay = function(player, args) {
		local slay_these = [];

		if (!args.len()) {
			ReplyToCommand(player, "Usage: slay name/@me/@red/@blue/@all");
			return;
		} else {
			if (args.len() == 1 && args[0] == "@me") {
				slaye_these.append(player);
			} else {
				slay_these = FindPlayersByName(args[0]);
				if (!slay_these.len()) {
					ReplyToCommand(player, "No player names found that matched the search string '" + args[0] + "'");
					return;
				}
			}
		}

		slay_these = slay_these.filter(function(index, player) {
			return player.IsAlive() && player.Die(true);
		})
		ReplyToCommand(player, "Slew " + slay_these.len() + " players");
	}
	// resurrect yourself in spawn
	res = function(player, args) {
		local raise = (args.len() && args[0] == "raise");

		if (!player.IsAlive() && player.GetTeam() > TEAM_SPECTATOR) {
			local pos = player.GetOrigin()
			local ang = player.EyeAngles()
			player.ForceRegenerateAndRespawn();
			if (raise) {
				player.Teleport(true, pos, true, ang, false, Vector());
			}
		}
	}
	// resurrect yourself to your current position
	raise = function(player, args) {
		CheckCommand(player, "res", ["raise"]);
	}

	// goto an entity targetname* - goto <targetname>
	goto = function(player, args) {
		if (!args.len()) {
			ReplyToCommand(player, "Usage: goto <entity name>");
			return;
		}
		local targetname = args[0].tostring();
		local ent = Entities.FindByName(null, targetname);
		if (!ent) {
			ReplyToCommand(player, "No entity found with the name '" + targetname + "'");
			return;
		}
		local ang = ent.GetAbsAngles();
		printl("Entity angles: " + ent + " " + ang);
		player.Teleport(true, ent.GetOrigin(), true, ent.GetAbsAngles(), true, Vector());
		ReplyToCommand(player, "Teleported you to " + ent.GetClassname() + " named " + ent.GetName());
	}
	// save your current position so you can go back there
	savepos = function(player, args) {
		if (!player) return; // not useable via console
		GetDeathrunDevTable(player).saved_pos <- {
			pos = player.GetOrigin()
			ang = player.EyeAngles()
		}
		ReplyToCommand(player, "Saved your current position");
	}
	// go back to your saved position
	back = function(player, args) {
		if (!player) return;
		local data = GetDeathrunDevTable(player);
		if (data.saved_pos) {
			player.Teleport(true, data.saved_pos.pos, true, data.saved_pos.ang, false, Vector());
			ReplyToCommand(player, "Teleported you to your saved pos");
		} else {
			ReplyToCommand(player, "You do not have a saved pos");
		}
	}
	// turn on or off being teleported back to your position at the end of the last round, if you were alive
	stay = function(player, args) {
		if (!player) return;
		local data = GetDeathrunDevTable(player);
		local on = false;
		if (!args.len()) {
			ReplyToCommand(player, "You are currently " + (data.is_staying ? "" : "not ") + "staying in your position on round restart");
			ReplyToCommand(player, "Usage: stay <on/off>");
		} else {
			on = (args[0] == "off") ? false : true;
			data.is_staying = on;
			ReplyToCommand(player, "You have turned " + (on ? "on" : "off") + " staying in place on round restart. Your position will be saved if you are alive");
		}
	}
	// bring
	bring = function(player, args) {
		local bring = [];

		if (!args.len()) {
			ReplyToCommand(player, "Usage: bring name/@red/@blue/@all");
			return;
		} else {
			bring = FindPlayersByName(args[0]);
			if (!bring.len()) {
				ReplyToCommand(player, "No player names found that matched the search string '" + args[0] + "'");
				return;
			}
		}

		local pos = player.GetOrigin();
		local ang = player.EyeAngles();
		foreach(target in bring) {
			if (target == player) continue;
			target.Teleport(true, pos, true, ang, true, Vector(0, 0, 0));
			ChatMsg(target, player.CName() + " brought you to them");
		}
		ReplyToCommand(player, "Brought " + bring.len() + " players to you");
	}

	// do
	// do = function(player, args) {
	// 	if (args.len() < 3) return ReplyToCommand(player, "Usage: <entity> <input> <parameters>");
	// }
	// run script code - lets you use backticks in chat
	// play a sound where you're looking
	soundfrom = function(player, args) {
		// get crosshair position
		// get sound from arg, or use a pre-set one
		// get soundlevel from arg, or just use 80
		// get volume from arg, or just use 1
		// arg 1 - sound
		// arg 2 - soundlevel
		// arg 3 - volume
		// print sound name, sound level and distance in reply
		// spawn a temporary icon or annotation at the point in the world
		if (!args.len()) return ReplyToCommand(player, "Play a sound from the point in the world your crosshair hits. Usage: soundfrom <sound> [soundlevel (integer)] [volume] [channel]");
		local sound_name = args[0];
		local sound_level = 80;
		local volume = 1.0;
		local channel = 0;
		if (args.len() == 2) sound_level = args[1].tointeger();
		if (args.len() == 3) volume = args[2].tofloat();
		if (args.len() == 4) channel = args[3].tointeger();
		local distance = 10000 * TraceLine(player.EyePosition(), player.EyePosition() + player.EyeAngles().Forward() * 10000, null);
		// ChatMsg(player, "TraceLine(player.EyePosition(), player.EyePosition() + player.EyeAngles().Forward() * 10000, null): " + (10000 * TraceLine(player.EyePosition(), player.EyePosition() + player.EyeAngles().Forward() * 10000, null)));
		local origin = player.EyePosition() + player.EyeAngles().Forward() * distance;
		PrecacheScriptSound(sound_name);
		EmitSoundEx({
			sound_name = sound_name
			sound_level = sound_level
			volume = volume
			origin = origin
		})
		DebugDrawLine(player.EyePosition(), origin, 0, 200, 255, false, 7.0);
		DebugDrawBox(origin, Vector(-4, -4, -4), Vector(4, 4, 4), 0, 200, 255, 150, 7.0);
		ReplyToCommand(player, "\x01Played \x05" + sound_name + " \x01with soundlevel \x05" + sound_level + " \x01from distance of \x05" + distance + " \x01on channel \x05" + channel);
		EntFire("worldspawn", "RunScriptCode", format("EmitSoundEx({ sound_name = `%s`, flags = SND_STOP })", sound_name), 7.0); // stop looping sounds
		// EntFire("worldspawn", "RunScriptCode", format("EmitSoundEx({ sound_name = `%s`, origin = Vector(%f, %f, %f), flags = SND_STOP })", sound_name, origin.x, origin.y, origin.z), 5.0); // stop looping sounds
	}

	// restart the round quickly
	restart = function(player, args) {
		if (IsInArenaMode()) { // slay everyone but the command user
			local remaining = LivePlayers().filter(function(index, elem) {
				if (elem == player) return false; // do not kill command user
				else return !elem.Die(true)
			});
			if (remaining.len()) ChatMsg(player, "Unable to kill " + remaining.len() + " players");
		} else { // call a normal round restart
			SendToConsole("mp_restartgame 1");
		}
	}
	// set team sorting - sorting on/off
	sorting = function(player, args) {
		if (!args.len()) return ReplyToCommand(player, "Team sorting is " + (deathrun_dev.sort_teams ? "on" : "off") + ". Usage: sorting <on/off>");
		local on = args[0] != "off";
		deathrun_dev.sort_teams = on;
		ReplyToCommand(player, "Team sorting has been switched " + (on ? "on" : "off"));
	}
	// rebalance = function(player, args) {
	// 	if (deathrun_dev.sort_teams) {
	// 		SortTeams(null);
	// 		return ReplyToCommand(player, "Teams have been resorted");
	// 	}
	// 	local players = LivePlayers();
	// 	local index = players.find(player);
	// 	if (index != null) players.remove(index); // remove command user so we don't switch their team
	// 	while (players.len()) {
	// 		local player = players[RandomInt(0, players.len() - 1)];
	// 		SwitchTeam(player, players.len() % 2 ? TF_TEAM_RED : TF_TEAM_BLUE);
	// 	}
	// 	return ReplyToCommand(player, "Players have been shuffled");
	// }
};

// check the command exists and can be used by this id then execute it
function CheckCommand(player, _command, args, commands) {
	if (!(_command in commands)) return;

	local command = commands[_command];
	local commands_restricted = (deathrun_dev.command_steam_ids.len());
	local steamid_authorised = player == null ? true : (deathrun_dev.command_steam_ids.find(player.SteamId()) != null);

	// check command steamid restriction or if source is server console (player == null)
	if (player == null || !commands_restricted || (commands_restricted && steamid_authorised)) {
		if (typeof command == "function") { // command is just a function
			command(player, args);
		} else {
			foreach(key, val in command) { // execute all functions in the command
				if (typeof val == "function") {
					val(player, args);
				}
			}
		}
	}
};


// print debug commands
function PrintDebugCommands() {
	local players = GetPlayers();
	local commands_restricted = (deathrun_dev.command_steam_ids.len());
	local message = "Development commands enabled:";
	local command_list = "";
	foreach(key, val in deathrun_dev_commands) {
		command_list += key + ", ";
	}

	// print to authorised players
	foreach(player in players) {
		local steamid_authorised = (deathrun_dev.command_steam_ids.find(player.SteamId()) != null);
		if (!commands_restricted || (commands_restricted && steamid_authorised)) {
			ClientPrint(player, HUD_PRINTCONSOLE, message);
			ClientPrint(player, HUD_PRINTCONSOLE, command_list);
		}
	}
	// print to server console
	printl(message);
	printl(command_list);
}
if (::deathrun_dev.dev_commands) PrintDebugCommands();

// get an array of player instances with names matching a pattern
function FindPlayersByName(pattern) {
	local players = [];
	if (pattern == "@red") players = GetReds(); // @red
	else if (pattern == "@blue") players = GetBlues(); // @blue
	else if (pattern == "@all") players = GetPlayers(); // @all
	else { // name match
		for (local i = 1; i <= maxclients; i++) {
			local player = PlayerInstanceFromIndex(i);
			if (player && player.IsValid() && player.Name().tolower().find(pattern.tolower()) != null) {
				players.append(player);
			}
		}
	}
	return players;
}

// send text to server console if player == null, else to player's chat
function ReplyToCommand(player, text) {
	if (player == null) {
		printl(text);
	} else {
		ClientPrint(player, HUD_PRINTTALK, text);
	}
}

/*
	Todo
	Find out why tf_arena_use_queue is not being set until players spawn
*/

/*
	Knowledge:
	Each script is executed as it's read from the vscripts field of the entity.
	Precache() is apparently called after all scripts have been executed.
	OnPostSpawn() is apparently called after all round restart entities have spawned.
*/