/*
	Matty's Deathrun Boss Bar
	Version 1.0

	Easy way to display the combined HP of one or more live blue players using the built-in Merasmus boss bar.
	The script can also monitor the health of any non-player entities that have a health property.
	You can add as many ents as you like and even mix players with non-player entities.
	Useful for MvM tanks, base_boss or even brush-based 'fake' bosses.

	Other features:
	* Accounts for overhealing
	* Colours the bar green if the blue players are invulnerable due to uber cond
	* Shuts itself off if the Merasmus bar is being used by something else (such as a server plugin)
	* Falls back to a HUD text display using a game_text entity
	* Optionally the HUD text display can be used immediately

	Usage:
	1. Add the script to a logic_script entity
	2. If you just want to display the bar for blues, send it CallScriptFunction > StartBlueBossBar.
		Do this when it becomes necessary, like at the start of a fight. Don't do it on round start.
	3. If you want to use the bar for non-player entities, send the logic_script
			RunScriptCode >	AddEntToBossBar(ent)
		Where 'ent' is the targetname string of one or more entities,
		or an entity instance, or an array of targetnames and/or entity instances.
		Then send CallScriptFunction > EnableBossBar to start showing the bar.
		Dead players, disconnected players and entities that have been killed are removed from the bar array.
	* You can send the logic_script CallScriptFunction > DisableBossBar to hide it, and EnableBossBar to show it again.
	* You can remove entities from the bar manually using RunScriptCode > RemoveEntFromBossBar(ent)

	Setting options:
		Auto Color:
			To disable automatic colouring of the Merasmus bar to green when all players are ubered,
			send the logic_script RunScriptCode > auto_color = false
		Fall back to text mode:
			If something else is also using the Merasmus boss bar the script will fall back to a HUD text display.
			if you wish to prevent the change from happening, send the logic_script the following input
			before you start to use the bar:
				RunScriptCode > text_mode_fallback = false


	Extra:
	* If you wish to add entity(s) to the bar and display it straight away, you can pass it/them in the
		argument of EnableBossBar like so: RunScriptCode > EnableBossBar(`tank_boss`)
		Note that this function and AddEntToBossBar support the wildcard suffix (*) in the targetname string!

	Notes:
	* The script uses a think function to check health and update the bar. It works by creating a separate logic_relay
		entity and adding it to that. This means you can use this script in a logic_script containing other scripts,
		confident in the knowledge that it will not be interrupted by other scripts adding a think function.
*/

/*
	Changelog
	1.0
		* Automatic fallback to a game_ui text display when monster_resource bar is being interfered with
		* The text mode display can be switched between block characters and a number
		* The text display is prefixed with the single blue player's name, or 'Blue' with more
		* Consolidated functionality into fewer functions
		* EnableBossBar can now take a targetname, instance or array of either to replace the bar array with
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
text_mode_fallback <- true; // fall back to text mode if the monster_resource value is changed externally
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
local think_ent = null; // entity where think function is stored
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
	function GetValue() return NetProps.GetPropInt(entity, "m_iBossHealthPercentageByte");

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
	 * Set the bar colour to green or back to default blue.
	 * Green is used in Merasmus when he hides and cannot be attacked.
	 * @param {bool} set True for green, false for blue
	 */
	function ColorGreen(set) NetProps.SetPropInt(entity, "m_iBossState", set ? 1 : 0);
}

/**
 * Wrapper for game_text
 * @param {table} params Table of optional parameter overrides. Supply entity keyvalues in a table named `keyvalues`
 * @param {CBaseEntity} game_text Optional existing game_text* entity to use
 */
