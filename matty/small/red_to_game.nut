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
		reds.resize(qty);
	}

	// if the activator must be included, ensure they are in the array
	if (include_activator && activator && activator.IsValid() && activator instanceof CTFPlayer && activator.GetTeam() == TF_TEAM_RED && activator.IsAlive()) {
		if (reds.find(activator) == null) {
			reds.insert(RandomInt(0, reds.len() - 1), activator); // insert them in a random spot in the array
			reds.resize(qty); // if the live red activator was not in the results, it's because a quantity was specified
		}
	}

	// teleport the remaining reds in the array to the destinations
	TeleportStuff(reds, dest);
}

/**
 * Teleport a quantity of live reds to one place and the rest to another.
 * Useful to teleport people to a finite number of spots in a minigame,
 * and the rest to audience positions.
 * Players are shuffled before being split up.
 * @param {integer} qty Number of players to teleport to dest1
 * @param {string} dest1 Targetname of destination entities to send group 1 to. Also accepts entity instance and array of instances
 * @param {string} dest2 Same as above but for group 2
 * @param {bool} include_act1 Include the activator in group 1 if they are present, alive and on red team
 */
function SplitTeleReds(qty, dest1, dest2, include_act1 = true) {
	// get live red players
	local group1 = GetPlayers({
		team = TF_TEAM_RED,
		alive = true,
		shuffle = true
	});
	local group2 = [];

	// include activator?
	if (include_act1 && activator && activator.IsValid() && activator instanceof CTFPlayer && activator.GetTeam() == TF_TEAM_RED && activator.IsAlive()) {
		local index = group1.find(activator); // get activator index in group1
		if (index != null && index >= qty) { // index is later than qty
			group1.remove(index); // remove activator from group1
			group1.insert(RandomInt(0, qty - 1), activator); // insert activator in a new random index lower than qty
		}
	}

	if (group1.len() > qty) { // more reds than the qty
		group2 = group1.slice(qty, group1.len()); // slice excess reds and put them in group2
	}

	TeleportStuff(group1, dest1);
	if (group2.len()) {
		TeleportStuff(group2, dest2);
	}
}