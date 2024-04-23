/*
	Matty's Stocks 2.1

	* Folds all native constants into root scope
	* Adds several new useful constants

	Entity helpers:
	* team_round_timer round time elapsed
	* Radius check between two ents
	* TeleportStuff all-purpose teleporter to replace map-wide triggers

	Sound
	* Precache and then play sounds
	* Set up looping ambient sounds which are stopped before round restart
	* Simpler single-purpose functions
	* Useful for reducing edict contribution from ambient_generic

	Player helpers
	* Players() class to produce a filtered list of players by chaining methods
	* GetPlayers() function which accepts arbitrary options in a table
	* Wrapper functions GetReds, GetBlues, LiveReds, LiveBlues, DeadReds, DeadBlues

	CTFPlayer methods
	* IsAlive
	* Die
	* Fizzle
	* IsObserver
	* Name
	* Team-coloured name
	* SteamId
	* UserId

	Messaging
	* ChatMsg - Easily print chat messages to players using a variety of targetting methods
	* ChatColor - Get a chat colour string for a player or team, or specify your own RGB or RGBA value
	* CenterMsg - Print a message to the 'centre say' area using the targetting system of ChatMsg
	* Annot - Print training annotations to targetted clients

	Other stuff
	* RandomiseArray - Takes an array and returns a shuffled copy
	* CleanGameEventCallbacks - Delete invalid game events instead of deleting all of them

	Thanks ficool2 and Joshie for all you've done for us!
	Changelog and more info is at the bottom of the doc.
*/

/*
	Changelog

	2.01
	* Removed ClearGameEventCallbacks()
*/

/**
 * Events
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Stop looping ambient sounds just before round restart
 * Used by PPlay
 */
function OnGameEvent_scorestats_accumulated_update(params) {
	local soundlist = ::matty.sounds;
	// printl(__FILE__ + " -- Stopping " + soundlist.len() + " sounds");
	foreach(sound in soundlist) {
		sound.flags <- SND_STOP;
		EmitSoundEx(sound);
	};
	soundlist = [];
}

__CollectGameEventCallbacks(this);


/**
 * Helpers
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Return standard max health for the given TF2 class
 * @param {integer} tfclass Class integer
 * @return {integer} Max health amount
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


/**
 * Constants
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Add every TF2 constant to root scope
 * This lets you use them more easily in scripts and I/O because you don't need to prefix them with
 * Constants.ETFWhatever. It also improves performance of the VM a bit
 */
::ROOT <- getroottable();
if (!("ConstantNamingConvention" in ROOT)) {
	foreach(a, b in Constants)
	foreach(k, v in b)
	if (v == null)
		ROOT[k] <- 0;
	else
		ROOT[k] <- v;
}

// Exit script execution now if it's been done before on this map
if ("matty" in ROOT) {
	return;
}

// Add the 'matty' table to the root scope
::matty <- {};

// Add various helper constants for you to make use of in I/O
constants <- {
	// EmitSoundEx flags
	SND_NOFLAGS = 0
	SND_CHANGE_VOL = 1
	SND_CHANGE_PITCH = 2
	SND_STOP = 4
	SND_SPAWNING = 8
	SND_DELAY = 16
	SND_STOP_LOOPING = 32
	SND_SPEAKER = 64
	SND_SHOULDPAUSE = 128
	SND_IGNORE_PHONEMES = 256
	SND_IGNORE_NAME = 512
	SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL = 1024

	// Chat colour hexadecimal values
	CHAT_COLOR_SPEC = 0xCCCCCC
	CHAT_COLOR_RED = 0xFF3F3F
	CHAT_COLOR_BLUE = 0x99CCFF

	// Chat colour prefixes
	CHAT_COLOR_01 = "\x01"
	CHAT_COLOR_07 = "\x07"
	CHAT_COLOR_08 = "\x08"

	maxclients = MaxClients().tointeger()
	worldspawn = Entities.FindByClassname(null, "worldspawn")
	tf_player_manager = Entities.FindByClassname(null, "tf_player_manager")
}

foreach(key, value in constants) {
	ROOT[key] <- value;
};


/**
 * Entity Effects
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Fizzle an entity
 * Uses Cow Mangler effect by default
 * @deprecated Doesn't work. Entities can't be fizzled this way
 * @param {integer} effect TF_DMG_CUSTOM damage type
 */
::CBaseEntity.Fizzle <-  function(effect = TF_DMG_CUSTOM_PLASMA) {
	this.TakeDamageCustom(null, this, null, Vector(0, 0, 0), this.GetOrigin(), this.GetHealth(), 0, effect);

	// self-damage is being neutralised by something
	if (this.IsAlive()) {
		this.TakeDamageCustom(null, worldspawn, null, Vector(0, 0, 0), this.GetOrigin(), this.GetHealth(), 0, effect);
	}
};


/**
 * Entity Helpers
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Get the elapsed time of a team_round_timer
 * @param {string} timer_name Targetname of the team_round_timer
 * @return {table} Table of minutes and seconds, or null if timer not found
 */
::GetRoundTimeElapsed <-  function(timer_name) {
	local timer = Entities.FindByName(null, timer_name);

	if (timer != null) {
		local time_remaining = NetProps.GetPropFloat(timer, "m_flTimeRemaining") + 1;
		local end_time = NetProps.GetPropFloat(timer, "m_flTimerEndTime");
		local time = Time();
		local time_elapsed = time_remaining - (end_time - time);
		local minutes = abs(time_elapsed / 60);
		local seconds = abs(time_elapsed % 60);

		return {
			minutes = minutes,
			seconds = seconds
		};
	}

	return null;
};

