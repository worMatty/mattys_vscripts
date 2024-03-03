/**
 * Give each player a set run speed
 * Uses an attribute.
 * Designed to be called from a trigger with a player as the activator.
 * Will not work if the activator is not a player or has no class.
 */

// Default TF2 class max run speeds
local class_speed = [
	0, // no class
	400, // scout
	300, // sniper
	240, // soldier
	280, // demoman
	320, // medic
	230, // heavy
	300, // pyro
	320, // spy
	300 // engineer
];

function GetClassRunSpeed(class) {
	return class_speed[class];
}

function IsValidPlayer(player) {
	return (player != instanceof CTFPlayer || player.GetPlayerClass() < 1);
}

function SetRunSpeed(runspeed) {
	if (!IsValidPlayer(activator)) {
		return;
	}

	local class_run_speed = GetClassRunSpeed(activator.GetPlayerClass());
	local speed_mod = class_run_speed / runspeed;
	activator.AddCustomAttribute("CARD: move speed bonus", speed_mod, -1);
}

function ClearSpeedMod() {
	if (!IsValidPlayer(activator)) {
		return;
	}

	activator.RemoveCustomAttribute("CARD: move speed bonus");
}