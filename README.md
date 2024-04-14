# Matty's VScripts

Team Fortress 2 VScripts for various things; mainly useful in the Deathrun gamemode. Most are functional, some are work-in-progress and may have bugs.

## Deathrun
### Boss Bar
Monitor the health of one or more entities and players, combining their health and maximum health into one set of values and applying it to the Merasmus boss bar. If you have an arena in your deathrun map, you can use this to show the health of the activator(s). Alternatively, you can use it with a 'boss', as long as the entity(s) has/have health.

### Health Scaling
Easily scale the health of the blue team players based on the number of live reds. Used for arena fights. Raises max health rather than overhealing, and scales down health from health packs to match the class's normal amount. Caps damage from backstab hits against blue to 300 HP per hit.

### Hold the elevator
* On activation, the elevator/door will wait until all live reds are inside a trigger
* If the timer elapses, the elevator will proceed regardless

### Speedlane
Applies a speed boost to players touching a trigger. Useful in making an omnidirectional speedlane instead of using two trigger_pushes.

### Teleport Player
Ordinarily when a player uses a `trigger_teleport` or a `point_teleport`, their velocity (the speed and direction they are moving through space) is not rectified to match their destination. Only their view angles are matched. If they arrive at a destination that does not have the same angles as the teleporter entrance, they will often slip backwards or to the side, instead of moving forwards away from the destination. This is a problem if the return teleporter is located behind the destination. It results in players being teleported straight back where they came from. This script changes the player's velocity direction to match the angles of the destination entity, so they always arrive moving forwards.

A future version will preserve the player's velocity relative to the destination entity's angles, rather than aligning it, to provide that true *Unreal Tournament*-style teleportation experience.

### Trigger Tricks
Do the following stuff to people inside a trigger:
* Kill them
* Kill them silently
* Stun them
* Hurt them

## Entities
### func_breakable
Calculate the amount of health a breakable should have in order to keep players at bay for an appropriate amount of time. Scales based on the number of players in the area and the number of seconds you provide.

### game_text
Update the message and display to one or more targets in one function call. Saves having to use AddOutput to change the message, then sending the Display input after a short delay. Makes reusing one game_text entity convenient, saving effort and edicts.
Compatible with game_text_tf.

### point_viewcontrol
Facilitates multiple players using the same point_viewcontrol.

### point_worldtext
Unfortunately, line breaks (`\n`) added to an entity's message keyvalue field are not used when running the map on a dedicated server. You can store your phrase in this script, add it to the Entity Scripts field of the point_worldtext, and change the message to `phrase.whatever`. On spawn, or when changing the message at run-time, the entity will replace the message with the matching phrase from the script file.

## General Stuff in the 'matty' folder
### Bumper Cars
Everything you need to set up a bumper car race, including
* Lap counter
* Custom soundscript game sound names for events like lap, final lap, finishing and winning
* Respawn function for 'out-of-bounds' trigger_multiple
* Checkpoint system
Work in progress. The coding is a bit messy and the lap timer system is broken.

### Feedback viewer
Display player feedback as training annotations in the world. They expand and collapse based on your distance. Designed for the playtest comment scripts our plugin produces but could be adapted to work with TF2Maps VMFs.

### givemehat
Apply a random hat or other cosmetic ornament to a prop_dynamic player character model.

### Holidays
* Automatically trigger named logic_relays when a holiday is active
* Check if a holiday is active using scripting
* Supports all valid TF2 holidays
* Supports custom holidays using date ranges
* Supports falling back to a date range when the server is forcing a holiday using a console variable
* Optionally force a holiday on for testing
* Work-in-progress support for holiday priorities. e.g. If multiple holidays are active, only those with the highest equal priority level will have their logic triggered.

### Jetboots
For rock and stone!

### Jukebox
An easier way to play music in your map
* Create one or more playlists in a separate file and import them at run-time
* Optionally randomise the order on import
* Play through playlists fully in sequence, avoiding the problems caused by logic_case PickRandomShuffle
* Playlist data is stored globally so it doesn't get wiped on round restart
* Automatically replay MP3 files when they reach the end
* Optionally display the track title in chat
Designed to be used with a separate playlists.nut file.

### Math Game
A simple example script which implements a math question game using func_buttons and point_worldtext.

### No healing
Bar players from receiving healing from any source. A very simple script.

### Sky cameras
* Easily switch players between 3D skyboxes
* Give individuals separate skyboxes or change it for all
* Set the current default skybox for new joiners
Based on a script by gidi30. Thank you!

### Stocks 2
Many helpful functions including
* More CTFPlayer methods
* Convenient chat and HUD messaging
* Easy filtered player list creation (e.g. live reds, humans only, within radius of X)
* Versatile player teleport function designed to replace map-wide trigger_teleport brushes
* Useful constants

### Thirdperson
Put players in and out of thirdperson state using I/O or while they are inside a trigger_multiple. This is really good for situations where the player needs to be able to see themselves, such as in minigames, or when something is happening to them (like they are being ridden by a ~~jockey~~ skeleton). If the player was already in thirdperson, because the server has a thirdperson plugin, the script will respect the player's preference and will not change their perspective.

### Training message
Basic implementation of the TF2 Training Mode HUD message. While the effect is nice, there are some side effects, so you should read the information in the script. Please don't overuse this! Instead, use it in a similar fashion to its original purpose - to direct players with single objectives. Potentially useful in minigames and Warioware-style games.

## Map-specific scripts
* Steamworks Extreme main script
* Castle Steveh main script
* Deathrun button automation and cooldown noise