/**
 * Check if one origin is within the specified radius of another origin
 * @param {vector} origin1 First origin
 * @param {vector} origin2 Second origin
 * @param {float} radius The radius to check within
 */
::RadiusCheck <-  function(origin1, origin2, radius) {
	radius = radius * radius;
	local distance = (origin1 - origin2).LengthSqr();
	return (distance <= radius)
};

/**
 * Teleport one or more entities to one or more destination entities.
 * If using a target or classname, it will find all instances.
 * If using a team number, dead players will be filtered out of the final results if respawn == false.
 * Grid arrangement of players only occurs when there is a single destination.
 *
 * @param {any} targets Team number, entity instance, array of entities, targetname, classname
 * @param {any} destinations Instance or targetname string of destination entity or entities
 * @param {table} options Table of optional settings. See below
 * Options:
 * @param {bool} respawn Optionally respawn any dead players before teleporting (default: false)
 * @param {bool} grid Arrange players in grid formation around a single ent if true (default), or all on the ent if false
 * @param {bool} grid_spacing Distance between the center of each player in the grid (default: 64)
 * @param {bool} shuffle_destinations If the number of destination ents is greater than the number of targets, shuffle the destinations (default: true)
 * @return {number} Number of entities teleported
 */
::TeleportStuff <-  function(targets, destinations, options = {}) {
	local defaults = {
		respawn = false
		grid = true
		grid_spacing = 64.0 // space between entities in grid formation
		shuffle_destinations = true // shuffle destinations when they surpass targets
	}

	foreach(key, value in defaults) {
		if (!(key in options)) {
			options[key] <- value;
		}
	}

	/**
	 * Process the input and produce an array of teleport targets or destinations.
	 * Accepts an array of entity instances, an entity instance, a targetname or classname string, or team integer.
	 * @param {any} input Input value for the teleport target(s) or destination(s)
	 * @return {array} Array of teleport targets or destinations
	 */
	local ProcessInput = function(input) {
		local output = [];

		// array
		if (typeof input == "array" && input.len() > 0) {
			output = input;
		}
		// instance
		else if (typeof input == "instance") {
			// entity
			if (input instanceof CBaseEntity && input.IsValid()) {
				output.push(input);
			}
			// Players instance
			else if (input instanceof Players) {
				output = input.Array();
			}
		}
		// string targetname & classname
		else if (typeof input == "string") {
			local ent = null;
			while (ent = Entities.FindByName(ent, input)) {
				output.push(ent);
			}
			if (output.len() == 0) {
				while (ent = Entities.FindByClassname(ent, input)) {
					output.push(ent);
				}
			}
		}
		// integer
		else if (typeof input == "integer") {
			// output = GetTeamPlayers(input);
			output = Players().Team(input).Array();
		}

		return output;
	}

	targets = ProcessInput(targets);
	destinations = ProcessInput(destinations);

	// filter dead players when not respawning
	if (options.respawn == false) {
		targets = targets.filter(function(index, target) {
			if (target instanceof CTFPlayer && !target.IsAlive()) {
				return false;
			} else {
				return true;
			}
		});
	}

	// exit early if no targets or destinations
	if (destinations.len() == 0 || targets.len() == 0) {
		printl("TeleportStuff -- Destinations or targets not found. Destinations: " + destinations.len() + " Targets: " + targets.len());
		return;
	}

	local teleported = 0;

	// there is only one destination
	if (destinations.len() == 1) {
		local destination = destinations.pop();
		local origin = destination.GetOrigin();
		local angles = destination.GetAbsAngles();

		// teleport multiple targets into grid formation around destination
		if (targets.len() > 1 && options.grid == true) {
			local rows = ceil(sqrt(targets.len())).tointeger();
			local offset = ((rows * options.grid_spacing) / 2) - (options.grid_spacing / 2);
			origin = Vector(origin.x - offset, origin.y + offset, origin.z);

			// column
			for (local i = 0; i < rows && targets.len(); i++) {
				// row
				for (local j = 0; j < rows && targets.len(); j++) {
					local new_origin = Vector(origin.x + (options.grid_spacing * j), origin.y - (options.grid_spacing * i), origin.z);
					local target = targets.pop();
					if (target instanceof CTFPlayer && !target.IsAlive()) {
						if (options.respawn) {
							target.ForceRespawn();
						} else {
							continue;
						}
					}
					target.Teleport(true, new_origin, true, angles, true, Vector());
					teleported++;
				}
			}
		}

		// teleport all targets to the same point
		else {
			foreach(target in targets) {
				if (target instanceof CTFPlayer && !target.IsAlive()) {
					if (options.respawn) {
						target.ForceRespawn();
					} else {
						continue;
					}
				}
				target.Teleport(true, origin, true, angles, true, Vector());
				teleported++;
			}
		}
	}

	// there are multiple destinations
	else {
		// randomise destination array if fewer targets than destinations
		if (targets.len() < destinations.len() && options.shuffle_destinations) {
			destinations = RandomiseArray(destinations);
		}

		// extend destinations array if smaller than targets array
		while (destinations.len() < targets.len()) {
			destinations.extend(destinations);
		}

		foreach(index, target in targets) {
			if (target instanceof CTFPlayer && !target.IsAlive()) {
				if (options.respawn) {
					target.ForceRespawn();
				} else {
					continue;
				}
			}
			target.Teleport(true, destinations[index].GetOrigin(), true, destinations[index].EyeAngles(), true, Vector());
			teleported++;
		}
	}

	// return number of targets teleported
	return teleported;
};


