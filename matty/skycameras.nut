/*
	sky_camera Switcher v0.1.1 by worMatty
	Switch players to different 3D skyboxes
	Based on a script by gidi30

	Usage

		Add the script to a logic_script entity. It does not need to have a targetname.

		Give each sky_camera a unique targetname.
		You can do this by disabling SmartEdit and adding a keyvalue pair like so:
			key: targetname		value: skycam_01

		In the logic_script's first EntityGroup field, add the targetname of the default sky_camera.
		This will be the first sky_camera active when the map starts.
		This is necessary because TF2 makes the last sky_camera spawned the active camera,
		and the order they spawn may be different to what you want.

		To set a player's sky camera when they start an I/O chain (e.g. by touching a trigger),
		send one of these inputs to the sky_camera entity itself:

			CallScriptFunction > UseSkybox
			RunScriptCode > UseSkybox(activator)

		To make a sky_camera the active one for all players, send it this input:

			CallScriptFunction > ActivateSkybox

		This will also make this sky_camera the active one for new players who join the server.

		Note: sky_cameras are 'preserved entities'. They are not deleted and respawned when the
		round restarts. If you set a sky_camera as active, it will remain active for the rest of
		the map session. If you want a different camera to be active on the next round, you
		must call ActiveSkybox on it on round restart. The simplest method is a logic_relay
		with an OnSpawn output.

	Extra functions

		You can set a sky_camera as the default for new players without making it active for
		existing players by sending it this input:

			CallScriptFunction > SetAsActive

		This could be useful if you have been gradually switching individual players to a different
		camera and wish to set a new default camera once most of them have transitioned.
*/

/*
	Changelog
		Version 0.1.1
		* Check if EntityGroup[0] is not null when setting first camera
		* Added the improved event hooking code from the VDC Wiki
*/

/*
	Possible issues
		* sky_cameras created after the round starts will not have the functions this script adds.
			Calling GetActiveSkybox() or UseSkybox() will fail in this case.
			A probable workaround is to call this script's Precache function manually after
			the new sky_cameras have spawned. Note that new cameras will receive these
			functions on round restart anyway.
*/

function Precache() {
	// get the first camera from EntityGroup[0]
	local first_camera = null;
	if ("EntityGroup" in self.GetScriptScope() && EntityGroup[0] != null) {
		first_camera = EntityGroup[0];
	}

	// iterate all sky_cameras
	local camera = null;
	while (camera = Entities.FindByClassname(camera, "sky_camera")) {
		camera.ValidateScriptScope();
		local scope = camera.GetScriptScope();

		// exit if already done (sky_cameras are preserved ents)
		if ("UseSkybox" in camera.GetScriptScope()) {
			break;
		}

		// add last_activated camera property
		scope.last_activated <- (first_camera == camera) ? 1.0 : 0.0;

		/**
		 * Makes a sky_camera the active one for the specified player
		 * @param {instance} player Player instance. Defaults to activator
		 */
		scope.UseSkybox <- function(player = null) {
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
		scope.ActivateSkybox <- function() {
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

		// todo: sky_cameras created after the round starts will not have this property
		if (camera.GetScriptScope().last_activated > active.GetScriptScope().last_activated) {
			active = camera;
		}
	}

	return active;
}


// Event Hooks
// --------------------------------------------------------------------------------

local EventsID = UniqueString();

getroottable()[EventsID] <- {

	// hook new joiners and give them the currently active camera
	function OnGameEvent_player_activate(params) {
		local player = GetPlayerFromUserID(params.userid);
		EntFireByHandle(self, "RunScriptCode", "GetActiveSkybox().GetScriptScope().UseSkybox(activator)", 1.0, player, null);
	}

	// cleanup events on round restart
	OnGameEvent_scorestats_accumulated_update = function(_) {
		delete getroottable()[EventsID];
	}
}

local EventsTable = getroottable()[EventsID];

foreach(name, callback in EventsTable) {
	EventsTable[name] = callback.bindenv(this)
	__CollectGameEventCallbacks(EventsTable)
}


// Notes
// --------------------------------------------------------------------------------

/*
	Findings
		The default skybox set for me when I joined the game was skycam_01.
		This actually had a later edict index than skycam_02.
		Presumably the most recent sky_camera to be spawned takes over.
*/