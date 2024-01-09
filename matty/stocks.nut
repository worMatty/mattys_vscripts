/*
	Matty's Stocks

	A bunch of commonly-used functions to include in other scripts
*/


// Constants
// --------------------------------------------------------------------------------

const chat_color_spec = 0xCCCCCC;
const chat_color_red = 0xFF3F3F;
const chat_color_blue = 0x99CCFF;

hud_chat <- Constants.EHudNotify.HUD_PRINTTALK;

::maxclients <- MaxClients();

// TEAM_UNASSIGNED				0
// TEAM_SPECTATOR				1
// TF_TEAM_PVE_DEFENDERS 		2
// TF_TEAM_RED 					2
// TF_TEAM_BLUE 				3
// TF_TEAM_PVE_INVADERS 		3
// TF_TEAM_COUNT 				4
// TF_TEAM_PVE_INVADERS_GIANTS 	4
// TEAM_ANY 					-2
// TEAM_INVALID 				-1
foreach (key, value in Constants.ETFTeam)
{
    getroottable()[key] <- value;
}


// Messages
// --------------------------------------------------------------------------------

/**
 * Print a message to a single player's chat
 *
 * @param {instance} player Player instance
 * @param {string} message The message to print to chat
 * @noreturn
 */
::PrintToChat <- function(player, message)
{
	ClientPrint(player, hud_chat, message);
}

/**
 * Print a message to a team
 *
 * @param {integer} team Team number
 * @param {string} message The message to display
 */
::PrintToChatTeam <- function(team, message)
{
	local players = GetTeamPlayers(team);

	foreach (player in players)
	{
		ClientPrint(player, hud_chat, message);
	}
}

::PrintToChatAll <- function(message)
{
	ClientPrint(null, hud_chat, message);
}

/**
 * Create a chat colour code string with the colour of the specified team.
 * Output looks like: "\x0799CCFF"
 *
 * @param {integer} team Team number
 * @return {string} Colour code string, or \x01 if team not recognised
 */
::GetTeamChatColorCode <- function(team)
{
	local color = "\x01";

	switch (team)
	{
		case TEAM_SPECTATOR:
		{
			color = format("\x07%X", chat_color_spec);
			break;
		}
		case TF_TEAM_RED:
		{
			color = format("\x07%X", chat_color_red);
			break;
		}
		case TF_TEAM_BLUE:
		{
			color = format("\x07%X", chat_color_blue);
			break;
		}
	}

	return color;
}

/**
 * Show a training annotation in the world above an entity
 *
 * @param {string} text - Message to display
 * @param {instance} entity - Instance of the entity to display above
 * @param {number} lifetime - Time the annotation is displayed for in seconds
 * @param {string} sound - Sound to play
 * @param {bool} show_distance - Display the distance from the annotation
 * @param {bool} show_effect - Display a small graphical effect on the annotation when it spawns
 * @param {number} id - Unique Id number of this annotation. Annotations using the same Id will replace it. Uses the entity index by default
 * @param {number} bitfield - A bit field of client indexes, used to control which players can see the annotation
 * @noreturn
*/
::ShowAnnotation <- function(text, entity, lifetime = 10, sound = "common/null.wav", show_distance = false, show_effect = false, id = 0, bitfield = 0)
{
	// Todo
	// Add a vertical offset

	if (!entity.IsValid())
	{
		printl("ShowAnnotation used with an invalid entity. Text: " + text);
		return;
	}

	entity = entity.GetEntityIndex();

	local params = {
		// worldPosX = 0,
		// worldPosY = 0,
		// worldPosZ = 0,
		// worldNormalX = 0,
		// worldNormalY = 0,
		// worldNormalZ = 0,
		id = (id == 0) ? entity : id,
		text = text,
		lifetime = lifetime,
		visibilityBitfield = bitfield,
		follow_entindex = entity,
		show_distance = show_distance,
		play_sound = sound,
		show_effect = show_effect
	}

	SendGlobalGameEvent("show_annotation", params);
	printl(format("Displayed a training annotation: ", text));
}

::TA_ToTeam <- function(team, text, entity, lifetime = 10, sound = "common/null.wav", show_distance = false, show_effect = false, id = 0)
{
	printl("TA_ToTeam called");
	ShowAnnotation(text, entity, lifetime, sound, show_distance, show_effect, id, CreateTAVisibilityBitField(GetTeamPlayers(team)));
}

::TA_ToPlayer <- function(player, text, entity, lifetime = 10, sound = "common/null.wav", show_distance = false, show_effect = false, id = 0)
{
	ShowAnnotation(text, entity, lifetime, sound, show_distance, show_effect, id, CreateTAVisibilityBitField([player]));
}

::CreateTAVisibilityBitField <- function(players)
{
	local field = 0;

	foreach (player in players)
	{
		field = field | 1 << player.GetEntityIndex();
	}

	return field;
}


// Helpers
// --------------------------------------------------------------------------------

