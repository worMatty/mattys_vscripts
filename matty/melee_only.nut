/*
    Melee Only
    v0.1.1 by worMatty

    Switch players to their melee weapon and restrict them to it.

    Usage:
        Method 1:
            Add the script to a trigger's vscripts field.
            Ensure the trigger's spawnflags are set to allow clients.
            When a player touches or leaves the trigger, they will be
            switched into and out of melee.
        Method 2:
            Add the script to a logic_script entity.
            Send an input to the logic_script with the player instance:
                RunScriptCode > MeleeOnly(player)
            If the input is triggered by a player, replace 'player' with 'activator'.
            To remove the player's melee restriction and return them to a
            weapon in their primary or secondary slot, use this input:
                RunScriptCode > MeleeOnlyOff(player)

    Notes:
        If a player does not have a melee weapon, they will be given one.
        The replacement weapon spies receives will not allow them to backstab.
        Their melee animations will be slightly odd but still understandable.

        When the melee restriction is removed from a player, they will be switched
        back to their primary or secondary weapon, whichever has any ammo.

        When a player dies, they lose their melee restriction.

        Spawning a player inside the trigger or firing the input the moment
        they spawn may not work without a short delay. I have not tested this.

        The script makes no attempt to balance melee combat or replace
        weapons with more favourable ones.
*/

/*
	Known issues
	* If you are scoped when made melee-only, when you are returned to your sniper rifle
	  the scope overlay will show briefly.
*/

/*
    Problematic weapon situations listed on the TF2 VScript functions page
    and how I have remedied them:

    Switching to melee
        Sniper
            Sniper rifle
			Problem: Coming straight out of a scope shot can prevent switching.
			Solution: If this is the player's active weapon, their active weapon property is set to null
			Problem: Doing the above doesn't get rid of the scope overlay or slowness
			Solution: Remove these two conditions prior to nullifying the active weapon
        Soldier
            Buff banner
                Problem: If the soldier is blowing their horn they will not be switched
                Solution: If this is the player's active weapon, their active weapon property is set to null
        Heavy
            Minigun
                Problem: If the heavy is spinning their minigun, they will not be switched
                Solution: If the player has the 'slowed'/aiming minigun spin-up condition, it will
                    be removed from them. Their active weapon property is thens et to null
        Pyro
            Thermal Thruster
                Problem: If the pyro has their TT active, they will not switch because the put-away animation is slow
                Solution: Set the player's active weapon to null
                Problem: The player is in flight when the switch is attempted
                Solution: If the player has the rocket pack flight condition, call a global game event which tells
                    all players that the player has landed, which is supposed to stop the flight sound.
                    Remove the rocket pack flight condition from the player.
    Switching from melee
        Spy
            Knife
                Problem: If the player backstabs a sniper with a razorback, their knife will be stunned, preventing switch
                Solution: Check that the player's active weapon is a knife
                    Get the weapon's current animation sequence name. If it's the stun animation,
                    set the player's active weapon property to null.
                    This is probably overkill but I'd rather make the extra check for safety.

*/

IncludeScript("matty/stocks2.nut"); // needed for tfcond and player class constants

::MAX_WEAPONS <- 8

self.ConnectOutput("OnStartTouch", "Output_OnStartTouch");
self.ConnectOutput("OnEndTouch", "Output_OnEndTouch");

/**
 * When a player touches the trigger, switch them to their melee
 * weapon and prevent them switching back.
 */
function Output_OnStartTouch() {
	if (activator instanceof CTFPlayer) {
		MeleeOnly(activator);
	}
}

/**
 * When a player exits the trigger, remove their melee restriction
 * and switch them to their primary or secondary weapon.
 * Whichever has ammo.
 */
function Output_OnEndTouch() {
	if (activator != null && activator instanceof CTFPlayer) {
		MeleeOnlyOff(activator);
	}
}

/**
 * Switch a player to their melee weapon and restrict them to it.
 * Works by adding the TF cond to restrict to melee.
 * If the player has no melee weapon, one will be
 * created and given to them.
 * @param {instance} player Player instance
 */
