/**
 * Matty's Deathrun Boss Bar
 * Version 0.2
 *
 * Features:
 * - Supports variable number of blues
 * - Remembers overhealed max health
 * - Colours bar green when all blues ubered
 * - Bar disables on round win
 * - Detects outside interference from plugins and disables itself
 * - Can monitor health of non-player entities added to the array
 *
 * How to use:
 * Add the script to a logic_script entity
 * If using only with blue players:
 *      CallScriptFunction StartBlueBossBar
 * If using with non-player entities:
 *      RunScriptCode AddEntToBar(arg)
 *      For arg, supply either an entity targetname (it will pick up all entities named the same)
 *      or an entity instance (you will know what this is if you are a VScript coder)
 *      CallScriptFunction StartBossBar
 * Note that you can add a mixture of players and non-player entities if you wish
 * Call DisableBar to hide it, and EnableBar to show it again.
 * The bar will disable itself on round win or when there are no valid entities in the array.
 * You do not need to do anything on round restart because the logic_script is killed and recreated by the game.
 */

/*
	Changelog
	0.2.1
		* Fix: An infinite loop caused by the script disabling and hiding the bar repeatedly when it
			detected outside interference. This produced console spam, which caused servers to freeze.
		* Change: When outside interference is detected, and the script disables itself, it will
			no longer change the bar's value in order to hide it. This allows the bar to continue
			displaying the value provided by the outside input with no visual disruption.
*/

// Options
local auto_color = true; // auto colour the bar green when all blues are in uber condition
local debug = false; // debug messages. set this to false for release

// Constants
team_blue <- Constants.ETFTeam.TF_TEAM_BLUE;
round_state_win <- Constants.ERoundState.GR_STATE_TEAM_WIN;
cond_uber <- Constants.ETFCond.TF_COND_INVULNERABLE;

// Variables
local enabled = false;
local bar_ents = [];
local peak_health = 0.0;
local prev_bar_val = 0;
local bar = Entities.FindByClassname(null, "monster_resource");
Assert((bar != null && bar.IsValid()), self + " monster_resource not found. Can't use boss bar"); // quit at this point of it doesn't exist

/**
 * Inputtable functions
 * --------------------------------------------------------------------------------
 */

/**
 * Start the boss bar
 * Fills the entity array with blue players
 * You only need to call this once. Calling it again will reset the array and peak health figure
 */
function StartBlueBossBar() {
	if (!IsBarValid()) {
		printl(__FILE__ + " Unable to start boss bar as the monster_resource is not present! Disabling");
		DisableBar();
		return;
	}

	peak_health = 0.0;
	bar_ents = GetTeamPlayers(team_blue);
	EnableBar();
}

/**
 * Start the boss bar with the entities in the array
 * You only need to call this once. Calling it again will reset the array and peak health figure
 */
function StartBossBar() {
	if (!IsBarValid()) {
		printl(__FILE__ + " Unable to start boss bar as the monster_resource is not present! Disabling");
		DisableBar();
		return;
	}

	if (bar_ents.len() == 0) {
		printl(__FILE__ + " Entity array is empty. Add some entities to monitor the health of then try again")
		return;
	}

	peak_health = 0.0;
	EnableBar();
}

/**
 * Add an entity to the bar ents array
 * The single argument accepts either targetname string or entity instance
 * @param {string} ent Targetname of ent ent(s) to add
 * @param {instance} ent Entity instance to add
 */
function AddEntToBar(ent) {
	if (typeof ent == "string") {
		local i = null;
		while (i = Entities.FindByName(i, ent)) {
			if (NetProps.HasProp(i, "m_iHealth")) {
				bar_ents.push(i);
				if (debug) printl(__FILE__ + " pushed " + i + " to bar ents array");
			} else {
				printl(__FILE__ + " entity " + i + " doesn't have a health property. Not adding");
			}
		}
	} else if (typeof ent == "instance" && ent.IsValid()) {
		if (NetProps.HasProp(ent, "m_iHealth")) {
			bar_ents.push(ent);
			if (debug) printl(__FILE__ + " pushed " + ent + " to bar ents array");
		} else {
			printl(__FILE__ + " entity " + ent + " doesn't have a health property. Not adding");
		}
	}
}

/**
 * Remove an entity from the bar ents array
 * The single argument accepts either targetname string or entity instance
 * @param {string} ent Targetname of ent ent(s) to remove
 * @param {instance} ent Entity instance to remove
 */
function RemoveEntFromBar(ent) {
	if (typeof ent == "string") {
		for (local i = bar_ents.len() - 1; i >= 0; i--) {
			if (!bar_ents[i].IsValid() || bar_ents[i].GetName() == ent) {
				bar_ents.remove(i);
				if (debug) printl(__FILE__ + " removed " + i + " from bar ents array");
			}
		}
	} else if (typeof ent == "instance" && ent.IsValid()) {
		local index = bar_ents.find(ent);
		if (index != null) {
			bar_ents.remove(index);
			if (debug) printl(__FILE__ + " removed " + ent + " from bar ents array");
		}
	}
}

/**
 * Enable the bar. This is called internally and you do not need to call it
 * unless you hid the bar using DisableBar().
 */
function EnableBar() {
	if (!enabled) {
		enabled = true;
		AddThinkToEnt(self, "Think"); // add the think
		if (debug) printl(__FILE__ + " enabled bar");
	}
}

/**
 * Hide the bar.
 * This is called internally when there is a problem or when the round ends.
 */
function DisableBar(hide_bar = true) {
	if (enabled) {
		enabled = false;
		AddThinkToEnt(self, ""); // remove the think
		if (hide_bar) {
			SetBarValue(0);
		}
		if (debug) printl(__FILE__ + " disabled bar");
	}
}


