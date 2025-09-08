/*
	Easy PVC Control v0.4.4 - worMatty
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
		0.4.4
			Set m_hPlayer property of the pvc to null before and after sending it an input.
			This should prevent a camera from disabling itself for its stored player handle
			when requested to do so by the game code, in response to another player changing cameras.
		0.4.3
			* Replaced previously-created AcceptInput RunScriptCode calls with direct property changes
		0.4.2
			* Replaced EntFire function calls with AcceptInput, which are synchronous and executed immediately.
		0.4.1
			* Fixed an issue where calling the enable function twice on a player would overwrite their stored
			  m_takedamage value with 0, making them immortal when disabling the camera and restoring the value.
			* When disabling, players' m_takedamage value will be set to 2 if they are alive, instead of restoring
			  the saved value from when the camera was enabled. This fixes the  aforementioned issue and guards
			  against players who were respawned while watching receiving immortality from a saved m_takedamage value of 0.
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

	player.RemoveCond(7); // stop taunts
	player.AddCond(87); // freeze input

	scope.__m_nForceTauntCam <- NetProps.GetPropInt(player, "m_nForceTauntCam"); // store current taunt perspective
	scope.current_pvc <- self; // store current pvc ent

	NetProps.SetPropInt(player, "m_takedamage", 0); // players will take no damage
	player.SetForcedTauntCam(0); // set first-person perspective

	NetProps.SetPropEntity(self, "m_hPlayer", player); // prevent the previous client to use this camera being disconnected
	self.AcceptInput("Enable", "", player, null);
	NetProps.SetPropEntity(self, "m_hPlayer", null); // prevent the client from being disconnected from this view by another player disabling early
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

	// store player's current lifestate, and set their lifestate to 'alive' so the camera functions for them
	scope.__lifestate <- NetProps.GetPropInt(player, "m_lifeState");
	NetProps.SetPropInt(player, "m_lifeState", 0);

	// set camera's user property to the player, then Disable the camera for them
	NetProps.SetPropEntity(self, "m_hPlayer", player);
	self.AcceptInput("Disable", null, player, player);
	NetProps.SetPropEntity(self, "m_hPlayer", null);

	// restore the player's previous lifestate and set the appropriate takedamage value
	NetProps.SetPropInt(player, "m_lifeState", player.GetScriptScope().__lifestate);
	if (player.IsAlive()) {
		NetProps.SetPropInt(player, "m_takedamage", 2);
	}

	player.AcceptInput("SetForcedTauntCam", scope["__m_nForceTauntCam"].tostring(), player, null); // restore taunt perspective
	player.RemoveCond(87); // remove input freeze condition
	scope.current_pvc = null; // reset assigned camera
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

	The code for this entity is in source-sdk-2013/src/game/server/triggers.cpp.
	https://github.com/ValveSoftware/source-sdk-2013/blob/68c8b82fdcb41b8ad5abde9fe1f0654254217b8e/src/game/server/triggers.cpp#L2852
*/

/*
	Known issues
	cl_first_person_uses_world_model 1 you can see your player model.
	GetForceLocalDraw and SetForceLocalDraw won't help.
	Rendermode and invis will help but will prevent other players from seeing you.
	You could try setting a fade distance on the player.

	SetForceLocalDraw may be useable in rendering the player's model to themselves.

	When you Enable a pvc for a player, the game will get the player's last pvc and disable that.
	The pvc code will disable the camera for its stored player handle.
	This can result in a player disabling a pvc for another player when they disable early.
	One possible solution is to set the pvc's m_hPlayer variable
	to the player's handle right before enabling it, and set it to null right after using any input on it.
	This prevents subsequent disablements of the camera from disconnecting the stored player handle.
	SpookyToad will be testing that in his new Berlin map version.
*/