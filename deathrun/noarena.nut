/**
 * Deathrun logic without Arena mode
 *
 * WORK IN PROGRESS
 * NOT FUNCTIONAL
 */

IncludeScript("matty/stocks2.nut");

/*
Control respawn wave time - done (disabled for now)
Handle victory conditions
* All reds failed the course
* All reds failed the minigame
   * Participants receive a flag ('Runner'? 'Played course'?)
   * When all flag holders have failed, or there are none, call blue victory
* No reds on team - done
* Blue disconnected (seek replacement?)
    * If blue switches to red while the round is active, kill them as punishment
* Blue died
   * During course (respawn them?)
   * During games
Optionally respawn in play area
Activatorless rounds?
*/

/*
Handled by plugin:
* Restrictions
* Activator selection
*/

/*
One possible approach:
Change respawn wave time to 30 seconds to a minute so players are forced to sit out for a time
then they respawn at the same time in a play area
 */

/*
Player flags:
* Played in the course - done
* Died while course active - done
* Failed the course
* Won the course - added but nothing sets it
* Was alive when the course was won ('played' without 'failed')
* Died during ending - done
*/

/*
Deathrun Redux/Classic stuff
* Move type
Maybe I can call the Arena round start event?
*/

/*
Deathrun Neu stuff
Hooks gamerules to tell if Arena game mode?
*/

round_win_while_blue_no_players = false;

function OnPostSpawn() {
	// check if we can change respawn wave time convar
	Assert(Convars.IsConVarOnAllowList("mp_respawnwavetime"), "This map requires the convar mp_respawnwavetime to be on the server's VScript whitelist");

	// set respawn wave time really high to effectively disable respawns
	Convars, SetValue("mp_respawnwavetime", 1000);

	// victory condition check
	AddThinkToEnt(self, "Think");

	// reset player variables on round restart
	local players = Players({
		include_spec = true
	}).Array();

	foreach(player in players) {
		SetUpPlayer(player);
	}
}

/**
 * Think function called every 0.1s
 */
function Think() {
	VictoryCheck();
}

/**
 * On round start, mark participating players as having played on the course
 */
function OnGameEvent_teamplay_round_active(params) {
	local players = Players().Array();

	foreach(player in players) {
		player.GetScriptScope().noarena.played_course = true;
	}
}

/**
 * Set appropriate flags on player when they perish during an activity
 */
function OnGameEvent_player_death(params) {
	local player = GetPlayerFromUserID(params.userid);

	if (player != null && player.GetTeam() == TF_TEAM_RED) {
		local scope = player.GetScriptScope();

		if (Deathrun.IsCourseActive()) {
			if (scope.noarena.played_course == true) {
				scope.noarena.died_on_course = true;
			}
		} else if (Deathrun.IsEndingActive()) {
			scope.noarena.died_during_ending = true;
		}
	}
}

/**
 * Create table slots on player when they first connect
 */
function OnGameEvent_player_connect_client(params) {
	local player = GetPlayerFromUserID(params.userid);
	if (player != null && player.IsValid()) {
		SetUpPlayer(player);
	}
}

function SetUpPlayer(player) {
	player.ValidateScriptScope();
	local scope = player.GetScriptScope();
	scope.noarena <- {
		played_course = null;
		died_on_course = null;
		won_course = null;
		died_during_ending = null;
	};

	printl("Set up " + player + " with noarena table");
	DumpObject(scope.noarena);
}

// what happens when there are no players on the server? what is the round state?
// should I check if there are dead players on red to determine red loss?

/**
 * Check if there are live players on red and blue and call appropriate team win.
 * Does nothing if the round state is not 'running'.
 * If red and blue both have 0 players, it's a stalemate.
 * If red have no players but blue has players, blue wins.
 * If blue has no players but red has players, red may optionally win depending on a local bool.
 */
function VictoryCheck() {
	if (GetRoundState() == GR_STATE_RND_RUNNING) {
		local reds = Players().Team(TF_TEAM_RED).Alive().players.len();
		local blues = Players().Team(TF_TEAM_BLUE).Alive().players.len();

		if (reds == 0) {
			if (blues == 0) {
				RoundWin(TEAM_UNASSIGNED)
			} else {
				RoundWin(TF_TEAM_BLUE)
			}
		} else if (blues == 0) {
			if (round_win_while_blue_no_players) {
				RoundWin(TF_TEAM_RED)
			}
		}
	}
}

/**
 * Call a round win by spawning a game_round_win
 * Configured to force map reset
 * @param {integer} team Team number
 */
function RoundWin(team) {
	local ent = SpawnEntityFromTable("game_round_win", {
		TeamNum = team
		force_map_reset = true
		switch_teams = false
	});

	if (ent != null) {
		EntFireByHandle(ent, "RoundWin", null, -1, null, null);
		EntFireByHandle(ent, "Kill", null, -1, null, null);
	}
}
// TODO: Change win condition to 'survived'