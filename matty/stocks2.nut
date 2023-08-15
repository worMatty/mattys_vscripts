/*
	Matty's Stocks 2

	A bunch of commonly-used functions to include in other scripts
	Superceding the old stocks file
	Work-in-progress
*/


// Constants
// --------------------------------------------------------------------------------

const chat_color_spec = 0xCCCCCC;
const chat_color_red = 0xFF3F3F;
const chat_color_blue = 0x99CCFF;

maxclients <- MaxClients();
local worldspawn = Entities.FindByClassname(null, "worldspawn");

// TEAM_UNASSIGNED				0
// TEAM_SPECTATOR				1
// TF_TEAM_RED 					2
// TF_TEAM_BLUE 				3
// TEAM_ANY 					-2
// TEAM_INVALID 				-1

foreach(key, value in Constants.ETFTeam) {
	if (!(key in getroottable())) {
		getroottable()[key] <- value;
	}
};


// Messages
// --------------------------------------------------------------------------------

foreach(key, value in Constants.EHudNotify) {
	if (!(key in getroottable())) {
		getroottable()[key] <- value;
	}
};

::Message <- {

	Chat = {

		Player = function(player, message) {
			ClientPrint(player, HUD_PRINTTALK, message);
		}

		Client = function(client, message) {
			ClientPrint(client, HUD_PRINTTALK, message);
		}

		Players = function(players, message) {
			foreach(player in players) {
				ClientPrint(player, HUD_PRINTTALK, message);
			}
		}

		Clients = function(clients, message) {
			foreach(client in clients) {
				ClientPrint(client, HUD_PRINTTALK, message);
			}
		}

		Team = function(team, message) {
			local players = GetTeamPlayers(team);

			foreach(player in players) {
				ClientPrint(player, HUD_PRINTTALK, message);
			}
		}

		All = function(message) {
			ClientPrint(null, HUD_PRINTTALK, message);
		}

		TeamColor = function(team) {
			local color = "\x01";

			switch (team) {
				case TEAM_SPECTATOR: {
					color = format("\x07%X", chat_color_spec);
					break;
				}
				case TF_TEAM_RED: {
					color = format("\x07%X", chat_color_red);
					break;
				}
				case TF_TEAM_BLUE: {
					color = format("\x07%X", chat_color_blue);
					break;
				}
			}

			return color;
		}
	}

	// note: if a slot in a table in a function header is not specified, then it will not be passed
	// to the function body

	/**
	 * Show a training annotation in the world above an entity.
	 * Some parameters are optional are are supplied in a table as the third argument
	 *
	 * @param {string} text - Message to display
	 * @param {instance} entity - Instance of the entity to display above
	 * @param {array} players Array of players to display the message to. Note: Client 32 will never see it due to a coding limitation in the game
	 * @param {number} lifetime - Time the annotation is displayed for in seconds
	 * @param {string} sound - Sound to play
	 * @param {bool} show_distance - Display the distance from the annotation
	 * @param {bool} show_effect - Display a small graphical effect on the annotation when it spawns
	 * @param {number} id - Unique Id number of this annotation. Annotations using the same Id will replace it. Uses the entity index by default
	 * @noreturn
	 */
	Annotation = function(options = {}) {
		local defaults = {
			text = "Your message here!"
			entity = null
			players = null
			lifetime = 10
			sound = "common/null.wav"
			show_distance = false
			show_effect = false
			id = 0
			origin = QAngle(0, 0, 0)
			// worldNormalX = 0
			// worldNormalY = 0
			// worldNormalZ = 0
		}

		// supply defaults
		foreach(key, value in defaults) {
			if (!(key in options)) {
				options[key] <- value;
			}
		}

		// calculate visibility bitfield
		local bitfield = 0;

		if (typeof options.players == "array") {
			foreach(player in options.players) {
				if (player != null && player.IsValid()) {
					bitfield = bitfield | 1 << player.GetEntityIndex();
				}
			}
		}
		printl(this + " origin is " + options.origin);
		// construct params
		local params = {
			text = options.text
			follow_entindex = (options.entity != null) ? options.entity.GetEntityIndex() : 0

			visibilityBitfield = bitfield
			lifetime = options.lifetime
			play_sound = options.sound
			show_distance = options.show_distance
			show_effect = options.show_effect
			id = options.id

			worldPosX = options.origin.x
			worldPosY = options.origin.y
			worldPosZ = options.origin.z
			// worldNormalX = options.worldNormalX
			// worldNormalY = options.worldNormalY
			// worldNormalZ = options.worldNormalZ
		}

		SendGlobalGameEvent("show_annotation", params);
	}
};



// Player
// --------------------------------------------------------------------------------

