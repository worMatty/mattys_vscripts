/*
	Deathrun Health Scaling
	Version 1.2 by worMatty

	Scales the health of any blue players up to an amount appropriate for the number of live reds.
	Should be used on the commencement of an Arena game after any reds have been respawned.
	Don't use it on round restart as the blue player may lose health before the game,
	and the number of live reds in the game may be different to those at the start.

	Features:
		* Instead of the player receiving an overheal, which decays quickly and prevents the use of
			health pickups, the player's maximum health is increased to the same amount.
			This enables better gameplay as the blue player can deny health packs to reds,
			and they are encouraged to roam the arena.
		* Health from health pickups is scaled down to the normal amount
		* Backstab damage on blues is capped at 300 per hit
		* New health value is printed to chat for the information of the participants

	How the scaling calculation works:
		Multiply number of live reds by 2, then multiply by the blue player's base class health.
		Subtract the blue player's base class health.
		Divide this by the number of blues (in the unlikely case where the server has multiple activators).
		e.g. a blue Heavy will have 5700 HP when there are ten reds.

	Usage:
		Put this script somewhere in tf/scripts/vscripts. I suggest deathrun/.
		Download matty/stocks2.nut and put it in tf/scripts/vscripts/matty.
		Create a logic_script entity and give it a targetname.
		Add the health scaling script to its vscripts field. Do not add stocks2.nut.
		When you wish to scale blue health, send the logic_script this input:
			CallScriptFunction > ScaleBlueHealth.
		If you don't want the script to announce the blue's new health, send this input:
			RunScriptCode > ScaleBlueHealth(false)
*/

/*
	Changelog
		1.2
			* Added a parameter to the scale function that gives the user the option not to
			  limit backstab damage on the scaled players.
			* Damage hook only affects players that have had their health scaled
			* Damage hook won't be added until the first time the function is called
			* Added debug messages that appear when `developer` mode is on
		1.1.2
			* Slightly improved instructions
			* Moved announcement option into function call
			* Replaced lengthy Players() array creation lines with LiveReds() etc. from stocks2
		1.1.1
			* Removed unnecessary stocks2.nut CleanGameEventCallbacks call
*/

IncludeScript("matty/stocks2.nut");
local reduced_backstab = [];
local hook_added = false;

/**
 * Scale the health of blue players.
 * Health is scaled in proportion with the number of red players alive.
 * @param {bool} announce Announce the new value of blue players' health to chat
 * @param {bool} reduce_backstab The player's backstab damaged received will be capped
 */
function ScaleBlueHealth(announce = true, reduce_backstab = true) {
	local number_live_reds = LiveReds().len();
	local live_blues = LiveBlues();
	local number_live_blues = live_blues.len();

	if (number_live_blues >= number_live_reds || !number_live_blues) {
		if (developer()) printl(__FILE__ + " -- No scaling performed as the teams have equal numbers or there are no blues");
		return; // no scaling on equal team numbers or when no blues
	}

	foreach(player in live_blues) {
		// calculate health to scale to
		local health = GetTFClassHealth(player.GetPlayerClass()).tofloat();
		health = (((number_live_reds * 2) * health) - health);
		health /= number_live_blues;

		// add attributes and scale health
		player.AddCustomAttribute("max health additive bonus", health - GetTFClassHealth(player.GetPlayerClass()), -1);
		player.SetHealth(health.tointeger());
		player.AddCustomAttribute("health from packs decreased", GetTFClassHealth(player.GetPlayerClass()) / health, -1);
		if (developer()) printl(__FILE__ + " -- " + player + " health has been scaled to " + health.tointeger());

		// we wish to reduced backstab damage on this player, and they are not already in the array
		if (reduce_backstab == true && reduced_backstab.find(player) == null) {
			reduced_backstab.append(player);
			if (developer()) printl(__FILE__ + " -- " + player + " will have their incoming backstab damage capped");
		}

		// we wish to announce new health to chat
		if (announce) {
			local message = format("%s now has \x05%d \x01health", player.CName(), health.tointeger());
			ChatMsg(null, message);
		}
	}

	// add damage hook
	if (hook_added == false) {
		hook_added = true;
		__CollectGameEventCallbacks(self.GetScriptScope());
		if (developer()) printl(__FILE__ + " -- Damage hook added");
	}
}

/**
 * Limit backstab damage on blues to 300
 * so they can't be one-shotted
 */
function OnScriptHook_OnTakeDamage(params) {
	local ent = params.const_entity;
	// if (developer()) {
	// 	printl(__FILE__ + " -- Damage hook -- victim: " + ent + ", reduced_backstab len: " + reduced_backstab.len() + ", found in array: " + (reduced_backstab.find(ent) != null));
	// 	printl(__FILE__ + " -- Damage hook -- victim: " + ent);
	// }
	// if (ent.IsPlayer() && params.damage_custom == TF_DMG_CUSTOM_BACKSTAB && reduced_backstab.find(ent) != null) {
	// 	if (developer()) printl(__FILE__ + " -- " + ent + " received backstab damage from " + params.attacker);
	// 	params.damage = 100; // backstabs always crit, which multiplies this to 300
	// }
}

/**
 * Remove scaled player from the no-backstab array if they're in there
 */
function OnGameEvent_player_death(params) {
	local player = GetPlayerFromUserID(params.userid);
	local index = reduced_backstab.find(player);
	if (index != null) {
		if (developer()) printl(__FILE__ + " -- " + player + " died. Removing them from reduced_backstab array");
		reduced_backstab.remove(index);
		if (developer()) printl(__FILE__ + " -- New reduced_backstab array len = " + reduced_backstab.len());
	}

	// todo: remove damage hook
}

/*
	Possible future features:
	See if blues have melee only and store it
	See if reds...
	Give more health to blue if they only have melee?
*/