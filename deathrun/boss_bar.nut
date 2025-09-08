/**
 * Matty's Deathrun Boss Bar
 * Version 0.2.1
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
 * I suggest you only call the functions when they are needed and not on round start.
 */

/*
	Matty's Deathrun Boss Bar
	Version 1.0

	Easy way to display the combined HP of one or more live blue players
	using the built-in Merasmus boss bar.
	The script can also monitor the health of any non-player entities with a health property.
	You can add as many ents as you like and even mix players with non-player entities.
	Useful for MvM tanks, base_boss or even brush-based 'fake' bosses.

	Other features:
	* Correctly accounts for overhealing
	* Optionally colour the bar green if the blue players are invulnerable due to uber cond
	* Shuts itself off if it detects outside interference, such as from a server plugin
	* Optionally fall back to a text-based display using game_text, should interference be detected
	* Alternatively you can enable the text display right away

	Usage:
	1. Add the script to a logic_script entity
	2. If you just want to display the bar for blues, send it CallScriptFunction > StartBlueBossBar
	3. If you want to use the bar for non-player entities, send the logic_script RunScriptCode >
		AddEntToBar(ent), where 'ent' is the targetname string of one or more entities,
		or an entity instance, or an array of targetnames and/or entity instances.
		Then send CallScriptFunction > EnableBar to start showing the bar.
		Dead players, disconnected players and entities that have been killed are removed from the bar array.
	* You can send the logic_script CallScriptFunction > DisableBar to hide it, and EnableBar to show it again.
	* You can remove entities from the bar manually using RunScriptCode > RemoveEntFromBar(ent)

	Setting options:
		Auto Color:
			To disable automatic colouring of the Merasmus bar to green when all players are ubered,
			send the logic_script RunScriptCode > auto_color = false
		Fall back to text mode:
			If you are monitoring the health of an entity such as a tank_boss or base_boss, or any other
			entity with a health property, you may find that the Deathrun server's deathrun plugin
			takes control of the Merasmus boss bar to display the health of the blue players.
			This script can fall back to a text display that sits underneath the Merasmus bar.
			To enable this feature, send the logic_script the following input:
			RunScriptCode > text_mode_fallback = true
			It's best to set this before you start to use the bar.

	Extra:
	* If you wish to add entity(s) to the bar and display it straight away, you can pass it/them in the
		argument of EnableBar like so: RunScriptCode > EnableBar(`tank_boss`)
		Note that this function and AddEntToBar support the wildcard suffix (*) in the targetname string!
*/

/*
	Changelog
	1.0
		* Automatic fallback to a game_ui text display when monster_resource bar is being interfered with
		* The text mode display can be switched between block characters and a number
		* The text display is prefixed with the single blue player's name, or 'Blue' with more
		* Consolidated functionality into fewer functions
		* EnableBar can now take a targetname, instance or array of either to replace the bar array with
		* Code refactoring. monster_resource and game_text are wrapped in a class
		* Function to switch to text mode manually
	0.2.1
		* Fix: An infinite loop caused by the script disabling and hiding the bar repeatedly when it
			detected outside interference. This produced console spam, which caused servers to freeze.
		* Change: When outside interference is detected, and the script disables itself, it will
			no longer change the bar's value in order to hide it. This allows the bar to continue
			displaying the value provided by the outside input with no visual disruption.
*/

// options
auto_color <- true; // auto colour the monster resource bar green when all blues are in uber condition
text_mode_fallback <- false; // fall back to text mode if the monster_resource value is changed externally
text_params <- {}; // user-supplied settings for the text bar. see TextBar class

// constants
local team_blue = Constants.ETFTeam.TF_TEAM_BLUE;
local round_state_win = Constants.ERoundState.GR_STATE_TEAM_WIN;
local cond_uber = Constants.ETFCond.TF_COND_INVULNERABLE;

// vars
local enabled = false;
local bar = null; // monster_resource entity
local bar_ents = []; // bar members
local peak_health = 0.0; // highest recorded health including overheal
local text_mode = false; // using a text-based bar instead
text <- null; // text fallback ent

