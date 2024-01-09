/**
 * Control the time it takes for a func_breakable to be broken.
 * Sets health of the breakable based on number of reds in the area.
 * Health granted per player is slightly reduced to account for slacking.
 * On maximum time reached, breakable is set to a low health for easy breaking.
 *
 * How to use:
 * Add this script to the breakable in the entity scripts field.
 * Set the initial health to something high like 1000 so it can't be broken.
 * Add an output `OnHealthChanged !self RunScriptCode CalculateHealth(10)` with a refire value of 1.
 * `10` is the maximum time you wish the players to struggle with the door.
 * It's used in calculating the breakable health and to make it easy to break after this time.
 *
 * Optional settings
 * CalculateHealth(10, 2048, false)
 * 2048 = radius to check for red players
 * false = don't set the health to something low at max time
 */


// constants
local maxclients = MaxClients();
local team_red = Constants.ETFTeam.TF_TEAM_RED;
local average_dps = 125; // average player DPS from melee attacks. Primary can be around ~25% higher
local weak_health = 10; // set self to this health when max time reached

// variables
local calculated = false; // stop the function being called again in case refire time is set to -1

/**
 * Calculate the health of the func_breakable
 * Takes the number of red players in the specified radius
 * Uses it to calculate health with diminishing returns
 * @param {float} max_time Time you want the breakable to last for
 * @param {integer} radius Radius to check for red players
 * @param {boolean} easy_break Set breakable health to a low amount when max time passes
 */
function CalculateHealth(max_time = 10.0, radius = 2048, easy_break = true) {
	if (calculated == true) {
		return;
	} else {
		calculated = true;
	}

	local red_count = GetRedCountWithinRadius(radius);

	// fall back to one red to avoid setting health of 0, making it invulnerable
	if (red_count == 0) {
		red_count = 1;
	}

	local new_health = 0;
	local dps = average_dps;

	// from two players or more, diminish dps to 0.95 per player
	for (local i = 2; i <= red_count; i++) {
		dps = dps * 0.95;
	}

	local new_health = (red_count * dps * max_time).tointeger();
	NetProps.SetPropInt(self, "m_iHealth", new_health);

	// make the breakable easy to destroy when time reached
	if (easy_break) {
		EntFireByHandle(self, "AddOutput", format("health " + weak_health), max_time, null, null);
	}
}

/**
 * Get the number of red players within the radius of self
 * @param {integer} radius Radius to check within
 */
function GetRedCountWithinRadius(radius) {
	local red_count = 0;
	local player = null;
	local origin = self.GetOrigin();

	while (player = Entities.FindByClassnameWithin(player, "player", origin, radius)) {
		if (player.GetTeam() == team_red) {
			red_count++;
		}
	}

	return red_count;
}


/*

Notes

OntakeDamage output seems to not work.
OnHealthChanged works but IIRC only if health has changed so not if the ent is invulnerable.

Time taken to break at 1000 health
Pyro melee 8s
Pyro shotgun + reload 20s
Heavy melee 8s
Heavy minigun 6s
Demo grenades - unpossible
Demo sticky 10s
Engi wrangled sentry both barrels 7s
Engi melee 8s
Soldier rockets 11s

Summary
Primary 8-11s
Melee 8s
Shotgun 20s

We should optimise for melee! We don't have to worry about projectiles taking longer.
Calculated Damage Per Second (DPS) is 125.
Multiply this by the time required to get the health.
Multiply this by the number of reds in the area? Or build in a timer to set the health to something low at ten seconds?
For a target of ten seconds breaking time

Health scaling calculation stuff

At 125 dps and ten seconds, per player, with a * 0.95 decrement loop
1 = 1250
2 = 2375
3 = 3384
4 = 4268
5 = 5090
10 = 7878

These allow time for players to destroy the door before the time limit,
and forgives players not being present or attentive.

125 * players * 10 straight multiplication
1 = 1250
2 = 2500
3 = 3750
4 = 5000
5 = 6250
10 = 12500


*/