/*
	Health recharge station v0.1 by worMatty
	Add to a func_button or wall charger prop_dynamic
*/

local IN_USE = Constants.FButtons.IN_USE;
local RECIPIENT_FILTER_SINGLE_PLAYER = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_SINGLE_PLAYER;
local RECIPIENT_FILTER_GLOBAL = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL;
local SND_STOP = 4;

start_sound_length <- 0.56; // duration of the start sound before we start the looping sound

local juice = 100.0; // amount of charge
local max_juice = juice;
local rate = 20; // charge rate in health per second
local charge_unit_time = 1.0 / rate; // amount of time that should pass before we give a user 1 HP
local next_charge = 0.0; // time when next charge of 1 HP will occur
local users = [];
local on = false;
local sound_time = null; // when the charge loop sound should start
local is_prop = false;
local is_brush = false;

// can be found in hl2 base soundscript
PrecacheScriptSound("WallHealth.Deny");
PrecacheScriptSound("WallHealth.Start");
PrecacheScriptSound("WallHealth.LoopingContinueCharge");
PrecacheScriptSound("WallHealth.Recharge");

// determine if entity is prop or func_button
function OnPostSpawn() {
	if (self instanceof CBaseAnimating) {
		is_prop = true;
		NetProps.SetPropBool(self, "m_bClientSideAnimation", false); // disable client-side animation so we can set cycle
		self.ResetSequence(self.LookupSequence("idle"));
		self.SetCycle(1.0 - (juice / max_juice)); // 1.0 is empty, 0.0 is full

		// create func_button so we can +use it
		local button = SpawnEntityFromTable("func_button", {
			origin = self.GetOrigin()
			spawnflags = 1025 // don't move, use activates
		})
		self.AcceptInput("SetParent", "!activator", button, null);
	} else if (self.GetClassname() == "func_button") is_brush = true;
}

// +use hook
function InputUse() {
	// check juice level
	if (!juice) {
		EmitSoundEx({
			sound_name = "WallHealth.Deny"
			entity = self
		});
		DebugDrawText(self.GetOrigin(), "No juice", false, 3.0);
	} else if (activator.GetHealth() >= activator.GetMaxHealth()) {
		EmitSoundEx({
			sound_name = "WallHealth.Deny"
			entity = activator
			filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
		});
		DebugDrawText(self.GetOrigin(), "Full health", false, 3.0);
	}
	// else add user to list of users
	else {
		users.append(activator);
		if (!on) AddThinkToEnt(self, "Think"); // start thinking if off
		DebugDrawText(self.GetOrigin(), "User added", false, 3.0);
	}

	return true;
}
Inputuse <- InputUse;

/**
 * Set the charge level of the station, which is the max amount of health it can currently dispense until empty
 * @param {integer} charge Charge amount
 */
function SetCharge(charge) {
	charge = charge < 0 ? 0.0 : charge.tofloat(); // clamp min

	// disable
	if (juice && !charge) {
		juice = charge;
		max_juice = juice;

		EmitSoundEx({
			sound_name = "WallHealth.Deny"
			origin = self.GetOrigin()
		});
		if (is_prop) {
			self.ResetSequence(self.LookupSequence("empty"));
		} else if (is_brush) {
			NetProps.SetPropInt(self, "m_iTextureFrameIndex", 1);
		}
	}

	// recharge
	else if (!juice && charge) {
		juice = charge;
		max_juice = juice;

		EmitSoundEx({
			sound_name = "WallHealth.Recharge"
			origin = self.GetOrigin()
		});
		if (is_prop) {
			self.SetPlaybackRate(0.0);
			self.ResetSequence(self.LookupSequence("idle"));
			self.SetCycle(1.0 - (juice / max_juice));
			// todo: bar isn't at 100%
		} else if (is_brush) {
			NetProps.SetPropInt(self, "m_iTextureFrameIndex", 0);
		}
	}

	// just set value
	else {
		juice = charge;
		max_juice = juice;
	}

	DebugDrawText(self.GetOrigin(), "Juice set to " + charge, false, 3.0);
}

/**
 * Set the rate at which the station heals, in HP per second
 * @param {integer} _rate Health points per second
 */