class TextBar {
	constructor(params = null, game_text = null) {
		// default parameters
		local keyvalues = {
			channel = 2
			effect = 0 // 0 = fade in/out
			holdtime = this.update_rate
			fadein = 0.1
			fadeout = 0.1
			color = "123 190 242" // blue
			spawnflags = 1
			x = 0.415
			y = 0.16
		}

		// set class properties
		if (typeof params == "table") {
			foreach(key, val in params) {
				if (key == "keyvalues") foreach(key, val in val[key]) keyvalues[key] <- val;
				else if (key in this) this[key] = val;
			}
		}

		// set or create text entity
		if (game_text && game_text.IsValid() && startswith(entity.GetClassname(), "game_text")) entity = game_text; // user supplied their own game_text*
		else entity = SpawnEntityFromTable("game_text", keyvalues); // create a new game_text
	}

	entity = null
	enable = false
	name = "" // word to prefix the bar
	blocks = true // use block characters instead of numbers
	update_rate = 1.0 // used for hold time and for the script update think

	/**
	 * Display a message using the text bar
	 * @param {string} message Message to display
	 */
	function DisplayMessage(message) {
		entity.KeyValueFromString("message", message); // todo: check my game_text script to see if this is the best way
		entity.AcceptInput("Display", null, null, null);
	}

	/**
	 * Construct a message from the data and display it.
	 * Add appropriate name prefix if none set.
	 * Format val with integer or block characters.
	 * @param {table} data Table of data
	 */
	function Update(data) {
		local message = "";
		if ((!name || !name.len()) && data.all_players) { // name field blank and bar ents are players
			if (data.members == 1) message = NetProps.GetPropString(bar_ents[0], "m_szNetname") + ": "; // single player name
			else message = "Blue: "; // team name
		}
		if (blocks) {
			local num_blocks = ceil(data.health.tofloat() / data.max_health * 10); // todo: overheal may screw with this
			for (local i = 0; i < num_blocks; i++) message += "▋";
		} else message += data.health;
		DisplayMessage(message);
	}
}

// Script Setup
// ------------------------------------------------------------------------------------------

bar = Entities.FindByClassname(null, "monster_resource");
if (bar) bar = MonsterResource(bar);
else text = TextBar(); // fall-back text ent

// note: monster_resource should always exist, this is just a precaution.
// i have found that killing it crashes the server! so again, this step is probably unnecessary


// Functions
// ------------------------------------------------------------------------------------------

/**
 * Put live blues in the bar array and start the bar.
 * Note that newly-spawned blues will not be added to the array automatically.
 */
function StartBlueBossBar() {
	local blues = [], maxclients = MaxClients().tointeger();
	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);
		if (player && player.IsValid() && player.IsAlive() && player.GetTeam() == TF_TEAM_BLUE) blues.push(player);
	}
	if (!blues.len()) return error(__FILE__ + " Error: StartBlueBossBar called with no live blues\n");
	peak_health = 0.0;
	EnableBossBar(blues);
}

/**
 * Add one or more entities to the bar array
 * @param {array/string/CBaseEntity} entity Targetname of entities to add, or entity instance, or an array of either
 */
function AddEntToBossBar(entities) {
	if (developer()) printl(__FILE__ + " AddEntToBossBar called with argument: " + entities);
	if (typeof entities != "array") entities = [entities];

	foreach(elem in entities) {
		if (typeof elem == "string") { // targetname
			local ent = null;
			while (ent = Entities.FindByName(ent, elem)) {
				if (NetProps.HasProp(ent, "m_iHealth")) {
					bar_ents.push(ent);
					if (developer()) printl(__FILE__ + " pushed " + ent + " to bar ents array");
				} else error(__FILE__ + " Error: Tried to add entity that doesn't have m_iHealth property: " + ent + "\n");
			}
		} else if (elem instanceof CBaseEntity && elem.IsValid()) { // entity instance
			if (NetProps.HasProp(elem, "m_iHealth")) {
				bar_ents.push(elem);
				if (developer()) printl(__FILE__ + " pushed " + elem + " to bar ents array");
			} else error(__FILE__ + " Error: Tried to add entity that doesn't have m_iHealth property: " + ent + "\n");
		}
	}
}