function MeleeOnly(player) {
	local weapons = GetPlayerWeapons(player);
	player.RemoveCond(TF_COND_TAUNTING); // taunting players will not be switched

	// switch to melee if it exists
	if (2 in weapons) {
		local melee_weapon = weapons[2];
		local active_weapon = player.GetActiveWeapon();

		/**
		 * Compare the player's active weapon's classname with a string.
		 * If they match, set the player's 'active weapon' property to null.
		 * The comparison checks that the active weapon's classname starts
		 * with the string. This accounts for special variants of the weapon
		 * that have more text suffixed to their classname.
		 * @param {string} classname Classname to compare against the player's active weapon's classname
		 */
		function CheckActiveAndNullify(classname) {
			if (startswith(active_weapon.GetClassname(), classname)) {
				NetProps.SetPropEntity(player, "m_hActiveWeapon", null);
			}
		}

		// account for certain conditions
		switch (player.GetPlayerClass()) {

			case TF_CLASS_SNIPER: {
				// player's active weapon is a sniper rifle
				// coming out of a zoom shot prevents switching
				if (startswith(active_weapon.GetClassname(), "tf_weapon_sniperrifle")) {
					NetProps.SetPropInt(active_weapon, "m_bRezoomAfterShot", 0); // these three props prevent
					NetProps.SetPropFloat(active_weapon, "m_flUnzoomTime", -1); // the player rescoping fully
					NetProps.SetPropFloat(active_weapon, "m_flRezoomTime", -1); // if leaving the trigger immediately
					player.RemoveCond(TF_COND_AIMING); // necessary to prevent sniper getting stuck at slow speed
					player.RemoveCond(TF_COND_ZOOMED); // necessary to prevent sniper having scope overlay permanently
					CheckActiveAndNullify("tf_weapon_sniperrifle");
				}

				break;
			}

			case TF_CLASS_SOLDIER: {
				// player's active weapon is a buff banner
				// buffing prevents switch
				CheckActiveAndNullify("tf_weapon_buff_item");
			}

			case TF_CLASS_HEAVYWEAPONS: {
				// heavy minigun is spun up
				if (player.InCond(TF_COND_AIMING)) {
					player.RemoveCond(TF_COND_AIMING);
					NetProps.SetPropEntity(player, "m_hActiveWeapon", null);
				}
				break;
			}

			case TF_CLASS_PYRO: {
				// player has a rocketpack active
				CheckActiveAndNullify("tf_weapon_rocketpack");

				// pyro is flying from rocketpack
				if (player.InCond(TF_COND_ROCKETPACK)) {
					// supposedly stop flight sound but doesn't seem to work well
					SendGlobalGameEvent("rocketpack_landed", {
						userid = player.UserId()
					})
					player.RemoveCond(TF_COND_ROCKETPACK);
				}

				break;
			}
		}

		player.Weapon_Switch(melee_weapon);
	}

	// player has no melee weapon so make one!
	else {
		local random_weapon_idi = [264, 1013, 1123, 1127]; // frying pan, ham shank, necro smasher, crossing guard
		local class_melee_classnames = [
			null, // undefined
			"tf_weapon_bat", // scout
			"tf_weapon_club", // sniper
			"tf_weapon_shovel", // soldier
			"tf_weapon_bottle", // demoman
			"tf_weapon_bonesaw", // medic
			"tf_weapon_fireaxe", // heavy (yes I know)
			"tf_weapon_fireaxe", // pyro
			"tf_weapon_fireaxe", // spy (using fireaxe because backstabbing with a pan is unexpected behaviour)
			"tf_weapon_wrench", // engi
		]

		local new_melee_weapon = GivePlayerWeapon(player, class_melee_classnames[player.GetPlayerClass()], random_weapon_idi[RandomInt(0, random_weapon_idi.len() - 1)]);
		player.Weapon_Switch(new_melee_weapon);
	}

	player.AddCond(TF_COND_CANNOT_SWITCH_FROM_MELEE); // this cond prevents the player switching away from melee
}

/**
 * Remove the melee restriction condition from a player and
 * switch them to their primary or secondary slot weapon,
 * whichever has any ammo. If neither has ammo, the player
 * will remain on their current weapon (melee).
 * @param {instance} player Player instance
 */
