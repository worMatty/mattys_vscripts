# Matty's VScripts

Team Fortress 2 VScripts for various things; mainly useful in the Deathrun gamemode. Most are functional, some are work-in-progress and may have bugs.

## Deathrun
### Boss Bar
Monitor the health of one or more entities and players, combining their health and maximum health into one set of values and applying it to the Merasmus boss bar. If you have an arena in your deathrun map, you can use this to show the health of the activator(s). Alternatively, you can use it with a 'boss', as long as the entity(s) has/have health. Falls back to a HUD text display if it detects outside interference.

### Health Scaling
Easily scale the health of the blue team players based on the number of live reds. Used for arena fights. Raises max health rather than overhealing, and scales down health from health packs to match the class's normal amount. Caps damage from backstab hits against blue to 300 HP per hit. Intended to be used at the beginning of a fight and not at the start of a round. 

### Hold the elevator
On activation, the elevator/door will wait until all live reds are inside a trigger. If the timer elapses, the elevator will proceed regardless. This is similar to the elevators in Left 4 Dead, except for the timeout.

### Speedlane
Applies a speed boost to players touching a trigger. Useful in making a single omnidirectional speedlane in the deathrun map's activator corridor instead of using multiple trigger_push.

### Teleport Player
Ordinarily when a player uses a `trigger_teleport` or a `point_teleport`, their velocity (the speed and direction they are moving through space) is not rectified to match their destination. Only their view angles are matched. If they arrive at a destination that does not have the same angles as the teleporter entrance, they will often slip backwards or to the side, instead of moving forwards away from the destination. This is a problem if the return teleporter is located behind the destination. It results in players being teleported straight back where they came from. This script changes the player's velocity direction to match the angles of the destination entity, so they always arrive moving forwards.

A future version will preserve the player's velocity relative to the destination entity's angles, rather than aligning it, to provide that true *Unreal Tournament*-style teleportation experience where you can walk backwards or sideways into a portal and keep moving in that direction on the other side.

### Trigger Tricks
Keep track of live players touching a trigger and do stuff to them.

### Breakable Door
Calculates an appropriate amount of health to give breakable doors on a deathrun course, that are typically used to slow down the runners so they don't rush too far ahead too quickly. Multiplies the number of live reds by the typical average 'damage per second' of a melee weapon, resulting in an average break time that scales appropriately with player count. In essence, if there's only one runner, the door or plank will break in one second, whereas with multiple runners, the time will be increased, giving them chance to catch up.

## Entities
### game_text
Functions attached to game_text entities that enable you to give it a new message and display it straight away. Scripting enables you to insert live data like scores and times rather than needing to create tens or hundreds of AddOutput inputs.

### point_viewcontrol
Facilitates multiple players using the same point_viewcontrol. Useful when making cutscenes. 

### deparent_point_viewcontrol
Just prior to round restart, iterate over all point_viewcontrol cameras and clear their parents. This prevents the entity from being deleted when its parent is deleted on round restart.

## General Stuff in the 'matty' folder
### Feedback viewer
Display feedback from playtesting sessions as training annotations in the world. Annotations expand and collapse when you get close to them and move further away. Designed for the playtest comment scripts our plugin produces but could be adapted to work with TF2Maps VMFs.

### Holidays
* Automatically trigger named logic_relays when a holiday is active
* Check if a holiday is active using scripting
* Supports all valid TF2 holidays
* Supports custom holidays using date ranges
* Supports falling back to a date range when the server is forcing a holiday using a console variable
* Optionally force a holiday on or off for testing
* Priority system that 'triggers' the most important holiday(s) when multiple are active (so you don't get a Hallowe'en-themed Christmas)

### Jukebox
A music player designed for deathrun mappers who want to have multiple music tracks but want to avoid repeats. Playlists are stored in global scope so are not affected by round restarts. This ensures that they are played through from start to finish before repeating.
It will loop MP3 tracks for you and can print track names to chat.

### Sky Cameras
Enables you to have multiple 3D skyboxes and to control which one each player sees.

### Stocks 2
A collection of time-saving functions that are used by some of my scripts. It also makes it easier for mappers to create short, one-line VScript outputs.
* CTFPlayer methods for getting name and Steam id
* Convenience functions for printing messages to chat and the HUD
* Quickly create arrays of players matching criteria (e.g. live reds, no bots, within a radius)
* Versatile, easy-to-use teleport function that removes the need for large teleport triggers
* All constants are folded into root scope and there are additional helpful ones from the SDK wiki

### Thirdperson
Easily put players into and out of thirdperson using inputs. Typically used in platforming games. Respects the player's preference if they have used a server plugin to put themselves into thirdperson. Returns players to first person on round restart.

### Worldtext
Functions to make the act of updating and display the content of point_worldtext entities simpler. '//' is replaced with a new line, allowing you to make messages in Hammer that are later displayed with line breaks. Has a basic phrase system that replaces the message with a longer one from the root script scope, enabling you to store your strings in a script rather than having to recompile the map.

## Map-specific scripts
* Steamworks Extreme main script
* Castle Steveh main script
* Deathrun button automation and cooldown noise
