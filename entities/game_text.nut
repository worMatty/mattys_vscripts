/**
 * Functions attached to game_text to make it easier to use
 * Also works with game_text_tf
 */

/**
 * Display the message
 * Optionally set a new message at the same time
 * @param {string} message The new message string
 */
function Display(message = null) {
	if (message != null && typeof message == "string") {
		EntFireByHandle(self, "AddOutput", "message " + message, -1, activator, caller);
	}

	EntFireByHandle(self, "Display", null, -1, activator, caller);
}

DisplayMessage <- Display; // backwards compatability

/**
 * Display the message to a specific player
 * This is done by temporarily changing the entity's spawnflags
 * @param {player} player Player instance. Default is activator
 * @param {string} message Optional new message
 */
function PrintToPlayer(player = null, message = null) {
	// assign recipient player
	Assert((player != null || activator != null), "game_text.nut -- PrintToPlayer -- Both 'player' and 'activator' are null. No-one to send message to!");
	player = (player != null) ? player : activator;

	// set message
	if (message != null && typeof message == "string") {
		EntFireByHandle(self, "AddOutput", "message " + message, -1, activator, caller);
	}

	local spawnflags = NetProps.GetPropInt(self, "m_spawnflags");
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", ~1 & spawnflags), -1, activator, caller);
	EntFireByHandle(self, "Display", null, -1, player, caller);
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", spawnflags), -1, activator, caller);
}

/**
 * Display the message to all players
 * This is done by temporarily changing the entity's spawnflags
 * @param {string} message Optional new message
 */
function PrintToAll(message = null) {
	// set message
	if (message != null && typeof message == "string") {
		EntFireByHandle(self, "AddOutput", "message " + message, -1, activator, caller);
	}

	local spawnflags = NetProps.GetPropInt(self, "m_spawnflags");
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", 1 | spawnflags), -1, activator, caller);
	EntFireByHandle(self, "Display", null, -1, activator, caller);
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", spawnflags), -1, activator, caller);
}

/**
 * Display the message to a specific team number
 * This is done by temporarily changing the entity's spawnflags
 * @param {number} team Team number (2 for red, 3 for blue)
 * @param {string} message Optional new message
 */
function PrintToTeam(team, message = null) {
	Assert(typeof team == "integer", "game_text.nut -- PrintToTeam -- team argument is not an integer");

	local players = [];
	local maxclients = MaxClients();

	for (local i = 1; i <= maxclients; i++) {
		local player = PlayerInstanceFromIndex(i);

		if (player != null && player.GetTeam() == team) {
			players.push(player);
		}
	}

	// set message
	if (message != null && typeof message == "string") {
		EntFireByHandle(self, "AddOutput", "message " + message, -1, activator, caller);
	}

	local spawnflags = NetProps.GetPropInt(self, "m_spawnflags");
	EntFireByHandle(self, "AddOutput", format("spawnflags %d", ~1 & spawnflags), -1, activator, caller);

	foreach(player in players) {
		EntFireByHandle(self, "Display", null, -1, player, caller);
	}

	EntFireByHandle(self, "AddOutput", format("spawnflags %d", spawnflags), -1, activator, caller);
}