function SetRate(_rate) {
	if (!rate) return; // maybe someone wants a harm dispenser. allow them to go negative
	rate = _rate;
	charge_unit_time = fabs(1.0 / rate); // ensure it's positive as we are setting a time in the future not the past
	DebugDrawText(self.GetOrigin(), "New rate and charge unit time: " + rate + ", " + charge_unit_time, false, 5.0);
}

function Think() {
	// filter out disconnected or dead players
	users = users.filter(function(index, player) return (player.IsValid() && player.IsAlive()));

	// turn off if no users
	if (!users.len()) {
		if (on) {
			on = false;
			EmitSoundEx({
				sound_name = "WallHealth.LoopingContinueCharge"
				origin = self.GetOrigin()
				flags = SND_STOP
				filter_type = RECIPIENT_FILTER_GLOBAL
			});
		}
		AddThinkToEnt(self, ""); // stop think when turned off
		return;
	}

	// turn on
	if (!on && users.len()) {
		if (juice) {
			on = true;
			next_charge = Time();
			EmitSoundEx({
				sound_name = "WallHealth.Start"
				origin = self.GetOrigin()
			});
			sound_time = Time() + start_sound_length;
		}
	}

	// play charge loop sound
	if (sound_time != null && sound_time <= Time()) {
		sound_time = null;
		EmitSoundEx({
			sound_name = "WallHealth.LoopingContinueCharge"
			origin = self.GetOrigin()
			filter_type = RECIPIENT_FILTER_GLOBAL
			// todo: check if this needs to come from the entity in order to be stopped
		});
	}

	// set animation frame
	if (is_prop) {
		self.SetPlaybackRate(0.0);
		self.SetCycle(1.0 - (juice / max_juice));
		// self.StudioFrameAdvanceManual(1.0 - (juice / max_juice));
		self.StudioFrameAdvance();
		self.DispatchAnimEvents(self);
	}

	// heal
	if (next_charge <= Time()) {
		for (local i = users.len() - 1; i >= 0; i--) {
			local player = users[i];

			// grant health if still using
			if (NetProps.GetPropInt(player, "m_nButtons") & IN_USE) {
				if (juice) {
					if (player.GetHealth() < player.GetMaxHealth()) {
						player.SetHealth(player.GetHealth() + 1);
						juice--;
						continue;
					}
				}
			}
			// todo: check proximity and angle to machine so they can't run away and keep charging. or just stop them in place I suppose?
			// NetProps.SetPropInt(player, "m_afButtonPressed", NetProps.GetPropInt(player, "m_nButtonss") &= ~IN_USE); // remove +use from pressed buttons
			users.remove(i); // remove user if they stopped pressing +use
		}
		local old_charge = next_charge;
		next_charge += charge_unit_time; // ensure we heal in increments of 1 HP, to avoid supplying floats and not actually healing
	}

	// out of juice, kick everyone off
	if (!juice) {
		users = [];
		EmitSoundEx({
			sound_name = "WallHealth.Deny"
			origin = self.GetOrigin()
		});
		if (is_prop) {
			self.ResetSequence(self.LookupSequence("empty"));
		} else if (is_brush) {
			NetProps.SetPropInt(self, "m_iTextureFrameIndex", 1);
		}
	}

	return -1;
}

// Source reference
// https://github.com/ValveSoftware/source-sdk-2013/blob/c623a7c30d5cb7275cc64ed0b866f61f4a64c6eb/src/game/server/hl2/item_healthkit.cpp#L385

// Known issues: If the rate is higher than the server framerate, health will initially be dispensed at a faster rate.
// A possible solution might be to calculate the health per frame time.
// You can keep +use pressed and walk away to keep healing. Easiest solution would be to check position and look angle.

/*
	Dev notes

	Use global 'on' if you plan to self-recharge.
	Otherwise just assume if the think function is running, it's on. check the think function

	Future
	Check animation anim time props to hopefully smooth anim
	Support health rates higher than server framerate
	Replace boolean checks for is_prop and is_brush with corresponding function on post spawn, for efficiency
	Recharge time ala HLDM

	To test
	Investigate whether the use of CHAN_ITEM interferes with other stuff
*/