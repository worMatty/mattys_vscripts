/*
	Commands v0.1 by worMatty
	-------------------------

	* Add multiple groups of commands
	* Add or remove Steam ids at runtime
	* Helper functions for checking Steam 3 ids, replying to a command and finding players by name (like Source Pawn)

	How to use:
	1. Put commands.nut and stocks2.nut in scripts/vscripts/matty
	2. Copy commands_list.nut to scripts/vscripts/mapname. Add your commands to that file and set any Steam ids.
		Alternatively you can copy the code into your own map script file.
	3. If you are a mapper and wish to use entities to add scripts:
			Add commands.nut and your modified command_list.nut to a logic_script's vscripts field in that order.
		If you make your own scripts:
			Ensure commands.nut is included before executing the command group code/command_list.nut.
	5. In-game, execute commands in text chat by typing the command with arguments after it:
			`mycommand arg1 arg2`
		In the client or server console, you must prefix the command line with the 'say' command:
			`say mycommand arg1 arg2`

	Permissions
		By default command groups are restricted to their set Steam ids. They are not open for all players to use.
		This is because the command script was created with the idea of it being used by map authors to test things.
		If you wish to allow all players to use a group's commands you can set this in the group's table in command_list.nut.

		You can add root Steam ids for users who need permission to execute *all* commands in *all* groups.
		This is intended for use by the map author and trusted development partners.
		Dedicated server console is allowed to execute any command, provided the group is enabled.
*/

/*
	Advanced stuff
	--------------

	In all of the following function calls, if you are executing them using entity logic/IO, send them to the logic_script
	entity using RunScriptCode, with the function calls as the parameter. Use `backticks` for string quotes.
	Scripts should instead use "double quotes".

	Enabling and disabling command groups at runtime:
		A command group can be turned on or off at any time. Disabling it prevents its commands being used by anyone.
			m_commands.EnableCommandGroup(`group_name_string`)
			m_commands.DisableCommandGroup(`group_name_string`)
		A command group is enabled by default when created unless you set it to be disabled in its table.
		Ordinarily, each command group will be recreated on round restart when the logic_script is created and its scripts run.
		This means a group that was disabled or enabled on the previous round will be reset to its default state on the next.

	Adding and removing Steam ids to a group at runtime:
		You may wish to grant permission to users when they achieve something in a map, or revoke it them when they die.
		In the following examples, 'player' can either be a Steam id 3 string (`[U:1:1234567890]`) or a player handle.
			m_commands.AddCommandGroupUser(`group_name_string`, player)
			m_commands.DeleteCommandGroupUser(`group_name_string`, player)
		Note that command groups are usually recreated on round restart so your permissions will need to be reapplied.

	Notes:
	* The player_say event is hooked once on script setup. Do not delete all events using ClearGameEventCallbacks.
	* Scripters, see the documentation for each function below.
	* You can use this in server console to see an overview of added command groups:
		m_commands.DumpCommands()
*/

// set up command system on first run
IncludeScript("matty/stocks2.nut");
if ("m_commands" in ROOT) return;
ROOT.m_commands <- {
	command_groups = {}
	steam_ids = [] // root steam ids
	events = {
		OnGameEvent_player_say = function(params) {
			local player = GetPlayerFromUserID(params.userid);
			local text = params.text;
			local args = split(text, " ", true);
			m_commands.CheckCommand(player, args.remove(0), args);
		}
	}
}
__CollectGameEventCallbacks(m_commands.events); // hook player_say event only once.

/**
 * Add a command group
 * @param {string} group_name Command group name. Will be used as the table slot name
 * @param {table} data Table of command data
 * @param {table} scope Script scope/environment to bind all command functions to. If any commands reference functions or variables in the script, supply self.GetScriptScope()
 * @param {array} steam_ids Optionally add permitted steam ids from an array
 */
