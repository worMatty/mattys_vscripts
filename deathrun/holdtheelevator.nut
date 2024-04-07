/**
 * Hold the elevator! v0.1
 * Hold an elevator until all red players are in the trigger or a timer finishes.
 */

/*
	Usage
		Create a trigger_multiple and add this script to its Entity Scripts field

		Using a logic_relay's OnSpawn output or something else, send the trigger the following input:
			RunScriptCode > SetElevator(`targetname`)
		`targetname` is the targetname of your func_tracktrain or other entity you wish to start moving.
		By default the script is set up to send SetSpeed 1.0.
		You can set your own input and parameter like so:
			RunScriptCode > SetElevator(`targetname`, `SetSpeed`, 0.5)

		Add the following output to the trigger:
			OnStartTouch > !self > CallScriptFunction > StartChecking > 0 > 1
		Note the refire time has been set to 1 so this only gets called once.

		The script will regularly check if all live reds are inside the trigger.
		If they are, it will start the elevator.

		It has a built-in timer with a default value of 20.0 seconds.
		When the timer expires after activation, it will start the elevator regardless.
		If you wish to change the timer time, send the following input on spawn:
			RunScriptCode > timer_duration = 30.0
		Replace 30.0 with your own time.

	Extra functions
		If you wish to stop checking at any time, send the following input:
			CallScriptFunction > StopChecking
*/

local red_team = Constants.ETFTeam.TF_TEAM_RED;
local maxclients = MaxClients().tointeger();

think_rate <- 0.5;
timer_duration <- 20.0;
kill_self_on_move <- true;

local touching = [];
local trigger_ent = self;
local trigger_targetname = (self.GetName() != "") ? self.GetName() : ("elevator_controller_" + self.entindex());
local timer = null;
local elevator = null; // Elevator entity reference
local elevator_input = null; // Input to use on elevator. Defaults to StartForward
local elevator_input_parm = null; // Input parameter to use on elevator along with input. e.g. 0.5

self.ConnectOutput("OnStartTouch", "Output_OnStartTouch");
self.ConnectOutput("OnEndTouch", "Output_OnEndTouch");

/**
 * When a red player triggers the trigger, add them to the touching list
 */
function Output_OnStartTouch() {
	if (activator instanceof CTFPlayer && activator.GetTeam() == red_team) {
		touching.append(activator);
	}
}

/**
 * When a red player leaves the trigger, remove them from the touching list.
 * If the player disconnected, check the touching list and filter out any invalid handles
 */
function Output_OnEndTouch() {
	if (activator != null && activator instanceof CTFPlayer && activator.GetTeam() == red_team) {
		local index = touching.find(activator);
		if (index != null) {
			touching.remove(index);
		}
	}

	// remove references to disconnected players
	else if (activator == null) {
		touching = touching.filter(function(index, player) {
			return player.IsValid();
		})
	}
}

/**
 * Check the number of live red players against the number of players
 * touching the trigger. Start the elevator if it's the same or
 * stop checking if all reds are dead.
 */
function CheckPlayers() {
	local red_players = GetAliveRedPlayers();

	// all reds dead
	if (red_players.len() == 0) {
		StopChecking();
	}

	// all reds in
	else if (red_players.len() <= touching.len()) {
		StopChecking();
		StartElevator();
	}

	return think_rate;
}

/**
 * Get all live red players
 * @return {array} Array of live red player instances
 */
function GetAliveRedPlayers() {
	local players = [];

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);
		if (player != null && player.GetTeam() == red_team && NetProps.GetPropInt(player, "m_lifeState") == 0) {
			players.append(player);
		}
	}

	return players;
}

/**
 * Create a logic_timer to start the elevator after a duration regardless if players are inside
 */
StartTimer <-  function() {
	timer = SpawnEntityFromTable("logic_timer", {
		RefireTime = timer_duration
		StartDisabled = false
		"OnTimer#1": format("%s,CallScriptFunction,StopChecking,-1,1", trigger_targetname)
		"OnTimer#2": format("%s,CallScriptFunction,StartElevator,-1,1", trigger_targetname)
	});
}

/**
 * Kill the timer
 */
KillTimer <-  function() {
	if (timer.IsValid()) {
		EntFireByHandle(timer, "Kill", null, -1, null, null);
	}
}

/**
 * Add the think function to check players
 */
function StartChecking() {
	if (trigger_ent.GetScriptThinkFunc() != "") {
		printl(__FILE__ + " -- StartChecking -- Already checking. Ignoring call to start checking again");
		return;
	}

	StartTimer();
	AddThinkToEnt(trigger_ent, "CheckPlayers");
	CheckPlayers();
}

/**
 * Stop the think function
 */
function StopChecking() {
	NetProps.SetPropString(trigger_ent, "m_iszScriptThinkFunction", "");
	KillTimer();
}

/**
 * Set the elevator targetname to use
 * Optionally set the input and parameter. Defaults to SetSpeed 1.0
 * @param {string} targetname Elevator targetname
 * @param {string} input Input name. e.g. SetSpeedReal
 * @param {any} input_parm Int, float or string. e.g. 100.0. Is converted to a string for the input
 */
function SetElevator(targetname, input = "SetSpeed", input_parm = 1.0) {
	elevator = Entities.FindByName(null, targetname);
	elevator_input = input;
	elevator_input_parm = input_parm.tostring();
	printl(__FILE__ + " -- SetElevator -- Entity:" + elevator);
}

/**
 * Start the elevator moving
 */
function StartElevator() {
	StopChecking();
	EntFireByHandle(elevator, elevator_input, elevator_input_parm, -1, null, null);
}