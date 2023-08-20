/**
 * Training messages
 * This is not a complete script. It was made for special cases by people who understand the side
 * effects of enabling training mode. Please read the Quirks section!
 * If you do use it, please note that the training HUD should be used to direct players, and not
 * for general information because it is designed to steal focus from everything for new players.
 * Good for use in minigames like Simon Says, Warioware clones, etc.
 */

// from Berke:
// How to use training HUD
// When you want to show the HUD, do this,
// Set "m_bIsInTraining" on "tf_gamerules" to true
// Spawn a "tf_logic_training_mode"
// Send "ShowTrainingHUD" input to "tf_logic_training_mode"
// Send "ShowTrainingObjective" input to "tf_logic_training_mode" for the top text
// Send "ShowTrainingMsg" input to "tf_logic_training_mode" for the bottom text,  symbol for yellow color,  to go back to white.
// When you are done with your message, send "HideTrainingHUD" to "tf_logic_training_mode", then kill it, then set "m_bIsInTraining" to false in "tf_gamerules"

// Quirks:
// You can't change team while the message is visible
// You need to double tap the changeclass key for the class menu to show up

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
	EntFireByHandle(training, "HideTrainingHUD", "", -1, null, null); // message body
	EntFireByHandle(training, "Kill", "", -1, null, null); // message body
	InTrainingMode(false);
}

function InTrainingMode(set = null) {
	if (set != null) {
		NetProps.SetPropBool(tf_gamerules, "m_bIsInTraining", set);
	}

	return NetProps.GetPropBool(tf_gamerules, "m_bIsInTraining");
}
