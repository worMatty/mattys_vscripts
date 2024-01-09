/**
 * Change the sound of an ambient_generic to a random one and play it.
 * This precaches all your sounds and retains the ability to control the ambient_generic using I/O.
 *
 * Add this script to the scripts field of your ambient_generic entity.
 * Send it `CallScriptFunction PlayRandomSound` to pick and play a sound.
 *
 * Note that in order to stop a sound playing on round end, you should change its 'Is NOT looped' spawnflag to 'disabled'.
 * This makes the game think it's a looping sound and it will stop it on round reset.
 */

local sounds = [
	"steamworks_extreme/ui/red_eclipse/bleeddamage.mp3",
	"steamworks_extreme/ui/red_eclipse/shell.mp3",
	"steamworks_extreme/ui/red_eclipse/shockdamage.mp3"
];

foreach(sound in sounds) {
	PrecacheSound(sound); // precaches raw sounds
};

function PlayRandomSound() {
	if (sounds.len() == 0) {
		return;
	}

	local sound = format("message %s", sounds[RandomInt(0, sounds.len() - 1)]);

	EntFireByHandle(self, "AddOutput", sound, 0.0, activator, caller);
	EntFireByHandle(self, "PlaySound", "", 0.0, activator, caller);
}