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

self.ConnectOutput("OnStartTouch", "Output_OnStartTouch");
self.ConnectOutput("OnEndTouch", "Output_OnEndTouch");

function GetTeamNum() {
	return NetProps.GetPropInt(self, "m_iTeamNum");
}

function Output_OnStartTouch() {
	if (activator instanceof CTFPlayer && activator.GetTeam() == GetTeamNum()) {
		touching.append(activator);

		// start thinking
		if (self.GetScriptThinkFunc() == "") {
			AddThinkToEnt(self, "Think");
		}
	}
}

function Output_OnEndTouch() {
	// remove player from touch list
	if (activator != null && activator instanceof CTFPlayer && activator.GetTeam() == GetTeamNum()) {
		local index = touching.find(activator);
		if (index != null) {
			touching.remove(index);
		}
	}
	// if player is null (disconnected), filter invalid players
	else if (activator == null) {
		touching = touching.filter(function(index, player) {
			return player.IsValid();
		})
	}

	// stop thinking when empty
	if (touching.len() == 0) {
		AddThinkToEnt(self, null);
	}
}

function Think() {
	local team_players = GetPlayers({
		team = GetTeamNum(),
		alive = true
	});

	// all players inside
	if (team_players.len() <= touching.len()) {
		AddThinkToEnt(self, null);
		self.AcceptInput("Disable", null, null, null);

		if (team_players.len() > 0) {
			self.AcceptInput("FireUser1", null, null, null);
		}
	}
}