function MeleeOnlyOff(player) {
	player.RemoveCond(TF_COND_CANNOT_SWITCH_FROM_MELEE);
	local weapons = GetPlayerWeapons(player);

	// switch to primary or secondary if they have ammo
	for (local i = 0; i < 2; i++) {
		if (i in weapons) {
			local weapon = weapons[i];
			if (weapon.HasAnyAmmo()) {

				// check certain conditions
				switch (player.GetPlayerClass()) {

					case TF_CLASS_SPY: {
						local active_weapon = player.GetActiveWeapon();

						if (startswith(active_weapon.GetClassname(), "tf_weapon_knife")) {
							local sequence_id = active_weapon.GetSequence();

							// check if player just backstabbed a sniper wearing a razorback
							if (active_weapon.GetSequenceName(sequence_id) == "knife_stun") {
								NetProps.SetPropEntity(player, "m_hActiveWeapon", null);
							}
						}
					}
				}

				player.Weapon_Switch(weapon);
				break;
			}
		}
	}
}

/**
 * Get a table of the player's weapons indexed by equip slot number.
 * Note that this is the primary, secondary or melee slot, NOT weapon array slot.
 * @param {instance} player Player instance
 * @return {table} Table of weapons
 */
function GetPlayerWeapons(player) {
	local weapons = {};

	for (local i = 0; i < MAX_WEAPONS; i++) {
		local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
		if (weapon != null) {
			weapons[weapon.GetSlot()] <- weapon;
		}
	}

	return weapons;
}

/**
 * Give a player a weapon, replacing the weapon in the same equip slot.
 * The old weapon is destroyed.
 * Note: The function contains a constant for the maximum number of weapons.
 * @param {instance} player Player handle
 * @param {string} classname Classname of weapon to give
 * @param {integer} item_def_index Item definition index of weapon to give
 * @return {instance} Handle of weapon entity
 */
function GivePlayerWeapon(player, classname, item_def_index) {
	local new_weapon = Entities.CreateByClassname(classname);

	NetProps.SetPropInt(new_weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", item_def_index);
	NetProps.SetPropBool(new_weapon, "m_AttributeManager.m_Item.m_bInitialized", true);
	NetProps.SetPropBool(new_weapon, "m_bValidatedAttachedEntity", true);
	new_weapon.SetTeam(player.GetTeam());

	Entities.DispatchSpawn(new_weapon);

	// replace existing weapon in same equip slot
	for (local i = 0; i < 8; i++) {
		local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i);

		// no weapon found, or weapon does not occupy the same equip slot
		if (weapon == null || weapon.GetSlot() != new_weapon.GetSlot()) {
			continue;
		}

		// destroy the old weapon and erase it from the player's weapons array
		weapon.Destroy();
		NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i);
		break;
	}

	// equip the new weapon to the player, which also adds it to the array
	player.Weapon_Equip(new_weapon);

	return new_weapon;
}

// Testing area
// ----------------------------------------------------------------------------------------------------

// function Think() {
// 	local player = PlayerInstanceFromIndex(1);
// 	if (player == null || !player.IsAlive()) {
// 		return;
// 	}

// 	local weapons = GetPlayerWeapons(player);
// 	if (0 in weapons) {
// 		local primary_weapon = weapons[0];

// 		if (startswith(primary_weapon.GetClassname(), "tf_weapon_sniperrifle")) {
// 			local sequence_id = primary_weapon.GetSequence();

// 			CenterMsg(player, "m_bInReload: " + NetProps.GetPropInt(primary_weapon, "m_bInReload") + "\n" +
// 				"m_flUnzoomTime: " + NetProps.GetPropFloat(primary_weapon, "m_flUnzoomTime") + "\n" +
// 				"m_flRezoomTime: " + NetProps.GetPropFloat(primary_weapon, "m_flRezoomTime") + "\n" +
// 				"m_flUnlockTime: " + NetProps.GetPropFloat(primary_weapon, "m_flUnlockTime") + "\n" +
// 				"Sequence name: " + primary_weapon.GetSequenceName(sequence_id) + "\n" +
// 				"m_bRezoomAfterShot: " + NetProps.GetPropInt(primary_weapon, "m_bRezoomAfterShot"));
// 		}
// 	}

// 	return -1;
// }

// AddThinkToEnt(self, "Think");

/*
	Findings

		Sniper rifle
			When a player fires while scoped, the weapon's m_flUnzoomTime and m_flRezoomTime properties
			change from -1 to a future tick time in seconds, one after the other.
			This can be used to detect when the sniper is reloading after making a scoped shot.
			The weapon plays the "fire" animation sequence regardless if it's scoped or not.
			m_bInReload always returns 0.
*/