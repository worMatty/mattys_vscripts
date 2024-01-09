/*
   ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄    ▄█     █▄   ▄██████▄     ▄████████    ▄█   ▄█▄    ▄████████
  ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄ ███     ███ ███    ███   ███    ███   ███ ▄███▀   ███    ███
  ███    █▀     ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███ ███     ███ ███    ███   ███    ███   ███▐██▀     ███    █▀
  ███            ███   ▀  ▄███▄▄▄       ███    ███ ███   ███   ███ ███     ███ ███    ███  ▄███▄▄▄▄██▀  ▄█████▀      ███
▀███████████     ███     ▀▀███▀▀▀     ▀███████████ ███   ███   ███ ███     ███ ███    ███ ▀▀███▀▀▀▀▀   ▀▀█████▄    ▀███████████
         ███     ███       ███    █▄    ███    ███ ███   ███   ███ ███     ███ ███    ███ ▀███████████   ███▐██▄            ███
   ▄█    ███     ███       ███    ███   ███    ███ ███   ███   ███ ███ ▄█▄ ███ ███    ███   ███    ███   ███ ▀███▄    ▄█    ███
 ▄████████▀     ▄████▀     ██████████   ███    █▀   ▀█   ███   █▀   ▀███▀███▀   ▀██████▀    ███    ███   ███   ▀█▀  ▄████████▀
                                                                                            ███    ███   ▀
   ▄████████ ▀████    ▐████▀     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄      ▄████████
  ███    ███   ███▌   ████▀  ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███
  ███    █▀     ███  ▐███       ▀███▀▀██   ███    ███   ███    █▀  ███   ███   ███   ███    █▀
 ▄███▄▄▄        ▀███▄███▀        ███   ▀  ▄███▄▄▄▄██▀  ▄███▄▄▄     ███   ███   ███  ▄███▄▄▄
▀▀███▀▀▀        ████▀██▄         ███     ▀▀███▀▀▀▀▀   ▀▀███▀▀▀     ███   ███   ███ ▀▀███▀▀▀
  ███    █▄    ▐███  ▀███        ███     ▀███████████   ███    █▄  ███   ███   ███   ███    █▄
  ███    ███  ▄███     ███▄      ███       ███    ███   ███    ███ ███   ███   ███   ███    ███
  ██████████ ████       ███▄    ▄████▀     ███    ███   ██████████  ▀█   ███   █▀    ██████████
                                           ███    ███
 */

IncludeScript("matty/stocks2.nut");

// Steamworks Extreme 'class'
// --------------------------------------------------------------------------------

::swe <- {
	phrases = {
		ta_lhc_button = "Hit this button to take the\nLow Health Challenge!"
		blue_walk_forwards = "Walk forwards to play the map normally, or hit the Auto Mode button. Choose within fifteen seconds"
		five_seconds_choose = "You have five seconds left to choose!"
		waiting_blue_choose = "Waiting for Blue to choose the course mode..."
		times_up_picking = "Time's up! Picking a mode randomly"
	}

	function ClearLowHealthChallenge() {
		for (local i = 1; i <= maxclients; i++) {
			local player = PlayerInstanceFromIndex(i);

			if (player != null && player.IsValid()) {
				if (player.IsOnLHC(true)) {
					player.SetLHC(false);
				}
			}
		}
	}
};


// Deathrun 'Class'
// --------------------------------------------------------------------------------

::CourseMode <- {
	Unselected = 0
	Manual = 1
	Auto = 2
};

::Deathrun <- {
	course_active = false
	ending_active = false
	course_mode = CourseMode.Unselected

	// debugging - not reset on round restart
	motivator_enabled = true
	show_state_message = false

	// check course state
	function IsCourseActive() {
		return (GetRoundState() == GR_STATE_STALEMATE && course_active == true);
	}

	function IsEndingActive() {
		return (GetRoundState() == GR_STATE_STALEMATE && ending_active == true);
	}

	function IsAutoMode() {
		return (course_mode == CourseMode.Auto);
	}

	function IsManualMode() {
		return (course_mode == CourseMode.Manual);
	}

	function IsModeSelected() {
		return (course_mode != CourseMode.Unselected);
	}

	function SetCourseMode(mode) {
		course_mode = mode;
	}

	// set course state
	function EndingChosen() {
		ending_active = true;
		if (show_state_message) printl("Deathrun: An ending has been chosen");
	}

	// forwards
	function EndCourse() {
		course_active = false;
		EntFire("relay_course_stop", "Trigger");
		if (show_state_message) printl("Deathrun: Course ended");
	}

	// debugging
	function IsMotivatorEnabled() {
		return (motivator_enabled);
	}

	// events
	function RoundRestart() {
		if (show_state_message) printl("Deathrun: Round restarted");

		course_active = false;
		ending_active = false;
		course_mode = CourseMode.Unselected;

		// reset players
		for (local i = 1; i <= maxclients; i++) {
			local player = PlayerInstanceFromIndex(i);

			if (player != null) {
				player.RoundReset();
			}
		}
	}

	function RoundStart() {
		if (show_state_message) printl("Deathrun: Round started");

		if (Players().Team(TF_TEAM_RED).players.len() && Players().Team(TF_TEAM_BLUE).players.len()) {
			course_active = true;
			EntFire("relay_round_start", "Trigger");
		}
	}

	function RoundWin() {
		if (show_state_message) printl("Deathrun: Round won");
		EntFire("relay_motivator_stop", "Trigger");
	}

	function PlayerDeath(params) {
		local player = GetPlayerFromUserID(params.userid);
		if (player != null && player.IsValid() && player.IsOnLHC()) {
			player.SetLHC(false);
		}
	}
};




