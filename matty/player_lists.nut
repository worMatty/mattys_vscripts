IncludeScript("matty/stocks.nut");

/**
 * Functions to generate arrays of players.
 *
 * Work-in-progress.
 *
 * For simplicity a player is someone on red or blue in this context.
 * Spectators or Team_Unassigned are excluded.
 * Check the Players class down the page to see all the available methods
 *
 * Usage:
 * Chain methods to refine the list. Each method returns a Players() instance to enable chaining
 * Add the 'players. property at the end to return an array
 * Players() returns all players as a Players class instance
 * Players().Team(2).players returns all Red players as an array
 * Players().Team(3).Dead().players returns all dead players on Blue team
 */

/**
 * Stuff to do:
 *
 * By proximity to a location
 * Within a location
 * Within a trigger
 * Set quantity
 * Exclude one or more
 * Include / exclude activator
 * Split into groups / divide.
 * 	Number of groups
 * 	Max group size
 */


// teams will be an array

/**
 * States
 *
 * Alive NOT
 * Dead
 * Observing (must be dead)
 * Team NOT
 * Human NOT
 * Bot
 * Targetname NOT
 * Within radius of NOT
 * Class
 * Has script key value
 */

// Generator
// Filter
// Modifier (shuffle, split)

// unfinished
function GetPlayers(options = {}) {
	local default_options = {
		include_spec = false
		team = null
		alive = null
		targetname = null
		proximity_to = null
		radius = 512
		human = null
	}

	local players = null;

	if (team != null) {
		players = Players(players.Team(team));
	}

	if (alive != null) {
		players <- Players(players.Alive(alive));
	}

	if (targetname != null) {
		players <- Players(players.Targetname(targetname));
	}

	// todo: proximity using vectors and distance

	if (human != null) {
		players <- Players(players.Human(human));
	}

	return players.players;
}


function GetAllPlayers(only_playing = true) {
	local players = [];

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null) {
			if (only_playing && player.GetTeam() > 1) {
				players.push(player);
			} else if (only_playing == false) {
				players.push(player);
			}
		}
	}

	return players;
}

::Players <- class {
	constructor(_options = {}) {
		options = _options;

		foreach(key, value in default_options) {
			if (!(key in options)) {
				options[key] <- value;
			}
		}

		players = GetAllPlayers();
	}

	// constants
	static maxclients = MaxClients()
	static player_manager = Entities.FindByClassname(null, "tf_player_manager")
	static default_options = {
		include_spec = false
	}

	// variables
	players = null
	options = null
	array = players	// does this work?

	// generators
	function Alive(alive = true) {
		players = players.filter(function(index, player) {
			return (player.IsAlive() == alive)
		})

		return this;
	}

	function Dead(dead = true) {
		return Alive(!dead);
	}

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
			return (player.GetTeam() == team)
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

	// output
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
			return GetPlayerUserId(a) <= > GetPlayerUserId(b);
		});

		return this;
	}

	function Display() {
		foreach(player in players) {
			printl(player.Name() + " (" + GetPlayerUserId(player) + ") -- team " + player.GetTeam() + " -- alive: " + player.IsAlive() + " -- bot: " + IsPlayerABot(player));
		}
	}

	// internal
	function GetAllPlayers() {
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

	function GetPlayerUserId(player) {
		return NetProps.GetPropIntArray(player_manager, "m_iUserID", player.entindex());
	}

	function RemovePlayers(_players) {
		foreach(player in _players) {
			this.RemovePlayer(player);
		}
	}

	function RemovePlayer(player) {
		local index = players.find(player);
		if (index != null) {
			players.remove(index);
		}
	}
};