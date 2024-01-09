/**
 * Custom projectile
 *
 * Unfinished
 */

/**
 * Method:
 * 1. Spawn the projectile
 * Use a model or sprite
 * Collision could be handled by:
 * * A trigger brush
 * * A hull check or trace
 * * Checking if the coordinates are inside the bounds of the nearest player
 *      Though that would prevent us from colliding with a wall.
 * Maybe we should use a trace, check the position of the projectile along it,
 * if it's touching a player, explode. If it's at the end of the trace, die.
 * A hull check or mini trace is probably best.
 */

/**
 * Create a projectile and start it on its journey
 * The root entity is used as the parent and all the properties
 * of the projectile are stored in its script scope.
 * This makes it self-contained and cleans up anything when it's killed.
 * @param {table} table Table of keyvalues
 */
function CreateProjectile(table = {}) {
	// movement
    angles = null;
    velocity = null; // units per second
	forward_vector = null; // alternative combined angles and velocity in the form of magnitude which I believe is in units per second though I don't yet know how to calculate that

	// damage
	damage = 100;
	damage_type = DMG_BLAST | DMG_BURN; // could be an OR. Should we have different amounts of each type? Probably not supported. This is not WoW
	damage_radius = 0; // if specified, damage falls off
	blast_force = null; // if specified, amount of force to apply from point of impact

	// effects
	trail = null; // env_spritetrail? Could this be the material? Should we handle that in the constructor and place the spritetrail ent in here? Can we dispatch effect?

	// get entity from template?
	template = null;

	foreach(key, value in table) {
		if (typeof value != "function") {
			this[key] <- value;
		}
	}

    // create entities
    // add keyvalues
    // add think function
    // spawn?

	function Think() {
		// calculate next position
		// trace line or hull
		// check collision
		// detonate or teleport
	}

	function Detonate() {

	}
}