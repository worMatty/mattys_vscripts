/*
    Hide a player's weapons and cosmetics
    v0.3 by worMatty

    Usage: Put in a logic_script and send it an input using RunScriptCode:
		HideItems(player)
		ShowItems(player)
		Killitems(player)

	If the function call is triggered by a player !activator you can supply 'activator'
	or just leave it blank and the function will default to activator.
		Hideitems()
	Alternatively use CallScriptFunction instad of RunScriptCode without brackets:
		HideItems

	If you only want to affect one type of item, weapons or cosmetics, you can toggle either
	off by supplying 'false' in the corresponding argument slot.
	Here are the function parameters:
		HideItems(player, wearables, weapons)
	Usage:
		HideItems(player, true, false)
	This would apply to wearables but not weapons.

	Example RunScriptCode inputs to hide the !activator's weapons and kill their wearables:
		HideItems(activator, false, true)
		KillItems(activator, true, false)
*/

/*
	Changelog
		v0.3
			* Hide code changed to disabling draw instead of alpha 0, which is more efficient
			* Enable draw of all items on player spawn
			* Primary parachute (demo) weapon and wearables are killed because I do not yet know how
				to hide the internal silk chute model
		v0.2
			* Function parameters changed to optionally specify selecting wearables and weapons
			* New function to KillItems
			* Expanded instructions
*/

/*
	Known issues
	* Cannot hide the silk chute model of primary parachute weapon on Demo yet so the weapon
		and associated wearables are killed for now
*/


// Vars & consts
// ----------------------------------------------------------------------------------------------------

::MAX_WEAPONS <- 8
local kill_parachute = true; // kill parachute because I haven't found a way to make the silk chute model invisible yet


// Get stuff
// ----------------------------------------------------------------------------------------------------

/**
 * Given a player instance, return an array of their weapons and/or cosmetics
 * @param {CTFPlayer} player Instance of CTFPlayer
 * @param {bool} wearables True to get wearables
 * @param {bool} weapons True to get weapons
 * @return {array} Array of items
 */
function GetPlayerItems(player, wearables = true, weapons = true) {
	local items = [];

	// wearables
	if (wearables) {
		for (local wearable = player.FirstMoveChild(); wearable != null; wearable = wearable.NextMovePeer()) {
			if (wearable instanceof CEconEntity && wearable instanceof CBaseCombatWeapon == false) {
				items.append(wearable);
			}
		}
	}

	// weapons
	if (weapons) {
		for (local i = 0; i < MAX_WEAPONS; i++) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon != null) {
				items.append(weapon);
			}
		}
	}

	return items;
}


// Do stuff to stuff
// ----------------------------------------------------------------------------------------------------

/**
 * Hide an item by changing its rendermode and alpha
 * @param {instance} item Item
 */
function HideItem(item) {
	if (!item.IsValid()) {
		return;
	}

	// kill primary parachute weapon and associated extra wearable
	if (item.GetClassname() == "tf_weapon_parachute_primary" && kill_parachute) {
		local wearable = NetProps.GetPropEntity(item, "m_hExtraWearable");
		wearable.Kill();
		item.Kill();
	}
	// else disable draw
	else {
		if (startswith(item.GetClassname(), "tf_weapon")) {
			item.AcceptInput("AddOutput", "rendermode 1", null, null);
			item.AcceptInput("Alpha", "0", null, null);
			item.AcceptInput("DisableShadow", null, null, null);
		}
		item.DisableDraw();
	}
}

/**
 * Show an item by restoring its rendermode and alpha to default
 * @param {instance} item Item
 */
function ShowItem(item) {
	if (startswith(item.GetClassname(), "tf_weapon")) {
		item.AcceptInput("AddOutput", "rendermode 1", null, null);
		item.AcceptInput("Alpha", "255", null, null);
		item.AcceptInput("EnableShadow", null, null, null);
	}
	item.EnableDraw();
}

/**
 * Hide a player's weapons and/or cosmetics
 * @param {CTFPlayer} player Player instance
 * @param {bool} wearables True to apply to wearables
 * @param {bool} weapons True to apply to weapons
 * @return {integer} Number of items hidden
 */
function HideItems(player, wearables = true, weapons = true) {
	if (player == null || !player.IsValid() || !(player instanceof CTFPlayer)) {
		error(__FILE__ + " -- Error: HideItems was not given a valid player handle: " + player + "\n");
		return;
	}

	local items = GetPlayerItems(player, wearables, weapons);
	foreach(item in items) {
		HideItem(item);
	}

	return items.len();
}

