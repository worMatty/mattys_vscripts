/*

Tasks
Enable the HUD
	It is working in my non-arena map
Look at convars

*/

/*
Quirks tested in Arena mode
sm_slay doesn't work on players in karts
*/

sounds <- [
	"BumperCar.Bump"
	"BumperCar.SpeedBoostStart"
	"BumperCar.SpeedBoostStop"
	"BumperCar.BumpIntoAir"
	"BumperCar.BumpHard"
	"BumperCar.Jump"
	"BumperCar.JumpLand"
];

models <- [
	"models/player/items/taunts/bumpercar/parts/bumpercar.mdl"
	"models/player/items/taunts/bumpercar/parts/bumpercar_nolights.mdl"
	"models/props_halloween/bumpercar_cage.mdl"
]

// store constants in root
if (!("TF_COND_HALLOWEEN_KART" in getroottable())) {
	foreach(k, v in Constants.ETFCond)
	if (v == null) {
		ROOT[k] <- 0;
	} else {
		ROOT[k] <- v;
	}
}

function Precache() {
	foreach(sound in sounds) {
		PrecacheScriptSound(sound);
		// printl(__FILE__ + " -- Precaching " + sound + ". Found: " + PrecacheScriptSound(sound));
	}

	foreach(model in models) {
		PrecacheModel(model);
		// printl(__FILE__ + " -- Precaching " + model + ". Index: " + PrecacheModel(model));
	}
}

checkpoints <- [];

function OnPostSpawn() {
	// get checkpoints
	foreach(checkpoint in EntityGroup) {
		if (checkpoint.IsValid()) {
			// local OnTouch = function() {
			// 	SetCheckpoint();
			// }

			checkpoint.ConnectOutput("OnStartTouch", SetCheckpoint);

			local array = checkpoints.append(checkpoint);
			printl(__FILE__ + " -- added checkpoint " + checkpoint + " in position " + array.len() - 1);
		}
	}
}

function GrantCar(player, hold_time) {
	player.SetAbsVelocity(Vector());
	player.RemoveCond(TF_COND_TAUNTING); // why?
	player.AddCond(TF_COND_HALLOWEEN_KART);
	if (hold_time >= 0) {
		player.AddCondEx(TF_COND_HALLOWEEN_KART_CAGE, hold_time, null); // requires cage model to be precached
	}
}

function RemoveCar(player) {
	player.RemoveCond(TF_COND_HALLOWEEN_KART);
	player.RemoveCond(TF_COND_HALLOWEEN_KART_CAGE);
}

function SetCheckpoint() {
	printl(__FILE__ + " -- SetCheckpoint called by activator " + activator + " via checkpoint " + caller);
	activator.ValidateScriptScope();
	activator.GetScriptScope().checkpoint <- {
		origin = activator.GetOrigin()
		angles = activator.EyeAngles()
	}
}

function TeleportToCheckpoint() {
	local checkpoint = activator.GetScriptScope().checkpoint;
	activator.Teleport(true, checkpoint.origin, true, checkpoint.angles, false, Vector());
}

function OutOfBounds() {
	if (activator == null || !(activator instanceof CTFPlayer)) {
		printl(__FILE__ + " non-player entity triggered Out of Bounds function: " + activator);
		return;
	}

	TeleportToCheckpoint();
}

// grant cond to all players, stop them moving, hold them in place for x seconds
function StartRace(hold_time = 10) {
	local players = GetPlayers();

	foreach(player in players) {
		GrantCar(player, hold_time);
	}
}

function StopRace() {
	local players = GetPlayers();

	foreach(player in players) {
		RemoveCar(player);
	}
}

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