/**
 * Sound
 * ----------------------------------------------------------------------------------------------------
 */

// This array will be used to store looping ambient sounds so they can be stopped before round restart
::matty.sounds <- [];

/**
 * Precache and play a sound, using EmitSoundEx with some default parameters.
 * There is an additional optional parameter named 'radius' which is converted to sound_level.
 * https://developer.valvesoftware.com/wiki/Team_Fortress_2/Scripting/Script_Functions/EmitSoundEx
 * @param {table} params Table of parameters to pass to EmitSoundEx. Only 'sound_name' is required
 */
::PPlay <-  function(params) {
	local sound_name_lowercase = params.sound_name.tolower();

	if (sound_name_lowercase.find(".wav") || sound_name_lowercase.find(".mp3")) {
		PrecacheSound(params.sound_name);
	} else {
		PrecacheScriptSound(params.sound_name);
	}

	local defaults = {
		channel = 6
		sound_level = 80
		entity = self
	}

	foreach(key, value in defaults) {
		if (!(key in params)) {
			params[key] <- value;
		}
	}

	// convert radius to decibels
	if ("radius" in params) {
		params.sound_level = SoundRadiustoDecibels(params.radius);
	}

	// assign origin for server-side entities (e.g. logic_relay)
	if ("entity" in params && params.entity.entindex() == 0) {
		if (!("origin" in params)) {
			params.origin <- params.entity.GetOrigin();
		}
	}

	// add looping sounds to loop list
	if (sound_name_lowercase.find("loop")) {
		local soundlist = matty.sounds;

		// remove from the list if this is a stop instruction
		if ("flags" in params && params.flags & SND_STOP) {
			for (local i = soundlist.len() - 1; i >= 0; i--) {
				local sound = soundlist[i];

				if (sound.sound_name == params.sound_name && sound.entity == params.entity) {
					soundlist.remove(i);
					// printl(__FILE__ + " looping sound removed: " + params.sound_name);
				}
			}
		} else {
			// printl(__FILE__ + " looping sound found: " + params.sound_name); //
			soundlist.append(params);
		}
	}

	// DumpObject(params);
	// printl(__FILE__ + " is emitting " + params.sound_name + " from " + params.entity);

	EmitSoundEx(params);
};

/**
 * Simple sound playing function designed for one-shot sounds
 * Precaches the sound before playing
 * Uses the static channel, and a sound_level of 80 by default
 * @param {string} sound Sound file or game sound name
 * @param {table} params Parameters to pass to EmitSoundEx.
 * Custom parameter 'radius' converts Hammer units into sound_level
 * Custom parameter 'source' is the entity handle to emit from
 */
::PlaySound <-  function(sound, params = {}) {
	local extension = (sound.len() > 4) ? sound.slice(-4).tolower() : null;
	// printl(__FILE__ + "-- PlaySound caller: " + caller + " activator: " + activator + " self: " + self);

	// precache
	if (extension == ".wav" || extension == ".mp3") {
		PrecacheSound(sound);
	} else {
		if (!PrecacheScriptSound(sound)) {
			printl(__FILE__ + " -- PlaySound -- soundscript sound not found: " + params.sound_name);
			return;
		}
	}

	// parameters
	local defaults = {
		channel = 6
		sound_level = 80
		entity = self
	}

	foreach(key, value in defaults) {
		if (!(key in params)) {
			params[key] <- value;
		}
	}

	// radius
	if ("radius" in params) {
		params.sound_level = SoundRadiustoDecibels(params.radius);
	}

	// source
	if ("source" in params) {
		params.entity = source;
	}

	// entity
	if (params.entity.entindex() == 0) {
		if (!("origin" in params)) {
			params.origin <- params.entity.GetOrigin();
		}
	}

	EmitSoundEx(params);
};

/**
 * Play a sound to a player
 * Useful for UI sounds
 * @param {string} sound Sound file or game sound name
 * @param {table} params Parameters to pass to EmitSoundEx
 */
::PlayToClient <-  function(client, sound, table = {}) {
	table.entity <- client;
	table.channel <- 0;
	table.sound_level <- 0;
	table.filter <- 4;
	SPlay(sound, table);
};

/**
 * Convert sound radius in Hammer units to decibels
 * for use as the soundlevel in sound functions
 * @param {integer} radius Radius in units
 * @return {integer} soundlevel equivalent
 */
::SoundRadiustoDecibels <-  function(radius) {
	return (40 + (20 * log10(radius / 36.0))).tointeger();
};


