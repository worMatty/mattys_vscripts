
IncludeScript("matty/stocks.nut");

damage_backstab <- Constants.ETFDmgCustom.TF_DMG_CUSTOM_BACKSTAB;

/**
 * To do
 *
 * See if blues have melee only and store it
 * See if reds...
 *
 * Give more health to blue if they only have melee?
 */

// Functions
// --------------------------------------------------------------------------------

function ScaleBlueHealth()
{
	// Get number of live reds
	local number_live_reds = GetTeamPlayers(TF_TEAM_RED, true).len();

	// Put live blues into an array
	local live_blues = GetTeamPlayers(TF_TEAM_BLUE, true);
	local number_live_blues = live_blues.len();

	// Stop if live blues >= live reds or there are no live blues
	if (number_live_blues >= number_live_reds || !number_live_blues)
	{
		return;
	}

	// Calculate new max health for each blue player and apply it
	foreach (player in live_blues)
	{
		local health = GetTFClassHealth(player.GetPlayerClass()).tofloat();

		health = (((number_live_reds * 2) * health) - health);
		health /= number_live_blues;

		player.AddCustomAttribute("max health additive bonus", health - GetTFClassHealth(player.GetPlayerClass()), -1);
		player.SetHealth(health.tointeger());
		player.AddCustomAttribute("health from packs decreased", GetTFClassHealth(player.GetPlayerClass()) / health, -1);

		// local message = format("\x07%X%s \x01now has \x05%d \x01health", chat_color_blue, NetProps.GetPropString(player, "m_szNetname"), health.tointeger());
		local message = format("%s now has \x05%d \x01health", player.ColoredName(), health.tointeger());
		ClientPrint(null, Constants.EHudNotify.HUD_PRINTTALK, message);
	}
}


// Event hooks
// --------------------------------------------------------------------------------

CleanGameEventCallbacks();

function OnScriptHook_OnTakeDamage(params)
{
	if (params.const_entity.IsPlayer()
		&& params.const_entity.GetTeam() == TF_TEAM_BLUE
		&& params.damage_custom == damage_backstab)
	{
		params.damage = 100;	// backstabs always crit, which multiplies this to 300
	}
}

__CollectGameEventCallbacks(this);