/**
 * Think
 * --------------------------------------------------------------------------------
 */

function Think() {
	local data = GetMembersData(); // table of health, max health and all-ubered bool

	// Disable on round win, or if bar not valid, or no health data returned due to no valid entities
	if (GetRoundState() == round_state_win || !IsBarValid() || data == null) {
		DisableBar();
		return;
	}

	if (GetBarValue() != prev_bar_val) {
		printl(__FILE__ + " Outside interference with monster_resource bar value detected. Disabling");
		DisableBar(false);
		return;
	}

	// Account for overheal
	if (data.health > data.max_health) {
		data.max_health = data.health;
	}

	// Set peak
	if (data.max_health > peak_health) {
		peak_health = data.max_health;
	}

	SetBarValue(data.health, peak_health);

	if (auto_color) {
		if (data.ubered) {
			SetBarColor(1);
		} else {
			SetBarColor(0);
		}
	}
}


/**
 * Array
 * --------------------------------------------------------------------------------
 */

/**
 * Get health and max health from entities in the array
 * @return {table} Table of health (int), max health (int) and all-ubered status (bool). Or null if no changes (no valid ents)
 */
function GetMembersData() {
	local data = {
		health = 0
		max_health = 0
		ubered = true
	};

	// todo: handle removal of invalid entities? or just check isvalid?
	foreach(ent in bar_ents) {
		if (!ent.IsValid()) {
			continue;
		} else if (ent.IsPlayer()) // handle player
		{
			local player = ent;

			// account for players who have switched team
			if (player.GetTeam() != team_blue) {
				continue;
			}

			data.health += IsPlayerAlive(player) ? player.GetHealth() : 0; // return 0 health if dead
			data.max_health += player.GetMaxHealth();

			if (!player.InCond(cond_uber)) {
				data.ubered = false;
			}
			// had to disable this because I don't know how to get a math_counter's value in VScript
			// } else if (ent.GetClassname() == "math_counter") {
			// data.health += NetProps.GetPropFloat(ent, "m_OutValue").tointeger();
			// data.max_health += NetProps.GetPropFloat(ent, "m_flMax").tointeger();
			// data.ubered = false;
		} else {
			data.health += ent.GetHealth();
			data.ubered = false;

			if (NetProps.HasProp(ent, "m_iMaxHealth")) { // todo: does every entity that has m_iHealth also have m_iMaxHealth?
				data.max_health += ent.GetMaxHealth();
			} else {
				data.max_health += ent.GetHealth();
			}
		}

		return data; // table will be null if no values were changed
	}
}


/**
 * Bar
 * --------------------------------------------------------------------------------
 */

function IsBarValid() {
	return (bar != null && bar.IsValid());
}

/**
 * Sets the value of the monster_resource bar.
 *
 * @param {integer} val Health value
 * @param {integer} max Maximum health value
 */
function SetBarValue(val, max = 255) {
	if (!IsBarValid()) {
		DisableBar();
		return;
	}

	val = ((val.tofloat() / max) * 255).tointeger();
	val = Clamp(val, 0, 255);
	NetProps.SetPropInt(bar, "m_iBossHealthPercentageByte", val);
	prev_bar_val = val;
	if (debug) printl(__FILE__ + " bar value set to " + val);
}

/**
 * Retrieves the bar value from the monster_resource netprop
 * @return {integer} Bar value from 0-255
 */
function GetBarValue() {
	return NetProps.GetPropInt(bar, "m_iBossHealthPercentageByte");
}

/**
 * Set the bar colour.
 * 0 = default blue, 1 = green.
 * Green is used in Merasmus when he hides and cannot be attacked.
 * @param {integer} color 0 for blue, 1 for green
 */
function SetBarColor(color = 0) {
	if (IsBarValid()) {
		NetProps.SetPropInt(bar, "m_iBossState", color);
	}
}


/**
 * Helpers
 * --------------------------------------------------------------------------------
 */

function Clamp(value, min, max) {
	if (value <= min) {
		value = min;
	} else if (value >= max) {
		value = max;
	}

	return value;
}

/**
 * Return an array of players on a team, optionally only those alive
 * @param {number} team - Team number
 * @param {bool} alive - Only return alive players
 * @returns {array} - Array of player handles
 */
function GetTeamPlayers(team, alive = false) {
	local players = [];
	local maxclients = MaxClients();

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player == null) continue;

		if (player.GetTeam() == team) {
			if (alive == true && player.IsAlive()) {
				players.push(player);
			} else if (alive == false) {
				players.push(player);
			}
		}
	}

	return players;
}

/**
 * Checks if a player is alive
 * @param {player} player - Handle to the player
 * @returns {bool} - True if the player is alive, false otherwise
 */
function IsPlayerAlive(player) {
	return NetProps.GetPropInt(player, "m_lifeState") == 0;
}


/*
Old Boss bar development notes

Used for activator fights
Supports health changes from all activators
Adjusts max health pool dynamically (optionally supports overheal)
Green mode for special attacks or ability attacks

Copy code from DTK

Create an array of the players (or entities?) we want to monitor the health of
Every frame (0.1 second) iterate over entities to get their max health and health
Maybe use OnTakeDamage if it shows all damage and healing?
Use it to modify the boss bar
Have a boolean to toggle the system
Have an optional timer to hide it after ten seconds
Have optional game_text
Have a boolean to set the colour green
Optionally colour it green if the top-most entity is an entity (not a player)
Optionally hide during round win or pre-round
Optionally make the bar green if there is one member and it's ubered
Disable on round end or when activators are dead
Remove null entities from list
*/