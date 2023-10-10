/**
 * Matty's Universal Teleporter v0.2
 *
 * Teleport any entity or array of entities to one or more destinations.
 * Optionally arrange in a grid around a single destination (on by default).
 *
 * Inputs accept an entity instance, array of entities, targetname or classname.
 * Also accepts an integer and returns an array with players belonging to that team.
 *
 * Teleport players conveniently without needing to make map-wide triggers.
 * Optionally respawns any dead player passed into the function (on by default).
 */

/**
 * Example usage:
 *
 * TeleportStuff(Constants.ETFTeam.TF_TEAM_RED, `tele_dest1`)	// teleport red team to a single entity
 * TeleportStuff(`named_entity`, `tele_dest2`)					// teleport named entity/entities to named entity/entities
 * TeleportStuff(array_of_targets, array_of_destinations)		// teleport an array of targets to an array of destinations
 */

IncludeScript("matty/stocks.nut");

local option_grid_spacing = 64.0; // space between entities in grid formation
local option_shuffle_destinations = true; // shuffle destinations when they surpass targets

/**
 * Teleport one or more entities to one or more destination entities.
 * If using a target or classname, it will find all instances.
 * @param {any} targets Team number, entity instance, array of entities, targetname, classname
 * @param {any} destinations Instance or targetname of destination entity
 * @param {bool} respawn Optionally respawn any dead players before teleporting
 * @return {number} Number of entities teleported
 */
function TeleportStuff(targets, destinations, respawn = true, grid = true) {
	targets = ProcessInput(targets);
	destinations = ProcessInput(destinations);

	// filter dead players when not respawning
	if (respawn == false) {
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
		printl(self + " destinations.len() = " + destinations.len() + " targets.len() = " + targets.len());
		return;
	}

	local teleported = 0;

	// one destination, optionally in formation
	if (destinations.len() == 1 && grid == true) {
		local destination = destinations.pop();
		local rows = ceil(sqrt(targets.len())).tointeger();
		local offset = ((rows * option_grid_spacing) / 2) - (option_grid_spacing / 2);

		local origin = destination.GetOrigin();
		origin = Vector(origin.x - offset, origin.y + offset, origin.z);
		local angles = destination.GetAbsAngles();

		// column
		for (local i = 0; i < rows && targets.len(); i++) {
			// row
			for (local j = 0; j < rows && targets.len(); j++) {
				local new_origin = Vector(origin.x + (option_grid_spacing * j), origin.y - (option_grid_spacing * i), origin.z);
				local target = targets.pop();
				if (target instanceof CTFPlayer && !target.IsAlive()) {
					if (respawn) {
						target.ForceRespawn();
					} else {
						continue;
					}
				}
				target.Teleport(true, new_origin, true, angles, false, Vector());
				teleported++;
			}
		}
	} else
	// multiple destinations
	{
		// randomise destination array if fewer targets than destinations
		if (targets.len() < destinations.len() && option_shuffle_destinations) {
			destinations = RandomiseArray(destinations);
		}

		// extend destinations array if smaller than targets array
		while (destinations.len() < targets.len()) {
			destinations.extend(destinations);
		}

		foreach(index, target in targets) {
			if (target instanceof CTFPlayer && !target.IsAlive()) {
				if (respawn) {
					target.ForceRespawn();
				} else {
					continue;
				}
			}
			target.Teleport(true, destinations[index].GetOrigin(), true, destinations[index].GetAbsAngles(), false, Vector());
			teleported++;
		}
	}

	return teleported;
}

/**
 * Process the input and produce an array of teleport targets or destinations.
 * Accepts an array of entity instances, an entity instance, a targetname or classname string, or team integer.
 * @param {any} input Input value for the teleport target(s) or destination(s)
 * @return {array} Array of teleport targets or destinations
 */
function ProcessInput(input) {
	local output = [];

	// array
	if (typeof input == "array" && input.len() > 0) {
		output = input;
	}
	// instance entity
	else if (typeof input == "instance" && input.IsValid()) {
		output.push(input);
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
		output = GetTeamPlayers(input);
	}

	return output;
}



/**
 * 11. Teleport players at random around a point, rounded to a ^2 grid value, avoiding overlapping
 * 12. Teleport players with a certain table slot value.
 *
 * Combine functions into one
 * Check typeof incoming destination
 * If string, get instance or array of instances
 * If instance...
 * If array...
 * When using the thing, check if array or instance.
 * If array, teleport to each destination entity.
 * If instance, don't.
 * Optionally teleport in grid formation
 * Optionally use landmark style teleportation, if a landmark is specified
 * Use a table for options
 * Make respawn dead an option
 * Integrate PlayerLists.
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

// grid todo
// add min and max bounds for square
// account for more than 32 players
// support a ratio of rows to columns for a wide group
// convert local origin to absolute origin somehow to allow for diagonal grids