
/**
 * Depends on stocks2.nut
 */

/**
 * Check for red players within a radius of 1024 units every second
 * Enable self if found and disable self if none found
 */
Think_CheckForReds <-  function() {
	local enabled = !(NetProps.GetPropInt(self, "m_iDisabled"));
	local players_nearby = (Players().Radius(self.GetOrigin(), 1024.0).Team(TF_TEAM_RED).players.len());

	if (players_nearby) {
		if (!enabled) {
			// printl(self + " players detected - enabling");
			EntFireByHandle(self, "Enable", "", -1, null, null);
		}
	} else if (enabled) {
		// printl(self + " no players detected - disabling");
		EntFireByHandle(self, "Disable", "", -1, null, null);
	}

	// printl(self + " Think_CheckForReds -- timer enabled is " + enabled);

	return 1;
};