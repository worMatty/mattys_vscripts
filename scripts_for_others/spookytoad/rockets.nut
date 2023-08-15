
/**
 * Constants
 * ----------------------------------------------------------------------------------------------------
 */
local in_attack = Constants.FButtons.IN_ATTACK;
local in_attack2 = Constants.FButtons.IN_ATTACK2;
local number_of_launchers = 20;
local rocket_fire_sound = "Building_Sentrygun.FireRocket";

local launcher_angles = [
	QAngle(0.0, 0.0, 0.0), // 0 - dummy
	QAngle(0.0, -5.0, 0.0),
	QAngle(0.0, -5.0, 0.0),
	QAngle(0.0, 0.0, 0.0),
	QAngle(0.0, 0.0, 0.0),
	QAngle(0.0, -4.0, 0.0), // 5
	QAngle(0.0, -4.0, 0.0),
	QAngle(0.0, 1.0, 0.0),
	QAngle(0.0, 1.0, 0.0),
	QAngle(0.0, -3.0, 0.0),
	QAngle(0.0, -3.0, 0.0), // 10
	QAngle(0.0, 2.0, 0.0),
	QAngle(0.0, 2.0, 0.0),
	QAngle(0.0, -2.0, 0.0),
	QAngle(0.0, -2.0, 0.0),
	QAngle(0.0, 3.0, 0.0), // 15
	QAngle(0.0, 3.0, 0.0),
	QAngle(0.0, -1.0, 0.0),
	QAngle(0.0, -1.0, 0.0),
	QAngle(0.0, 4.0, 0.0),
	QAngle(0.0, 4.0, 0.0) // 20
];


/**
 * Functions
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Get the frame rate or 'tick rate'
 * TF2 is normally 66.6 fps, but some servers push it higher
 * Note that the frame count on a listen server increments by twice that of a dedicated server
 * @return {number} The frame rate of the server in frames per second
 */
function GetServerFrameRate() {
	local rate = 1 / FrameTime();

	if (IsDedicatedServer()) {
		return rate;
	} else {
		return rate * 2;
	}
};

/**
 * Rocket launcher class
 * Contains methods for checking the state of the launcher, firing and managing cooldown/reload time
 * @param {instance} _entity Instance/handle of the weapon mimic
 * @param {bool} _enabled Whether the rocket should be unlocked for shooting
 */
local Launcher = class {
	constructor(_entity, _slot, _enabled = true) {
		entity = _entity;
		enabled = _enabled;
		angles = {};
		angles.normal <- entity.GetLocalAngles();
		angles.spread <- angles.normal + launcher_angles[_slot];
	}

	static cooldown = GetServerFrameRate() * 4.0 // time it takes to reload

	entity = null
	enabled = false
	reloaded_time = 0 // time in the future of when the launcher is useable again after being 'reloaded'
	angles = null

	function IsReady() {
		return (IsEnabled() && IsLoaded());
	}

	function IsEnabled(_enabled = null) {
		if (_enabled != null) {
			enabled = _enabled;
		}

		return enabled;
	}

	function IsLoaded() {
		return GetFrameCount() >= reloaded_time;
	}

	function Fire() {
		reloaded_time = GetFrameCount() + cooldown;
		EntFireByHandle(entity, "FireOnce", "", -1, null, null);
		EmitSoundEx({
			sound_name = rocket_fire_sound
			origin = entity.GetOrigin()
		});
	}

	function FireWithAngles() {
		entity.SetLocalAngles(angles.spread);
		Fire();
		EntFireByHandle(entity, "RunScriptCode", format("self.SetLocalAngles(QAngle(%f, %f, %f))", angles.normal.x, angles.normal.y, angles.normal.z), -1, null, null);
	}
};

/**
 * Rocket launcher manager
 * Contains methods for automating the selection and firing of rockets
 */
