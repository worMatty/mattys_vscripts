/*
    Hide a player's weapons and cosmetics
    v0.4 by worMatty

    Usage:
		Add the script to a logic_case
		Call a function on a player like so:
			OnStartTouch > !activator > RunScriptCode > self.HideWearables()
			OnStartTouch > !activator > RunScriptCode > self.ShowWearables()
*/

/*
	Changelog
		v0.4
			* Made functions methods of CTFPlayer
			* Split functions into separate ones for weapons and wearables to make it simpler
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


// Get stuff
// ----------------------------------------------------------------------------------------------------

/**
 * Get the player's weapons
 * @return {array} Array of weapons
 */
function GetWeapons() {
	local weapons = [];
	for (local i = 0; i < MAX_WEAPONS; i++) {
		local weapon = NetProps.GetPropEntityArray(this, "m_hMyWeapons", i)
		if (weapon != null) {
			weapons.append(weapon);
		}
	}
	return weapons;
}

/**
 * Get the player's wearables
 * @return {array} Array of wearables
 */
function GetWearables() {
	local wearables = [];
	for (local child = this.FirstMoveChild(); child != null; child = child.NextMovePeer()) {
		if (child instanceof CEconEntity && child instanceof CBaseCombatWeapon == false) {
			wearables.append(child);
		}
	}
	return wearables;
}


// Do stuff to stuff
// ----------------------------------------------------------------------------------------------------

/**
 * Hide an item by making it not draw
 * Weapons will begin drawing again when... drawn by the player, so we also
 * change their rendermode to 1 and alpha to 0, and disable their dynamic shadow.
 * tf_weapon_parachute_primary is killed because it has a silk chute model that I don't yet know how to hide.
 * @param {instance} item Item
 */
function HideItem(item) {
	if (!item.IsValid()) {
		return;
	}

	// kill primary parachute weapon and associated extra wearable
	if (item.GetClassname() == "tf_weapon_parachute_primary") {
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
 * Restore an item to visibility by making them draw again
 * Makes weapons visible by restoring their alpha to 255 and enabling their dynamic shadows.
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
 * Hide the player's weapons
 */
function HideWeapons() {
	local weapons = GetWeapons();
	foreach(weapon in weapons) {
		HideItem(weapon);
	}
}

/**
 * Hide the player's wearables
 */
function HideWearables() {
	local wearables = GetWearables();
	foreach(wearable in wearables) {
		HideItem(wearable);
	}
}

/**
 * Show the player's weapons
 */
function ShowWeapons() {
	local weapons = GetWeapons();
	foreach(weapon in weapons) {
		ShowItem(weapon);
	}
}

/**
 * Show the player's wearables
 */
function ShowWearables() {
	local wearables = GetWearables();
	foreach(wearable in wearables) {
		ShowItem(wearable);
	}
}

/**
 * Kill the player's weapons.
 * Note that this will make them go into reference pose
 */
function KillWeapons() {
	local weapons = GetWeapons();
	foreach(weapon in weapons) {
		weapon.Destroy();
	}
}

/**
 * Kill the player's wearables
 */
function KillWearables() {
	local wearables = GetWearables();
	foreach(wearable in wearables) {
		wearable.Destroy();
	}
}

if ("HideItem" in ::CTFPlayer == false) {
	foreach(key, val in this) {
		if (typeof val == "function") {
			::CTFPlayer[key] <- val; //
			::CTFBot[key] <- val;
		}
	}
}

// Event hooks
// ----------------------------------------------------------------------------------------------------

local EventsID = UniqueString();

getroottable()[EventsID] <- {

	// show player items on spawn
	OnGameEvent_post_inventory_application = function(params) {
		local player = GetPlayerFromUserID(params.userid);
		player.ShowWeapons();
		player.ShowWearables();
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