/**
 * Player Helpers
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Matty's Player Lists v0.1
 *
 * Easy creation of lists of players by characteristic.
 * Chain methods to further refine the list.
 *
 * Usage:
 * `Players()` returns all players on red and blue as a Players class instance.
 * Chain methods to refine the results.
 * Adding the `.players` property to the end of the chain returns the results in an array.
 * Many methods can be given a `false` argument to invert them.
 *
 * Example									Method						Alternative
 * Get all players on team 2 (Red)			Players().Team(2)
 * Get all dead players on team 3 (Blue)	Players().Team(3).Dead()
 * Get all bot players						Players().Bot()				Players().Human(false)
 * Get all non-bot players					Players().Human()			Players().Bot(false)
 * Get all live players						Players().Alive()			Players().Dead(false)
 * Get all observers						Players().Observing()
 * Get all players with the targetname		Players().Targetname(`whatever`)
 * Get all players within a radius			Players().Radius(origin, radius)
 *
 * Modify the results
 * Shuffle the order of the array			Players().Shuffle()
 * Sort by time on the server / User Id		Players().SortByUserId()
 * Exclude a player, array of players or Players results
 * 											Players().Exclude(player)	Players().Exclude(Players.Dead())
 *
 * Debugging
 * Display the results in the console		Players().Display()
 */
::Players <- class {
	constructor(_options = {}) {
		options = _options;

		// default options
		local default_options = {
			include_spec = false
		};

		// insert defaults to options table where no value exists
		foreach(key, value in default_options) {
			if (!(key in options)) {
				options[key] <- value;
			}
		};

		/**
		 * Get all current valid player instances
		 * Initial sort order is by edict index ranging from 1 to MaxClients()
		 * @return {array} Array of player instances
		 */
		local GetAllPlayers = function() {
			local array = [];

			for (local i = 1; i <= maxclients; i++) {
				local player = PlayerInstanceFromIndex(i);

				if (player != null) {
					if (!options.include_spec && player.GetTeam() > 1) { // not including spectator team
						array.push(player);
					} else if (options.include_spec && player.GetTeam() > 0) { // including spectator team
						array.push(player);
					}
				}
			}

			return array;
		}

		players = GetAllPlayers();
	}

	// variables
	players = null
	options = null


	// Filtering
	// ----------------------------------------

	/**
	 * Filter players from the players array if they are not alive
	 * @param {bool} alive Keep only live players if true, or discard live players if false
	 * @return {Players} This
	 */
	function Alive(alive = true) {
		players = players.filter(function(index, player) {
			return (player.IsAlive() == alive)
		})

		return this;
	}

	function Dead(dead = true) {
		return Alive(!dead);
	}

	function Human(human = true) {
		players = players.filter(function(index, player) {
			return (!IsPlayerABot(player) == human)
		})

		return this;
	}

	function Bot(bot = true) {
		return Human(!bot);
	}

	function Team(team) {
		players = players.filter(function(index, player) {
			return (player.GetTeam() == team);
		});

		return this;
	}

	function Observing(observing = true) {
		players = players.filter(function(index, player) {
			return (!!NetProps.GetPropInt(player, "m_iObserverMode") == observing);
		});

		return this;
	}

	function Targetname(targetname) {
		foreach(player in players) {
			if (player.GetName() != targetname) {
				RemovePlayer(player);
			}
		}

		return this;
	}

	function Radius(origin, radius) {
		players = players.filter(function(index, player) {
			return (RadiusCheck(origin, player.GetOrigin(), radius));
		});

		return this;
	}


	// Querying
	// ----------------------------------------

	/**
	 * Checks the players array to see if it contains the specified player
	 * @param {instance} player Player instance
	 * @return {integer} Index of player or null if not found
	 */
	function ContainsPlayer(player) {
		return players.find(player);
	}

	/**
	 * Return the internal players array
	 * @return {array} The array of players
	 */
	function Array() {
		return players;
	}


	// Modifying
	// ----------------------------------------

	function Shuffle() {
		local array = [];

		while (players.len() > 0) {
			array.push(players.remove(RandomInt(0, players.len() - 1)));
		}

		players = array;
		return this;
	}

	function SortByUserId() { // time on server
		players.sort(function(a, b) {
			return (a.UserId()) <=> (b.UserId());
		});

		return this;
	}

	/**
	 * Remove a player or array of players from the player array and return
	 * the modified Players instance
	 * @param {any} object player instance or array of players
	 * @return {Players} This
	 */
	function Exclude(object) {
		if (type(object) == "array") {
			RemovePlayers(object);
		} else if (object instanceof Players) {
			RemovePlayers(object.players);
		} else if (object instanceof CTFPlayer) {
			RemovePlayer(object);
		}

		return this;
	}

	/**
	 * Divide players into multiple groups
	 * @param {integer} number_of_groups The number of groups
	 * @return {array} Array of arrays of players
	 */
	function Divide(number_of_groups) {
		local groups = [];
		local number_of_players = players.len();
		local remainder = number_of_players % number_of_groups;
		local group_size = floor(number_of_players / number_of_groups);

		local count = 0;

		while (count < number_of_groups) {
			local group = [];

			local size = group_size;
			if (remainder > 0) {
				size++;
				remainder--;
			}

			while (group.len() < size) {
				group.append(players.remove(0));
			}

			groups.append(group);
			printl("Group size: " + group.len());
			count++
		}

		printl("Number of groups: " + groups.len());
		return groups;
	}

	/**
	 * Removes an array of players from the players array or removes
	 * the specified number of players from the bottom of the players array
	 * @param {any} _players The array of players to remove, or number of players to remove
	 * @return {array} Array of removed player instances
	 */
	function RemovePlayers(_players) {
		local array = [];

		// array of player instances to remove
		if (typeof _players == "array") {
			foreach(player in _players) {
				local player = this.RemovePlayer(player);
				if (player != null) {
					array.append(player);
				}
			}
		}
		// quantity of players to remove
		else if (typeof _players == "integer") {
			// guard against exceeding the indexes of the players array
			if (players.len() < _players) {
				_players = players.len();
			}

			for (local i = 0; i < _players; i++) {
				array.append(players.remove(0));
			}
		}

		return array;
	}

	/**
	 * Remove a player from the array
	 * @param {instance} player Player instance
	 * @return {instance} Instance of the player if found and removed, null otherwise
	 */
	function RemovePlayer(player) {
		local index = players.find(player);
		if (index != null) {
			return players.remove(index);
		}
		return null;
	}


	// Debug
	// ----------------------------------------

	function Display() {
		foreach(player in players) {
			printl(player.Name() + " (" + player.UserId() + ") -- team " + player.GetTeam() + " -- alive: " + player.IsAlive() + " -- bot: " + IsPlayerABot(player));
		}

		return this;
	}
};

