/**
 * Bumper Cars v0.1 by worMatty
 */

/*

Tasks
Enable the HUD
	It is working in my non-arena map
Look at convars
End race on finish or time limit
Replace trigger scriptscope function with AddOutput
Don't reset checkpoint when regranting car on respawn
Use movetype and uber instead of cage
Respawn function
Time
Leaderboard
Crash through obstacles like barrel props
Pickups
Can't set kart velocity on teleport. May need to set a netprop

Respawn bind
Respawn flashing
Respawn tempoary non-solidity
Respawn at destination?
Prevent people triggering checkpoints by going in reverse. Possible options:
* Have at least three checkpoints
* Build in reverse detection using path_tracks
* Respawn them at latest CP if they go through a wrong CP
* Deduct one from the player's checkpoint count each time they go back through a previous CP
  * Use this to complain they are going the wrong way
  * Add 1 to checkpoint count when they turn around and go through a proper next CP (what if they skip?)
  * Reset CP count to highest count when respawning
Exploits
* Can you get out of a cart?
* What happens if a player respawns while a race is active?
*/

/*
Quirks tested in Arena mode
sm_slay doesn't work on players in karts
The following buttons are confirmed to not be recorded/transmitted while in a kart:
IN_DUCK, IN_RELOAD, IN_LEFT, IN_RIGHT, IN_ALT1, IN_SPEED, IN_ATTACK3
*/

// Global vars
// --------------------------------------------------------------------------------

checkpoints <- [];
standings <- [];
race_start_time <- null;
laps <- null;

// Constants
// --------------------------------------------------------------------------------

sounds <- [
	"BumperCar.Bump"
	"BumperCar.SpeedBoostStart"
	"BumperCar.SpeedBoostStop"
	"BumperCar.BumpIntoAir"
	"BumperCar.BumpHard"
	"BumperCar.Jump"
	"BumperCar.JumpLand"
	// sounds used by this script:
	"BumperCar.Checkpoint"
	"BumperCar.Respawn"
	"BumperCar.Lap"
	"BumperCar.FinalLap"
	"BumperCar.Finished"
	"BumperCar.Win"
];

models <- [
		"models/player/items/taunts/bumpercar/parts/bumpercar.mdl"
		"models/player/items/taunts/bumpercar/parts/bumpercar_nolights.mdl"
		"models/props_halloween/bumpercar_cage.mdl"
	]

	// store all constants in root table
	::ROOT <- getroottable();
if (!("ConstantNamingConvention" in ROOT)) // make sure folding is only done once
{
	foreach(a, b in Constants)
	foreach(k, v in b)
	if (v == null)
		ROOT[k] <- 0;
	else
		ROOT[k] <- v;
}


// Initialization
// --------------------------------------------------------------------------------

function Precache() {
	foreach(sound in sounds) {
		PrecacheScriptSound(sound);
	}

	foreach(model in models) {
		PrecacheModel(model);
	}
}

function OnPostSpawn() {
	// get checkpoints
	foreach(checkpoint in EntityGroup) {
		if (checkpoint.IsValid()) {
			checkpoint.ValidateScriptScope();

			local scope = checkpoint.GetScriptScope();

			scope.script <- self;
			scope.silent <- checkpoint.GetName().tolower().find("silent") != null;
			scope.Check <-  function() {
				// ensure only players in a cart can trigger checkpoints
				// easier for debugging and prevents noclip abuse
				if (activator instanceof CTFPlayer && activator.InCond(TF_COND_HALLOWEEN_KART)) {
					script.GetScriptScope().CheckCheckpoint(activator, caller);
				}
			}
			checkpoint.ConnectOutput("OnStartTouch", "Check");
			checkpoints.append(checkpoint);
		}
	}

	// Assert("EntityGroup" in this, __FILE__ + " ERROR -- You did not add any checkpoints to the logic_script");
	// Assert(EntityGroup.len() < 0, __FILE__ + " ERROR -- You need at least two checkpoints");

	if (checkpoints.len() <= 2) {
		printl(__FILE__ + " -- Warning! Having only two checkpoints will allow players to race in reverse. I recommend having at least three")
	}
}

// Race control
// --------------------------------------------------------------------------------

