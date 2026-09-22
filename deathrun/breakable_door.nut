/*
	Deathrun Breakable Door Health Scale v0.3 by worMatty
	Scale func_breakable health by number of red players alive on first hit.

	How it works:
	The first time the breakable takes damage, its health will be set to an appropriate amount depending on the
	number of red players alive at the time. This ensures that rushers cannot break it quickly if there are still
	several players behind them. When more players arrive it will take less time to break through.
	The more players there are behind them, the longer it will take to destroy.
	When there are only a small number of reds, the breakable will only take a few seconds to destroy.

	How to use:
	Add the script to the entity scripts field of a func_breakable.
	If the object is part of a set, such as a group of individual wooden plank entities, add the script to each
	entity and send each the following input at the start:
		RunScriptCode > parts = #
	Where '#' is the number of parts in the group. e.g. For three planks, type 'parts = 3'.
	This will divide the health by the number of parts. Obviously if only two parts need to be broken
	to get through the doorway, you should set parts to 2, regardless of the number of planks.
*/

parts <- 1; // number of parts that make up the breakable barrier (e.g. planks). set this for each breakable in a set
const DPS = 125.0; // average damage per second for a melee player. primary weapons deal a bit more
self.SetHealth(100000) // start with high health to prevent being destroyed
EntityOutputs.AddOutput(self, "OnHealthChanged", "!self", "CallScriptFunction", "CalculateHealth", -1, -1);

/**
 * Set the health of the breakable to num_reds * 125.
 * Deletes the OnHealthChanged output to prevent it being called again.
 * Dooes not do anything if the round is not active.
 */
function CalculateHealth() {
	if (GetRoundState() < GR_STATE_RND_RUNNING) return;
	EntityOutputs.RemoveOutput(self, "OnHealthChanged", "!self", "CallScriptFunction", "CalculateHealth");
	local num_reds = 0, maxclients = MaxClients().tointeger();
	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);
		if (player && player.IsAlive() && player.GetTeam() == Constants.ETFTeam.TF_TEAM_RED) num_reds++;
	}
	num_reds = (num_reds < 1) ? 1 : num_reds; // minimum of 1 red
	local new_health = (num_reds * DPS / parts).tointeger();
	self.SetHealth(new_health);
	if (developer()) printl(self + " " + __FILE__ + " set health to " + new_health);
}