/**
 * Matty's Deathrun Thirdperson Script v2.0
 *
 * Put players into thirdperson and back into firstperson using either a function call
 * or a trigger, but it respects the player's preference if they are using a server
 * command to set their perspective.
 *
 * How to use:
 * Add the script to a logic_script entity. You have two ways to activate it:
 *
 * 1. Enter the targetnames of any triggers you wish to put people in thirdperson
 * 		in the EntityGroup fields. One targetname per line, starting from 0.
 * 		They must be unique. If there are more than 16, you can create more
 * 		logic_scripts with the same script and name the remaining triggers there.
 * 		When players touch the triggers they will be put in thirdperson, and
 * 		returned to firstperson when they leave it.
 *
 * 2. Use I/O triggered by the player !activator, sent to the logic_script:
 * 		OnStartTouch > my_logic_script > RunScriptCode MakeTP(activator)
 * 		OnEndTouch > my_logic_script > ReturnToFP(activator)
 *
 * Players will be returned to firstperson on round restart so you don't need to
 * do this yourself! The two functions above accept a player instance or an array
 * of player instances.
 *
 * Extra functions to put all live red players in thirdperson or firstperson state:
 *		my_logic_script > CallScriptFunction > MakeRedTP
 *		my_logic_script > CallScriptFunction > ReturnRedToFP
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
	foreach(entity in EntityGroup) {
		if (startswith(entity.GetClassname(), "trigger_")) {
			entity.ValidateScriptScope();

			entity.GetScriptScope().MakeActivatorTP <-  function() {
				if (activator instanceof CTFPlayer) {
					thirdperson.ent.GetScriptScope().MakeTP(activator);
				}
			}

			entity.GetScriptScope().MakeActivatorFP <-  function() {
				if (activator != null && activator.IsValid() && activator instanceof CTFPlayer) {
					thirdperson.ent.GetScriptScope().ReturnToFP(activator);
				}
			}
		}

		entity.ConnectOutput("OnStartTouch", "MakeActivatorTP");
		entity.ConnectOutput("OnEndTouch", "MakeActivatorFP");
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
function MakeTP(players) {
	// array check
	if (players instanceof CTFPlayer) {
		players = [players]
	};

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
function ReturnToFP(players) {
	// array check
	if (players instanceof CTFPlayer) {
		players = [players]
	};

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


// Helper functions
// --------------------------------------------------------------------------------------------------------------

local maxclients = MaxClients().tointeger();
local red_team = Constants.ETFTeam.TF_TEAM_RED;

function GetLiveReds() {
	local reds = [];

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);
		if (player != null && player.IsValid() && player.GetTeam() == red_team && NetProps.GetPropInt(player, "m_lifeState") == 0) {
			reds.append(player);
		}
	}

	return reds;
}

function MakeRedTP() {
	local reds = GetLiveReds();
	MakeTP(reds);
}

function ReturnRedToFP() {
	local reds = GetLiveReds();
	ReturnToFP(reds);
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