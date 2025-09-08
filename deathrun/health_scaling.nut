/*
	Deathrun Health Scaling
	Version 1.2.1 by worMatty

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
		1.2.1
			* Event hooks deleted prior to round restart to keep things clean
			* Event hooks not created when not protecting against backstabs
		1.2
			* Added a parameter to the scale function that gives the user the option not to
			  limit backstab damage on the scaled players.
			* Damage hook only affects players that have had their health scaled
			* Damage hook won't be added until the first time the function is called
		1.1.2
			* Slightly improved instructions
			* Moved announcement option into function call
			* Replaced lengthy Players() array creation lines with LiveReds() etc. from stocks2
		1.1.1
			* Removed unnecessary stocks2.nut CleanGameEventCallbacks call
*/

IncludeScript("matty/stocks2.nut"); // needed for GetTFClassHealth, so we're making use of other functions as well
local backstab_players = [];

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

	// blue team has the same or more players than red,
	// or there are no live blues. do nothing
	if (number_live_blues >= number_live_reds || !number_live_blues) {
		return;
	}

	foreach(player in live_blues) {
		// calculate scaled health for this blue player then divide it by no. of live blues
		local health = GetTFClassHealth(player.GetPlayerClass()).tofloat();
		health = (((number_live_reds * 2) * health) - health);
		health /= number_live_blues;

		// scale max health and heal to full
		player.AddCustomAttribute("max health additive bonus", health - GetTFClassHealth(player.GetPlayerClass()), -1);
		player.SetHealth(health.tointeger());
		player.AddCustomAttribute("health from packs decreased", GetTFClassHealth(player.GetPlayerClass()) / health, -1);

		// reduce backstab damage
		if (reduce_backstab && !backstab_players.find(player)) {
			backstab_players.append(player);
		}

		// announce new health to chat
		if (announce) {
			ChatMsg(null, format("%s now has \x05%d \x01health", player.CName(), health.tointeger()));
		}
	}

	if (reduce_backstab) {
		SetUpEventHooks(); // hook damage taken
	}
}

// event hooks
local EventsID = null;
function SetUpEventHooks() {
	if (EventsID) {
		return;
	}

	EventsID = UniqueString();
	getroottable()[EventsID] <- {
		// limit backstab damage on blues to 300
		function OnScriptHook_OnTakeDamage(params) {
			if (params.damage_custom == TF_DMG_CUSTOM_BACKSTAB && backstab_players.find(params.const_entity) != null) {
				params.damage = 100; // backstabs always crit. this will be multiplied to 300
			}
		}

		// remove player from backstab array on death
		function OnGameEvent_player_death(params) {
			local player = GetPlayerFromUserID(params.userid);
			local index = backstab_players.find(player);
			if (index != null) {
				backstab_players.remove(index);
			}
		}

		// clean up event hooks before round restarts
		OnGameEvent_scorestats_accumulated_update = function(_) {
			delete getroottable()[EventsID];
		}
	}

	local EventsTable = getroottable()[EventsID];

	foreach(name, callback in EventsTable) {
		EventsTable[name] = callback.bindenv(this)
		__CollectGameEventCallbacks(EventsTable)
	}
}

/*
	Possible future features:
	See if blues have melee only and store it
	See if reds...
	Give more health to blue if they only have melee?
*/