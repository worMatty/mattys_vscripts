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

local sound = null;

/**
 * Teleport the player to the destination.
 * Changes the angle of their momentum to match their new angle
 * @param {string} destination Targetname of destination entity
 * @param {bool} stop_moving Set momentum to 0 on teleport, or change momentum angle to match new angle
 */
Teleport <-  function(destination, stop_moving = false) {
	Assert(typeof destination == "string", self + " -- destination is not a string value");

	local ent = Entities.FindByName(null, destination);

	if (ent == null) {
		printl(self + " -- destination entity '" + destination + "' not found");
		return;
	}

	activator.SetAbsOrigin(ent.GetOrigin());
	activator.SnapEyeAngles(ent.GetAbsAngles());

	if (stop_moving) {
		activator.SetAbsVelocity(Vector(0 0 0));
	} else {
		local velocity = ent.GetAbsAngles().Forward() * activator.GetAbsVelocity().Length();
		activator.SetAbsVelocity(velocity);
	}

	if (sound != null) {
		EmitSoundEx({
			sound_name = sound,
			channel = 6,
			entity = activator,
			filter_type = 4
		});
	}
}

/**
 * Set the sound to play to the teleporting player
 * @param {string} new_sound Path to new sound file, relative to tf/sound
 */
function SetSound(new_sound) {
	Assert(typeof new_sound == "string", self + " -- sound is not a string value");

	PrecacheSound(new_sound);
	PrecacheScriptSound(new_sound);
	sound = new_sound;
}