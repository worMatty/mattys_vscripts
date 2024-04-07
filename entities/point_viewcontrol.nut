/*
	Easy PVC Control v0.4 - worMatty
	----------------------------------------------------------------------------------------------------

	Enables you to use a point_viewcontrol with more than one player.

	Usage:
	1. Add this script to the Entity Scripts field of each point_viewcontrol
	2. Send it the input `CallScriptFunction` with parameter `EnableCameraAll` to switch everyone to it.
	3. Send it the input `CallScriptFunction` with parameter `DisableCameraAll` to switch everyone off it.
	Each camera should use Infinite Hold Time, and be disabled manually.

	Facts:
	* Enabling a second camera will override the first
	* You must disable whichever camera the player is using to reset their view
		This is intentional to allow you to switch between cameras without timed inputs on previous
		cameras interrupting your cinematic effects
	* Cameras will disable their viewers on round restart
	* You must not kill the camera, or players may be stuck in their viewing position
	* Players will have their input frozen while viewing and will not take damage

	This script is meant to be easy to use and simple in execution.
	It does not have protection against players doing the following while using a camera:
	* Changing their view perspective
	* Taunting
	* Killing themselves

	Thanks to SpookyToad and ficool2
*/

/*
	Changelog
		0.4
			* Replaced round restart event hook with a preserved logic_eventlistener
			* Set and restore m_takedamage on players on camera Enable and Disable to prevent invincibility
*/

local maxclients = MaxClients();

// ----------------------------------------------------------------------------------------------------

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
			// printl(__FILE__ + " -- DisableCameraAll -- Firing DisableCamera() with " + player);
			DisableCamera(player);
		}
	}
}

// ----------------------------------------------------------------------------------------------------

/**
 * Enable this camera for the specified player or activator
 * @param {instance} player Player instance, or activator if left blank
 */
function EnableCamera(player = null) {
	if (player == null && activator != null) {
		player = activator;
	}

	player.ValidateScriptScope();
	local scope = player.GetScriptScope();

	// conditions
	player.RemoveCond(7); // stop taunts
	player.AddCond(87); // freeze input

	// store properties
	scope.__m_nForceTauntCam <- NetProps.GetPropInt(player, "m_nForceTauntCam");
	scope.__takedamage <- NetProps.GetPropInt(player, "m_takedamage");
	scope.current_pvc <- self;

	// don't take damage
	NetProps.SetPropInt(player, "m_takedamage", 0);

	// set first person perspective
	player.SetForcedTauntCam(0);

	// enable the camera for this player
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

	// skip this player if they have not been assigned a camera, or are not using this camera
	if (!("current_pvc" in scope && scope.current_pvc == self)) {
		return;
	}

	// store current lifestate and set lifestate to 'alive' so the Disable input works on them
	EntFireByHandle(player, "RunScriptCode", "self.GetScriptScope().__lifestate <- NetProps.GetPropInt(self, `m_lifeState`); NetProps.SetPropInt(self, `m_lifeState`, 0)", -1, player, player);

	// configure the camera to use this player, and Disable it
	EntFireByHandle(self, "RunScriptCode", "NetProps.SetPropEntity(self, `m_hPlayer`, activator)", -1, player, player);
	EntFireByHandle(self, "Disable", null, -1, player, player);

	// restore lifestate, taunt perspective and takedamage
	EntFireByHandle(player, "RunScriptCode", "NetProps.SetPropInt(self, `m_lifeState`, self.GetScriptScope().__lifestate)", -1, player, player);
	EntFireByHandle(player, "RunScriptCode", "NetProps.SetPropInt(self, `m_takedamage`, self.GetScriptScope().__takedamage)", -1, player, player);
	EntFireByHandle(player, "SetForcedTauntCam", scope["__m_nForceTauntCam"].tostring(), -1, player, null);

	// remove input freeze condition
	player.RemoveCond(87);

	// reset assigned camera
	scope.current_pvc = null;
}

// ----------------------------------------------------------------------------------------------------

if (!("__pvc_event_teamplay_round_start" in getroottable())) {
	getroottable().__pvc_event_teamplay_round_start <- SpawnEntityFromTable("logic_eventlistener", {
		classname = "move_rope",
		eventname = "teamplay_round_start",
		targetname = "event_pvc_restart",
		IsEnabled = true,
		OnEventFired = "point_viewcontrol,CallScriptFunction,DisableCameraAll,-1,-1",
	});
}

// ----------------------------------------------------------------------------------------------------

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

/*
	Known issues
	cl_first_person_uses_world_model 1 you can see your player model.
	GetForceLocalDraw and SetForceLocalDraw won't help.
	Rendermode and invis will help but will prevent other players from seeing you.
	You could try setting a fade distance on the player.

	SetForceLocalDraw may be useable in rendering the player's model to themselves.
*/
