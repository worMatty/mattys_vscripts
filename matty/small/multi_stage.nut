/*
	Basic multi-stage control

	Usage:
		Add this script to a logic_script entity.
		Create a logic_relay for each stage's logic and name them like so:
			relay_stage1_load
			relay_stage2_load
			etc.
		When a new round starts this script will execute and fire the relay for the set stage.
		When you wish to set the next stage, send an input to the logic_script like this:
			Input: RunScriptCode
			Parameter: mymap.next_stage = 2
		Do this before the round restarts and on the next round, the new stage will load.

	Tips:
		You can create multiple relays with the same targetname, and they will all be fired.
		Note that the script includes a wildcard character at the end of its targetname
		parameter, so you are free to give the relays suffixes if it will help you to organise them.
		e.g. relay_stage1_load_music, relay_stage1_load_mobs, etc.

		It is typical for creators of multi-stage maps to put players in a temporary holding
		spawn room on round restart, then teleport them to the spawn area for that stage
		using something like a trigger_teleport.
*/

// create global variables
if (!("mymap" in getroottable())) {
	getroottable().mymap <- {
		stage = 1
		next_stage = null
	}
}

// check the stage to play on round restart (when this script is executed).
// trigger a named relay
if (mymap.next_stage != null) {
	mymap.stage = mymap.next_stage;
	mymap.next_stage = null;
}
EntFire("relay_stage" + mymap.stage + "_load*", "Trigger", null, -1.0);