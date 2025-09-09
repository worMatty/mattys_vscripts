/*
	Teleport a random selection of live red players to a particular place
	or set of places. If the activator is a live red player, make sure
	they're in the group.
*/

IncludeScript("matty/stocks2.nut");

/**
 * Teleport live red players to the given destination entities.
 * The array of reds is shuffled.
 * @param {string/CBaseEntity/array} dest Destination entity targetname, instance or array of instances
 * @param {integer} qty Cap the number of reds to this. Reds after this index will be removed from the array
 * @param {bool} include_activator True to guarantee the activator is in the results. They must be alive and on red.
 */
function TeleLiveReds(dest, qty = null, include_activator = true) {
	// get an array of live reds, shuffled
	local reds = GetPlayers({
		team = TF_TEAM_RED,
		alive = true,
		shuffle = true
	});

	// if we set a quantity and have too many reds, remove some
	if (qty && reds.len() > qty) {
		reds = reds.resize(qty);
	}

	// if the activator must be included, ensure they are in the array
	if (include_activator && activator.IsValid() && activator instanceof CTFPlayer && activator.GetTeam() == TF_TEAM_RED && activator.IsAlive()) {
		if (reds.find(activator) == null) {
			reds.insert(RandomInt(0, reds.len() - 1)); // insert them in a random spot in the array
			reds.resize(qty); // if the live red activator was not in the results, it's because a quantity was specified
		}
	}

	// teleport the remaining reds in the array to the destinations
	TeleportStuff(reds, dest);
}