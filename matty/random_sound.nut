/**
 * Random sound
 *
 * Very basic example script
 *
 * 1. List of sounds
 * 2. Precache list
 * 3. Pick one at random
 * 4. Emit sound at location
 */

// list of sounds
local sounds = [
	"steamworks_extreme/ui/red_eclipse/bleeddamage.mp3",
	"steamworks_extreme/ui/red_eclipse/shell.mp3",
	"steamworks_extreme/ui/red_eclipse/shockdamage.mp3"
];

// this will precache the sounds
foreach(sound in sounds) {
	PrecacheSound(sound); // precaches raw sounds
}

// this is the function you call to play a sound
// if you don't specify an entity, the receiving entity will be used
function PlayRandomSound(entity = null) {
	if (sounds.len() == 0) {
		return; // don't do anything if the sounds array is empty
	}

	local sound = sounds[RandomInt(0, sounds.len() - 1)];

	if (entity == null) {
		entity = self;
	}

	entity.EmitSound(sound);
}