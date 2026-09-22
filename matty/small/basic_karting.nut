/*
	Basic karting script
	v0.1 by worMatty

	Provides the bare essentials for putting players in karts and taking them out.
	Precaches all sounds and models.
	Does not support anything like checkpoints or respawning.

	Usage:
		Add the script to a logic_script.
		Make players racers by calling StartRace and supplying an array of players in the first argument.
		If you're not scripting and simply wish to make all live reds or live players karters
		in a Hammer input, you can send one of these inputs to the logic_script:
			RunScriptCode > StartRace(LiveReds())
			RunScriptCode > StartRace(LivePlayers())
		Quick arrays of players is made possible by stocks2.nut which this script depends on.
		If at the start of the race you wish to freeze the players in place for a certain amount of time
		you can specify the delay in the second argument:
			RunScriptCode > StartRace(LiveReds(), 5.0)
		To end the race prematurely, call QuitRace().
		To respawn a racer, call RespawnRacer(destination, player). Supply an entity instance or targetname for the first arg.
		The second arg is a player instance, or you can leave it blank to use the activator. For example to respawn the racer
		at an entity named `respawn_point01`, do:
			RunScriptCode > RespawnRacer(`respawn_point01`)
*/

/*
	Note:
		This will likely be superceded at some point by a far better script.
		I'm working on something at the moment that I can split out later.
*/

IncludeScript("matty/stocks2.nut");

local sounds = [
	"BumperCar.Bump"
	"BumperCar.SpeedBoostStart"
	"BumperCar.SpeedBoostStop"
	"BumperCar.BumpIntoAir"
	"BumperCar.BumpHard"
	"BumperCar.Jump"
	"BumperCar.JumpLand"
];

local models = [
	"models/player/items/taunts/bumpercar/parts/bumpercar.mdl"
	"models/player/items/taunts/bumpercar/parts/bumpercar_nolights.mdl"
	"models/props_halloween/bumpercar_cage.mdl"
]

function Precache() {
	foreach(sound in sounds) PrecacheScriptSound(sound);
	foreach(model in models) PrecacheModel(model);
}

/**
 * Turn players into racers and optionally hold them in place for a set time.
 * @param {array} players Array of CTFPlayer instances
 * @param {float} hold_time Time to hold players in place for
 */
function StartRace(players, hold_time = 0.0) {
	if (typeof players != "array") return error(__FILE__ + " Error: StartRace was not supplied with an array\n");
	if (!players.len()) return error(__FILE__ + " Error: StartRace was provided with no players in its array\n");

	foreach(player in players) {
		GrantCar(player);

		if (hold_time > 0.0) {
			player.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_DEFAULT); // freeze in place. can still build up speed
			EntFireByHandle(player, "RunScriptCode", "self.SetMoveType(MOVETYPE_WALK, MOVECOLLIDE_DEFAULT)", hold_time, null, null); // start moving after the delay
			player.AddCondEx(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED, hold_time, null); // make them immune to damage
		}
	}
}

/**
 * Iterate over all players and if they're in kart, remove it
 */
function QuitRace() {
	local players = GetPlayers();
	foreach(player in players) {
		if (player.InCond(TF_COND_HALLOWEEN_KART)) RemoveCar(player);
	}
}

/**
 * Put a player in a kart
 * @param {CTFPlayer} player Player instance, or if left blank will use the !activator
 */
function GrantCar(player = null) {
	if (!player) player = activator;
	player.SetAbsVelocity(Vector()); // reset velocity so they start still
	player.RemoveCond(TF_COND_TAUNTING); // remove any taunt as this interferes with the kart animation
	player.AddCond(TF_COND_HALLOWEEN_KART);
}

/**
 * Take a player out of their kart
 */
function RemoveCar(player) {
	if (!player) player = activator;
	player.RemoveCond(TF_COND_HALLOWEEN_KART);
}

/**
 * Remove a player's kart, teleport them to a given destination entity and give them back their kart.
 * It's necessary to temporarily remove the kart so the next time it's given it uses the player's new yaw.
 * @param {CBaseEntity} destination Entity instance, or string targetname of one or more destination entities. Supports wildcards
 * @param {CTFPlayer} player Player instance
 */
function RespawnRacer(destination, player = null) {
	if (!player) player = activator;
	RemoveCar(player);
	TeleportStuff(player, destination);
	GrantCar(player);
}