function SetupRace(_laps = 3, hold_time = 0) {
	local players = GetPlayers();
	laps = (_laps < 1) ? 3 : _laps; // minimum one lap

	foreach(player in players) {
		player.ValidateScriptScope();
		player.GetScriptScope().race <- {
			checkpoint = {
				id = null
				origin = null
				angles = null
				respawn_ent = null
			}
			lap = 1
			times = []
			respawned = 0.0
		}

		GrantCar(player);
		SetCheckpoint(player, checkpoints[0]);
		EntFireByHandle(self, "RunScriptCode", "SetCheckpoint(activator, checkpoints[0]);", -1, player, null);

		// if (hold_time >= 0) {
		// 	player.AddCondEx(TF_COND_HALLOWEEN_KART_CAGE, hold_time, null); // requires cage model to be precached
		// }
		if (hold_time >= 0) {
			EntFireByHandle(player, "RunScriptCode", "self.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_DEFAULT)", -1, null, null);
			EntFireByHandle(player, "RunScriptCode", "self.SetMoveType(MOVETYPE_WALK, MOVECOLLIDE_DEFAULT)", hold_time, null, null);
			player.AddCondEx(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED, hold_time, null);
		}
	}
}

function StartRace() {
	race_start_time = Time();
	AddThinkToEnt(self, "Think");
}

function StopRace() {
	AddThinkToEnt(self, null);
}

function QuitRace() {
	local players = GetPlayers();

	foreach(player in players) {
		if (player.InCond(TF_COND_HALLOWEEN_KART)) {
			RemoveCar(player);
			delete player.GetScriptScope().race;
		}
	}
}


// Cars
// --------------------------------------------------------------------------------

function GrantCar(player) {
	player.SetAbsVelocity(Vector());
	player.RemoveCond(TF_COND_TAUNTING); // why?
	player.AddCond(TF_COND_HALLOWEEN_KART);
}

function RemoveCar(player) {
	player.RemoveCond(TF_COND_HALLOWEEN_KART);
	// player.RemoveCond(TF_COND_HALLOWEEN_KART_CAGE);
}


/**
 * Check for presses of Reload button
 */
function Think() {
	local players = GetPlayers();

	foreach(player in players) {
		if (NetProps.GetPropInt(player, "m_nButtons") & IN_ATTACK && player.InCond(TF_COND_HALLOWEEN_KART) && Time() > player.GetScriptScope().race.respawned + 3.0) {
			TeleportToCheckpoint(player);
		}
	}
}


// Checkpoints
// --------------------------------------------------------------------------------

/**
 * Check a checkpoint a player touched to see if the player should progress
 * @param {instance} player Player
 * @param {instance} checkpoint Checkpoint entity
 */
function CheckCheckpoint(player, checkpoint) {
	// get player's current lap
	local race = player.GetScriptScope().race;
	local lap = race.lap;

	if (checkpoint == GetNextCheckpoint(player)) {
		SetCheckpoint(player, checkpoint); // will not set a silent checkpoint as respawn point

		if (checkpoint.GetScriptScope().silent) {
			return;
		}

		if (lap > laps) {
			return;
		}

		// finish line
		if (checkpoints.find(checkpoint) == 0) {

			// finished
			if (lap == laps) {
				PlayerFinished(player);
			}

			// lap
			else {
				// penultimate
				if (lap == laps - 1) {
					UISound(player, "BumperCar.FinalLap");
					ClientPrint(player, HUD_PRINTCENTER, "Final Lap!");
				}
				// normal
				else {
					UISound(player, "BumperCar.Lap");
					ClientPrint(player, HUD_PRINTCENTER, "Lap " + (lap + 1));
				}

			}

			// increment lap and store time
			race.lap++;
			local time = Time() - race_start_time;
			foreach(val in race.times) {
				time -= val;
			}
			race.times.append(time);
			local t_time = SecondsToTime(time);

			if (race.times.len() > 1) {
				local best = time;

				foreach(val in race.times) {
					if (val > best) {
						best = val;
					}
				}

				local diff = time - best;
				local diff_string = "";
				local t_diff = SecondsToTime(diff);

				if (diff < 0) {
					diff_string = format("(\x07%X-%d:%.2f \x01BEST)", 0x00FF00, t_diff.minutes * -1, t_diff.seconds * -1);
				} else if (diff > 0) {
					diff_string = format("(\x07%X+%d:%.2f \x01BEST)", 0xFF0000, t_diff.minutes, t_diff.seconds);
				} else {
					diff_string = "(SAME AS YOUR BEST)"
				}

				ClientPrint(player, HUD_PRINTTALK, format("\x01LAP TIME: %d:%.2f %s", t_time.minutes, t_time.seconds, diff_string));
			} else {
				ClientPrint(player, HUD_PRINTTALK, format("LAP TIME: %d:%.2f", t_time.minutes, t_time.seconds));
			}

			printl(__FILE__ + " -- time: " + time + " Time(): " + Time() + " race_start_time: " + race_start_time);
			DumpObject(t_time);

		}
		// any other checkpoint
		else {
			UISound(player, "BumperCar.Checkpoint");
			ClientPrint(player, HUD_PRINTCENTER, "Checkpoint!");
		}
	}
	// respawn players who are going in the wrong direction
	else if (checkpoint != checkpoints[race.checkpoint.id]) {
		TeleportToCheckpoint(player);
	}
}