m_commands.AddCommandGroup <- function(group_name, data, scope = null, steam_ids = null) {
	if (typeof group_name != "string") return error(__FILE__ + " AddCommandGroup needs a string for the group name but you provided a " + (typeof group_name) + "\n");
	if (typeof data != "table") return error(__FILE__ + " AddCommandGroup needs a table of command data but you provided a " + (typeof data) + "\n");
	if (!("group_name" in command_groups)) { // TODO: why am i checking this?
		// command group default values
		command_groups[group_name] <- {
			enabled = true // toggle the whole group on or off
			id_required = true // only useable by players with a matching steam id, or console
			commands = {}
			steam_ids = []
		};
	}
	if (!scope) scope = this;
	local AddSteamIds = function(ids) {
		if (typeof ids == "string") ids = [ids];
		foreach(id in ids) AddCommandGroupUser(group_name, id);
	}
	foreach(key, val in data) {
		if (key == "id_required") command_groups[group_name].id_required = val;
		else if (key == "steam_ids") AddSteamIds(val);
		else {
			try {
				// deprecated code supporting multiple command functions in one
				// if (typeof val == "function") { // command contains a function
				// 	command_groups[group_name].commands[key] <- val.bindenv(scope);
				// } else { // command contains a table, containing functions
				// 	command_groups[group_name].commands[key] <- val;
				// 	local command = command_groups[group_name].commands[key];
				// 	foreach(key, val in command) if (typeof val == "function") command[key] <- val.bindenv(scope);
				// }
				command_groups[group_name].commands[key] <- val.bindenv(scope); // just add one function per command
			} catch (e) error(__FILE__ + " Error trying to add command with key " + key + ". Type of val is " + (typeof val) + ". Exception: " + e + "\n");
		}
	}
	if (developer()) printf("%s Added %d commands in group %s\n", __FILE__, command_groups[group_name].commands.len(), group_name);
	if (steam_ids) AddSteamIds(steam_ids);
}

/**
 * Delete a command group
 * @param {string} group_name Command group name to delete
 */
m_commands.DeleteCommandGroup <- function(group_name) {
	if (group_name in command_groups) {
		delete command_groups[group_name];
		if (developer()) printl(__FILE__ + " Deleted command group " + group_name);
	}
}

/**
 * Enable a disabled command group
 * @param {string} group_name Command group name
 */
m_commands.EnableCommandGroup <- function(group_name) command_groups[group_name].enabled = true

/**
 * Disable a command group
 * @param {string} group_name Command group name
 */
m_commands.DisbleCommandGroup <- function(group_name) command_groups[group_name].enabled = false

/**
 * Check a Steam 3 id string for expected characters to ensure input isn't garbage
 * @param {string} id Steam 3 id
 * @return {bool} True if id format is valid
 */
m_commands.CheckSteam3IdString <- function(id) {
	if (typeof id != "string") return error(__FILE__ + " id needs to be a string type. You gave a " + typeof id + "\n");
	if (!(startswith(id, "[U:1:") && endswith(id, "]"))) return error(__FILE__ + " Not a valid id: " + id + ". Needs to be a Steam3 id format like [U:1:1047392]\n");
	return true;
}

/**
 * Add a Steam 3 id to a command group, giving the user permission to execute its commands
 * @param {string} group_name Command group name
 * @param {string/CTFPlayer} input Steam 3 id or player handle
 */
m_commands.AddCommandGroupUser <- function(group_name, input) {
	if (input instanceof CTFPlayer) input = input.SteamId();
	if (!CheckSteam3IdString(input)) return;
	if (!(group_name in command_groups)) return error(__FILE__ + " No command group named '" + group_name + "'\n");
	local index = command_groups[group_name].steam_ids.find(input);
	if (index == null) {
		command_groups[group_name].steam_ids.append(input);
		if (developer()) printf("%s Added Steam3 id %s to command group %s\n", __FILE__, input, group_name);
	}
}

/**
 * Remove a Steam 3 id from a command group, removing the user's permission to execute its commands
 * @param {string} group_name Command group name
 * @param {string/CTFPlayer} input Steam 3 id or player handle
 */
m_commands.DeleteCommandGroupUser <- function(group_name, input) {
	if (input instanceof CTFPlayer) input = input.SteamId();
	if (!CheckSteam3IdString(input)) return;
	if (!(group_name in command_groups)) return error(__FILE__ + " No command group named '" + group_name + "'\n");
	local index = command_groups[group_name].steam_ids.find(input);
	if (index != null) {
		command_groups[group_name].steam_ids.remove(index);
		if (developer()) printf("%s Removed Steam3 id %s from command group %s\n", __FILE__, input, group_name);
	}
}

