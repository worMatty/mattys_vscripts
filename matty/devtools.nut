function GiveWeaponCubemap(player = null) {
	if (player == null) {
		player = GetListenServerHost();
	}

	local cubemap = "models/shadertest/envballs.mdl"
	PrecacheModel(cubemap);

	for (local i = 0; i < 7; i++) {
		local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i);
		if (weapon == null)
			continue;

		if (weapon.GetSlot() != 2) // melee
			continue;

		weapon.SetCustomViewModel(cubemap);
		break;
	}

	printl("Gave cubemap viewmodel to " + player);
}

function PrintLifeStates() {
	local maxclients = MaxClients().tointeger();

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.IsValid()) {
			printl(player + " lifestate: " + NetProps.GetPropInt(player, "m_lifeState"));
		}
	}
}

function ToggleJumpOverlay() {
	// create think ent
	// attach think

	local tname = "jump_overlay_thinker";
	local ent = Entities.FindByName(null, tname);

	if (ent != null) {
		ent.Kill();
		ClientPrint(null, Constants.EHudNotify.HUD_PRINTTALK, "Jump overlay disabled");
	} else {
		ent = SpawnEntityFromTable("logic_relay", {
			targetname = tname
		})
	}

	ent.ValidateScriptScope();
	local scope = ent.GetScriptScope();

	scope.players <- {}; // player data table, indexed by instance handle

	scope.Think <- function() {
		local maxclients = MaxClients().tointeger();

		for (local i = 1; i <= maxclients; i++) {
			local player = PlayerInstanceFromIndex(i);

			if (player != null && player.IsAlive()) {
				if (!(player in players)) {
					players[player] <- {
						// origin = null
						// air_pos = null
						highest_z = null
					};
				}

				if (player.IsJumping()) {
					local pos = player.GetOrigin();

					if (players[player].highest_z == null || pos.z > players[player].highest_z) {
						players[player].highest_z = pos.z;
					}
				} else if (players[player].highest_z != null) {
					ClientPrint(player, Constants.EHudNotify.HUD_PRINTTALK, "Peak jump height: " + players[player].highest_z - player.GetOrigin().z);
					players[player].highest_z = null;
				}

				// if (player.IsOnGround()) {
				// 	players[player].origin = player.GetOrigin();

				// 	if (players[player].air_pos != null) {

				// 	}
				// } else {
				// 	players[player].air_pos = player.GetOrigin();
				// }
			}
		}
	}

	AddThinkToEnt(ent, "Think");
}