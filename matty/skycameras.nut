/**
 * sky_camera Switcher v0.1
 * Switch to different skyboxes
 * Based on a script by gidi30
 */

/*
	Usage

	1. Add the script to a logic_script
	2. Give each sky_camera a unique targetname by disabling SmartEdit and adding a keyvalue pair
			key: targetname		value: skycam_01
	3. In EntityGroup[0], add the targetname of the default sky_camera
	4. To set an activating player's skybox, send the sky_camera this input:
			CallScriptFunction > UseSkybox
	5. To set the skybox for all players, send a sky_camera this input:
			CallScriptFunction > ActivateSkybox
		This will also make this sky_camera the active camera for new players

	Extra functions

	UseSkybox can take a player instance as its argument
		RunScriptCode > UseSkybox(player)

	You can manually set a sky_camera as the active camera for new players without
	switching any players to the sky_camera
		CallScriptFunction > SetAsActive
	This could be useful if you have been gradually switching individual players to a different
	camera and wish to set a new default camera once most of them have transitioned.
*/

function Precache() {
	// set first camera if specified
	local first_camera = null;
	if ("EntityGroup" in self.GetScriptScope()) {
		first_camera = EntityGroup[0];
	}

	// iterate all sky_cameras
	local camera = null;
	while (camera = Entities.FindByClassname(camera, "sky_camera")) {
		camera.ValidateScriptScope();
		local scope = camera.GetScriptScope();

		// exit if already done
		if ("UseSkybox" in camera.GetScriptScope()) {
			break;
		}

		// add last_activated camera property
		scope.last_activated <- (first_camera == camera) ? 1.0 : 0.0;

		/**
		 * Makes a sky_camera the active one for the specified player
		 * @param {instance} player Player instance. Defaults to activator
		 */
		scope.UseSkybox <-  function(player = null) {
			if (player == null) {
				if (activator != null) {
					player = activator;
				} else {
					error(self + " -- Received UseSkybox with invalid player instance '" + player + "'");
					return;
				}
			}

			NetProps.SetPropInt(player, "m_Local.m_skybox3d.scale", NetProps.GetPropInt(self, "m_skyboxData.scale"))
			NetProps.SetPropVector(player, "m_Local.m_skybox3d.origin", NetProps.GetPropVector(self, "m_skyboxData.origin"))
			NetProps.SetPropFloat(player, "m_Local.m_skybox3d.fog.start", NetProps.GetPropFloat(self, "m_skyboxData.fog.start"))
			NetProps.SetPropFloat(player, "m_Local.m_skybox3d.fog.maxdensity", NetProps.GetPropFloat(self, "m_skyboxData.fog.maxdensity"))
			NetProps.SetPropFloat(player, "m_Local.m_skybox3d.fog.end", NetProps.GetPropFloat(self, "m_skyboxData.fog.end"))
			NetProps.SetPropBool(player, "m_Local.m_skybox3d.fog.enable", NetProps.GetPropBool(self, "m_skyboxData.fog.enable"))
			NetProps.SetPropVector(player, "m_Local.m_skybox3d.fog.dirPrimary", NetProps.GetPropVector(self, "m_skyboxData.fog.dirPrimary"))
			NetProps.SetPropInt(player, "m_Local.m_skybox3d.fog.colorSecondary", NetProps.GetPropInt(self, "m_skyboxData.fog.colorSecondary"))
			NetProps.SetPropInt(player, "m_Local.m_skybox3d.fog.colorPrimary", NetProps.GetPropInt(self, "m_skyboxData.fog.colorPrimary"))
			NetProps.SetPropBool(player, "m_Local.m_skybox3d.fog.blend", NetProps.GetPropBool(self, "m_skyboxData.fog.blend"))
			NetProps.SetPropInt(player, "m_Local.m_skybox3d.area", NetProps.GetPropInt(self, "m_skyboxData.area"))
		}

		/**
		 * Set the active skybox for all players
		 * Also sets the camera as the default for any connecting clients
		 */
		scope.ActivateSkybox <-  function() {
			SetAsActive();
			local maxclients = MaxClients().tointeger();

			for (local i = 1; i <= maxclients; i++) {
				local player = PlayerInstanceFromIndex(i);

				if (player != null && player.IsValid()) {
					UseSkybox(player);
				}
			}
		}

		/**
		 * Set the current sky_camera as the active camera
		 * It will be used as the default camera for new players
		 */
		scope.SetAsActive <- function() {
			last_activated <- Time();
		}
	}

	// hook new joiners
	__CollectGameEventCallbacks(self.GetScriptScope());
}

/**
 * Find the most recently activated camera
 * @return {instance} sky_camera instance
 */
function GetActiveSkybox() {
	local active = null;
	local camera = null;

	while (camera = Entities.FindByClassname(camera, "sky_camera")) {
		if (active == null) {
			active = camera;
			continue;
		}

		if (camera.GetScriptScope().last_activated > active.GetScriptScope().last_activated) {
			active = camera;
		}
	}

	return active;
}

// hook new joiners and give them the currently active camera
function OnGameEvent_player_activate(params) {
	local player = GetPlayerFromUserID(params.userid);
	EntFireByHandle(self, "RunScriptCode", "GetActiveSkybox().GetScriptScope().UseSkybox(activator)", 1.0, player, null);
}

/*
	Findings
		The default skybox set for me when I joined the game was skycam_01.
		This actually had a later edict index than skycam_02.
		Presumably the most recent sky_camera to be spawned takes over.
*/