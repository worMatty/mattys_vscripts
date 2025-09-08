
/*
	Basic karting script
	v0.1 by worMatty

	Provides the bare essentials for putting players in karts and taking them out.
	Precaches all sounds and models.

	Does not support anything like checkpoints or respawning.
*/

/*
	Note:
		This will likely be superceded at some point by a far better script.
		I'm working on something at the moment that I can split out later.
*/

IncludeScript("matty/stocks2.nut");

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

function Precache() {
	foreach(sound in sounds) {
		PrecacheScriptSound(sound);
	}

	foreach(model in models) {
		PrecacheModel(model);
	}
}

function StartRace(players, hold_time = 0) {
	if (typeof players != "array") {
		error(self + " -- Error: StartRace was not supplied with an array\n");
		return;
	} else if (players.len() == 0) {
		error(self + " -- Error: StartRace was provided with no players in its array\n");
		return;
	}

	foreach(player in players) {
		GrantCar(player);

		if (hold_time > 0) {
			player.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_DEFAULT);
			EntFireByHandle(player, "RunScriptCode", "self.SetMoveType(MOVETYPE_WALK, MOVECOLLIDE_DEFAULT)", hold_time, null, null);
			player.AddCondEx(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED, hold_time, null);
		}
	}
}

function QuitRace() {
	local players = GetPlayers();

	foreach(player in players) {
		if (player.InCond(TF_COND_HALLOWEEN_KART)) {
			RemoveCar(player);
		}
	}
}

function GrantCar(player = null) {
	if (player == null) {
		player = activator;
	}

	player.SetAbsVelocity(Vector());
	player.RemoveCond(TF_COND_TAUNTING); // why?
	player.AddCond(TF_COND_HALLOWEEN_KART);
}

function RemoveCar(player) {
	if (player == null) {
		player = activator;
	}

	player.RemoveCond(TF_COND_HALLOWEEN_KART);
}
