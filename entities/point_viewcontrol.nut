/**
 * Easy PVC Control v0.3 - worMatty
 *
 * Usage: Add this script to your point_viewcontrol
 * Send it the input `CallScriptFunction` with parameter `EnableCameraAll` to switch everyone to it.
 * Send it the input `CallScriptFunction` with parameter `DisableCameraAll` to switch everyone off it.
 *
 * You can use this with more than one camera.
 * Enabling a second camera will override the first.
 * You must disable whichever camera the player is using to reset their view.
 * Cameras will disable their viewers on round restart.
 * You must not kill the camera, or players may be stuck in their viewing position.
 * Players will have their input frozen while viewing.
 *
 * This script is meant to be easy to use and simple in execution.
 * It does not have protection against players doing the following while using a camera:
 * * Changing their view perspective
 * * Taunting
 * * Killing themselves
 * * Taking damage
 *
 * Thanks to SpookyToad and ficool2
 */

/*
Known issues
cl_first_person_uses_world_model 1 you can see your player model.
GetForceLocalDraw and SetForceLocalDraw won't help.
Rendermode and invis will help but will prevent other players from seeing you.
You could try setting a fade distance on the player.

SetForceLocalDraw may be useable in rendering the player's model to themselves.
*/

local maxclients = MaxClients();

/**
 * Set all players to view through the point_viewcontrol
 */
function EnableCameraAll() {
	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.IsValid()) {
			EnableCamera(player);
		}
	}
}

/**
 * Disable the current point_viewcontrol on all players
 */
function DisableCameraAll() {
	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.IsValid()) {
			DisableCamera(player);
		}
	}
}

/**
 * Enable this camera for the specified player or activator
 * @param {instance} player Player instance, or activator if left blank
 */
function EnableCamera(player = null) {
	if (player == null && activator != null) {
		player = activator;
	}

	player.RemoveCond(7); // stop taunts
	player.AddCond(87); // freeze input

	player.ValidateScriptScope();
	player.GetScriptScope().perspective <- NetProps.GetPropInt(player, "m_nForceTauntCam"); // store current perspective
	player.GetScriptScope().view_entity <- self; // store camera

	player.SetForcedTauntCam(0); // set first person perspective

	EntFireByHandle(self, "Enable", "", -1, player, null);
}

/**
 * Disable this camera for the specified player or activator
 * @param {instance} player Player instance, or activator if left blank
 */
function DisableCamera(player = null) {
	if (player == null && activator != null) {
		player = activator;
	}

	player.ValidateScriptScope();
	local scope = player.GetScriptScope();

	// continue if the player hasn't been assigned this or any camera
	if (!("camera" in scope && scope.view_entity == self)) {
		continue;
	}

	local perspective = scope["perspective"];

	EntFireByHandle(player, "RunScriptCode", "activator.GetScriptScope().__lifestate <- NetProps.GetPropInt(activator, `m_lifeState`); NetProps.SetPropInt(activator, `m_lifeState`, 0)", -1, player, player);
	EntFireByHandle(self, "RunScriptCode", "NetProps.SetPropEntity(self, `m_hPlayer`, activator)", -1, player, player);
	EntFireByHandle(self, "Disable", null, -1, player, player);
	EntFireByHandle(player, "RunScriptCode", "NetProps.SetPropInt(activator, `m_lifeState`, activator.GetScriptScope().__lifestate)", -1, player, player);
	EntFireByHandle(player, "SetForcedTauntCam", perspective.tostring(), -1, player, null);
	player.RemoveCond(87); // remove freeze input
	scope.view_entity = null; // reset assigned camera
}

// disable cameras on round reset
function OnGameEvent_teamplay_round_start(params) {
	DisableCameraAll();
}

__CollectGameEventCallbacks(this);

/*

point_viewcontrol multiplayer use process

Enabling:
1. Enable, using player as activator
The Enable input sets m_hPlayer to the activator's handle.

Disabling (all using EntFire to ensure the correct order)
1. Store player's lifestate in their script scope for later use
2. Set the player's life state to alive
3. Set the camera's m_hPlayer property to the player's handle, using SetPropEntity
4. Disable, using the player as activator
5. Restore the player's previous life state

*/