function GetNextCheckpoint(player) {
	local current_id = player.GetScriptScope().race.checkpoint.id;

	// set first checkpoint if none
	if (current_id == null) {
		return checkpoints[0];
	}
	// already passed a checkpoint
	else {
		if (current_id == checkpoints.len() - 1) {
			return checkpoints[0];
		} else {
			return checkpoints[current_id + 1]
		}
	}
}

/**
 * Set a player's checkpoint
 * If a non-silent checkpoint, also sets respawn location
 * @param {instance} player Player
 * @param {instance} checkpoint Checkpoint entity instance
 */
function SetCheckpoint(player, checkpoint = null) {
	local cp_data = player.GetScriptScope().race.checkpoint;
	cp_data.id = GetCheckpointId(checkpoint)

	// respawn transform
	if (checkpoint.GetScriptScope().silent == false) {
		cp_data.respawn_ent = checkpoint;
		cp_data.origin = player.GetOrigin();
		cp_data.angles = player.EyeAngles();
	};
}

function GetCheckpointId(checkpoint) {
	if (checkpoint == null) {
		return null;
	}

	local index = checkpoints.find(checkpoint);
	return index;
}

function TeleportToCheckpoint(player) {
	local table = player.GetScriptScope().race.checkpoint;

	// remove the car, teleport the player and grant the car as a workaround to not being able
	// to set car yaw directly
	// todo: is there a way to set the car yaw directly?
	player.RemoveCond(TF_COND_HALLOWEEN_KART_DASH);
	RemoveCar(player);
	table.id = GetCheckpointId(table.respawn_ent);
	player.Teleport(true, table.origin, true, table.angles, true, Vector());
	GrantCar(player);
	EmitSoundEx({
		sound_name = "BumperCar.Respawn"
		channel = 6
		entity = player
	});
	player.GetScriptScope().race.respawned = Time();
	// local checkpoint_id = checkpoints.find(table.id);
	// SetCheckpoint(player, checkpoint_id);
}

function PlayerFinished(player) {
	local position = standings.append(player).len();

	switch (position) {
		case 1: {
			UISound(player, "BumperCar.Win");
			ClientPrint(player, HUD_PRINTCENTER, "You finished 1st!");
		}
		case 2: {
			ClientPrint(player, HUD_PRINTCENTER, "You finished 2nd!");
		}
		case 3: {
			ClientPrint(player, HUD_PRINTCENTER, "You finished 3rd!");
		}
		default: {
			if (position > 3) {
				ClientPrint(player, HUD_PRINTCENTER, format("You finished %dth", position));
			}

			local total_time = 0.0;
			local times = player.GetScriptScope().race.times;
			foreach(time in times) {
				total_time += time;
			}
			local t_time = SecondsToTime(total_time);
			ClientPrint(player, HUD_PRINTTALK, format("TRACK TIME: %d:%.2f", t_time.minutes, t_time.seconds));
			UISound(player, "BumperCar.Finished");
			// ClientPrint(player, HUD_PRINTTALK, format("Your time was ", position));
		}
	}
}


// Environment
// --------------------------------------------------------------------------------

function OutOfBounds() {
	// do not teleport players who aren't in a kart
	if (activator instanceof CTFPlayer && activator.InCond(TF_COND_HALLOWEEN_KART)) {
		TeleportToCheckpoint(activator);
	}
}


// Helpers
// --------------------------------------------------------------------------------

function GetPlayers(alive = true) {
	local players = [];
	local maxclients = MaxClients();

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);
		if (player != null && player.IsValid()) {
			if ((alive && IsAlive(player)) || !alive) {
				players.append(player);
			}
		}
	}

	return players;
}

function IsAlive(player) {
	return NetProps.GetPropInt(player, "m_lifeState") == 0;
}

function SecondsToTime(seconds) {
	return {
		minutes = abs(seconds / 60)
		seconds = seconds % 60
	};
}

/**
 * Play a BumperCar UI sound to a player
 * @param {instance} player Player instance
 * @param {string} sound Game sound name
 */
function UISound(player, sound) {
	EmitSoundEx({
		sound_name = sound
		entity = player
		filter = 4
	});
	EmitSoundEx({
		sound_name = sound
		entity = player
		filter = 4
	});
}