/**
 * Remove one or more entities from the bar array
 * @param {string/CBaseEntity} entity Targetname of entities to remove, or entity instance
 */
function RemoveEntFromBossBar(entity) {
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

	// bar_ents = bar_ents.filter(@(index, ent) {
	// 	return !(ent.IsValid() && ((typeof entity == "string" && ent.Name() == entity) || (entity instanceof CBaseEntity && ent == entity)));
	// })
}

/**
 * Show the bar.
 * Won't display anything unless there are players/entities in the array.
 * @param {array/string/CBaseEntity} entities Optionally clear the bar array and add these entities to it.
 * Accepts a targetname, entity instance or array of either
 */
function EnableBossBar(entities = null) {
	if (enabled) return;
	if (developer()) printl(__FILE__ + " Enabling bar");
	enabled = true;
	if (entities) {
		bar_ents = [];
		AddEntToBossBar(entities);
	}
	if (think_ent && think_ent.IsValid()) think_ent.Kill();
	think_ent = SpawnEntityFromTable("logic_relay", {
		targetname = "boss bar think ent"
	})
	think_ent.ValidateScriptScope();
	think_ent.GetScriptScope().script <- this;
	think_ent.GetScriptScope().Think <- function() return script.BossBarThink();
	AddThinkToEnt(think_ent, "Think");
}

/**
 * Hide the bar without removing entities from the bar array
 * @param {bool} update True to update the display to hide it
 */
function DisableBossBar(update = true) {
	if (!enabled) return;
	if (developer()) printl(__FILE__ + " Disabling bar");
	enabled = false;
	if (think_ent && think_ent.IsValid()) think_ent.Kill();
	if (update) UpdateBar();
}

/**
 * Update the boss bar whether it's the monster_resource or text system
 * @return {float} Update rate for think function
 */
function UpdateBar() {
	// script disabled. hide display
	if (!enabled) {
		if (text_mode) text.DisplayMessage("");
		else bar.SetValue(0, 0);
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
			if (player.InCond(cond_uber)) uber_count++;
		}
		// other type of entity
		else {
			data.all_players = false; // at least one non-player entity in the bar
			data.health += ent.GetHealth();
			if (NetProps.HasProp(ent, "m_iMaxHealth")) data.max_health += ent.GetMaxHealth(); // todo: does every entity that has m_iHealth also have m_iMaxHealth?
			else data.max_health += ent.GetHealth();
		}
	}

	data.members = bar_ents.len();
	if (uber_count && uber_count == bar_ents.len()) data.uber = true; // all members are in uber cond
	if (data.health > data.max_health) data.max_health = data.health; // overhealed
	if (data.max_health > peak_health) peak_health = data.max_health; // record new max health peak

	if (text_mode) {
		text.Update(data);
		return text.update_rate;
	} else {
		bar.SetValue(data.health, peak_health);
		if (auto_color) {
			if (data.uber) bar.ColorGreen(true);
			else bar.ColorGreen(false);
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
		if (!text) text = TextBar(text_params); // create bar
	} else if (!use && text_mode) {
		text_mode = false;
		if (text && text.entity.IsValid()) {
			text.entity.Kill();
			text = null;
		}
	}
}

function BossBarThink() {
	if (GetRoundState() == round_state_win || !bar_ents.len()) return DisableBossBar(); // disable on round win or tracking no ents
	if (!text_mode && bar.InterferedWith()) { // enable text mode fall back
		error(__FILE__ + " -- Something is interfering with the monster_resource entity, likely a SourceMod plugin. I will no longer touch it\n")
		if (text_mode_fallback) {
			error(__FILE__ + " Fell back to text mode\n")
			UseTextMode();
			bar.SetValue(0, 0); // hide the monster_resource bar
		} else return DisableBossBar();
	}
	return UpdateBar(); // will think again when the bar display type says to
}

/*
	Future posibilities
	- Entities go in a table along with their names for text mode fall back prefix
	- Optionally do not group entity health together. Instead, have a text bar for each.
*/