
/**
 * No fall damage v0.1 by worMatty
 *
 * Adds the `cancel falling damage` attribute to players after they spawn.
 * This disables fall damage globally.
 *
 * Usage: Add to the 'Entity scripts' field of a logic_script.
 * No further action is needed.
 *
 * Note to deathrun mappers:
 * Fall damage is a hazard and the point of deathrun is to survive in a hazardous
 * environment. By removing it completely you are reducing your possible gameplay
 * mechanics. If a player makes a mistake and takes fall damage as a result,
 * it's a punishment, and too much damage will kill them. This is how health
 * is supposed to function.
 *
 * Unavoidable fall damage taken during the course of normal gameplay is bad design.
 * You should either limit your drop heights to 256 units maximum, adjust the player's
 * gravity so their downwards velocity is slowed, or place a
 * `trigger_add_or_remove_tf_player_attributes` trigger around the area you wish to
 * disable fall damage in. Give it the attribute `cancel falling damage` with a
 * duration of -1. While in the trigger, the player will not take fall damage.
 * https://developer.valvesoftware.com/wiki/Trigger_add_or_remove_tf_player_attributes
 *
 * If you still wish to disable fall damage globally, do not use a very large trigger
 * brush which envelopes the whole of the map. Such a practice could cause you to
 * exceed the game's maximum number of touch links (collision detection between objects),
 * which would break collision detection for other triggers. Instead, use this script.
 */

// If this is the only VScript you're using, uncomment the below line
// ClearGameEventCallbacks();

function OnPostSpawn() {
    __CollectGameEventCallbacks(self.GetScriptScope());
    EntFire("player", "RunScriptCode", "self.AddCustomAttribute(`cancel falling damage`, 1.0, -1)");
}

function OnGameEvent_player_spawn(data) {
	local player = GetPlayerFromUserID(data.userid);

	if (player != null) {
		EntFireByHandle(player, "RunScriptCode", "self.AddCustomAttribute(`cancel falling damage`, 1.0, -1)", -1, player, player);
	}
}