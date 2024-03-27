/**
 * Matty's Deathrun Health Scaling
 * Version 1.1 - modified to use stocks2
 *
 * Scales the health of any blue players up to an amount appropriate for the number of live reds.
 *
 * Features:
 * - Instead of the player receiving an overheal, which decays quickly and prevents the use of
 * 		health pickups, the player's maximum health is increased to the same amount.
 * 		This enables better gameplay as the blue player can deny health packs to reds,
 * 		and they are encouraged to roam the arena.
 * - Health from health pickups is scaled down to the normal amount
 * - Backstab damage on blues is capped at 300 per hit
 * - New health value is printed to chat for the information of the participants
 *
 * How the scaling calculation works:
 * Multiply number of live reds by 2, then multiply by the blue player's base class health.
 * Subtract the blue player's base class health.
 * Divide this by the number of blues (in the unlikely case where the server has multiple activators).
 * e.g. a blue Heavy will have 5700 HP when there are ten reds.
 *
 * Usage:
 * Add the script to a logic_script (or any entity you wish)
 * Input CallScriptFunction ScaleBlueHealth at the start of your Arena game. Not until.
 */

/**
 * Possible future features:
 * See if blues have melee only and store it
 * See if reds...
 * Give more health to blue if they only have melee?
 */

// includes
IncludeScript("matty/stocks2.nut");

// options
local option_announce = true; // announce scaled health values to chat

// Functions
// --------------------------------------------------------------------------------

function ScaleBlueHealth() {
	local number_live_reds = Players().Team(TF_TEAM_RED).Alive().Array().len();
	local live_blues = Players().Team(TF_TEAM_BLUE).Alive().Array();
	local number_live_blues = live_blues.len();

	if (number_live_blues >= number_live_reds || !number_live_blues) {
		return; // no scaling on equal team numbers or when no blues
	}

	foreach(player in live_blues) {
		local health = GetTFClassHealth(player.GetPlayerClass()).tofloat();

		health = (((number_live_reds * 2) * health) - health);
		health /= number_live_blues;

		player.AddCustomAttribute("max health additive bonus", health - GetTFClassHealth(player.GetPlayerClass()), -1);
		player.SetHealth(health.tointeger());
		player.AddCustomAttribute("health from packs decreased", GetTFClassHealth(player.GetPlayerClass()) / health, -1);

		if (option_announce) {
			local message = format("%s now has \x05%d \x01health", player.CName(), health.tointeger());
			ChatMsg(null, message);
		}
	}
}


// Event hooks
// --------------------------------------------------------------------------------

CleanGameEventCallbacks();

function OnScriptHook_OnTakeDamage(params) {
	if (params.const_entity.IsPlayer() &&
		params.const_entity.GetTeam() == TF_TEAM_BLUE &&
		params.damage_custom == TF_DMG_CUSTOM_BACKSTAB) {
		params.damage = 100; // backstabs always crit, which multiplies this to 300
	}
}

__CollectGameEventCallbacks(this);