// DRPlayer Class
// --------------------------------------------------------------------------------

// assigning functions to a player assigns them to their script scope, not the player class
// you need to do player.GetScriptScope().Function()

local player_methods_properties = {
	lhc = false
	reached_end = false

	RoundReset = function() {
		reached_end = false;

		if (IsOnLHC) {
			SetLHC(false);
		}
	}

	// state checks
	IsOnLHC = function(set = null) {
		if (set != null) {
			lhc = set;
		}

		return lhc;
	}

	HasReachedEnd = function(set = null) {
		if (set != null) {
			reached_end = set;
		}

		return reached_end;
	}

	// low health challenge
	ToggleLHC = function() {
		if (IsOnLHC() == false) {
			SetLHC(true);
			// Message.Chat.Client(this, "You have accepted the low health challenge. Good luck!");
			ChatMsg(this, "You have accepted the low health challenge. Good luck!");
		} else {
			SetLHC(false);
			// Message.Chat.Client(this, "You are no longer on the low health challenge");
			ChatMsg(this, "You are no longer on the low health challenge");
		}
	}

	SetLHC = function(set) {
		if (set) {
			IsOnLHC(true);
			this.SetHealth(50);

			for (local i = 0; i < 7; i++) {
				local weapon = NetProps.GetPropEntityArray(this, "m_hMyWeapons", i);

				if (weapon == null || !weapon.IsValid()) {
					continue;
				}

				weapon.AddAttribute("healing received penalty", 0.0, -1);
			}

			printl(this.Name() + " is now on the low health challenge");
		} else if (set == false) {
			IsOnLHC(false);
			this.SetHealth(this.GetMaxHealth());

			for (local i = 0; i < 7; i++) {
				local weapon = NetProps.GetPropEntityArray(this, "m_hMyWeapons", i);

				if (weapon == null || !weapon.IsValid()) {
					continue;
				}

				weapon.RemoveAttribute("healing received penalty");
			}
			// Maybe regeneration would be better?

			printl(this.Name() + " is no longer on the low health challenge");
		}
	}

	// player reaches end of course
	EndReached = function() {
		printl("EndReached triggered");
		if (Deathrun.IsCourseActive() && HasReachedEnd() == false) {
			HasReachedEnd(true);

			if (IsOnLHC()) {
				// Message.Chat.All(this.CName() + " finished while on the Low Health Challenge!");
				ChatMsg(null, this.CName() + " finished while on the Low Health Challenge!");
			} else {
				// Message.Chat.All(this.CName() + " reached the end of the course!");
				ChatMsg(null, this.CName() + " reached the end of the course!");
			}

			DisplayCourseTime();
		}
	}

	DisplayCourseTime = function(timer_name = "round_timer") {
		local time = GetRoundTimeElapsed(timer_name);

		if (time != null) {
			// Message.Chat.Client(this, format("Your time was %d:%d", time.minutes, time.seconds));
			ChatMsg(this, format("Your time was %d:%d", time.minutes, time.seconds));
		}
	}
}

foreach(key, value in player_methods_properties) {
	if (!(key in ::CTFPlayer)) {
		::CTFPlayer[key] <- value; //
		::CTFBot[key] <- ::CTFPlayer[key]; //
	}
}

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

	// printl("Group 1 size is " + groups.group1.len());
	// printl("Group 2 size is " + groups.group2.len());

	// printl("Dumping group 1");
	// DumpObject(groups.group1);

	// printl("Dumping group 2");
	// DumpObject(groups.group2);
}


// Hooks
// --------------------------------------------------------------------------------

// Old events are cleaned by stocks2.nut

function OnGameEvent_teamplay_round_start(params) {
	::Deathrun.RoundRestart();
}

function OnGameEvent_arena_round_start(params) {
	::Deathrun.RoundStart();
}

function OnGameEvent_teamplay_round_win(params) {
	::Deathrun.RoundWin();
}

function OnGameEvent_player_death(params) {
	::Deathrun.PlayerDeath(params);
}

__CollectGameEventCallbacks(this);