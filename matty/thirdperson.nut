/**
 * Matty's Deathrun Thirdperson Script v2.2
 *
 * Easily put players into thirdperson and back into firstperson.
 * Useful for platforming minigames or when the player is affected by something (e.g. stun).
 * Use with triggers, so that players are in thirdperson while inside their bounds.
 * Or apply to specific players directly using I/O.
 *
 * If the server is likely to use a SourceMod plugin enabling them to go in and out of thirdperson
 * using a command, then using this script is better than setting the player into thirdperson
 * using the native SetForcedTauntCam input. The script checks if the player has put
 * themselves into thirdperson and respects their preference by not changing their camera.
 * It's common for deathrun servers to use such a SourceMod plugin.
 *
 * How to use:
 * Add the script to a logic_script entity. There are two ways to use it:
 *
 * 1. In the logic_script's EntityGroup fields, enter the targetnames of the triggers
 * 		you wish to grant thirdperson. Use one field per targetname. The script will
 * 		search for all triggers with the same name.
 * 2. Use inputs to the logic_script. See the examples below
 *
 * Setting the !activator into thirdperson:
 * 		logic_script > CallScriptFunction > MakeTP
 * 		logic_script > RunScriptCode > MakeTP(activator)
 *
 * Setting a specific player instance, or array of players into thirdperson:
 * 		logic_script > RunScriptCode > MakeTP(player)
 * 		logic_script > RunScriptCode > MakeTP(players)
 * If you use my stocks2.nut file you can easily create arrays of groups of players,
 * such as all players, one team only, alive or dead, humans or bots, within a radius, etc.
 * 		logic_script > RunScriptCode > MakeTP(LiveReds())
 *		logic_script > RunScriptCode > MakeTP(GetPlayers({ alive = true }))
 * If you want to know if you can do something, ask me.

 * Players will be returned to firstperson automatically on round restart.
 * To return players to firstperson manually, replace the MakeTP calls above with ReturnToFP.
 */

/*
	Changelog
		2.2
			Improved documentation
			Script searches for all triggers with the same targetname as those entered in EntityGroup fields
			Removed the player array helper functions as they are superceded by those in stocks2.nut.
		2.1
			MakeTP and ReturnToFP can be used with CallScriptFunction and activator
*/

// Setup and resetting
// --------------------------------------------------------------------------------------------------------------

// using global storage to transcend rounds and enable use of multiple logic_scripts
if (!("thirdperson" in getroottable())) {
	::thirdperson <- {
		players_to_ignore = []
		players_in_tp = []
		ent = null
	}
}

thirdperson.ent = self;

/**
 * Hook each trigger named in EntityGroup
 */
function OnPostSpawn() {
	// hook triggers
	if ("EntityGroup" in self.GetScriptScope()) {
		foreach(entity in EntityGroup) {
			if (entity == null || !startswith(entity.GetClassname(), "trigger_")) {
				continue;
			}

			local triggers = [];
			local trigger = null;

			while (trigger = Entities.FindByName(trigger, entity.GetName())) {
				trigger.ValidateScriptScope();

				trigger.GetScriptScope().MakeActivatorTP <-  function() {
					if (activator instanceof CTFPlayer) {
						thirdperson.ent.GetScriptScope().MakeTP(activator);
					}
				}

				trigger.GetScriptScope().MakeActivatorFP <-  function() {
					if (activator != null && activator.IsValid() && activator instanceof CTFPlayer) {
						thirdperson.ent.GetScriptScope().ReturnToFP(activator);
					}
				}

				trigger.ConnectOutput("OnStartTouch", "MakeActivatorTP");
				trigger.ConnectOutput("OnEndTouch", "MakeActivatorFP");
			}
		}
	}

	// return players in tp to fp
	ReturnToFP(thirdperson.players_in_tp);

	// reset arrays
	thirdperson.players_to_ignore <- [];
	thirdperson.players_in_tp <- [];
}


// Functions
// --------------------------------------------------------------------------------------------------------------

/**
 * Make specified players thirdperson
 * @param {array} players CTFPlayer instance or array of them
 */
function MakeTP(players = null) {
	// use activator when no argument
	if (players == null && activator != null && activator instanceof CTFPlayer) {
		players = activator;
	}

	// type check
	if (players instanceof CTFPlayer) {
		players = [players];
	} else if (typeof players != "array") {
		error(__FILE__ + " -- MakeTP - Incorrect object type provided. Must be player or array\n");
		return;
	}

	foreach(player in players) {
		if (player != null && player.IsValid() && player instanceof CTFPlayer) {
			if (NetProps.GetPropInt(player, "m_nForceTauntCam")) {
				if (thirdperson.players_in_tp.find(player) == null) {
					thirdperson.players_to_ignore.append(player);
				}
			} else {
				thirdperson.players_in_tp.append(player);
				EntFireByHandle(player, "SetForcedTauntCam", "1", -1, player, player);
			}
		}
	}
}

/**
 * Make specified players firstperson
 * @param {array} players CTFPlayer instance or array of them
 */
function ReturnToFP(players = null) {
	// use activator when no argument
	if (players == null && activator != null && activator instanceof CTFPlayer) {
		players = activator;
	}

	// type check
	if (players instanceof CTFPlayer) {
		players = [players]
	} else if (typeof players != "array") {
		error(__FILE__ + " -- ReturnToFP - Incorrect object type provided. Must be player or array\n");
		return;
	}

	foreach(player in players) {
		if (player != null && player.IsValid() && player instanceof CTFPlayer) {

			// remove tp
			local index = thirdperson.players_in_tp.find(player);
			if (index != null && NetProps.GetPropInt(activator, "m_nForceTauntCam")) {
				EntFireByHandle(player, "SetForcedTauntCam", "0", -1, player, player);
				thirdperson.players_in_tp.remove(index);
			}

			// remove from ignore list
			index = thirdperson.players_to_ignore.find(player);
			if (index != null) {
				thirdperson.players_to_ignore.remove(index);
			}
		}
	}
}

// Notes
// --------------------------------------------------------------------------------------------------------------

/*
	Notes on the 'forced taunt cam perspective' property

	Forced Taunt Cam Perspective (FTCP) can only be enabled using an input on the player.
	When enabled, the player's property m_nForcedTauntCam is set to 1.
	When taunting, this property is not affected!
	When finishing a taunt, this property will not be reset and the player will remain in FTCP!
	This makes it ideal for forcing thirdperson because it's not overridden by taunts.
	This script checks if a player is already in FTPC on entrance, and if so, does not change it at all.
	This respects server plugins which allow players to freely toggle thirdperson.
*/