/*
	Hide Items - Version 0.5.1 by worMatty
    Hide a player's weapons and cosmetics. Adds methods to CTFPlayer & CTFBot

    Usage:
		Add the script to a logic_script entity.
		Call one of the CTFPlayer methods below on the !activator of an I/O chain. e.g. When touching a trigger...
			OnStartTouch > !activator > RunScriptCode > self.HideWearables()
			OnEndTouch > !activator > RunScriptCode > self.ShowWearables()

		You can instead call inputs on select player entities from an arbitrary output. For instance to hide wearables on live reds:
			OnWhatever > player > RunScriptCode > if (self.IsAlive() && self.GetTeam() == Constants.ETFTeam.TF_TEAM_RED) self.HideWearables()

		Scripters can just use these as methods of a CTFPlayer or CTFBot instance.
*/

if (!("HideItem" in CTFPlayer)) {

	local methods = {

		/**
		 * Get the player's equipped weapons
		 * @return {array} Array of weapon handles
		 */
		function GetWeapons() {
			local weapons = [], weapons_len = NetProps.GetPropArraySize(this, "m_hMyWeapons");
			for (local i = 0; i < weapons_len; i++) {
				local weapon = NetProps.GetPropEntityArray(this, "m_hMyWeapons", i);
				if (weapon && weapon.IsValid()) weapons.append(weapon);
			}
			return weapons;
		}

		/**
		 * Get the player's wearables
		 * @return {array} Array of wearable item handles
		 */
		function GetWearables() {
			local wearables = [];
			for (local child = this.FirstMoveChild(); child != null; child = child.NextMovePeer()) {
				if (child instanceof CEconEntity && !(child instanceof CBaseCombatWeapon)) wearables.append(child);
			}
			return wearables;
		}

		/**
		 * Hide a weapon or wearable item belonging to the player.
		 * All items are told not to draw, but weapons also have their rendermode changes, their alpha set to 0
		 * and shadow disabled. This is because when the player switches to a weapon, it will draw again.
		 */
		function HideItem(item) {
			if (!item.IsValid()) return;
			if (item.GetClassname() == "tf_weapon_parachute_primary") { // kill primary parachute weapon and associated extra wearable
				local wearable = NetProps.GetPropEntity(item, "m_hExtraWearable");
				wearable.Kill();
				item.Kill();
			} else {
				if (startswith(item.GetClassname(), "tf_weapon")) { // also set rendermode, alpha and shadow of weapons in addition to not
					item.AcceptInput("AddOutput", "rendermode 1", null, null); // drawing them, as when player switches back to them
					item.AcceptInput("Alpha", "0", null, null); // they will begin to draw again
					item.AcceptInput("DisableShadow", null, null, null);
				}
				item.DisableDraw();
			}
		}

		/**
		 * Unhide an item by instructing it to draw and resetting its rendermode, alpha and enabling its shadow
		 */
		function ShowItem(item) {
			if (startswith(item.GetClassname(), "tf_weapon")) { // restore rendermode, alpha and dynamic shadows
				item.AcceptInput("AddOutput", "rendermode 1", null, null);
				item.AcceptInput("Alpha", "255", null, null);
				item.AcceptInput("EnableShadow", null, null, null);
			}
			item.EnableDraw();
		}

		/**
		 * Hide all of the player's weapons
		 */
		function HideWeapons() {
			local weapons = GetWeapons();
			foreach(weapon in weapons) HideItem(weapon);
		}

		/**
		 * Show all of the player's weapons
		 */
		function ShowWeapons() {
			local weapons = GetWeapons();
			foreach(weapon in weapons) ShowItem(weapon);
		}

		/**
		 * Kill all of the player's weapons
		 */
		function KillWeapons() {
			local weapons_len = NetProps.GetPropArraySize(this, "m_hMyWeapons");
			for (local i = 0; i < weapons_len; i++) {
				local weapon = NetProps.GetPropEntityArray(this, "m_hMyWeapons", i);
				if (!weapon) continue;
				if (weapon.IsValid()) weapon.Destroy();
				NetProps.SetPropEntityArray(this, "m_hMyWeapons", null, i);
			}
		}

		/**
		 * Hide all of the player's wearables
		 */
		function HideWearables() {
			local wearables = GetWearables();
			foreach(wearable in wearables) HideItem(wearable);
		}

		/**
		 * Show all of the player's wearables
		 */
		function ShowWearables() {
			local wearables = GetWearables();
			foreach(wearable in wearables) ShowItem(wearable);
		}

		/**
		 * Kill all of the player's wearables
		 */
		function KillWearables() {
			local wearables = GetWearables();
			foreach(wearable in wearables) wearable.Destroy();
		}

	}

	// add methods
	foreach(key, val in methods) {
		::CTFPlayer[key] <- val; //
		::CTFBot[key] <- val;
		if (developer()) printl(__FILE__ + " -- Added " + key + " method to CTFPlayer and CTFBot");
	}

	// hook events
	local event_hooks = {
		// show player items on spawn
		OnGameEvent_post_inventory_application = function(params) {
			local player = GetPlayerFromUserID(params.userid);
			player.ShowWeapons();
			player.ShowWearables();
		}
	}
	__CollectGameEventCallbacks(event_hooks);

}

/*
	Known issues
	* Cannot hide the silk chute model of primary parachute weapon on Demo yet so the weapon
		and associated wearables are killed for now. If you know a good way please LMK.
*/

/*
	Changelog
		0.5.1
			Hook post-spawn event once on script first run then never again. Do not use ClearGameEventCallbacks.
			If you do the event will be deleted.
		0.5
			* Cleaned up documentation
			* Cleaned up code and comments
		0.4
			* Made functions methods of CTFPlayer
			* Split functions into separate ones for weapons and wearables to make it simpler
		0.3
			* Hide code changed to disabling draw instead of alpha 0, which is more efficient
			* Enable draw of all items on player spawn
			* Primary parachute (demo) weapon and wearables are killed because I do not yet know how
				to hide the internal silk chute model
		0.2
			* Function parameters changed to optionally specify selecting wearables and weapons
			* New function to KillItems
			* Expanded instructions
*/