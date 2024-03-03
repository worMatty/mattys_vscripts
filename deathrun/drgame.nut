/*
1. Activator selection
2. Anti-team swapping
3. Weapon restriction
4. Environment settings
*/

IncludeScript("matty/stocks2.nut");

// Constants
enum  {
    kActivator
    kRunner
};

// Activator selection
// --------------------------------------------------------------------------------

function SelectRandomRed() {
	local reds = Players().Team(TF_TEAM_RED).Shuffle().Array();
	if (reds.len()) {
		return reds[0];
	} else {
		return null;
	}
}

function SelectActivator() {
    local player = SelectRandomReds();
    if (player != null) {

    }
}

function SortTeams() {
    local players = Players().Shuffle().Array();
    local activator = players.remove(0);
    player.SwitchTeamSilently(TF_TEAM_BLUE);
    player.drflags.role = kActivator;

    foreach (player in players) {
        player.SwitchTeamSilently(TF_TEAM_RED);
        player.drflags.role = kRunner;
    }
}

function OnGameEvent_player_connect_client(params) {
    local player = GetPlayerFromUserID(params.userid);
    if (player != null && player.IsValid()) {
        player.ValidateScriptScope();
        player.GetScriptScope().drflags <- {
            role = kNone
            qp = 0
            lastact = 0
        };
        player.drflags <- player.GetScriptScope().drflags;
    }
}

function OnPostSpawn() {
    SetConVars();
    __CollectGameEventCallbacks(self);
}

// Anti-team swapping
// --------------------------------------------------------------------------------

// Weapon restriction
// --------------------------------------------------------------------------------

// Environment settings
// --------------------------------------------------------------------------------

function SetConVars() {
    local convars = [
        "mp_autoteambalance"
        "mp_scrambleteams_auto"
        "tf_arena_use_queue"
        "tf_arena_first_blood"
    ]

    foreach (convar in convars) {
        if (Assert(IsConVarOnAllowList(convar)), __FILE__ + " -- convar needs to be on the server whitelist for deathrun to function: " + convar);
        SetValue(convar, "0");
    }
}