/**
 * Wrapper for the monster_resource entity
 */
class MonsterResource {
	constructor(_entity) {
		entity = _entity;
		prev_value = GetValue();
		if (developer()) printl(__FILE__ + " -- Created MonsterResource class instance for " + entity + ". Current value: " + prev_value);
	}

	entity = null;
	prev_value = null; // used in comparison to detect outside interference

	/**
	 * Sets the value of the monster_resource bar
	 * @param {integer} health Health value
	 * @param {integer} max_health Maximum health value
	 */
	function SetValue(health, max_health) {
		health = ((health.tofloat() / max_health) * 255).tointeger(); // map value to a 255 range
		local value = (health < 0) ? 0 : (health > 255) ? 255 : health; // clamp between 0 and max_health
		NetProps.SetPropInt(entity, "m_iBossHealthPercentageByte", value);
		prev_value = value;
	}

	/**
	 * Retrieve the bar value from the monster_resource netprop
	 * @return {integer} Bar value from 0-255
	 */
	function GetValue() {
		return NetProps.GetPropInt(entity, "m_iBossHealthPercentageByte");
	}

	/**
	 * Check if the current value is different to the previously-recorded value.
	 * If they are not the same, it's likely the monster_resource has had its
	 * value altered by something else, like a server plugin.
	 * @return {bool} True if the values don't match
	 */
	function InterferedWith() {
		return (GetValue() != prev_value);
		// note: you must surround the expression in brackets if you wish to return a bool
		// or the VM will return the value of the first item
	}

	/**
	 * Set the bar colour.
	 * 0 = default blue, 1 = green.
	 * Green is used in Merasmus when he hides and cannot be attacked.
	 * @param {integer} color 0 for blue, 1 for green
	 */
	function SetColor(color = 0) {
		NetProps.SetPropInt(entity, "m_iBossState", color);
	}
}

/**
 * Wrapper for game_text
 * @param {table} params Table of optional parameter overrides. Supply entity keyvalues in a table named `keyvalues`
 * @param {CBaseEntity} _entity Optional existing game_text* entity to use
 */
class TextBar {
	constructor(params = null, _entity = null) {
		// default parameters
		local keyvalues = {
			channel = 2
			effect = 0 // 0 = fade in/out. 1 = credits. 2 = scan out (typed in then faded out)
			holdtime = this.update_rate
			fadein = 0 // fade-in time, or time per character in scan-out effect
			fadeout = 0.1 // fade out time, after hold time. 0.1 accounts for slight gaps between refreshes
			fxtime = 0 // length of time to scan all letters in the scan effect
			color = "123 190 242 255" // blue
			color2 = "0 0 0" // scan effect character scan colour
			spawnflags = 1 // 1: all players, 0: activator
			x = 0.415
			y = 0.16
		}

		// set class properties
		if (typeof params == "table") {
			foreach(key, val in params) {
				if (key == "keyvalues") { // user supplied custom keyvalues
					foreach(key, val in val[key]) {
						keyvalues[key] <- val;
					}
					continue;
				}
				if (key in this) { // user supplied custom class members
					this[key] = val;
				}
			}
		}

		// set or create text entity
		if (_entity && _entity.IsValid() && startswith(entity.GetClassname(), "game_text")) {
			entity = _entity; // user supplied their own game_text*
		} else {
			entity = SpawnEntityFromTable("game_text", keyvalues); // create a new game_text
		}
	}

	entity = null;
	enable = false;
	name = null; // word to prefix the bar
	blocks = true; // use block characters instead of numbers
	update_rate = 1.0; // used for hold time and for the script update think

	/**
	 * Display a message using the text bar
	 * @param {string} message Message to display
	 */
	function DisplayMessage(message) {
		entity.KeyValueFromString("message", message); // todo: check my game_text script to see if this is the best way
		entity.AcceptInput("Display", null, null, null);
	}

