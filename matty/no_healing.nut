maxplayers = MaxClients();

function AllPlayersNoHealing(set = true) {
	for (local i = 1; i <= maxplayers; i++) {
		local player = PlayerInstanceFromIndex(i);
		if (player != null && player.IsValid()) {
			for (local j = 0; j < 7; j++) {
				local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", j);

				if (weapon != null && weapon.IsValid()) {
					if (set == true) {
						weapon.AddAttribute("healing received penalty", 0.0, -1);
					} else {
						weapon.RemoveAttribute("healing received penalty");
					}
				}
			}
		}
	}
}