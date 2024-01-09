/**
 * Functions attached to game_text to make it easier to use
 */

maxclients <- MaxClients();

/**
 * Set the message of a game_text and immediately display it
 *
 * @param {string} message - Message to print
 * @noreturn
 */
function DisplayMessage(message) {
	self.__KeyValueFromString("message", message);
	EntFireByHandle(self, "Display", null, 0.0, activator, caller);
}

/**
 * Set the message of a game_text and immediately display it to a specified player.
 * Automatically adjusts and then resets the entity's spawnflags.
 * Pass 'activator' to 'player' to print to !activator
 *
 * @param {player} player - Player instance
 * @param {string} message - Message to print
 * @noreturn
 */
function PrintToPlayer(player, message) {
	local spawnflags = NetProps.GetPropInt(self, "m_spawnflags");
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", ~1 & spawnflags), 0.0, activator, caller);
	EntFireByHandle(self, "AddOutput", format("message %s", message), 0.0, activator, caller);
	EntFireByHandle(self, "Display", null, 0.0, activator, caller);
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", spawnflags), 0.0, activator, caller);
}

/**
 * Set the message of a game_text and immediately display it to all players.
 * Automatically adjusts and then resets the entity's spawnflags.
 *
 * @param {string} message - Message to print
 * @noreturn
 */
function PrintToAll(message) {
	local spawnflags = NetProps.GetPropInt(self, "m_spawnflags");
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", 1 | spawnflags), 0.0, activator, caller);
	EntFireByHandle(self, "AddOutput", format("message %s", message), 0.0, activator, caller);
	EntFireByHandle(self, "Display", null, 0.0, activator, caller);
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", spawnflags), 0.0, activator, caller);
}

/**
 * Set the message of a game_text and immediately display it to the specified team.
 * Automatically adjusts and then resets the entity's spawnflags.
 *
 * @param {number} team - TF team number
 * @param {string} message - Message to print
 * @noreturn
 */
function PrintToTeam(team, message) {
	local players = [];

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.GetTeam() == team) {
			players.push(player);
		}
	}

	local spawnflags = NetProps.GetPropInt(self, "m_spawnflags");

	EntFireByHandle(self, "AddOutput", format("spawnflags %d", ~1 & spawnflags), 0.0, activator, caller);
	EntFireByHandle(self, "AddOutput", format("message %s", message), 0.0, activator, caller);

	foreach(player in players) {
		EntFireByHandle(self, "Display", null, 0.0, player, caller);
	}

	EntFireByHandle(self, "AddOutput", format("spawnflags %d", spawnflags), 0.0, activator, caller);
}