	/**
	 * Construct a message from the data and display it
	 * @param {table} data Table of data
	 */
	function Update(data) {
		local message = null;

		// format prefix
		if (!name && data.all_players) {
			if (data.members == 1) { // single player
				local player = bar_ents[0];
				message = NetProps.GetPropString(player, "m_szNetname") + ": ";
			} else {
				message = "Blue: " // team name
			}
		}

		// format value
		if (blocks) {
			local num_blocks = ceil(data.health.tofloat() / data.max_health * 10);
			// todo: overheal may screw with this
			for (local i = 0; i < num_blocks; i++) {
				message += "▋";
			}
		} else {
			message += data.health;
		}

		DisplayMessage(message);
	}
}

// Script Setup
// ------------------------------------------------------------------------------------------

bar = Entities.FindByClassname(null, "monster_resource");
if (bar) {
	bar = MonsterResource(bar);
} else {
	text = TextBar(); // fall-back text ent
}
// note: monster_resource should always exist, this is just a precaution.
// i have found that killing it crashes the server! so again, this step is probably unnecessary


// Functions
// ------------------------------------------------------------------------------------------

/**
 * Put live blues in the bar array and start the bar.
 * Note that newly-spawned blues will not be added to the array automatically.
 */
function StartBlueBossBar() {
	// get live blue players
	local players = [];
	local maxclients = MaxClients().tointeger();
	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);
		if (player && player.IsValid() && player.IsAlive() && player.GetTeam() == TF_TEAM_BLUE) {
			players.push(player);
		}
	}

	if (players.len()) {
		peak_health = 0.0;
		EnableBar(players);
	} else {
		error(__FILE__ + " Error: StartBlueBossBar called with no live blues\n")
	}
}

/**
 * Add one or more entities to the bar array
 * @param {array/string/CBaseEntity} entity Targetname of entities to add, or entity instance, or an array of either
 */
function AddEntToBar(entities) {
	if (developer()) printl(__FILE__ + " AddEntToBar called with argument: " + entities);
	if (typeof entities != "array") {
		entities = [entities];
	}

	// push each item to the bar array
	foreach(elem in entities) {

		// targetname
		if (typeof elem == "string") {
			local ent = null;
			while (ent = Entities.FindByName(ent, elem)) {
				if (NetProps.HasProp(ent, "m_iHealth")) {
					bar_ents.push(ent);
					if (developer()) printl(__FILE__ + " pushed " + ent + " to bar ents array");
				} else {
					error(__FILE__ + " Error: Tried to add entity that doesn't have m_iHealth property: " + ent + "\n");
				}
			}
		}

		// entity instance
		else if (elem instanceof CBaseEntity && elem.IsValid()) {
			if (NetProps.HasProp(elem, "m_iHealth")) {
				bar_ents.push(elem);
				if (developer()) printl(__FILE__ + " pushed " + elem + " to bar ents array");
			} else {
				error(__FILE__ + " Error: Tried to add entity that doesn't have m_iHealth property: " + ent + "\n");
			}
		}
	}
}

/**
 * Remove one or more entities from the bar array
 * @param {string/CBaseEntity} entity Targetname of entities to remove, or entity instance
 */
function RemoveEntFromBar(entity) {
	if (typeof entity == "string") {
		for (local i = bar_ents.len() - 1; i >= 0; i--) {
			if (!bar_ents[i].IsValid() || bar_ents[i].GetName() == entity) {
				bar_ents.remove(i);
				if (developer()) printl(__FILE__ + " removed " + i + " from bar ents array");
			}
		}
	} else if (typeof entity == "instance" && entity.IsValid()) {
		local index = bar_ents.find(entity);
		if (index != null) {
			bar_ents.remove(index);
			if (developer()) printl(__FILE__ + " removed " + entity + " from bar ents array");
		}
	}
}

/**
 * Show the bar.
 * Won't display anything unless there are players/entities in the array.
 * @param {array/string/CBaseEntity} entities Optionally clear the bar array and add these entities to it.
 * Accepts a targetname, entity instance or array of either
 */