/**
 * Simpler player getter
 * Options:
 * * targetname = `whatever*`
 * * alive = true/false
 * * team = number/constant (TF_TEAM_RED)
 * * bot = true/false
 * * observer = true/false
 * * shuffle = anything (ignored)
 * * sort = `userid` (time on server)
 * @param {table} options Filtering rules
 * @return {array} Player instances
 */
::GetPlayers <-  function(options = {}) {
	local players = [];

	// targetname search
	if ("targetname" in options) {
		local ent = null;
		while (ent = Entities.FindByName(player, options.targetname)) {
			if (ent instanceof CTFPlayer) {
				players.append(ent);
			}
		}
	}

	// else get all players
	else {
		for (local i = 1; i <= maxclients; i++) {
			local player = PlayerInstanceFromIndex(i);

			if (player != null && player.IsValid()) {
				players.push(player);
			}
		}
	}

	// alive
	if ("alive" in options) {
		players = players.filter(function(index, player) {
			return (player.IsAlive() == options.alive)
		})
	}

	// team
	if ("team" in options) {
		players = players.filter(function(index, player) {
			return (player.GetTeam() == options.team)
		})
	}

	// bot
	if ("bot" in options) {
		players = players.filter(function(index, player) {
			return (IsPlayerABot(player) == options.bot)
		})
	}

	// observer
	if ("observer" in options) {
		players = players.filter(function(index, player) {
			return (!!NetProps.GetPropInt(player, "m_iObserverMode") == options.observer);
		})
	}

	// shuffle
	if ("shuffle" in options) {
		local players_new = [];
		while (players.len() > 0) {
			players_new.push(players.remove(RandomInt(0, players.len() - 1)));
		}
		players = players_new;
	}

	// sort
	if ("sort" in options) {
		if (options.sort == "userid") {
			players.sort(function(a, b) {
				return (a.UserId()) <=> (b.UserId());
			})
		}
	}

	return players;
};

/**
 * Get red players
 * @return {array} Array of player instances
 */
::GetReds <-  function() {
	return Players().Team(TF_TEAM_RED).Array();
};

/**
 * Get live red players
 * @return {array} Array of player instances
 */
::LiveReds <-  function() {
	return Players().Team(TF_TEAM_RED).Alive().Array();
};

/**
 * Get dead red players
 * @return {array} Array of player instances
 */
::DeadReds <-  function() {
	return Players().Team(TF_TEAM_RED).Dead().Array();
};

/**
 * Get blue players
 * @return {array} Array of player instances
 */
::GetBlues <-  function() {
	return Players().Team(TF_TEAM_BLUE).Array();
};

/**
 * Get live blue players
 * @return {array} Array of player instances
 */
::LiveBlues <-  function() {
	return Players().Team(TF_TEAM_BLUE).Alive().Array();
};

/**
 * Get dead blue players
 * @return {array} Array of player instances
 */
::DeadBlues <-  function() {
	return Players().Team(TF_TEAM_BLUE).Dead().Array();
};


/**
 * CTFPlayer Extra Functions
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Checks if a player is alive
 * @return {bool} - True if the player is alive, false otherwise
 */
CTFPlayer_IsAlive <-  function() {
	return NetProps.GetPropInt(this, "m_lifeState") == 0;
}

/**
 * Cause the player to just die
 * @param {bool} silently Quietly move the player to the 'unalive' state without any pain
 * @noreturn
 */
CTFPlayer_Die <-  function(silently = true) {
	if (!this.IsAlive()) {
		return;
	}

	if (silently == true) {
		NetProps.SetPropInt(this, "m_iObserverLastMode", 5);
		local team = this.GetTeam();
		NetProps.SetPropInt(this, "m_iTeamNum", 1);
		this.DispatchSpawn();
		NetProps.SetPropInt(this, "m_iTeamNum", team);
	} else {
		this.TakeDamage(this.GetHealth(), 0, this);

		// self-damage is being neutralised by something
		if (this.IsAlive()) {
			this.TakeDamage(this.GetHealth(), 0, worldspawn)
		}
	}
}

/**
 * Kill a player using a fizzle effect
 * Uses Cow Mangler by default
 * Dropped weapons and ammo packs can't be fizzled
 * @param {bool} remove_weapon Destroy the player's dropped weapon
 * @param {bool} remove_ammopack Destroy the player's dropped ammo pack
 * @param {integer} effect TF_DMG_CUSTOM effect
 */