/**
 * Return an array of players on a team, optionally only those alive
 *
 * @param {number} team - Team number
 * @param {bool} alive - Only return alive players
 * @returns {array} - Array of player handles
*/
::GetTeamPlayers <- function(team, alive = false)
{
	local players = [];

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
 * Randomise an array
 * @param {array} array Input array
 * @return {array} Input values in a different order
 */
function RandomiseArray(array) {
	local new_array = [];

	while (array.len() > 0) {
		local index = RandomInt(0, array.len() - 1);
		new_array.push(array[index]);
		array.remove(index); // note: remove() returns the value.
	}

	return new_array;
}


// Player
// --------------------------------------------------------------------------------

/**
 * Checks if a player is alive
 *
 * @returns {bool} - True if the player is alive, false otherwise
*/
::CTFPlayer.IsAlive <- function()
{
	return NetProps.GetPropInt(this, "m_lifeState") == 0;
}
::CTFBot.IsAlive <- CTFPlayer.IsAlive;

/**
 * Get a player's name
 *
 * @returns {string} - Player's name
 */
::CTFPlayer.Name <- function()
{
	return NetProps.GetPropString(this, "m_szNetname");
}
::CTFBot.Name <- CTFPlayer.Name;

/**
 * Get a player's name coloured to their team colour.
 * Returned string already includes \x01 reset colour code.
 *
 * @returns {string} Player's team-coloured name
 */
::CTFPlayer.ColoredName <- function()
{
	return format("%s%s\x01", GetTeamChatColorCode(this.GetTeam()), NetProps.GetPropString(this, "m_szNetname"));
}
::CTFBot.ColoredName <- CTFPlayer.ColoredName;

/**
 * Cause a player to just die
 *
 * @param {instance} player - Player
 * @noreturn
 */
::CTFPlayer.Die <- function(silently = true)
{
	if (!this.IsAlive())
	{
		printl(this + " is not alive");
		return;
	}

	if (silently == true)
	{
		NetProps.SetPropInt(this, "m_lifeState", 2);
	}

	printl(this + " has " + this.GetHealth() + " health");
	this.TakeDamage(this.GetHealth(), 0, this);
}
::CTFBot.Name <- CTFPlayer.Die;

/**
 * Return standard max health for the given TF2 class
 *
 * @param {number} tfclass - Class number
 * @returns {number} - Max health amount
*/
function GetTFClassHealth(tfclass)
{
	local health = [
		50,	 	// None
		125,	// Scout
		125,	// Sniper
		200,	// Soldier
		175,	// Demoman
		150,	// Medic
		300,	// Heavy
		175,	// Pyro
		125,	// Spy
		125	 	// Engineer
	];

	return health[tfclass];
}

function FizzlePlayer(player)
{
	// Cow Mangler
    player.TakeDamageCustom(null, player, null, Vector(0, 0, 0), player.GetOrigin(), player.GetHealth(), 0, Constants.ETFDmgCustom.TF_DMG_CUSTOM_PLASMA);
}

/*
Custom damage types
TF_DMG_CUSTOM_TAUNTATK_BARBARIAN_SWING (24) - Decapitate
TF_DMG_CUSTOM_GOLD_WRENCH (35) - Paralyze and play a gold hit sound
TF_DMG_CUSTOM_PLASMA (46) - Cow Mangler / Righteous Bison / Pomson / Short Circuit
TF_DMG_CUSTOM_PLASMA_CHARGED (47) - Explode into gibs. 50% chance of gibs getting plasma fizzle.
TF_DMG_CUSTOM_HEADSHOT_DECAPITATION (51) - Decapitation
TF_DMG_CUSTOM_MERASMUS_DECAPITATION (60) - Decapitation
TF_DMG_CUSTOM_KART (75) - 50 chance of higher velocity

Ragdoll properties
m_bGib				High blood gib
m_bBurning			75% chance to set on fire
m_bElectrocuted		Kritz disspipation electricity crackle
m_bFeignDeath		No effect
m_bWasDisguised		No effect
m_bBecomeAsh		C.A.P.P.E.R. Glowing ash / Phlog / Third Degree / Manmelter / Shooting Star
m_bOnGround			No effect
m_bCloaked			Cloaks the ragdoll!
m_bGoldRagdoll		Makes the ragdoll semi rigid and gold
m_bIceRagdoll		Makes the ragdoll semi-rigid and gives it an ice freeze effect with particles
m_bCritOnHardHit	No effect

env_entity_dissolver damage types
0	Combine energy ball
1	Combine energy ball but ragdoll does not float
2	Same as 1
3	Same as 1 but happens very fast
*/


// Hooking
// --------------------------------------------------------------------------------

function CleanGameEventCallbacks()
{
    CleanCallbacks("GameEventCallbacks");
    // CleanCallbacks(ScriptEventCallbacks);
    CleanCallbacks("ScriptHookCallbacks");
}

function CleanCallbacks(event_table)
{
	if (!(event_table in getroottable()))
	{
		return;
	}

    foreach (event, event_array in getroottable()[event_table])
    {
        for (local i = event_array.len() - 1; i >= 0; i--)
        {
            if (!event_array[i].self.IsValid())
            {
                event_array.remove(i);
            }
        }
    }
}



// Test stuff
// --------------------------------------------------------------------------------

/**
 * Cause all observing players to observe a specific entity
 *
 * @param {instance} target Instance of entity to observe. Leave at default for activator
 * @noreturn
 */
// function SetAllObserverTarget(target = null)
// {
// 	if (target == null)
// 	{
// 		target = activator;
// 	}

// 	printl("Setting everyone's observer target to " + target);

// 	for (local i = 1; i <= maxclients; i++)
// 	{
// 		local player = PlayerInstanceFromIndex(i);

// 		if (player != null && player.IsValid() && !player.IsAlive())
// 		{
// 			NetProps.SetPropEntity(player, "m_hObserverTarget", target);
// 		}
// 	}
// }

/**
 * Dump the script scope for all players
 *
 * @noreturn
 */
// ::DumpPlayerScopes <- function()
// {
// 	for (local i = 1; i <= maxclients; i++)
// 	{
// 		local player = PlayerInstanceFromIndex(i);

// 		if (player != null)
// 		{
// 			printl("Script scope for " + player.Name());
// 			__DumpScope(0, player.GetScriptScope());
// 		}
// 	}
// }