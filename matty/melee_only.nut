/*
    Melee Only v0.1.1 by worMatty
    Switch players to their melee weapon and restrict them to it.

    Usage:
        Method 1:
            Add the script to any trigger's vscripts field. When a player touches
            or leaves the trigger, they will be switched in and out of melee.
        Method 2:
            Add the script to a logic_script entity. To put the !activator into and out of
			melee-only mode, send it the following inputs:
                RunScriptCode > MeleeOnly(activator)
                RunScriptCode > MeleeOnlyOff(activator)
		You can use the functions in a script by including it and calling them on player instances.

    Notes:
        If a player does not have a melee weapon, they will be given one.
        The replacement weapon spies receive will not allow them to backstab.
        Their melee animations will be slightly odd but still understandable.

        When the melee restriction is removed from a player, they will be switched
        back to their primary or secondary weapon, whichever has any ammo.

        When a player dies, they lose their melee restriction.

        Spawning a player inside the trigger or firing the input the moment
        they spawn may not work without a short delay. I have not tested this.

        The script makes no attempt to balance melee combat or replace
        weapons with more favourable ones.

		The random_weapon_idis array contains item definition indexes used in replacement weapons.
		You can modify this yourself using RunScriptCode or another script.
*/

/*
	Changelog
	0.1.1
		Documentation, code, comments and function name cleanup and refinement
		Exposed random weapon idi and classname arrays so they can be modified externally
*/

/*
	Known issues
	* If you are scoped when put into melee-only mode, when you are returned
	  to your sniper rifle the scope overlay will show briefly.
*/

IncludeScript("matty/stocks2.nut"); // needed for tfcond and player class constants
::MAX_WEAPONS <- 8
random_weapon_idis <- [264, 1013, 1123, 1127]; // frying pan, ham shank, necro smasher, crossing guard
created_weapon_classnames <- [ // classname of replacement melee weapon created for each class
	null, // not a class
	"tf_weapon_bat", // scout
	"tf_weapon_club", // sniper
	"tf_weapon_shovel", // soldier
	"tf_weapon_bottle", // demoman
	"tf_weapon_bonesaw", // medic
	"tf_weapon_fireaxe", // heavy (yes I know)
	"tf_weapon_fireaxe", // pyro
	"tf_weapon_fireaxe", // spy (using fireaxe because backstabbing with a pan is unexpected behaviour)
	"tf_weapon_wrench", // engi
];
self.ConnectOutput("OnStartTouch", "OnStartTouch");
self.ConnectOutput("OnEndTouch", "OnEndTouch");

function OnStartTouch() {
	if (activator instanceof CTFPlayer) MeleeOnly(activator);
}
function OnEndTouch() {
	if (activator && activator instanceof CTFPlayer) MeleeOnlyOff(activator);
}

/**
 * Switch a player to their melee weapon and restrict them to it.
 * Works by adding the TF cond to restrict to melee.
 * If the player has no melee weapon, one will be
 * created and given to them.
 * @param {CTFPlayer} player Player instance
 */
