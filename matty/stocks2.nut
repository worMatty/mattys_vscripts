/*
	Matty's Stocks 2

	A bunch of commonly-used functions to include in other scripts
	Superceding the old stocks file
	Work-in-progress

	Thanks ficool2 for all you've done for us
*/

IncludeScript("matty/stocks/globals.nut");	// global functions and constants


// Helpers
// --------------------------------------------------------------------------------

/**
 * Return standard max health for the given TF2 class
 * @param {integer} tfclass Class integer
 * @return {integer} Max health amount
 */
function GetTFClassHealth(tfclass) {
	local health = [
		50, // None
		125, // Scout
		125, // Sniper
		200, // Soldier
		175, // Demoman
		150, // Medic
		300, // Heavy
		175, // Pyro
		125, // Spy
		125 // Engineer
	];

	return health[tfclass];
}


// Events
// --------------------------------------------------------------------------------

CleanGameEventCallbacks();

// stop sounds just before round restart
function OnGameEvent_scorestats_accumulated_update(params) {
	local soundlist = ::matty.sounds;

	printl("Stopping " + soundlist.len() + " sounds");

	foreach(sound in soundlist) {
		sound.flags <- SND_STOP;
		EmitSoundEx(sound);
	};

	soundlist = [];
}

__CollectGameEventCallbacks(this);