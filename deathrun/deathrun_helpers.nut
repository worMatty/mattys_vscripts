/*
	Deathrun Helpers
	Functions to do common stuff in a map
*/

/**
 * Simple player teleporter/ Work-in-progress
 *
 * trigger_teleport preserve's the player's momentum as they are teleported.
 * So does point_teleport.
 * This can result in players sliding back into the return teleport trigger.
 * This script effectively stops the player in-place when they arrive to stop that.
 * The original intention was to preserve momentum but change the movement direction
 * to match the destination entity but I could not work out how to do that at the time.
 * This script is being developed alongside Steamworks Extreme
 */

/**
 * Teleport the player to a destination entity.
 * Changes the direction of their velocity so they move in the right direction on arrival
 * @param {CTFPlayer} player Player instance
 * @param {string} destination Targetname of destination entity
 * @param {bool} zero_velocity Set velocity to zero on arrival (their speed becomes 0 and they stop moving)
 */
function TeleportPlayer(player, destination, zero_velocity = false) {
	local ent = Entities.FindByName(null, destination);
	if (!ent) return;

	local velocity = Vector(0, 0, 0);
	if (!zero_velocity) {
		velocity = ent.GetAbsAngles().Forward() * player.GetAbsVelocity().Length(); // apply player's magnitude to ent's forward vector
		velocity += ent.GetAbsVelocity(); // add ent's velocity to player's in case it's a moving platform
	}

	player.Teleport(true, ent.GetOrigin(), true, ent.GetAbsAngles(), true, velocity);
	// note: model appears to turn on teleport from third person
}