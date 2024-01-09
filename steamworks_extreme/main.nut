/*
	Steamworks Extreme
	Main VScript file

	Attach to a logic_script
	Designed to be reloaded on round restart

	Old version
*/

IncludeScript("matty/stocks.nut");


// Constants
// --------------------------------------------------------------------------------

enum CourseMode {
	Unselected,
	Manual,
	Auto
}

phrase_lhc_notify <- "Hit this button to take the\nLow Health Challenge!";

roundstate_stalemate <- Constants.ERoundState.GR_STATE_STALEMATE;


// Variables
// --------------------------------------------------------------------------------

local course_active = false;		// Deathrun course is being played - not endings
local ending_active = false;		// An ending is being played
local course_mode = 0;				// Manual or auto mode (1 or 2)


// Test stuff
// --------------------------------------------------------------------------------



// State checks
// --------------------------------------------------------------------------------

::Deathrun_IsCourseActive <- function()
{
	return (GetRoundState() == roundstate_stalemate
		&& course_active == true);
}

::Deathrun_IsEndingActive <- function()
{
	return (GetRoundState() == roundstate_stalemate
		&& ending_active == true);
}

::Deathrun_IsAutoMode <- function()
{
	return (course_mode == CourseMode.Auto);
}

::Deathrun_CourseMode <- function()
{
	return course_mode;
}

::Deathrun_SetCourseMode <- function(mode)
{
	course_mode = mode;
}


// Custom events/forwards
// --------------------------------------------------------------------------------

::Deathrun_CourseEnded <- function()
{
	course_active = false;
	EntFire("relay_course_stop", "Trigger");
}

::Deathrun_EndingChosen <- function()
{
	ending_active = true;
}

// Player
// --------------------------------------------------------------------------------

function ToggleLowHealthChallenge()
{
	if (activator.GetScriptScope().round_flags["lhc"] == false)
	{
		SetLowHealthChallenge(activator, true);
		PrintToChat(activator, "You have accepted the low health challenge. Good luck!");
	}
	else
	{
		SetLowHealthChallenge(activator, false);
		PrintToChat(activator, "You are no longer on the low health challenge");
	}
}

function SetLowHealthChallenge(player, set)
{
	if (set)
	{
		player.GetScriptScope().round_flags["lhc"] = true;
		player.SetHealth(50);

		for (local i = 0; i < 7; i++)
		{
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i);

			if (weapon == null || !weapon.IsValid())
			{
				continue;
			}

			weapon.AddAttribute("healing received penalty", 0.0, -1);
		}

		printl(player.Name() + " is now on the low health challenge");
	}
	else if (set == false)
	{
		player.GetScriptScope().round_flags["lhc"] = false;
		player.SetHealth(player.GetMaxHealth());

		for (local i = 0; i < 7; i++)
		{
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i);

			if (weapon == null || !weapon.IsValid())
			{
				continue;
			}

			weapon.RemoveAttribute("healing received penalty");
		}
		// Maybe regeneration would be better?

		printl(player.Name() + " is no longer on the low health challenge");
	}
}

function ClearLowHealthChallenge()
{
	for (local i = 1; i <= MaxClients(); i++)
	{
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.IsValid())
		{
			if (player.GetScriptScope().round_flags["lhc"] == true)
			{
				SetLowHealthChallenge(player, false);
			}
		}
	}
}

function PlayerReachedEnd()
{
	if (Deathrun_IsCourseActive() && activator.GetScriptScope().round_flags["reached_end"] == false)
	{
		activator.GetScriptScope().round_flags["reached_end"] = true;

		if (activator.GetScriptScope().round_flags["lhc"] == true)
		{
			PrintToChatAll(activator.ColredName() + " finished while on the Low Health Challenge!");
		}
		else
		{
			PrintToChatAll(activator.ColoredName() + " reached the end of the course!");
		}

		DisplayRoundTimeElapsed();
	}
}

function DisplayRoundTimeElapsed(timer_name = "round_timer")
{
	local timer = Entities.FindByName(null, timer_name);

	if (timer != null)
	{
		local time_remaining = NetProps.GetPropFloat(timer, "m_flTimeRemaining") + 1;
		local end_time = NetProps.GetPropFloat(timer, "m_flTimerEndTime");
		local time = Time();
		local time_elapsed = time_remaining - (end_time - time);
		local minutes = abs(time_elapsed / 60);
		local seconds = abs(time_elapsed % 60);

		PrintToChat(activator, format("Your time was %d:%d", minutes, seconds));
	}
}


// Player flags
// --------------------------------------------------------------------------------

/**
 * Resets round flags to their starting values and undoes any property changes
 *
 * @param {instance} player - Player instance
 * @noreturn
 */
function ResetRoundFlags(player)
{
	local round_flags = {
		lhc = false,
		reached_end = false
	};

	// First-time user
	if (!("round_flags" in player.GetScriptScope()))
	{
		player.GetScriptScope().round_flags <- round_flags;
		return;
	}

	if (player.GetScriptScope().round_flags["lhc"] == true)
	{
		SetLowHealthChallenge(player, false);
	}

	// Replace the table with default values
	player.GetScriptScope().round_flags <- round_flags;
}


// Hooks
// --------------------------------------------------------------------------------

/**
 * Remove orphaned hooks from the game event tables
 */
CleanGameEventCallbacks();

/**
 * Reset player round flags on round restart
 */
function OnPostSpawn()
{
	// Reset player round flags
	for (local i = 1; i <= MaxClients(); i++)
	{
		local player = PlayerInstanceFromIndex(i);

		if (player != null)
		{
			ResetRoundFlags(player);
		}
	}
}

/**
 * Set up a player's script scope and round flags when they first spawn
 */
function OnGameEvent_player_initial_spawn(params)
{
	local player = PlayerInstanceFromIndex(params.index);

	if (player != null)
	{
		player.ValidateScriptScope();
		ResetRoundFlags(player);
	}
}

/**
 * When a player dies, take them off the Low health Challenge
 */
function OnGameEvent_player_death(params)
{
	local player = GetPlayerFromUserID(params.userid);

	// Turn off LHC challenge on death
	if (player != null && player.GetScriptScope().round_flags["lhc"] == true)
	{
		SetLowHealthChallenge(player, false);
	}
}

/**
 * When the Arena round starts and is 'valid', start course logic
 */
function OnGameEvent_arena_round_start(params)
{
	// If round is valid and active
	if ( GetTeamPlayers(TF_TEAM_RED).len() && GetTeamPlayers(TF_TEAM_BLUE).len() )	// Both teams have players
	{
		course_active = true;
		EntFire("relay_round_start", "Trigger");	// Start course logic
	}
}

/**
 * When the round is won while the course is active, end the course
 */
// function OnGameEvent_teamplay_round_win(params)
// {
// 	// End course if active on round win
// 	if ( course_active == true )
// 	{
// 		Deathrun_CourseEnded();
// 	}
// }

__CollectGameEventCallbacks(this);