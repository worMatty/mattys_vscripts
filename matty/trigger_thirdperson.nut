/**
 * Put a player into thirdperson when they touch a trigger.
 * Take them out when they leave it.
 *
 * Forced Taunt Cam Perspective (FTCP) can only be enabled using an input on the player.
 * When enabled, the player's property m_nForcedTauntCam is set to 1.
 * When taunting, this property is not affected.
 * When finishing a taunt, this property will not be reset and the player will remain in FTCP.
 * This makes it ideal for forcing thirdperson.
 * This script checks if a player is already in FTPC on entrance, and if so, does not change it at all.
 * This respects server plugins which allow players to freely toggle thirdperson.
 */

self.ConnectOutput("OnStartTouch", "Output_OnStartTouch");
self.ConnectOutput("OnEndTouch", "Output_OnEndTouch");

already_ftc <- []; // already in Forced Taunt Cam perspective

function Output_OnStartTouch() {
	if (NetProps.GetPropInt(activator, "m_nForceTauntCam")) {
		already_ftc.push(activator);
	} else {
		EntFireByHandle(activator, "SetForcedTauntCam", "1", 0.0, activator, caller);
	}
}

function Output_OnEndTouch() {
	local index = already_ftc.find(activator);

	if (index != null) {
		already_ftc.remove(index);
	} else if (activator != null && activator.IsValid()) // account for disconnecting players
	{
		EntFireByHandle(activator, "SetForcedTauntCam", "0", 0.0, activator, caller);
	}
}