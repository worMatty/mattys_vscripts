team_blue <- Constants.ETFTeam.TF_TEAM_BLUE;
round_state_win <- Constants.ERoundState.GR_STATE_TEAM_WIN;
maxclients <- MaxClients();

local members = [];
local enabled = false;
local peak_health = 0.0;
local bar = Entities.FindByClassname(null, "monster_resource");

enum BarColor {
    Blue,
    Green
}


// Main Functions
// --------------------------------------------------------------------------------

function StartBlueBossBar()
{
    ClearMembers();
    PopulateWithBlues();
    EnableBar();
}

function BossBar_Tick()
{
    // Stop if disabled
    if (!enabled)
    {
        return;
    }

    // Disable and stop if bar not found
    if (!BarUseable())
    {
        DisableBar();
        return;
    }

    // Disable and hide on round win
    if (GetRoundState() == round_state_win)
    {
        DisableBar();
        HideBar();
        return;
    }

    local health = GetCombinedHealthValues();
    local current_health = health[0];
    local max_health = health[1];

    // Account for overheal
    if (current_health > max_health)
    {
        max_health = current_health;
    }

    // Set peak
    if (max_health > peak_health)
    {
        peak_health = max_health;
    }

    UpdateBar(current_health, peak_health);
}


// Array Members
// --------------------------------------------------------------------------------

function AddMember(member)
{
    members.push(member);
}

function RemoveMember(member)
{
    members.remove(member);
}

function ClearMembers()
{
    members.clear();
}

function PopulateWithBlues()
{
    for (local i = 1; i <= maxclients; i++)
    {
        local player = PlayerInstanceFromIndex(i);

        if (player != null && player.GetTeam() == team_blue)
        {
            members.push(player);
        }
    }
}

function GetCombinedHealthValues()
{
    local current_health = 0.0;
    local max_health = 0.0;

    foreach (member in members)
    {
        if (!member.IsValid())
        {
            members.remove(member);
            continue;
        }

        current_health += IsPlayerAlive(member) ? member.GetHealth() : 0;
        max_health += member.GetMaxHealth();
    }

    return [current_health, max_health];
}


// Bar Control
// --------------------------------------------------------------------------------

function EnableBar()
{
    enabled = true;
    // Enable tick function
}

function DisableBar()
{
    enabled = false;
    // Disable tick function
}

function HideBar()
{
    SetBarValue(0);
}

function BarUseable()
{
    return (bar != null && bar.IsValid);
}

function UpdateBar(current_health, peak_health)
{
    local value = ((current_health / peak_health) * 255).tointeger();
    SetBarValue(value);
}

function SetBarValue(value)
{
    value = Clamp(value, 0, 255);

    if (bar)
    {
        NetProps.SetPropInt(bar, "m_iBossHealthPercentageByte", value);
    }
}

function SetBarColor(color = BarColor.Blue)
{
    if (bar)
    {
        NetProps.SetPropInt(bar, "m_iBossState", color);
    }
}

function ResetPeakHealth()
{
    peak_health = 0.0;
}


// Misc Helpers
// --------------------------------------------------------------------------------

function Clamp(value, min, max)
{
    if (value <= min)
    {
		value = min;
    }
	else if (value >= max)
    {
		value = max;
    }

    return value;
}


/**
 * Checks if a player is alive
 *
 * @param {player} player - Handle to the player
 * @returns {bool} - True if the player is alive, false otherwise
*/
function IsPlayerAlive(player)
{
	return NetProps.GetPropInt(player, "m_lifeState") == 0;
}