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

IncludeScript("matty/player_lists.nut");
IncludeScript("matty/stocks2.nut");

// Constants
// --------------------------------------------------------------------------------

// global


// enum CourseMode {
// 	Unselected,
// 	Manual,
// 	Auto
// }

// local
// local roundstate_stalemate = Constants.ERoundState.GR_STATE_STALEMATE;
local maxclients = MaxClients();
local course_timer_name = "round_timer";


// Variables
// --------------------------------------------------------------------------------

::swe <- {}; // global table of map-specific stuff


// Sounds
// --------------------------------------------------------------------------------

::swe.sounds <- {
	notify = "steamworks_extreme/ui/red_eclipse/shockdamage.mp3"
}

foreach(name, path in swe.sounds) {
	PrecacheSound(path);
};


// Phrases
// --------------------------------------------------------------------------------

::swe.phrases <- {
	ta_lhc_button = "Hit this button to take the\nLow Health Challenge!"
};


// Deathrun Class
// --------------------------------------------------------------------------------

::CourseMode <- {
	Unselected = 0
	Manual = 1
	Auto = 2
};

::Deathrun <- {
	roundstate_stalemate = Constants.ERoundState.GR_STATE_STALEMATE

	course_active = false
	ending_active = false
	course_mode = CourseMode.Unselected

	function IsCourseActive() {
		return (GetRoundState() == roundstate_stalemate && course_active == true);
	}

	function IsEndingActive() {
		return (GetRoundState() == roundstate_stalemate && ending_active == true);
	}

	function IsAutoMode() {
		return (course_mode == CourseMode.Auto);
	}

	function SetCourseMode(mode) {
		course_mode = mode;
	}

	function EndCourse() {
		course_active = false;
		EntFire("relay_course_stop", "Trigger");
	}

	function EndingChosen() {
		ending_active = true;
	}

	// events
	function RoundStart() {
		if (Players().Team(TF_TEAM_RED).players.len() && Players().Team(TF_TEAM_BLUE).players.len()) {
			course_active = true;
			EntFire("relay_round_start", "Trigger");
		}
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
			Message.Chat.Client(this, "You have accepted the low health challenge. Good luck!");
		} else {
			SetLHC(false);
			Message.Chat.Client(this, "You are no longer on the low health challenge");
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
				Message.Chat.All(this.ColoredName() + " finished while on the Low Health Challenge!");
			} else {
				Message.Chat.All(this.ColoredName() + " reached the end of the course!");
			}

			DisplayCourseTime();
		}
	}

	DisplayCourseTime = function(timer_name = "round_timer") {
		local time = GetRoundTimeElapsed();

		if (time != null) {
			Message.Chat.Client(this, format("Your time was %d:%d", time.minutes, time.seconds));
		}
	}
}

foreach(key, value in player_methods_properties) {
	if (!(key in ::CTFPlayer)) {
		::CTFPlayer[key] <- value; //
		::CTFBot[key] <- ::CTFPlayer[key]; //
	}
}

// Player
// --------------------------------------------------------------------------------

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

function GetRoundTimeElapsed(timer_name = course_timer_name) {
	local timer = Entities.FindByName(null, timer_name);

	if (timer != null) {
		local time_remaining = NetProps.GetPropFloat(timer, "m_flTimeRemaining") + 1;
		local end_time = NetProps.GetPropFloat(timer, "m_flTimerEndTime");
		local time = Time();
		local time_elapsed = time_remaining - (end_time - time);
		local minutes = abs(time_elapsed / 60);
		local seconds = abs(time_elapsed % 60);

		return {
			minutes = minutes,
			seconds = seconds
		};
	}

	return null;
}


// Hooks
// --------------------------------------------------------------------------------

CleanGameEventCallbacks();

function OnPostSpawn() {
	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null) {
			player.RoundReset();
		}
	}
}

/**
 * Set up a player's script scope and round flags when they first spawn
 */
// function OnGameEvent_player_initial_spawn(params) {
// 	local player = PlayerInstanceFromIndex(params.index);

// 	if (player != null && player.IsValid()) {
// 		player.ValidateScriptScope();
// 		foreach(key, value in player_methods_properties) {
// 			player.GetScriptScope()[key] <- value;
// 		}
// 	}
// }

function OnGameEvent_arena_round_start(params) {
	::Deathrun.RoundStart();
}

function OnGameEvent_player_death(params) {
	::Deathrun.PlayerDeath(params);
}

__CollectGameEventCallbacks(this);