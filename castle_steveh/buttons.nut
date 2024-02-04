/**
 * Castle Steveh buttons
 * Helps with colours and stuff
 */

colours <- {
	ready = "81 255 81" // button can be pressed - green
	consumed = "10 30 10" // single-use button has been used - dull green
	cooldown = "255 158 28" // multiple-use button is on cooldown - orange
	locked = "255 158 28" // cannot currently press button - orange
}

state <- {
	consumed = false
	oncooldown = false
}

self.ConnectOutput("OnPressed", "OnPressed");
self.ConnectOutput("OnOut", "OnOut");

function OnPressed() {
	if (NetProps.GetPropFloat(self, "m_flWait").tointeger() != -1) {
		Cooldown();
	} else {
		Consume();
	}
}

function OnOut() {
	Ready();
}

/**
 * Show a button as ready to use
 */
function Ready() {
	state.consumed = false;
	state.oncooldown = false;
	EntFireByHandle(self, "Color", colours.ready, -1, null, null);
}

/**
 * Show the button as having been consumed
 * Typically uses a 'drained' colour to simulate removing illumination
 */
function Consume() {
	state.consumed = true;
	EntFireByHandle(self, "Color", colours.consumed, -1, null, null);
}

/**
 * Show the button as being on cooldown
 * Typically uses a colour like orange to suggest it's in a pending state
 */
function Cooldown() {
	state.oncooldown = true;
	EntFireByHandle(self, "Color", colours.cooldown, -1, null, null);
}

/**
 * Show a button as being locked
 * The button looks like has not yet been consumed but is unable to be pressed
 */
function Lock() {
	EntFireByHandle(self, "Lock", null, -1, activator, caller);

	// colour the button if it is not consumed
	if (state.consumed == false) {
		EntFireByHandle(self, "Color", colours.locked, -1, null, null);
	}
}

function Unlock() {
	EntFireByHandle(self, "Unlock", null, -1, activator, caller);

	// colour the button if it is not consumed
	if (state.consumed == false) {
		EntFireByHandle(self, "Color", colours.ready, -1, null, null);
	}
}

/**
 * Consume and lock the button
 * Makes it look like it's been used and locks it to stop it from being pressed
 */
function Deactivate() {
	Consume();
	Lock();
}

Ready();


// function CheckColor() {
// 	if (NetProps.GetPropBool(self, "m_bLocked")) {
// 		self.Lock()
// 	}
// }

// m_fStayPushed	-1 float 1 int - unknown
// m_bLocked	false
// m_flWait		5
// m_spawnflags		1536

// TBA
// Texture index
// Cooldown animation, effect or sprite based on wait time