CTFPlayer_Fizzle <-  function(remove_weapon = false, remove_ammopack = false, effect = TF_DMG_CUSTOM_PLASMA) {
	local Dissolve = function(ent, source = null) {
		source = (source == null) ? ent : source;
		ent.TakeDamageCustom(null, source, null, Vector(0, 0, 0), ent.GetOrigin(), ent.GetHealth(), 0, effect);
	}

	Dissolve(this);

	// self-damage is being neutralised by something
	if (this.IsAlive()) {
		Dissolve(this, worldspawn);
		// Dissolve(this, worldspawn);
		// this.TakeDamageCustom(null, worldspawn, null, Vector(0, 0, 0), this.GetOrigin(), this.GetHealth(), 0, effect);
	}

	// remove dropped weapon
	if (remove_weapon) {
		local ent = null;
		while (ent = Entities.FindByClassname(ent, "tf_dropped_weapon")) {
			if (NetProps.GetPropInt(ent, "m_flAnimTime") == NetProps.GetPropInt(ent, "m_flSimulationTime")) {
				ent.Destroy();
				break;
			}
		}
	}

	// remove dropped ammo pack
	if (remove_ammopack) {
		local ent = null;
		while (ent = Entities.FindByClassname(ent, "tf_ammo_pack")) {
			if (NetProps.GetPropEntity(ent, "m_hOwnerEntity") == this) {
				ent.Destroy();
				break;
			}
		}
	}
};

/**
 * Checks if a player is an observer
 * (Dead on a participating team or on Spectator team, and watching a player, game objective or observer point)
 * @return {bool} True if player is observing something
 */
CTFPlayer_IsObserver <-  function() {
	return NetProps.GetPropInt(this, "m_iObserverMode") != 0;
}

/**
 * Get a player's name
 * @return {string} - Player's name
 */
CTFPlayer_Name <-  function() {
	return NetProps.GetPropString(this, "m_szNetname");
}

/**
 * Get a player's name coloured to their team colour
 * Returned string already includes \x01 reset colour code at the end
 * @return {string} Player's team-coloured name
 */
CTFPlayer_CName <-  function() {
	return ChatColor(this) + this.Name() + CHAT_COLOR_01;
}
// I had to reduce this from ColoredName because it wasn't getting added. Too long?

/**
 * Get a player's Steam Id
 * @return {string} Steam Id
 */
CTFPlayer_SteamId <-  function() {
	return NetProps.GetPropString(this, "m_szNetworkIDString");
}

/**
 * Get a player's User Id
 * This can be used to tell how long they've been in the server session
 * compared with others
 * @return {integer} User Id
 */
CTFPlayer_UserId <-  function() {
	return NetProps.GetPropIntArray(tf_player_manager, "m_iUserID", this.entindex());
}

// Add all these to CTFPlayer and CTFBot
foreach(key, value in this) {
	if (typeof(value) == "function" && startswith(key, "CTFPlayer_")) {
		local func_name = key.slice(10);
		CTFPlayer[func_name] <- value;
		CTFBot[func_name] <- value;
		delete this[key];
	}
};


/**
 * Messaging
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * ChatMsg
 * Sends a message to one or more players
 * Accepts any of the following data types:
 * * null/0 (all players)
 * * player instance (e.g. activator)
 * * team integer (e.g. 2 or TF_TEAM_RED)
 * * array of player instances
 * * targetname string
 * * Players instance
 * @param {any} targets Target data object
 * @param {string} message Message string
 * @param {integer} destination Destination channel. Text chat by default but you could use HUD_PRINTCENTER
 */
::ChatMsg <-  function(targets, message, destination = HUD_PRINTTALK) {
	// add colour code to start of line if colour is used without it
	if (message.find("\x0") && !startswith(message, "\x0")) {
		message = "\x01" + message;
	}

	// all players
	if (targets == null || targets == 0) {
		ClientPrint(null, destination, message);
		return;
	}

	// player
	else if (typeof targets == "instance" && targets.IsValid() && targets instanceof CTFPlayer) {
		ClientPrint(targets, destination, message);
		return;
	}

	// arrays
	// team
	else if (typeof targets == "integer") {
		targets = Players().Team(targets).players;
	}

	// targetname
	else if (typeof targets == "string") {
		targets = Players().Targetname(targets).players;
	}

	// Players instance
	else if (targets instanceof Players) {
		targets = targets.players;
	}

	// array
	if (typeof targets == "array") {
		foreach(target in targets) {
			if (target != null && target.IsValid() && target instanceof CTFPlayer) {
				ClientPrint(target, destination, message);
			}
		}
	}
};

/**
 * Produces a chat colour code from the following types of input value:
 * * Team number integer (produces that team's chat colour)
 * * Player instance - get's the player's team integer and does the above
 * * String of six or eight-character hexadecimal, representing RGB or RGBA
 * @param {any} value Input value
 * @return {string} Hexadecimal chat colour prefix. 'Standard' \x01 if no match found
 */
::ChatColor <-  function(value = null) {
	local color = CHAT_COLOR_01;

	// default value
	if (value == null) {
		return color;
	}

	// player instance
	if (typeof value == "instance" && value instanceof CTFPlayer && value.IsValid()) {
		value = value.GetTeam();
	}

	// hexadecimal string
	else if (typeof value == "string") {
		if (value.len() == 3 || value.len() == 6) {
			color = CHAT_COLOR_07 + value;
		} else if (value.len() == 4 || value.len() == 8) {
			color = CHAT_COLOR_08 + value;
		}
	}

	// team integer
	if (typeof value == "integer") {
		switch (value) {
			case TEAM_SPECTATOR: {
				color = format("%s%X", CHAT_COLOR_07, CHAT_COLOR_SPEC);
				break;
			}
			case TF_TEAM_RED: {
				color = format("%s%X", CHAT_COLOR_07, CHAT_COLOR_RED);
				break;
			}
			case TF_TEAM_BLUE: {
				color = format("%s%X", CHAT_COLOR_07, CHAT_COLOR_BLUE);
				break;
			}
		}
	}

	return color;
};