function MeleeOnly(player) {
	local weapons = GetPlayerWeaponsTable(player);
	player.RemoveCond(TF_COND_TAUNTING); // taunting players are immune to weapon switching

	// switch to melee if it exists
	if (2 in weapons) {
		local melee_weapon = weapons[2];
		local active_weapon = player.GetActiveWeapon();

		// check if the active weapon is a classname of this type, and if so, set the player's active weapon property to null.
		// this removes an obstacle to the switching code working.
		function SetWeaponInactive(classname) {
			if (startswith(active_weapon.GetClassname(), classname)) NetProps.SetPropEntity(player, "m_hActiveWeapon", null);
		}

		// deal with specific property and animation issues preventing switching
		switch (player.GetPlayerClass()) {
			case TF_CLASS_SNIPER: {
				// if the player's active weapon is a sniper rifle,
				// coming out of a zoom shot will prevent them from switching
				if (startswith(active_weapon.GetClassname(), "tf_weapon_sniperrifle")) {
					NetProps.SetPropInt(active_weapon, "m_bRezoomAfterShot", 0); // these three props prevent
					NetProps.SetPropFloat(active_weapon, "m_flUnzoomTime", -1); // the player rescoping fully
					NetProps.SetPropFloat(active_weapon, "m_flRezoomTime", -1); // if leaving the trigger immediately
					player.RemoveCond(TF_COND_AIMING); // necessary to prevent the sniper getting stuck with a slow speed
					player.RemoveCond(TF_COND_ZOOMED); // necessary to prevent the sniper having a scope overlay permanently
					SetWeaponInactive("tf_weapon_sniperrifle");
				}
				break;
			}
			case TF_CLASS_SOLDIER: {
				// if the player's active weapon is a buff banner,
				// buffing prevents them from switching
				SetWeaponInactive("tf_weapon_buff_item");
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
				SetWeaponInactive("tf_weapon_rocketpack"); // player has a rocketpack active
				if (player.InCond(TF_COND_ROCKETPACK)) { // pyro is flying using rocketpack
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

	// player has no melee weapon so we need to make one for them
	else {
		local new_melee_weapon = GivePlayerWeapon(player, created_weapon_classnames[player.GetPlayerClass()], random_weapon_idis[RandomInt(0, random_weapon_idis.len() - 1)]);
		player.Weapon_Switch(new_melee_weapon);
	}

	player.AddCond(TF_COND_CANNOT_SWITCH_FROM_MELEE); // this cond prevents the player switching away from melee
}

/**
 * Remove the melee restriction condition from a player and
 * switch them to their primary or secondary slot weapon,
 * whichever has any ammo. If neither has ammo, the player
 * will remain on their current weapon (melee).
 * @param {CTFPlayer} player Player instance
 */
function MeleeOnlyOff(player) {
	player.RemoveCond(TF_COND_CANNOT_SWITCH_FROM_MELEE);
	local weapons = GetPlayerWeaponsTable(player);

	// switch to primary or secondary if they have ammo
	for (local i = 0; i < 2; i++) {
		if (!(i in weapons)) continue; // no weapon in this slot
		local weapon = weapons[i];
		if (!weapon.HasAnyAmmo()) continue; // weapon has no ammo

		// deal with spy that's just backstabbed a sniper wearing a razorback
		if (player.GetPlayerClass() == TF_CLASS_SPY) {
			local active_weapon = player.GetActiveWeapon();
			if (startswith(active_weapon.GetClassname(), "tf_weapon_knife")) {
				local sequence_id = active_weapon.GetSequence();
				if (active_weapon.GetSequenceName(sequence_id) == "knife_stun") { // still stunned from the razorback
					NetProps.SetPropEntity(player, "m_hActiveWeapon", null); // set active weapon to null to allow us to switch away
				}
			}
		}

		player.Weapon_Switch(weapon);
		break;
	}
}

/**
 * Get a table of the player's weapons indexed by equip slot number.
 * Note that this is the primary, secondary or melee slot, NOT weapon array slot.
 * @param {CTFPlayer} player Player instance
 * @return {table} Table of weapons
 */
function GetPlayerWeaponsTable(player) {
	local weapons = {};
	for (local i = 0; i < MAX_WEAPONS; i++) {
		local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
		if (weapon) weapons[weapon.GetSlot()] <- weapon;
	}
	return weapons;
}

/**
 * Give a player a weapon, replacing the weapon in the same equip slot.
 * The old weapon is destroyed.
 * Note: The function contains a constant for the maximum number of weapons.
 * @param {CTFPlayer} player Player handle
 * @param {string} classname Classname of weapon to give
 * @param {integer} item_def_index Item definition index of weapon to give
 * @return {CBaseCombatWeapon} Weapon entity
 */
function GivePlayerWeapon(player, classname, item_def_index) {
	local new_weapon = Entities.CreateByClassname(classname);
	NetProps.SetPropInt(new_weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", item_def_index);
	NetProps.SetPropBool(new_weapon, "m_AttributeManager.m_Item.m_bInitialized", true);
	NetProps.SetPropBool(new_weapon, "m_bValidatedAttachedEntity", true);
	new_weapon.SetTeam(player.GetTeam());
	Entities.DispatchSpawn(new_weapon);

	// iterate player's weapons and replace the one occupying the same weapon slot
	for (local i = 0; i < 8; i++) {
		local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i);
		if (!weapon || weapon.GetSlot() != new_weapon.GetSlot()) continue;
		weapon.Destroy(); // kill
		NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i); // remove from array
		break;
	}

	player.Weapon_Equip(new_weapon); // adds it to the array
	return new_weapon;
}

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

// Testing area
// ----------------------------------------------------------------------------------------------------

// function Think() {
// 	local player = PlayerInstanceFromIndex(1);
// 	if (player == null || !player.IsAlive()) {
// 		return;
// 	}

// 	local weapons = GetPlayerWeaponsTable(player);
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