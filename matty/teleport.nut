/**
 * Teleporting players conveniently without resorting to map-wide triggers.
 *
 * Teleport players to multiple specified location entities
 * Teleport players into a grid formation so you can avoid teleporting them all to one spot
 *
 * Work-in-progress but mostly functional
 */

IncludeScript("matty/stocks.nut");

/**
 * 11. Teleport players at random around a point, rounded to a ^2 grid value, avoiding overlapping
 * 12. Teleport players with a certain table slot value.
 */

// optionally respawn dead players

// teleport some players somewhere and others somewhere else
// put them in different arrays?

// teleport players until destinations are full -- aka a set number of players
// how to select players?

// teleport !activator one place and the rest of the team somewhere else

// create array using filters?
// supply a filter argument, perhaps in the form of a function
// a filter could be a radius check or volume check

// teleport into grid formation around a destination

// teleport into circular formation around a destination

// teleport a set distance from a destination with an angle that's a fraction of a circle
// e.g. teleport 64  units from centre at 0, 90, 180, 270
//      teleport 128 units from centre at 0, 45, 90, 135, 180, etc.

// get number of players
// calculate optimal number of rows and columns
// calculate length of a row and column in units by multiplying 64 * length
// get center position by dividing by 2

// use info_team_spawn configuration

// teleport but retain stuff relative to landmark
// has to be done when players are inside a trigger
// unless we can use a source entity landmark
// look at the code for this ent


local option_spacing = 128.0;
local option_randomise_destinations_when_fewer = true;

function TeleportToDestinations(players, destinations) {
	// adapt this function for entities
	// may need a different function which grabs origin/player origin

	// randomise destination array if fewer players than destinations
	if (players.len() < destinations.len() && option_randomise_destinations_when_fewer) {
		destinations = RandomiseArray(destinations);
	}

	// extend destination array if smaller than players array
	while (destinations.len() < players.len()) {
		destinations.extend(destinations);
	}

	local players_len = players.len();

	// for (local i = 0; i < players_len; i++)
	// {
	//     players[i].Teleport(true, destinations[i].GetOrigin(), true, destinations[i].GetAbsAngles(), false, Vector());
	// }

	foreach(index, player in players) {
		players[index].Teleport(true, destinations[index].GetOrigin(), true, destinations[index].GetAbsAngles(), false, Vector());
	}
}

function GetDestinations(targetname) {
	local array = [];
	local ent = null;

	while (ent = Entities.FindByName(ent, targetname)) {
		array.push(ent);
	}

	return array;
}

function TeleportTeam(team, destination_entity, respawn = false) {
	local players = GetTeamPlayers(team);
	local origin = destination_entity.GetOrigin();
	local angles = destination_entity.GetAbsAngles();

	foreach(player in players) {
		if (!player.IsAlive()) {
			if (respawn) {
				ForceRespawn(player);
			} else {
				continue;
			}
		}

		player.Teleport(true, origin, true, angles, false, Vector());
	}
}

function RandomiseArray(array) {
	local new_array = [];

	while (array.len() > 0) {
		local index = RandomInt(0, array.len() - 1);
		new_array.push(array[index]);
		array.remove(index); // note: remove() returns the value.
	}

	return new_array;
}


function TeleportToGrid(players, destination) {
	// to do
	// add min and max bounds for square
	// account for more than 32 players
	// support a ratio of rows to columns for a wide group
	// convert local origin to absolute origin somehow to allow for diagonal grids

	local len = players.len();
	local rows = ceil(sqrt(len)).tointeger();

	// printl(self + " TeleportToGrid -- rows = " + rows);
	printl(self + " TeleportToGrid -- destination local origin is " + destination.GetLocalOrigin());

	local offset = ((rows * option_spacing) / 2) - (option_spacing / 2);

	local origin = destination.GetOrigin();
	// printl(self + " TeleportToGrid -- origin = " + origin);

	origin = Vector(origin.x - offset, origin.y + offset, origin.z);

	// printl(self + " TeleportToGrid -- offset = " + offset);

	local angles = destination.GetAbsAngles();

	// column
	for (local i = 0; i < rows && players.len(); i++) {
		// row
		for (local j = 0; j < rows && players.len(); j++) {
			local new_origin = Vector(origin.x + (option_spacing * j), origin.y - (option_spacing * i), origin.z);
			local player = players.pop();
			player.Teleport(true, new_origin, true, angles, false, Vector());
			// printl(self + " TeleportToGrid -- teleporting " + player.Name() + " to " + new_origin);
		}
	}
}

function Test_GetAllPlayers() {
	local array = [];
	local maxclients = MaxClients();

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.IsValid()) {
			array.push(player);
		}
	}

	return array;
}