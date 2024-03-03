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