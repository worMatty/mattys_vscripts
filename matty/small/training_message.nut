/*
	Training messages

	Lets you use the training mode HUD to display info to players prominently.

	WARNING: Will cause problems! Only use in specific circumstances.
		* You can't change team while the message is visible!
		* You need to double tap the changeclass key for the class menu to show up!
		* Dead players will respawn as stock soldiers!
		With this in mind, it's probably best to ensure all players are alive before you use it.
		And you may want to prevent them dying while it's displayed.
		This is of course especially important in Arena modes where dead players should stay dead.

	If you do use it, please note that the training HUD should be used to direct players, and not
	for general information because it is designed to steal focus from everything for new players.
	Good for use in minigames like Simon Says, Warioware clones, etc.
*/

local tf_gamerules = Entities.FindByClassname(null, "tf_gamerules");
local training = null;

function DisplayMessage(title, body) {
	InTrainingMode(true);

	if (training == null || !training.IsValid()) {
		training = SpawnEntityFromTable("tf_logic_training_mode", {});
	}

	EntFireByHandle(training, "ShowTrainingHUD", "", -1, null, null); // show the HUD
	EntFireByHandle(training, "ShowTrainingObjective", title, -1, null, null); // message title
	EntFireByHandle(training, "ShowTrainingMsg", body, -1, null, null); // message body
}

function HideMessage() {
	if (InTrainingMode()) {
		EntFireByHandle(training, "HideTrainingHUD", "", -1, null, null); // message body
		EntFireByHandle(training, "Kill", "", -1, null, null); // message body
		InTrainingMode(false);
	}
}

function InTrainingMode(set = null) {
	if (set != null) {
		NetProps.SetPropBool(tf_gamerules, "m_bIsInTraining", set);
	}

	return NetProps.GetPropBool(tf_gamerules, "m_bIsInTraining");
}


// Original info from Berke:
// How to use training HUD
// When you want to show the HUD, do this,
// Set "m_bIsInTraining" on "tf_gamerules" to true
// Spawn a "tf_logic_training_mode"
// Send "ShowTrainingHUD" input to "tf_logic_training_mode"
// Send "ShowTrainingObjective" input to "tf_logic_training_mode" for the top text
// Send "ShowTrainingMsg" input to "tf_logic_training_mode" for the bottom text,  symbol for yellow color,  to go back to white.
// When you are done with your message, send "HideTrainingHUD" to "tf_logic_training_mode", then kill it, then set "m_bIsInTraining" to false in "tf_gamerules"