local Launchers = class {
	constructor(_self) {
		self = _self;

		for (local i = 1; i <= number_of_launchers; i++) {
			local entity = Entities.FindByName(null, prefix + i);

			if (entity != null && entity.IsValid() && entity.GetClassname() == classname) {
				local launcher = Launcher(entity, i);

				if (launcher != null) {
					launchers.push(launcher);
				}
			}
		}

		// get trace origin entity - this could be used to get attached mimics
		for (local child = self.FirstMoveChild(); child != null; child = child.NextMovePeer()) {
			if (child.GetName() == forwards_name) {
				trace_ent = child;
			}
		}

		launchers_len = launchers.len();
	}

	static forwards_name = "mech_forwards"	// targetname of the entity used for forwards tracing
	static classname = "tf_point_weapon_mimic"
	static prefix = "mecha_hitler_model_guns_mimic"

	launchers = [] // note that this array will be shared by all instances of this class
	launchers_len = null
	last_fired = 0
	trace_ent = null
	self = null

	/**
	 * Fire a rocket from the next ready launcher
	 * @returns {bool} True if a launcher was found and told to fire, false if none found
	 */
	function Fire() {
		local result = GetNextReady();

		if (result != null) {
			result.launcher.Fire();
			last_fired = result.slot;
			GetTracePos(result.launcher.entity);
			return true;
		}

		return false;
	}

	/**
	 * Fire all ready launchers
	 * @param {bool} override True to ignore cooldown status of launchers and fire regardless
	 * @returns {number} Number of launchers fired
	 */
	function FireAll(override = false) {
		local count = 0;

		foreach(launcher in launchers) {
			if (override == false && launcher.IsReady()) {
				launcher.FireWithAngles();
				count++;
			} else if (override == true) {
				launcher.FireWithAngles();
				count++;
			}
		}

		return count;
	}

	/**
	 * Returns the next available ready launcher
	 * @return {table} launcher = instance of Launcher class, slot = array slot, for setting last-fired. Or null if none ready
	 */
	function GetNextReady() {
		local i = 0;
		local j = last_fired + 1;

		while (i < launchers_len) {
			if (j >= launchers_len) {
				j = 0;
			}
			local launcher = launchers[j];

			if (launcher.IsReady()) {
				return {
					launcher = launcher,
					slot = j
				};
			}

			j++;
			i++;
		}

		return null;
	}

	/**
	 * Get the number of launchers ready for use
	 * @return {number} Number of launchers ready for use
	 */
	function GetReadyCount() {
		local count = 0;

		foreach(launcher in launchers) {
			if (launcher.IsReady()) {
				count++;
			}
		}

		return count;
	}

	/**
	 * Given an entity with origin and angles, traces a line from the entity in the direction it's facing
	 * and returns the pos of a hit
	 * @param {instance} start_ent Entity to draw trace from
	 * @return {vector} Origin of hit
	 */
	function GetTracePos(start_ent) {
		local trace = {
			start = start_ent.GetOrigin()
			end = start_ent.GetOrigin() + (start_ent.GetAbsAngles().Forward() * 32768.0)
		}

		local result = TraceLineEx(trace);
		return trace.pos;
	}
};

// must create an instance of the Launchers class for the constructor to run
// local launchers = Launchers();
::launchers <- Launchers(self);

// slot type assignment is necessary to call methods on the launchers instance via I/O
// RunScriptCode must be used


// basic rocket counter HUD
// uses a point_worldtext with my script in it but you can adapt it for any message entity
local HUD = class {
	constructor() {
		entity = Entities.FindByName(null, "rocket_count");
	}

	entity = null;

	function SetCount(count) {
		EntFireByHandle(entity, "RunScriptCode", format("SetMessage(%d)", count), 0.0, null, null);
	}
}

hud <- HUD();

function OnPostSpawn() {
	AddThinkToEnt(self, "OnThink");
}

function OnThink() {
	// hud.SetCount(launchers.GetReadyCount())
	// hud.SetCount(launchers.GetTotalCooldownRemaining() - GetFrameCount());
	local total_cooldown_length = launchers.max_cooldown;	// length in frames of cooldown period for all launchers in total - 2660
	local frames_remaining = launchers.GetTotalCooldownRemaining();	// number of frames until all launchers are loaded - 1330 at half loaded
	local percentage = frames_remaining / total_cooldown_length;
	// hud.SetCount(percentage * 100);
	hud.SetCount(abs((100 / total_cooldown_length) * (total_cooldown_length - frames_remaining)));
}

// notes: this method shows percentage of *cooldown time* so it will always show ~50% because rockets go on
// cooldown the moment they are fired. It should not be used. The Thermal Thrust model is good to analyse