local ctfplayer_functions = {

	/**
	 * Checks if a player is alive
	 *
	 * @returns {bool} - True if the player is alive, false otherwise
	 */
	IsAlive = function() {
		return NetProps.GetPropInt(this, "m_lifeState") == 0;
	}

	/**
	 * Checks if a player is an observer
	 * (Dead on a participating team or on Spectator team, and watching a player, game objective or observer point)
	 *
	 * @returns {bool} True if player is observing something
	 */
	IsObserver = function() {
		return NetProps.GetPropInt(this, "m_iObserverMode") != 0;
	}

	/**
	 * Get a player's name
	 *
	 * @returns {string} - Player's name
	 */
	Name = function() {
		return NetProps.GetPropString(this, "m_szNetname");
	}

	/**
	 * Get a player's name coloured to their team colour
	 * Returned string already includes \x01 reset colour code at the end
	 *
	 * @returns {string} Player's team-coloured name
	 */
	ColoredName = function() {
		// return format("%s%s\x01", Message.Chat.TeamColor(this.GetTeam()), NetProps.GetPropString(this, "m_szNetname"));
		return format("%s%s\x01", Message.Chat.TeamColor(this.GetTeam()), this.Name());
	}

	/**
	 * Cause a player to just die
	 *
	 * @param {instance} player - Player
	 * @noreturn
	 */
	Die = function(silently = true) {
		if (!this.IsAlive()) {
			return;
		}

		// doesn't work - see trigger_tricks
		if (silently == true) {
			NetProps.SetPropInt(this, "m_lifeState", 2);
		}

		this.TakeDamage(this.GetHealth(), 0, this);

		// self-damage is being negated by something
		if (this.IsAlive()) {
			this.TakeDamage(this.GetHealth(), 0, worldspawn)
		}
	}

	Fizzle = function() {
		local effect = Constants.ETFDmgCustom.TF_DMG_CUSTOM_PLASMA; // Cow Mangler
		this.TakeDamageCustom(null, this, null, Vector(0, 0, 0), this.GetOrigin(), this.GetHealth(), 0, effect);

		// self-damage is being negated by something
		if (this.IsAlive()) {
			this.TakeDamageCustom(null, worldspawn, null, Vector(0, 0, 0), this.GetOrigin(), this.GetHealth(), 0, effect);
		}
	}
}

// iterate and assign
// note: setting using .key literally creates a slot named 'key'
foreach(key, value in ctfplayer_functions) {
	if (!(key in ::CTFPlayer)) {
		::CTFPlayer[key] <- value; //
		::CTFBot[key] <- ::CTFPlayer[key]; //
	}
}

/**
 * Return standard max health for the given TF2 class
 *
 * @param {number} tfclass - Class number
 * @returns {number} - Max health amount
 */
function GetTFClassHealth(tfclass) {
	local health = [
		50, // None
		125, // Scout
		125, // Sniper
		200, // Soldier
		175, // Demoman
		150, // Medic
		300, // Heavy
		175, // Pyro
		125, // Spy
		125 // Engineer
	];

	return health[tfclass];
}

/*
Custom damage types
TF_DMG_CUSTOM_TAUNTATK_BARBARIAN_SWING (24) - Decapitate
TF_DMG_CUSTOM_GOLD_WRENCH (35) - Paralyze and play a gold hit sound
TF_DMG_CUSTOM_PLASMA (46) - Cow Mangler / Righteous Bison / Pomson / Short Circuit
TF_DMG_CUSTOM_PLASMA_CHARGED (47) - Explode into gibs. 50% chance of gibs getting plasma fizzle.
TF_DMG_CUSTOM_HEADSHOT_DECAPITATION (51) - Decapitation
TF_DMG_CUSTOM_MERASMUS_DECAPITATION (60) - Decapitation
TF_DMG_CUSTOM_KART (75) - 50 chance of higher velocity

Ragdoll properties
m_bGib				High blood gib
m_bBurning			75% chance to set on fire
m_bElectrocuted		Kritz disspipation electricity crackle
m_bFeignDeath		No effect
m_bWasDisguised		No effect
m_bBecomeAsh		C.A.P.P.E.R. Glowing ash / Phlog / Third Degree / Manmelter / Shooting Star
m_bOnGround			No effect
m_bCloaked			Cloaks the ragdoll!
m_bGoldRagdoll		Makes the ragdoll semi rigid and gold
m_bIceRagdoll		Makes the ragdoll semi-rigid and gives it an ice freeze effect with particles
m_bCritOnHardHit	No effect

env_entity_dissolver damage types
0	Combine energy ball
1	Combine energy ball but ragdoll does not float
2	Same as 1
3	Same as 1 but happens very fast
*/


// Hooking
// --------------------------------------------------------------------------------

/**
 * Iterates the event tables and removes any entries attached to an invalid instance
 * Unlike ClearGameEventCallbacks, this does not wipe every event from the tables
 */
function CleanGameEventCallbacks() {
	local clean = function(event_table) {
		if (!(event_table in getroottable())) {
			return;
		}

		foreach(event, event_array in getroottable()[event_table]) {
			for (local i = event_array.len() - 1; i >= 0; i--) {
				if (!event_array[i].self.IsValid()) {
					event_array.remove(i);
				}
			}
		}
	};

	clean("GameEventCallbacks");
	// clean(ScriptEventCallbacks);
	clean("ScriptHookCallbacks");
}





// Test stuff
// --------------------------------------------------------------------------------

/**
 * Cause all observing players to observe a specific entity
 *
 * @param {instance} target Instance of entity to observe. Leave at default for activator
 * @noreturn
 */
// function SetAllObserverTarget(target = null)
// {
// 	if (target == null)
// 	{
// 		target = activator;
// 	}

// 	printl("Setting everyone's observer target to " + target);

// 	for (local i = 1; i <= maxclients; i++)
// 	{
// 		local player = PlayerInstanceFromIndex(i);

// 		if (player != null && player.IsValid() && !player.IsAlive())
// 		{
// 			NetProps.SetPropEntity(player, "m_hObserverTarget", target);
// 		}
// 	}
// }

/**
 * Dump the script scope for all players
 *
 * @noreturn
 */
// ::DumpPlayerScopes <- function()
// {
// 	for (local i = 1; i <= maxclients; i++)
// 	{
// 		local player = PlayerInstanceFromIndex(i);

// 		if (player != null)
// 		{
// 			printl("Script scope for " + player.Name());
// 			__DumpScope(0, player.GetScriptScope());
// 		}
// 	}
// }