/**
 * Wrapper for ChatMsg which directs the message to the Center Say channel
 * @param {any} targets Target data object
 * @param {string} message Message string
 */
::CenterMsg <-  function(targets, message) {
	ChatMsg(targets, message, HUD_PRINTCENTER);
};

/**
 * Show a training annotation in the world above an entity.
 * All arguments are supplied in a table: Annot({ text = `Your mum` })
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
::Annot <-  function(options = {}) {
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
};


/**
 * Array Helpers
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Randomise an array
 * @param {array} array Input array
 * @return {array} A new array with the original values in a random order
 */
::RandomiseArray <-  function(array) {
	local new_array = [];

	while (array.len() > 0) {
		local index = RandomInt(0, array.len() - 1);
		new_array.push(array.remove(index));
	}

	return new_array;
};


/**
 * VScript Helpers
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Iterates the event tables and removes any entries attached to an invalid instance
 * Unlike ClearGameEventCallbacks, this does not wipe every event from the tables
 */
::CleanGameEventCallbacks <-  function() {
	local Clean = function(event_table) {
		if (!(event_table in ROOT)) {
			return;
		}

		foreach(event, event_array in ROOT[event_table]) {
			for (local i = event_array.len() - 1; i >= 0; i--) {
				if (!event_array[i].self.IsValid()) {
					event_array.remove(i);
				}
			}
		}
	};

	Clean("GameEventCallbacks");
	// clean(ScriptEventCallbacks);
	Clean("ScriptHookCallbacks");
};



/**
 * Further Instructions
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Matty's Player Lists v0.1
 *
 * Easy creation of lists of players by characteristic.
 * Chain methods to further refine the list.
 *
 * Usage:
 * `Players()` returns all players on red and blue as a Players class instance.
 * Chain methods to refine the results.
 * Adding the `.players` property to the end of the chain returns the results in an array.
 * Many methods can be given a `false` argument to invert them.
 *
 * Example									Method						Alternative
 * Get all players on team 2 (Red)			Players().Team(2)
 * Get all dead players on team 3 (Blue)	Players().Team(3).Dead()
 * Get all bot players						Players().Bot()				Players().Human(false)
 * Get all non-bot players					Players().Human()			Players().Bot(false)
 * Get all live players						Players().Alive()			Players().Dead(false)
 * Get all observers						Players().Observing()
 * Get all players with the targetname		Players().Targetname(`whatever`)
 * Get all players within a radius			Players().Radius(origin, radius)
 *
 * Modify the results
 * Shuffle the order of the array			Players().Shuffle()
 * Sort by time on the server / User Id		Players().SortByUserId()
 * Exclude a player, array of players or Players results
 * 											Players().Exclude(player)	Players().Exclude(Players.Dead())
 *
 * Debugging
 * Display the results in the console		Players().Display()
 */

/**
 * Matty's Universal Teleporter v0.2.1.1
 * Designed to be included by matty/stocks/globals.nut
 *
 * Teleport any entity or array of entities to one or more destinations.
 * Optionally arrange in a grid around a single destination (on by default).
 *
 * Inputs accept an entity instance, array of entities, targetname or classname.
 * All instances of the supplied targetname or classname are found.
 * Also accepts the integer value of a team, e.g. 2 for red.
 *
 * Teleport players conveniently without needing to make map-wide triggers.
 * Optionally respawns any dead player passed into the function (off by default).
 */

/**
 * Usage:
 *
 * TeleportStuff(source entity or entities, destination entity or entities)
 * Both values can be a `targetname`, `classname`, instance, array or team number.
 * All instances of targetnames and classnames are used.
 *
 * 		TeleportStuff(TF_TEAM_RED, `multiple_destinations`)
 * 		TeleportStuff(3, `single_destination`)
 * 		TeleportStuff(`named_entities`, array_of_entities)
 *
 * Optional arguments 3 and 4 and their default values
 * 		TeleportStuff(source, destination, respawn = false, grid = true)
 */

/*
TeleportStuff Changlog
v0.2.2
Created options table parameter and moved 'grid' and 'respawn' parameters into it.
v0.2.1.1
Target to teleport was being checked if it was an instance but presumed it was an entity.
As a result, passing Players instances to it caused an error when it checked IsValid().
Now, instances are checked if they are an instance of CBaseEntity or Players.
v0.2.1
Velocity is nullified on teleport
*/


