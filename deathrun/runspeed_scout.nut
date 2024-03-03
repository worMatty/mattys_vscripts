/**
 * Set Scout run speed on round start and player spawn
 * Uses an attribute
 * Version 1.0.1 by worMatty
 */

local scout_speed = 400;
local new_speed = 320; // change this
local speed_mod = new_speed.tofloat() / scout_speed.tofloat();
local maxclients = MaxClients().tointeger();

// If this is the only VScript you're using, uncomment the below line
// This function should only be called once on round restart by one script in your map
// otherwise there is a risk some of your already-hooked game events will be cleared.
// That's why I am hooking my player_spawn event in Precache in this script.
ClearGameEventCallbacks();


function OnGameEvent_player_spawn(params) {
	local player = GetPlayerFromUserID(params.userid);

	if (player != null && player.GetPlayerClass() == 1) {
		EntFireByHandle(player, "RunScriptCode", format("self.AddCustomAttribute(`CARD: move speed bonus`, %f, -1)", speed_mod), -1, player, player);
	}
}

function OnPostSpawn() {
	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.IsValid() && player.GetPlayerClass() == 1) {
			player.AddCustomAttribute("CARD: move speed bonus", speed_mod, -1);
		}
	}
}

function Precache() {
	__CollectGameEventCallbacks(self.GetScriptScope());
}