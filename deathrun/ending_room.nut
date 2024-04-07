/**
 * Deathrun ending room
 *
 * Manage the player(s) in a captive ending room to avoid stalls
 */

/*
1. Manage red player(s) for choosing (count choosers)
2. Replace chooser if chooser(s) die
3. Expire chooser by swapping or releasing reds, or choosing a game
*/

local choosers = [];

/**
 * Store the supplied players in the script's choosers array
 * @param {any} players Array or instance handle of player(s) assigned to choose an ending
 */
function StartChoosing(players, delay = 20) {
	if (typeof players == "instance" && players instanceof CTFPlayer) {
		choosers = [players];
	} else {
		choosers = players;
	}
}

function OnGameEvent_player_died(params) {
	local indesx = choosers.find(GetPlayerFromUserID(params.userid));

	if (index != -1) {
		choosers.remove(index);
	}

	if (choosers.len() == 0) {

	}
}