/**
 * Add a Steam 3 id to the root steam id array, giving the user permission to execute all commands
 * @param {string/CTFPlayer} input Steam 3 id or player handle
 */
m_commands.AddRootUser <- function(input) {
	if (input instanceof CTFPlayer) input = input.SteamId();
	if (!CheckSteam3IdString(input)) return;
	local index = steam_ids.find(input);
	if (index == null) {
		steam_ids.append(input);
		if (developer()) printf("%s VScript chat commands: Added Steam3 id %s as root user\n", __FILE__, input);
	}
}

/**
 * Remove a Steam 3 id from the root steam id array, removing the user's permission to execute all commands
 * @param {string/CTFPlayer} input Steam 3 id or player handle
 */
m_commands.DeleteRootUser <- function(input) {
	if (input instanceof CTFPlayer) input = input.SteamId();
	if (!CheckSteam3IdString(input)) return;
	local index = steam_ids.find(input);
	if (index != null) {
		steam_ids.remove(index);
		if (developer()) printf("%s VScript chat commands: Removed Steam3 id %s as root user\n", __FILE__, input);
	}
}

/**
 * Check a player's access to a command and execute it
 * @param {CTFPlayer} player Player handle
 * @param {string} command_name Command name retrieved from chat
 * @param {array} args Array of arguments
 */
m_commands.CheckCommand <- function(player, command_name, args) {
	foreach(group in command_groups) {
		if (!group.enabled || !(command_name in group.commands)) continue; // group disabled, or command not in group
		local command = group.commands[command_name];
		local authorised = (!player || !group.id_required) ? true : (group.steam_ids.find(player.SteamId()) != null || m_commands.steam_ids.find(player.SteamId()) != null); // if player == null, it's the server console
		if (!authorised) continue;
		// if (typeof command == "function") command(player, args); // deprecated
		// else foreach(key, val in command) if (typeof val == "function") val(player, args); // deprecated
		command(player, args);
	}
};

/**
 * Dump command group data to console
 */
m_commands.DumpCommands <- function() {
	local num_groups = m_commands.command_groups.len();
	if (!num_groups) return printl("No command groups");
	printl("Number of command groups: " + num_groups);
	foreach(key, val in m_commands.command_groups) {
		printl("  Command group: \"" + key + "\" contains " + val.commands.len() + " commands");
		if (val.commands.len()) {
			local buffer = "    Commands: ";
			foreach(key, val in val.commands) buffer += key + ", ";
			printl(buffer);
		}
		printl("    Enabled: " + val.enabled);
		printl("    Restricted: " + val.id_required);
		if (!val.steam_ids.len()) printl("    No Steam ids added");
		else {
			local buffer = "    Steam ids: ";
			foreach(id in val.steam_ids) buffer += id + ", ";
			printl(buffer);
		}
	}
};

/**
 * Get an array of player instances with names matching a pattern
 * @param {CTFPlayer} player Player making the request
 * @param {string} pattern Name pattern to check
 * @return {array} Array of player instances whose names match the target string
 */
::FindPlayersByName <- function(player, pattern) {
	local players = [];
	if (pattern == "@me") players.append(player);
	else if (pattern == "@red") players = GetReds();
	else if (pattern == "@blue") players = GetBlues();
	else if (pattern == "@all") players = GetPlayers();
	else { // name match
		for (local i = 1; i <= maxclients; i++) {
			local player = PlayerInstanceFromIndex(i);
			if (player && player.IsValid() && player.Name().tolower().find(pattern.tolower()) != null) {
				players.append(player);
			}
		}
	}
	return players;
};

/**
 * Send text to server console if player == null, else to player's chat
 * @param {CTFPlayer} player Player handle
 * @param {string} formatting Formatting parameters
 * @param {array} ... Variable array of formatting arguments
 */
::ReplyToCommand <- function(player, formatting, ...) {
	vargv.insert(0, formatting);
	vargv.insert(0, this);
	local buffer = format.acall(vargv);
	if (!player) printl(buffer);
	else ClientPrint(player, HUD_PRINTTALK, buffer);
};