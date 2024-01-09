/**
 * Trigger tricks! v0.1
 *
 * Do stuff to players inside this trigger.
 *
 * Usage:
 * Add this script to the trigger's scripts.
 * Check the below functions to see what you can do.
 * Call `CallScriptFunction <function>` to do it.
 */

/**
 * Note on damage:
 * The deathrun plugin may negate self-damage, so TakeDamage/Ex should use an attacker handle that's not
 * the players. e.g. worldspawn
 */


// Functions which affect players in the volume
// ----------------------------------------------------------------------------------------------------

/**
 * Kill players
 * Works by applying damage equal to their health
 */
function KillPlayers() {
	foreach(player in players) {
		KillPlayer(player);
	}
}

/**
 * Kill players 'silently' with no death noises
 */
function KillPlayersSilently() {
	foreach(player in players) {
		KillPlayerSilently(player);
	}
}

/**
 * Stun or slow players within the volume
 * Uses a trigger_stun and supports different types of stun.
 * The slow_percentage doesn't scale run speed by the player's maximum run speed.
 * Their class or buffs don't matter. All players are treated as if their max
 * run speed is 450, so a slow_percentage of 0.5 would be 225 run speed.
 * @param {float} duration Stun duration
 * @param {integer} type Type of stun. 0 = slow only. 1 = Sandman stun (unable to move). 2 = scared
 * @param {float} slow_percentage Amount of percentage speed reduction. 1.0 is 100%. Not relevant with type 1
 */
function StunPlayers(duration = 5.0, type = 1, slow_percentage = 1.0) {
	local stunner = CreateStunTrigger(duration, type, slow_percentage);

	foreach(player in players) {
		EntFireByHandle(stunner, "EndTouch", "", 0.0, player, player);
	}

	EntFireByHandle(stunner, "Kill", "", 0.0, activator, caller);
}

/**
 * Kill players using a trigger_hurt instead of by applying damage
 * @param {integer} damage Damage to apply every 0.5s
 */
function HurtPlayers(damage = 500) {
	local hurt = CreateHurtTrigger(damage * 2);

	foreach(player in players) {
		EntFireByHandle(hurt, "EndTouch", "", 0.0, player, player);
	}

	EntFireByHandle(hurt, "Kill", "", 0.0, null, null);
}


// Nothing useable below here
// ----------------------------------------------------------------------------------------------------

local debug = false; // prints debug text to console

players <- [];
self.ConnectOutput("OnStartTouch", "OnStartTouch");
self.ConnectOutput("OnEndTouch", "OnEndTouch");

local worldspawn = Entities.FindByClassname(null, "worldspawn");


// Functions used by the above
// ----------------------------------------------------------------------------------------------------

/**
 * Kill a player by damaging them for an amount equal to their health
 * @param {instance} player Player instance
 * @noreturn
 */
function KillPlayer(player) {
	if (player.IsValid()) {
		player.TakeDamageEx(null, player, null, Vector(0, 0, 0), player.GetOrigin(), player.GetHealth(), 0);

		// self-damage is being negated
		if (NetProps.GetPropInt(player, "m_lifeState") == 0) {
			// todo: fix the player being thrown from the origin of the map
			if (debug) printl(activator + " was not killed by TakeDamageEx self-damage, so we're killing them by worldspawn");
			player.TakeDamageEx(null, worldspawn, null, Vector(0, 0, 0), player.GetOrigin(), player.GetHealth(), 0);
		}
	}
}

function KillPlayerSilently(player) {
	NetProps.SetPropInt(player, "m_iObserverLastMode", 5);
	local team = player.GetTeam();
	NetProps.SetPropInt(player, "m_iTeamNum", 1);
	player.DispatchSpawn();
	NetProps.SetPropInt(player, "m_iTeamNum", team);
}

/**
 * Create a trigger_stun for use in stunning players.
 * Should be killed after use!
 * See the description of StunPlayers() for more detailed info.
 * @param {float} duration Length of time for the stun effect to last for
 * @param {integer} type The type of stun
 * @param {float} speed_reduction Percentage of speed reduction from 0.0-1.0
 */
function CreateStunTrigger(duration, type, speed_reduction) {
	local stunner = SpawnEntityFromTable("trigger_stun", {
		move_speed_reduction = speed_reduction
		spawnflags = 1
		stun_duration = duration
		stun_type = type
		trigger_delay = 0
	});

	return stunner;
}

function CreateHurtTrigger(damage = 1000, damage_type = 0, no_damage_force = 1, doubling = 0, damage_cap = 20) {
	local hurt = SpawnEntityFromTable("trigger_hurt", {
		damage = damage
		damagetype = damage_type
		nodmgforce = no_damage_force
		damagemodel = doubling
		damagecap = damage_cap
		spawnflags = 1
	});

	return hurt;
}

// ----------------------------------------------------------------------------------------------------

// players start touching
function OnStartTouch() {
	if (debug) printl(activator + " OnStartTouch");
	players.push(activator);
}

// players stop touching, or disconnect
function OnEndTouch() {
	if (debug) printl(activator + " OnEndTouch");
	local index = players.find(activator);

	if (index != null) {
		players.remove(index);
	} else {
		if (debug) printl(activator + " not found in the array, so we'll clean it of invalid players");
		players = players.filter(function(index, player) {
			return player.IsValid();
		})
	}
}

// display touching players
function Display() {
	printl(players.len() + " players touching " + self);
	foreach(player in players) {
		printl(player);
	}
}