/*
	List of common constants

	ETFTeam
	TEAM_UNASSIGNED				0
	TEAM_SPECTATOR				1
	TF_TEAM_RED 				2
	TF_TEAM_BLUE 				3
	TEAM_ANY 					-2
	TEAM_INVALID 				-1

	EmitSoundEx filters
	RECIPIENT_FILTER_DEFAULT 			0
	RECIPIENT_FILTER_PAS_ATTENUATION 	1
	RECIPIENT_FILTER_PAS 				2
	RECIPIENT_FILTER_PVS 				3
	RECIPIENT_FILTER_SINGLE_PLAYER 		4
	RECIPIENT_FILTER_GLOBAL 			5
	RECIPIENT_FILTER_TEAM 				6

    Custom damage types for use with Fizzle
    TF_DMG_CUSTOM_PLASMA                     (46) - Cow Mangler / Righteous Bison / Pomson / Short Circuit
    TF_DMG_CUSTOM_PLASMA_CHARGED             (47) - Explode into gibs, which then plasma fizzle.
    TF_DMG_CUSTOM_TAUNTATK_BARBARIAN_SWING   (24) - Decapitate. Character does a special animation. No velocity. Squelch noise
    TF_DMG_CUSTOM_HEADSHOT_DECAPITATION      (51) - Decapitation. Headshot kill feed icon as if sniped. Squelch noise
    TF_DMG_CUSTOM_MERASMUS_DECAPITATION      (60) - Decapitation. Merasmus attack kill feed icon. Squelch noise
    TF_DMG_CUSTOM_KART                       (75) - Higher velocity death
    TF_DMG_CUSTOM_GOLD_WRENCH                (35) - Paralyze and play a gold hit sound
*/


/*
	Ragdoll properties for future use
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
	3	Same as 1 but happens very fast - good for quick removal
*/


/**
 * Development notes
 * ----------------------------------------------------------------------------------------------------
 */

/*
EmitSoundEx common uses
Playing a UI sound to a client
Emitting a sound in the world from somewhere with a set radius
Playing a looping ambient sound
	Either store sound in a table or make an ambient_generic
	Use RECIPIENT_FILTER_PAS

Keyvalues
sound
	Sorts between raw and soundscript
volume
	Integer 100 percent or float 1.0 (or integer 1)
radius
	Integer
channel
	integer or string
loop
	If key provided, always true
	SPlayAmbient(sound, table)
playfrom
	CBaseEntity Instance or targetname or origin
playto
	Play to a client or array of clients or Players()
	SPlayToClient(sound, client, table)
*/


// ROOT
//     GameEventCallbacks (event table)
//         arena_round_start (event)
//             [array] (of hooks of this event)
//                 {table} (data I don't fully understand)
//                     self (entity the event is associated with)

// If you store a function in global scope somewhere, you can compare its handle with those in the event tables.

/**
 * TeleportStuff
 * Optionally use landmark style teleportation, if a landmark is specified
 * Use a table for options
 * Integrate PlayerLists.
 *
 * Teleport into circular formation around a destination?
 * 		teleport a set distance from a destination with an angle that's a fraction of a circle
 *		e.g. teleport 64  units from centre at 0, 90, 180, 270
 *  	teleport 128 units from centre at 0, 45, 90, 135, 180, etc.
 *
 * Grid todo
 * 		add min and max bounds for square
 * 		account for more than 32 players
 * 		support a ratio of rows to columns for a wide group
 * 		convert local origin to absolute origin somehow to allow for diagonal grids
 */


/**
 * Old or WIP functions
 * ----------------------------------------------------------------------------------------------------
 */

// work in progress. not functional
/* function SPlay(sound, table = {}) {

	// precache
	local sound_name_lowercase = params.sound_name.tolower();
	if (sound_name_lowercase.find(".wav") || sound_name_lowercase.find(".mp3")) {
		PrecacheSound(params.sound_name);
	} else {
		if (!PrecacheScriptSound(params.sound_name)) {
			printl(__FILE__ + " -- SPlay -- soundscript sound not found: " + params.sound_name);
			return;
		}
	}

	local sounds_to_play = [];

	// create table for EmitSoundEx
	local params = {
		channel = 6 // chan_static
		sound_level = 80 //
	};

	// volume
	if ("volume" in table) {
		if (typeof table.volume == "integer") {
			if (table.volume == 1) {
				params.volume <- 1.0;
			} else {
				params.volume <- table.volume * 0.01;
			}
		} else if (typeof table.volume == "float") {
			params.volume <- table.volume;
		}
	}

	// radius
	if ("radius" in table) {
		params.sound_level = SoundRadiustoDecibels(table.radius);
	}

	// channel
	if ("channel" in table) {
		local channel = table.channel;

		if (typeof channel == "integer") {
			params.channel = channel;
		} else if (typeof channel == "string") {
			if (channel == "static") {
				params.channel = 6;
			} else if (channel == "auto") {
				params.channel = 0
			}
		}
	}

	//playfrom
	if ("playfrom" in table) {

		// array of instances to process later
		local ents = [];

		// entity instance
		if (typeof table.playfrom == "instance" && table.playfrom instanceof CBaseEntity) {
			ents.append(table.playfrom);
		}

		// string
		else if (typeof table.playfrom == "string") {
			local targetname = table.playfrom;
			local ent = null;
			local ents = [];

			while ((ent = Entities.FindByName(ent, targetname)) != null) {
				ents.append(ent);
			}
		}

		// vector
		else if (typeof table.playfrom == "vector") {
			params.origin <- table.playfrom;
			sounds_to_play.append(params);
		}

		// process array of ents
		if (ents.len() > 0) {
			foreach(ent in ents) {

				// server-side ent or edict
				if (ent.entindex() == 0) {
					params.origin <- ent.GetOrigin();
					delete params.entity;
				} else {
					params.entity <- ent;
					delete params.origin;
				}

				sounds_to_play.append(params);
			}
		}
	}

	// play all tables in the array
	foreach(sound in sounds_to_play) {
		EmitSoundEx(sound);
	}
} */