function EnableBar(entities = null) {
	if (!enabled) {
		if (developer()) printl(__FILE__ + " Enabling bar");
		enabled = true;
		if (entities) {
			bar_ents = [];
			AddEntToBar(entities);
		}
		AddThinkToEnt(self, "Think");
	}
}

/**
 * Hide the bar without removing entities from the bar array
 * @param {bool} update True to update the display to hide it
 */
function DisableBar(update = true) {
	if (enabled) {
		if (developer()) printl(__FILE__ + " Disabling bar");
		enabled = false;
		AddThinkToEnt(self, null);
		if (update) {
			UpdateBar();
		}
	}
}

/**
 * Update the boss bar whether it's the monster_resource or text system
 * @return {float} Update rate for think function
 */
function UpdateBar() {
	// script disabled. hide display
	if (!enabled) {
		if (text_mode) {
			text.DisplayMessage("");
		} else {
			bar.SetValue(0, 0);
		}
		return;
	}

	// get data for bar
	local data = {
		health = 0
		max_health = 0
		uber = false
		members = 0 // number of bar members
		all_players = true // members are all players
	};

	local uber_count = 0;

	for (local i = bar_ents.len() - 1; i >= 0; i--) {
		local ent = bar_ents[i];

		if (!ent.IsValid()) { // player disconnected / entity killed
			bar_ents.remove(i);
			continue;
		}

		// player
		if (ent.IsPlayer()) {
			local player = ent;

			if (player.GetTeam() != team_blue || !player.IsAlive()) { // player not on blue, or is dead
				bar_ents.remove(i);
				continue;
			}

			data.health += player.GetHealth();
			data.max_health += player.GetMaxHealth();

			if (player.InCond(cond_uber)) {
				uber_count++;
			}
		}
		// other type of entity
		else {
			data.all_players = false; // at least one non-player entity in the bar
			data.health += ent.GetHealth();

			if (NetProps.HasProp(ent, "m_iMaxHealth")) { // todo: does every entity that has m_iHealth also have m_iMaxHealth?
				data.max_health += ent.GetMaxHealth();
			} else {
				data.max_health += ent.GetHealth();
			}
		}
	}

	// set uber to true if all members are in uber cond
	if (uber_count && uber_count == bar_ents.len()) {
		data.uber = true;
	}

	// overhealed
	if (data.health > data.max_health) {
		data.max_health = data.health;
	}

	// record new max health peak
	if (data.max_health > peak_health) {
		peak_health = data.max_health;
	}

	if (text_mode) {
		text.Update(data);
		return text.update_rate;
	} else {
		bar.SetValue(data.health, peak_health);

		if (auto_color) {
			if (data.uber) {
				bar.SetColor(1);
			} else {
				bar.SetColor(0);
			}
		}

		return 0.1;
	}
}

/**
 * Switch from using the monster_resource boss bar
 * to a game_text-based display
 * @param {bool} use True to switch to text mode, false to return to monster_resource mode
 */
function UseTextMode(use = true) {
	if (use && !text_mode) {
		text_mode = true;
		if (!text) {
			text = TextBar(text_params);
		}
	} else if (!use && text_mode) {
		text_mode = false;
		if (text && text.entity.IsValid()) {
			text.entity.Kill();
			text = null;
		}
	}
}

function Think() {
	// disable on round win or when no entities in the array
	if (GetRoundState() == round_state_win || !bar_ents.len()) {
		DisableBar();
		return;
	}

	// check if we should fall back to text mode
	if (!text_mode && bar.InterferedWith()) {
		error(__FILE__ + " -- Something is interfering with the monster_resource entity, likely a SourceMod plugin. I will no longer touch it and will use a text-based replacement\n")
		if (text_mode_fallback) {
			UseTextMode();
			bar.SetValue(0, 0); // hide the monster_resource bar
		} else {
			DisableBar();
			return;
		}
	}

	return UpdateBar(); // will think again when the bar display type says to
}