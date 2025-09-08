/**
 * Jetboots
 *
 * Press and hold jump while in the air and activate jetboots.
 * An impulse is imparted every frame, pushing you higher in the air over time.
 * You have a fuel meter so you can't use it all the time.
 */

// NetProps.GetPropInt(player, "m_nButtons")
// player.IsJumping()
// ApplyAbsVelocityImpulse(Vector())
// ApplyLocalAngularVelocityImpulse(Vector())

/*
Future:
Don't start boosting until you press Jump again (i.e. double jump bind)
Don't boost a scout until after they've used their air dash(es)
Output fuel to somewhere else
Add boosting noises
Add noise for attempting to use while out of fuel
Add noise when fuel runs out
Add jet effects to feet
Add smoke trail
Disrupt physics objects nearby (send out push wave? Blast with zero damage? point_push?)
Create a custom weapon which has ammo that can be replenished using ammo packs, and hopefully has a HUD element
*/

// constants
getroottable().IN_JUMP <- Constants.FButtons.IN_JUMP;
getroottable().HUD_PRINTTALK <- Constants.EHudNotify.HUD_PRINTTALK;
getroottable().HUD_PRINTCENTER <- Constants.EHudNotify.HUD_PRINTCENTER;
default_max_fuel <- 40;
start_refuel_delay <- 3.0; // time player must be landed before fuel starts to replenish

// variables
users <- []; // players with jetboots

/**
 * Enable the jetboots for the input activator player
 * If there are no users of jetboots when the player is added,
 * the Think function starts running
 * @param {integer} fuel Starting fuel
 * @param {integer} max_fuel Max fuel capacity
 */
function EnableJetBoots(fuel = default_max_fuel, max_fuel = default_max_fuel) {
	local player = activator;

	if (player == null || !player.IsValid() || !(activator instanceof CTFPlayer)) {
		return error(__FILE__ + " -- EnableJetBoots() -- Activator is invalid or not a player\n");
	}

	users.append({
		player = player
		fuel = fuel
		max_fuel = max_fuel
		landed = 0.0
	});

	ClientPrint(player, HUD_PRINTTALK, "Equipped you with Jetboots! Press and hold Jump");
	ClientPrint(player, HUD_PRINTCENTER, "Jetboots fuel: " + fuel);

	if (self.GetScriptThinkFunc() == "") {
		AddThinkToEnt(self, "Think");
	}
}

/**
 * Disable the jetboots for the input activator player
 * If there are no users of jetboots when the player is removed,
 * the Think function stops running
 */
function DisableJetBoots() {
	local player = activator;

	if (player == null || !player.IsValid() || !(activator instanceof CTFPlayer)) {
		return error(__FILE__ + " -- DisableJetBoots() -- Activator is invalid or not a player\n");
	}

	// remove player from users array
	foreach(i, value in users) {
		if (value.player == player) {
			users.remove(i);
			break;
		}
	}

	ClientPrint(player, HUD_PRINTTALK, "Removed Jetboots from you");

	if (users.len() == 0) {
		AddThinkToEnt(player, null);
	}
}

/**
 * Toggle jetboots on the activator player
 * Player fuel and max fuel will be set to default values
 */
function ToggleJetboots() {
	if (activator == null || !activator.IsValid() || !(activator instanceof CTFPlayer)) {
		return error(__FILE__ + " -- ToggleJetboots() -- Activator is invalid or not a player\n");
	}

	// is user in array?
	local using = false;

	foreach(i, value in users) {
		if (value.player == activator) {
			using = true;
			break;
		}
	}

	if (using) {
		DisableJetBoots();
	} else {
		EnableJetBoots();
	}
}

/**
 * Think function
 * Iterates array of jetboot users
 * Checks if they are boosting, applies impulse and deducts fuel
 * Checks if they have been landed for a certain time and adds fuel
 */
function Think() {
	for (local i = users.len() - 1; i >= 0; i--) {
		local user = users[i];
		local player = user.player;

		if (!user.player.IsValid()) {
			users.remove(i);
			continue;
		}

		// using jetboots
		if (player.IsJumping()) {
			user.landed = 0.0;

			if (NetProps.GetPropInt(player, "m_nButtons") & IN_JUMP && user.fuel > 0) {
				player.ApplyAbsVelocityImpulse(Vector(0, 0, 120.0));
				user.fuel -= 1;
				ClientPrint(player, HUD_PRINTCENTER, "Jetboots fuel: " + user.fuel);
			}
		} else {
			user.landed += 0.1;

			if (user.fuel < user.max_fuel && user.landed >= start_refuel_delay) {
				user.fuel += 1;
				ClientPrint(player, HUD_PRINTCENTER, "Jetboots fuel: " + user.fuel);
			}
		}
	}
}