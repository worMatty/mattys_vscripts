/**
 * Matty's Deathrun Boss Bar
 * Version 0.1
 *
 * Features:
 * - Supports variable number of blues
 * - Remembers overhealed max health
 * - Colours bar green when all blues ubered
 * - Bar disables on round win
 * - Detects outside interference from plugins and disables itself
 *
 * How to use:
 * Add to a logic_script and input CallScriptFunction StartBlueBossBar to start using it.
 * Call DisableBar to hide it, and EnableBar to show it again.
 */

// Options
local auto_color    = true;     // auto colour the bar green when all blues are in uber condition

// Constants
team_blue           <- Constants.ETFTeam.TF_TEAM_BLUE;
round_state_win     <- Constants.ERoundState.GR_STATE_TEAM_WIN;
cond_uber           <- Constants.ETFCond.TF_COND_INVULNERABLE;

// Variables
local enabled       = false;
local bar_players   = [];
local peak_health   = 0.0;
local prev_bar_val  = 0;
local bar           = Entities.FindByClassname(null, "monster_resource");


/**
 * Inputtable functions
 * --------------------------------------------------------------------------------
 */

/**
 * Store all the blue players, display the health bar and monitor health.
 * You only need to call this once.
 * Calling it again will reset it.
 */
function StartBlueBossBar()
{
    if (!IsBarValid())
    {
        printl("Unable to start boss bar as the monster_resource is not present! Disabling");
        DisableBar();
        return;
    }

    peak_health = 0.0;
    bar_players = GetTeamPlayers(team_blue);

    EnableBar();
}

/**
 * Enable the bar. This is called internally and you do not need to call it
 * unless you hid the bar using DisableBar().
 */
function EnableBar()
{
    if (!enabled)
    {
        enabled = true;
        AddThinkToEnt(self, "Think");   // add the think
    }
}

/**
 * Hide the bar.
 * This is called internally when there is a problem or when the round ends.
 */
function DisableBar()
{
    if (enabled)
    {
        AddThinkToEnt(self, "");  // remove the think
        SetBarValue(0);
        enabled = false;
    }
}


/**
 * Think
 * --------------------------------------------------------------------------------
 */

function Think()
{
    // Disable on round win or if bar not valid
    if (GetRoundState() == round_state_win || !IsBarValid())
    {
        DisableBar();
        return;
    }

    local member_data = GetMembersData();
    local health = member_data[0];
    local max_health = member_data[1];
    local ubered = member_data[2];


    // Account for overheal
    if (health > max_health)
    {
        max_health = health;
    }

    // Set peak
    if (max_health > peak_health)
    {
        peak_health = max_health;
    }

    SetBarValue(health, peak_health);

    if (auto_color)
    {
        if (ubered)
        {
            SetBarColor(1);
        }
        else
        {
            SetBarColor(0);
        }
    }
}


/**
 * Array
 * --------------------------------------------------------------------------------
 */

 /**
  * Gets health and uber status from array players and returns an array of three values.
  * [0] = combined health (integer)
  * [1] = combined max health (integer)
  * [2] = all ubered (bool)
  *
  * @return {array} Array player health and uber status
  */
function GetMembersData()
{
    local health = 0;
    local max_health = 0;
    local ubered = true;

    foreach (player in bar_players)
    {
        // account for bar members who have since left
        // account for bar members who have switched team
        if (!player.IsValid() || player.GetTeam() != team_blue)
        {
            //bar_players.remove(player);   // does this skip an index?
            continue;
        }

        health += IsPlayerAlive(player) ? player.GetHealth() : 0;
        max_health += player.GetMaxHealth();

        if (!player.InCond(cond_uber))
        {
            ubered = false;
        }
    }

    return [health, max_health, ubered];
}


/**
 * Bar
 * --------------------------------------------------------------------------------
 */

function IsBarValid()
{
    return (bar != null && bar.IsValid());
}

/**
 * Sets the value of the monster_resource bar.
 *
 * @param {integer} val Health value
 * @param {integer} max Maximum health value
 */
function SetBarValue(val, max = 255)
{
    if (!IsBarValid())
    {
        DisableBar();
        return;
    }

    if (enabled && GetBarValue() != prev_bar_val)
    {
        printl(self + " Outside interference with monster_resource bar value detected. Disabling");
        DisableBar();
        return;
    }

    val = ((val.tofloat() / max) * 255).tointeger();
    val = Clamp(val, 0, 255);
    NetProps.SetPropInt(bar, "m_iBossHealthPercentageByte", val);
    prev_bar_val = val;
}

/**
 * Retrieves the bar value from the monster_resource netprop
 *
 * @return {integer} Bar value from 0-255
 */
function GetBarValue()
{
    return NetProps.GetPropInt(bar, "m_iBossHealthPercentageByte");
}

/**
 * Set the bar colour.
 * 0 = default blue, 1 = green.
 * Green is used in Merasmus when he hides and cannot be attacked.
 *
 * @param {integer} color 0 for blue, 1 for green
 */
function SetBarColor(color = 0)
{
    if (IsBarValid())
    {
        NetProps.SetPropInt(bar, "m_iBossState", color);
    }
}


/**
 * Helpers
 * --------------------------------------------------------------------------------
 */

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
 * Return an array of players on a team, optionally only those alive
 *
 * @param {number} team - Team number
 * @param {bool} alive - Only return alive players
 * @returns {array} - Array of player handles
*/
function GetTeamPlayers(team, alive = false)
{
	local players = [];
    local maxclients = MaxClients();

	for (local i = 1; i <= maxclients; i++)
	{
		local player = PlayerInstanceFromIndex(i);

		if (player == null) continue;

		if (player.GetTeam() == team)
		{
			if (alive == true && player.IsAlive())
			{
				players.push(player);
			}
			else if (alive == false)
			{
				players.push(player);
			}
		}
	}

	return players;
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