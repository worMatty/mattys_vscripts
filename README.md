# mattys_vscripts
Script for various things. Mainly Deathrun-focused. Most are functional, some are work-in-progress and may have bugs.
## Deathrun
### Boss Bar
Monitor the health of one or more entities and players, combining their health and maximum health into one set of values and applying it to the Merasmus boss bar. If you have an arena in your deathrun map, you can use this to show the health of the activator(s). Alternatively, you can use it with a 'boss', as long as the entity(s) has/have health.
### Health Scaling
Easily scale the health of the blue team players based on the number of live reds. Used for arena fights. Raises max health rather than overhealing, and scales down health from health packs to match the class's normal amount. Caps damage from backstab hits against blue to 300 HP per hit.
### Speedlane
Applies a speed boost to players touching a trigger. Useful in making an omnidirectional speedlane instead of using two trigger_pushes.
### Teleport Player
An alternative to `trigger_teleport` which presently nullifies player speed when they arrive, preventing them falling back into the reverse teleporter. The original plan was to alter player momentum to match their new angles but at the time I couldn't figure out how to do it. If you want this, ask me and I'll focus on it.
### Trigger Tricks
Do the following stuff to people inside a trigger:
* Kill them
* Kill them silently
* Stun them (you can supply arguments!)
* Hurt them
## Entities
### `game_text`
Functions to re-use a single game_text easily.
* Immediately change and display the message without needing to use `AddOutput message` and a delayed `Display`
* Display to a single player
* Display to a team
* Display to everyone

Should be compatible with `game_text_tf` since it uses the same output but I haven't checked all the functions.
### `point_worldtext`
Basic script which doesn't add much, but does have built-in phrase support. Put `phrase.whatever` in the `message` field and add the phrase to the file. When the entity spawns, the message will be changed to the phrase in the file. This is useful if you need to re-use the same phrase or want to use a line break, because line breaks in Hammer strings don't work when the map is run on a dedicated server.
## Matty
### Holidays
* Automatically trigger named logic_relays when a holiday is active
* Check if a holiday is active using scripting
* Supports all valid TF2 holidays
* Supports custom holidays using date ranges
* Supports falling back to a date range when the server is forcing a holiday using a console variable
* Optionally force a holiday on for testing
* Work-in-progress support for holiday priorities. e.g. If multiple holidays are active, only those with the highest equal priority level will have their logic triggered.
### Jukebox
Work-in-progress script to handle looping background music, crossfading between tracks, playlists etc.
### Math Game
An example of a maths-based minigame using buttons and `point_worldtext`.
### Player Lists
Implements a class for the easy creation of lists of players filtered by specific conditions, e.g. team, life state, etc. Supports chaining methods, so for example you can do `Players().Team(2)` to get all red players. Returns an instance of the `Players` class by default, so add `.players` to the end to get the internal array of player instances.
Future plans are to filter by proximity to something, filter by area (maybe named nav area) and some other stuff I can't recall. Check the script to see all the filter possibilities.
### Stocks
A bunch of common-use functions.
### Stocks 2
New version of Stocks that's in-development.
### Teleport
Intended to be used to replace huge trigger brushes when teleporting players, to avoid exceeding the number of touch links. Includes functions to easily teleport arbitrary groups of players to a single destination, a set of destinations with the same name, and to arrange players in a grid around the destination, so they don't all get teleported to the same spot. Use with Player Lists for extra Clever Points.
### Training Message
Basic implementation of the TF2 Training Mode HUD message. While the effect is nice, there are some side effects, so you should read the information in the script. Please don't overuse this! Instead, use it in a similar fashion to its original purpose - to direct players with single objectives. Potentially useful in minigames and Warioware-style games.
### Trigger Thirdperson
Players entering this volume will go into thirdperson, and will return to firstperson when stepping out. This is really good for situations where the player needs visibility of themselves to understand the nature of an effect that's been applied to them. For examples of this, see Left 4 Dead, or taunting in TF2, or being on the receiving end of a stun!

Useful in minigames where you're surrounded by other players and need to have a greater view of the environment. If the player is already in thirdperson because the server supports that, then then player's view state will not be affected.
## Scripts for Others
### SpookyToad - Rockets
Mecha Hitler missile launcher management.
## Steamworks Extreme
In-development scripts for this deathrun map of mine. In the future I will split out the global Deathrun functions into a separate Deathrun map script for use by other mappers. 
