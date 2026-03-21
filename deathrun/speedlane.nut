/*
	Deathrun Speedlane v0.3
	Apply to a trigger and touching players will receive a run speed boost.

	Notes:
	TF2 run speed is capped to 520.0 unless the server raises it using a plugin or extension.
	This script sets 600.0 run speed in case they do.
	Setting a player's max run speed property alone won't do anything until their spoeed is recalculated by something.
	Applying or removing a speed-modifying condition (like the Disciplinary Action) causes recalculation.
*/

self.ConnectOutput("OnStartTouch", "Output_OnStartTouch");
self.ConnectOutput("OnEndTouch", "Output_OnEndTouch");

local speed_cond = Constants.ETFCond.TF_COND_SPEED_BOOST;
local max_speed = 600.0;

function Output_OnStartTouch() {
	if (!(activator instanceof CTFPlayer)) return;
	activator.AddCond(speed_cond);
	NetProps.SetPropFloat(activator, "m_flMaxspeed", max_speed);
}
function Output_OnEndTouch() {
	if (!activator.IsValid() || !(activator instanceof CTFPlayer)) return;
	activator.RemoveCond(speed_cond);
}