/**
 * Deathrun Mapper Script - Breakable 2 - Version 1
 * Designed to supply a breakable anti-rush/slowdown device with appropriate health.
 *
 * When the round is active, when the breakable is first damaged, its health is calculated:
 * Number of live reds * average DPS * minimum time required to break.
 * Health is set to 1 after the maximum time to break, as a failsafe against premature calculation.
 *
 * Examples:
 * 1x red player = 250
 * 2x red players = 500
 * 10x red players = 2500
 *
 * Effects:
 * At the time of calculation if there is only one red player alive, they will take two seconds
 * to break through, which reduces needless delays in a low population server or close round.
 * At higher numbers of players, there are two scenarios:
 * 1. All players reach the breakable at the same time. This is uncommon and at this point, the
 * deathrun activator should not be in need of a long slow-down.
 * 2. Some rushers/fast lone wolves gain significant distance from the runner group and initiate
 * calculation upon damaging the breakable. The large amount of health ensures they cannot break
 * it quickly. Runners who catch up will then be able to help break it.
 * In all cases, since health is calculated upon first damage, it will scale with whatever
 * amount of red players are alive at that time.
 *
 * Average melee DPS has been previously determined to be ~125.
 * Primary can be up to 25% more.
 *
 * Usage: Add to a breakable's VScripts field.
 */

IncludeScript("matty/stocks2.nut");

/*
	Todo:
	On spawn, get health from entity and treat as longest number of seconds to break.
	Get total number of live red players and deduct nearby players.
	e.g. If there is only one player alive, and 100% of those players are nearby, it should take the shortest time to break.
	Take the distance of each red player and average it. Scale the health by that. If the average is closer, make it take less time to break.
	Get the distance of the furthest player to use in scaling for longest break time.
	Minimum and maximum break times. Get them from global storage or as arguments in the function call.
	Recalculate health after a period of non-breaking/inactivity?
	Add a single fire output to self to trigger the calculation on first hit.
	Don't calculate outside of round active states ('locked')
*/

local average_dps = 125; // average player DPS from melee attacks. Primary can be around ~25% higher
local health = 10000; // starter health and storage of health for calculating deduction of initial hit
local min_break_time = 2.0;
local max_break_time = 8.0;

/**
 * On spawn, set the health of the breakable to something high so it can't be broken by weaponsfire.
 * Add an output which is used to respond to damage events.
 */
function OnPostSpawn() {
	self.SetHealth(health);
	EntityOutputs.AddOutput(self, "OnHealthChanged", "!self", "CallScriptFunction", "OnHealthChanged", -1, -1);
}

/**
 * When the breakable receives damage, if the round is not active, restore its starting health.
 * Otherwise, remove the output and request that the appropriate amount of health be calculated.
 * Supply the damage taken for deduction afterwards.
 */
function OnHealthChanged() {
	// pre-round ignore damage
	if (GetRoundState() < GR_STATE_RND_RUNNING) {
		if (self.GetHealth() < health) {
			self.SetHealth(health);
		}
		return;
	}

	EntityOutputs.RemoveOutput(self, "OnHealthChanged", "!self", "CallScriptFunction", "OnHealthChanged");
	EntFireByHandle(self, "RunScriptCode", "self.SetHealth(1)", max_break_time, null, null);
	local deduction = health - self.GetHealth();
	CalculateHealth(min_break_time, deduction);
}

/**
 * Calculate an appropriate amount of health for the breakable.
 * Based on the number of live reds, average DPS figure and minimum break time.
 * Deduct the damage from the initial hits from the calculated amount and clamp min to 1.
 * Set the health of the breakable to the new amount.
 */
function CalculateHealth(min_time, deduct_dmg) {
	local reds = LiveReds().len();
	local new_health = ((reds > 0) ? reds : 1) * average_dps * min_time;
	new_health -= deduct_dmg;
	new_health = (new_health > 0) ? new_health : 1;
	self.SetHealth(new_health);
	health = new_health;
}
