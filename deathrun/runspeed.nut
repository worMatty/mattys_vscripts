/*
	Set class run speed
	v0.2 by worMatty

	Usage:
		Add the script to a logic_script entity. It does not need a targetname.

		When you want to set a player's speed to a specific number in units per second, perform this input on them:
			OnTrigger > !activator > RunScriptCode > self.SetRunSpeed(100)

		If you want to set a player's speed to a percentage of their usual run speed, do this
			OnTrigger > !activator > RunScriptCode > self.PercentRunSpeed(0.5)

		To reset the player's run speed, do this
			OnTrigger > !activator > RunScriptCode > self.ResetRunSpeed()

		To apply a run speed to players matching specific criteria, e.g. those on the red team, do this:
			OnTrigger > player > RunScriptCode > if (self.GetTeam() == Constants.ETFTeam.TF_TEAM_RED) self.SetRunSpeed(100)

	Notes:
		* Run speed changes use attributes so they reset when the player spawns
		* The attribute used is "CARD: move speed bonus"
		* The attribute scales all player speed-altering actions, such as spinning up a weapon
*/

if ("GetClassRunSpeed" in ::CTFPlayer) {
	return;
}

/**
 * Get a class's default run speed
 * @param {int} tfclass Class int
 */
::CTFPlayer.GetClassRunSpeed <- function(tfclass) {
	local run_speeds = [
		0, // no class
		400, // scout
		300, // sniper
		240, // soldier
		280, // demoman
		320, // medic
		230, // heavy
		300, // pyro
		320, // spy
		300 // engineer
	];

	return run_speeds[tfclass];
}

/**
 * Set a player's run speed
 * @param {float} runspeed Desired run speed in u/s
 */
::CTFPlayer.SetRunSpeed <- function(runspeed) {
	local class_speed = GetClassRunSpeed(this.GetPlayerClass()).tofloat();
	this.AddCustomAttribute("CARD: move speed bonus", runspeed / class_speed, -1);
}

/**
 * Reset a player's altered run speed by removing the attrib
 * @param {CTFPlayer} player Player instance
 */
::CTFPlayer.ResetRunSpeed <- function() {
	this.RemoveCustomAttribute("CARD: move speed bonus");
}

/**
 * Set a player's run speed to some percentage of their class run speed
 * Requires a decimal representation of percent. e.g. 0.5 for 50%.
 * @param {CTFPlayer} player Player instance
 * @param {float} percent Percent to multiply class run speed by
 */
::CTFPlayer.PercentRunSpeed <- function(percent) {
	local class_speed = GetClassRunSpeed(this.GetPlayerClass()).tofloat();
	this.AddCustomAttribute("CARD: move speed bonus", percent, -1);
}