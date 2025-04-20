/*
    Personal Music v0.2
	By worMatty

	Play a music track to a client.
	Accepts soundscript sound names.

	Usage:
		Add the script to a logic_script.
		To play a track to the !activator of a trigger:
			OnStartTouch > logic_script > RunScriptCode > PlayTrack(`track_name`)
		To stop the !activator's current track:
			OnStartTouch > logic_script > CallScriptFunction > StopMusic

		If you are a VScript coder and want to use a player's handle, the functions
		will accept these as optional extra arguments. Check the function info below.

	Notes:
		* Tracks are stopped on round restart
		* If you play a track to a player, it will replace their current track
		* Playing the same track they are listening to will not interrupt playback

	Warning about caching long audio files:
		If you try to play a long audio file that has not yet been cached, it will cause a short
		freeze for affected players. The solution is to precache your music in the first round,
		before anyone has joined the server.
		Alternatively, since you are using a soundscript, try prepending an asterisk
		(the `*` character) to the wave filepath. This should cause the game to stream the
		audio file instead of caching it. I have not tested this. 
*/

/*
	Todo:
		Check if precaching is actually necessary.
		Investigate the possibility of scanning all entity outputs on first load
			for PlayTrack function calls, and precaching their tracks.
		Test if the * character in a soundscript makes caching unnecessary.
*/

/**
 * Play a track to a player
 * Emits the sound to the client so only they can hear it
 * @param {string} track Track name. Must be in the track list
 * @param {instance} player Optional player instance. Uses activator if not specified
 */
function PlayTrack(track, player = null) {
	// set activator as player if none supplied
	if (player == null && activator != null && activator instanceof CTFPlayer) {
		player = activator;
	}

	if (GetPlayerCurrentTrack(player) != track) { // player not already listening to this track
		PrecacheScriptSound(track);
		StopMusic(player);
		SetPlayerCurrentTrack(player, track);
		EmitSoundOnClient(track, activator);
	}
}

/**
 * Stop a player's currently-playing music track
 * @param {instance} player Optional player instance. Uses activator if not specified
 */
function StopMusic(player = null) {
	// set activator as player if none supplied
	if (player == null && activator != null && activator instanceof CTFPlayer) {
		player = activator;
	}

	local current_track = GetPlayerCurrentTrack(player);
	if (current_track != null) {
		StopSoundOn(current_track, player);
	}
}

/**
 * Get a player's current music track
 * @param {instance} player Player instance
 * @return {string} Name of track if one has been set, else returns null
 */
function GetPlayerCurrentTrack(player) {
	player.ValidateScriptScope();
	local scope = player.GetScriptScope();

	if ("personal_music_track" in scope == false) {
		scope.personal_music_track <- null;
	}
	return scope.personal_music_track;
}

/**
 * Set the name of the player's current track in their properties
 * @param {instance} player Player instance
 * @param {string} track Track name
 */
function SetPlayerCurrentTrack(player, track) {
	player.ValidateScriptScope();
	player.GetScriptScope().personal_music_track <- track;
}

// stop each player's music on round restart
local maxclients = MaxClients().tointeger();
for (local i = 1; i <= maxclients; i++) {
	local player = PlayerInstanceFromIndex(i);
	if (player != null) {
		StopMusic(player);
	}
}
