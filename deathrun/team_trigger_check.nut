/*
	Team Trigger Check - v0.1 by worMatty
	Do something when all live players on the associated team are inside a trigger

	Usage
		1. Create a trigger_multiple and add this script to its Entity Scripts field
		2. Turn off SmartEdit and add the TeamNum property with your team's integer as the value. e.g. 2 for red, 3 for blue
		3. Add the outputs you wish to fire as OnUser1

	The trigger will start to check when the first player touches it, and will stop checking when the last player leaves it.
	While checking, it will compare the number of live players on the associated team with the number inside its volume.
	When all live players are within the volume, it fires its OnUser1 outputs and calls Disable on itself.
	This also stops the checking.
*/

IncludeScript("matty/stocks2.nut");
local touching = [];
self.ConnectOutput("OnStartTouch", "OnStartTouch");
self.ConnectOutput("OnEndTouch", "OnEndTouch");

function GetTriggerTeam() return NetProps.GetPropInt(self, "m_iTeamNum");
function OnStartTouch() {
	if (activator instanceof CTFPlayer && activator.GetTeam() == GetTriggerTeam()) {
		touching.append(activator);
		if (self.GetScriptThinkFunc() == "") AddThinkToEnt(self, "Think"); // start think
	}
}
function OnEndTouch() {
	// remove player from touch list
	if (activator && activator instanceof CTFPlayer && activator.GetTeam() == GetTriggerTeam()) {
		local index = touching.find(activator);
		if (index != null) touching.remove(index);
	}
	// filter out disconnected players
	else if (!activator) touching = touching.filter(function(index, player) {
		return player.IsValid();
	})
	if (!touching.len()) AddThinkToEnt(self, null); // stop thinking when empty
}

function Think() {
	local num_live_teammates = GetPlayers({
		team = GetTriggerTeam(),
		alive = true
	}).len();

	// all players inside
	if (num_live_teammates <= touching.len()) {
		AddThinkToEnt(self, null);
		self.AcceptInput("Disable", null, null, null);
		if (num_live_teammates > 0) self.AcceptInput("FireUser1", null, null, null); // fire outputs if there are teammates inside
	}
}