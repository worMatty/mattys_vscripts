// drmap

IncludeScript("matty/stocks2.nut");

// Helper functions
// --------------------------------------------------------------------------------

/**
 * Divide the live red players into two or more groups for use in minigames
 * Shuffles the players before putting them in their groups.
 * @param {integer} number_of_groups The number of groups
 * @param {bool} activator_in_first If true, place the activator in index 0 of the first group
 * @return {array} An array of arrays containing players
 */
function DivideReds(number_of_groups = 2, activator_in_first = true) {
	local players = Players().Team(TF_TEAM_RED).Alive().Shuffle();

	if (activator_in_first && players.ContainsPlayer(activator) != null) {
		players.Exclude(activator).Array().insert(0, activator);
	}

	return players.Divide(number_of_groups);
}

/**
 * Split live red players into two groups
 * Specify the size of group 1 and all remaining players go into group 2
 * Used when teleporting players to the active and spectator areas of a minigame
 * Shuffles the player list prior to assigning them to groups
 * @param {integer} group1_size Size of group 1
 * @param {bool} activator_in_first Position the activator at index 0 of the first group's array
 * @return {table} Table of arrays in this format: groups.group1/group2
 */
function ApportionReds(group1_size, activator_in_first = true) {
	local groups = {
		group1 = []
		group2 = []
	}

	local players = Players().Team(TF_TEAM_RED).Alive().Shuffle();

	if (activator_in_first && players.ContainsPlayer(activator) != null) {
		players.Exclude(activator).Array().insert(0, activator);
	}

	groups.group1 = players.RemovePlayers(group1_size);
	groups.group2 = players.Array();

	return groups;
}


// Hooks
// --------------------------------------------------------------------------------

// Old events are cleaned by stocks2.nut

/**
 * When a round becomes active, verify it is a valid round
 * by checking each team has at least one live player.
 * If true, trigger the `relay_round_active` logic_relay
 */
function OnGameEvent_arena_round_start(params) {
	if (Players().Team(TF_TEAM_RED).Alive().players.len() && Players().Team(TF_TEAM_BLUE).Alive().players.len()) {
		course_active = true;
		EntFire("relay_round_active*", "Trigger", null, -1);
	}
}

/**
 * On the round win event, trigger various course stop relays
 */
function OnGameEvent_teamplay_round_win(params) {
	EntFire("relay_round_win*", "Trigger", null, -1);
}

/**
 * On round restart, reset deathrun map variables
 * and collect game events
 */
function OnPostSpawn() {
	course_active = false;
}

__CollectGameEventCallbacks(self.GetScriptScope());

// Global stuff
// --------------------------------------------------------------------------------

if ("course_active" in ROOT) {
	return;
}

drmap <- {
	course_active = false
	motivator_enabled = true

	function IsRoundActive() {
		return (GetRoundState() == GR_STATE_STALEMATE);
	}

	function IsCourseActive() {
		return (GetRoundState() == GR_STATE_STALEMATE && course_active == true);
	}

	function EndCourse() {
		course_active = false;
		EntFire("relay_course_stop*", "Trigger");
	}
};

foreach(key, value in drmap) {
	ROOT[key] <- value;
};

delete drmap;
// when assigning drmap using `local drmap = {}` I got this error
// drmap.nut line = (113) column = (14) : error cannot delete an (outer) local