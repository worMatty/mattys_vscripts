/*
	Hide Items - Version 0.5 by worMatty
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

::MAX_WEAPONS <- 8

if (!("HideItem" in ::CTFPlayer)) {
	local new_methods = {
		GetWeapons = function() { // gets weapons from player's weapons array
			local weapons = [];
			for (local i = 0; i < MAX_WEAPONS; i++) {
				local weapon = NetProps.GetPropEntityArray(this, "m_hMyWeapons", i);
				if (weapon != null) weapons.append(weapon);
			}
			return weapons;
		}
		GetWearables = function() { // gets instances of CEconEntity parented to player
			local wearables = [];
			for (local child = this.FirstMoveChild(); child != null; child = child.NextMovePeer()) {
				if (child instanceof CEconEntity && child instanceof CBaseCombatWeapon == false) wearables.append(child);
			}
			return wearables;
		}

		HideItem = function(item) {
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
		ShowItem = function(item) {
			if (startswith(item.GetClassname(), "tf_weapon")) { // restore rendermode, alpha and dynamic shadows
				item.AcceptInput("AddOutput", "rendermode 1", null, null);
				item.AcceptInput("Alpha", "255", null, null);
				item.AcceptInput("EnableShadow", null, null, null);
			}
			item.EnableDraw();
		}

		HideWeapons = function() { // hide all weapons
			local weapons = GetWeapons();
			foreach(weapon in weapons) HideItem(weapon);
		}
		ShowWeapons = function() { // show all weapons
			local weapons = GetWeapons();
			foreach(weapon in weapons) ShowItem(weapon);
		}
		KillWeapons = function() { // kill all weapons
			local weapons = GetWeapons();
			foreach(weapon in weapons) weapon.Destroy();
		}

		HideWearables = function() { // hide all wearables
			local wearables = GetWearables();
			foreach(wearable in wearables) HideItem(wearable);
		}
		ShowWearables = function() { // show all wearables
			local wearables = GetWearables();
			foreach(wearable in wearables) ShowItem(wearable);
		}
		KillWearables = function() { // kill all wearables
			local wearables = GetWearables();
			foreach(wearable in wearables) wearable.Destroy();
		}
	}

	// add functions to CTFPlayer
	foreach(key, val in new_methods) {
		if (typeof val == "function") {
			::CTFPlayer[key] <- val; //
			::CTFBot[key] <- val;
		}
	}

	// event hooks
	local events = {
		OnGameEvent_post_inventory_application = function(params) { // show player items on spawn
			local player = GetPlayerFromUserID(params.userid);
			player.ShowWeapons();
			player.ShowWearables();
		}
	}
	__CollectGameEventCallbacks(events);
}

/*
	Known issues
	* Cannot hide the silk chute model of primary parachute weapon on Demo yet so the weapon
		and associated wearables are killed for now. If you know a good way please LMK.
*/

/*
	Changelog
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