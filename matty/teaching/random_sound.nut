/*
	An example script demonstrating one method of playing a random sound.

	Notes:
	* Sounds must be precached at least once before being played. It's best to do it when the map loads.
		Precaching them again each round restart is not impactful. However precaching long sounds will freeze
		the client the first time.
*/

// list of sounds
local sounds = [
	"steamworks_extreme/ui/red_eclipse/bleeddamage.mp3",
	"steamworks_extreme/ui/red_eclipse/shell.mp3",
	"steamworks_extreme/ui/red_eclipse/shockdamage.mp3"
];

// precache the sounds
foreach(sound in sounds) {
	PrecacheSound(sound); // precaches raw sounds. for scriptsounds, use PrecacheScriptSound
}

// this is the function you call to play a sound. if you don't specify an entity,
// the entity this script belongs to will be used (self)
function PlayRandomSound(entity = null) {
	if (sounds.len() == 0) {
		return; // don't do anything if the sounds array is empty
	}

	local sound = sounds[RandomInt(0, sounds.len() - 1)];
	// each time the function is called, a random item in the array is picked.
	// RandomInt returns an integer number from 0 to the last index in the array.
	// that is obtained by taking the length (number of items) and subtracting 1.
	// arrays are indexed from 0, not 1.

	if (entity == null) {
		entity = self;
	}

	entity.EmitSound(sound);
}