/**
 * Show a player's weapons and/or cosmetics
 * @param {CTFPlayer} player Player instance
 * @param {bool} wearables True to apply to wearables
 * @param {bool} weapons True to apply to weapons
 * @return {integer} Number of items shown
 */
function ShowItems(player, wearables = true, weapons = true) {
	if (player == null || !player.IsValid() || !(player instanceof CTFPlayer)) {
		error(__FILE__ + " -- Error: ShowItems was not given a valid player handle: " + player + "\n");
		return;
	}

	local items = GetPlayerItems(player, wearables, weapons);
	foreach(item in items) {
		ShowItem(item);
	}

	return items.len();
}

/**
 * Kill a player's weapons and/or cosmetics
 * @param {CTFPlayer} player Player instance
 * @param {bool} wearables True to apply to wearables
 * @param {bool} weapons True to apply to weapons
 * @return {integer} Number of items killed
 */
function KillItems(player, wearables = true, weapons = true) {
	if (player == null || !player.IsValid() || !(player instanceof CTFPlayer)) {
		error(__FILE__ + " -- Error: KillItems was not given a valid player handle: " + player + "\n");
		return;
	}

	local items = GetPlayerItems(player, wearables, weapons);
	foreach(item in items) {
		item.Destroy();
	}

	return items.len();
}


// Debugging
// ----------------------------------------------------------------------------------------------------

/**
 * Print the cosmetics and weapons of a player
 * @param {CTFPlayer} player Player handle
 */
function PrintItems(player) {
	if (player == null || player instanceof CTFPlayer == false) {
		printl(__FILE__ + " Argument '" + player + "' is not a player handle");
		return;
	}

	printl(__FILE__ + " Printing wearables for " + player);
	local wearables = GetPlayerItems(player, true, false);
	foreach(wearable in wearables) {
		local extra_wearable = NetProps.GetPropEntity(wearable, "m_hExtraWearable");
		printl("Wearable: " + wearable + " Model index: " + NetProps.GetPropInt(wearable, "m_nModelIndex") + " Model name: " + wearable.GetModelName());
	}

	printl(__FILE__ + " Printing weapons for " + player);
	local weapons = GetPlayerItems(player, false, true);
	foreach(weapon in weapons) {
		local extra_wearable = NetProps.GetPropEntity(weapon, "m_hExtraWearable");
		printl("Weapon: " + weapon + " Extra wearable: " + extra_wearable);
	}
}

/**
 * Print the children of a player
 * @param {CTFPlayer} player Player handle
 */
function PrintChildrenAndWeapons(player) {
	printl(__FILE__ + " Printing children for " + player);

	for (local child = player.FirstMoveChild(); child != null; child = child.NextMovePeer()) {
		printl("Child: " + child + " CEconEntity: " + (child instanceof CEconEntity) + " CBaseCombatWeapon: " + (child instanceof CBaseCombatWeapon));
		printl("Model: " + child.GetModelName());
	}

	printl(__FILE__ + " Printing weapons for " + player);

	for (local i = 0; i < MAX_WEAPONS; i++) {
		local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
		if (weapon != null) {
			printl("Weapon: " + weapon + " CEconEntity: " + (weapon instanceof CEconEntity) + " CBaseCombatWeapon: " + (weapon instanceof CBaseCombatWeapon));
			printl("Model: " + weapon.GetModelName());
		}
	}
}


// Event hooks
// ----------------------------------------------------------------------------------------------------

/**
 * Unhide items on player spawn
 */
function OnGameEvent_post_inventory_application(params) {
	// self check prevents event code being called once for each round restart
	if (self.IsValid()) {
		local player = GetPlayerFromUserID(params.userid);
		ShowItems(player);
	}
}

__CollectGameEventCallbacks(this);


// Notes
// ----------------------------------------------------------------------------------------------------

/*
	CEconEntity
		tf_powerup_bottle
		tf_weapon_sword
		tf_wearable
		tf_weapon_parachute_primary
		tf_weapon_spellbook
		tf_wearable_razorback

	Hiding the wearable portion of a parachute primary makes it look all glitchy
		m_iWorldModelIndex: 0
		m_nModelIndex: 0
		m_hOwnerEntity: The player
		m_hEffectEntity: null
		m_nBody: null/0
		m_flModelScale: 1
*/