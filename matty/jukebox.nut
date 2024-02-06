/**
 * Jukebox v0.2.2 by worMatty
 *
 * Features:
 * * Simplifies the playing of music track playlists
 * * Stores playlists globally so tracks do not repeat
 * * Optionally shuffle the playlist on load and cycle through it
 * * Precaches all music files for you
 * * Only spawns one ambient_generic while playing
 * * Replays a track when it finishes, without needing to use a wave file and cue point
 * * Loads playlists from a separate file
 * * Prints track name to chat on play (leave the 'name' field blank to stop this)
 *
 * Usage:
 * 1. Add jukebox.nut to a logic_script, and any playlist files *after* it.
 *    Playlist files can live anywhere and be named anything.
 * 	  e.g. mapname/playlists.nut, mapname_music.nut
 * 2. To play the next track in a playlist, do
 * 		RunScriptCode worldspawn jukebox.PlayNext(`playlist_name`)
 *    Any currently playing track will be stopped automatically.
 * 	  This function loads the specified playlist into the jukebox.
 *    Subsequent playing functions use the loaded playlist when none is specified.
 * 3. To stop the jukebox, do
 * 		RunScriptCode worldspawn jukebox.Stop()
 * 	  Alternatively, fade out the current track using
 * 		RunScriptCode worldspawn jukebox.FadeOut(3.0)
 *
 * Music tracks are stopped on round restart by the game because they are played using
 * an ambient_generic (named `jukebox`). This is by design.
 * Sound files are played through the music channel by the script. It does this by
 * prefixing the filepath with '#'. You should not add this character yourself.
 * However, if you use a soundscript sound, you need to add the '#' in the soundscript.
 *
 * More functions and arguments:
 * PlayNext() with no arguments
 * 		Play the next track in the currently loaded playlist.
 * PlayTrack(track, playlist)
 * 		Specify a track by instance, number or `search string`.
 * 		If the second argument, `playlist`, is not specified, the currently-loaded playlist will be used.
 * 		A track's number is the same as its position in the playlist file, beginning with 1.
 * 		The string search will check track filename, soundname and name, and is case-sensitive.
 * 		If not found in loaded playlist, or no playlist is loaded, it will check all playlists.
 * FadeOut(duration)
 * 		Fade the currently playing track out over the specified number of seconds. Takes a float.
 * Please see the ::jukebox table functions below for full details.
 *
 * Packing your music:
 * CompilePal will not find your music so you need to create a list file.
 * Load your map and in the console type:
 * 		script jukebox.CreatePacklist("C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf")
 * If you installed Team Fortress 2 somewhere else, then use that path. You should use forward slashes (/).
 * This will create a packlist you can use with CompilePal, in tf/scriptdata/jukebox.
 * If you store your assets in a folder in tf/custom then you must use that path:
 * 		script jukebox.CreatePacklist("C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/custom/my_assets")
 */

/*
Changes:
0.2.2
Created a new function to assist with making a list of your music files so you can pack them more
easily using CompilePal or BSPZIP. See the notes above for how to use jukebox.CreatePacklist().

0.2.1.1
Updated documentation to remove reference to deleted functionality, where calling PlayNext()
with no playlist loaded would pick a random track.
Removed PlaySomething() from documentation.
Documentation cleanup.
Removed line print to console when loading a playlist.

0.2.1
Better documentation
Removed PlaySomething() and the failsafe which played *any* track when you tried to PlayNext() with
no playlist loaded.
Removed PlayPlaylist() in favour of just PlayNext().
Added return Track instance to PlayNext().
Added return Track instance to PlayTrack().
Removed last_played time from tracks as it wasn't used.
Added a string type check to the Track constructor for the 'name' slot.

0.2
Tracks now have a `relay` slot to specify a logic_relay that will be triggered when the track is played.
Playlists loaded from multiple logic_scripts is now supported.
New function: PlayTrack() - accepts a track number (integer) or search string.
Playlist structure has changed. Tracks now live in an array, and there is a shuffle option.
*/



// Local stuff - run each round
// --------------------------------------------------------------------------------

playlists <- {};

function Precache() {
	// load playlists from scope if they do not exist
	foreach(key, value in playlists) {
		if (!(key in jukebox.playlists)) {
			local playlist = Playlist(value);

			if (playlist.tracks.len()) {
				jukebox.playlists[key] <- playlist;
				printl(__FILE__ + " -- Added playlist '" + key + "'");
			} else {
				error(__FILE__ + " -- Playlist contains no tracks: '" + key + "'\n");
			}
		}
	}

	jukebox.RoundReset();
	self.TerminateScriptScope(); // playlists table no longer needed post import
}


// Global stuff - run once
// --------------------------------------------------------------------------------
if ("jukebox" in getroottable()) {
	return;
	// tip: Type this in server console to fully reset jukebox for testing:
	// script delete jukebox
}

/**
 * Jukebox root scope
 * All the methods, playlists and their tracks are stored in here.
 * You can see the functions available to you and read how to use them.
 */
::jukebox <- {
	playlists = {}
	playlist = null // loaded playlist
	sound_ent = null // ambient_generic
	playing_track = null

	/**
	 * Load and play the next track in the playlist
	 * That track is then moved to the back of the playlist.
	 * Uses the currently-loaded playlist if none is specified
	 * @param {string} _playlist The playlist to play from
	 * @return {Track} Track instance if one was successfully selected and played, null if not
	 */
	function PlayNext(_playlist = null) {

		// specified a playlist
		if (_playlist != null) {
			if (!LoadPlaylist(_playlist)) {
				return null;
			}
		}

		// use loaded playlist
		if (playlist != null) {
			local track = playlist.LoadNextTrack();
			Play(track);
			return track;
		}

		error(__FILE__ + " -- PlayNext -- No playlist specified or loaded\n");
		return null;
	}

	/**
	 * Play a specific track
	 * Track number requires a playlist is loaded
	 * Note: If using a search string, the loaded playlist will be searched,
	 * and then all others will be searched.
	 * @param {any} track Takes track instance, track number or search string
	 * @param {string} _playlist Playlist name to load, or null to use the currently-loaded playlist
	 * @return {Track} Track instance if one was successfully found and played, null if not
	 */
	function PlayTrack(track, _playlist = null) {
		// track is a track instance
		if (track instanceof Track) {
			Play(track);
			return track;
		}

		// load playlist if specified
		if (_playlist != null) {
			if (!LoadPlaylist(_playlist)) {
				error(__FILE__ + " -- LoadPlaylist -- Playlist '" + _playlist + "' not found\n");
				return null;
			}
		}

		// track is an integer (track number)
		if (typeof track == "integer") {

			// no playlist loaded
			if (playlist == null) {
				error(__FILE__ + " -- PlayTrack -- Can't play track number '" + track + "' as no playlist is loaded\n");
				return null;
			}

			// track number falls within range
			if (track > 0 && track <= playlist.tracks.len()) {
				track = playlist.tracks[track - 1];
				Play(track);
				return track;
			}
			// track number falls outside range
			else {
				error(__FILE__ + " -- PlayTrack -- Track number '" + track + "' falls outside tracklist range\n");
				return null;
			}
		}

		// track is string
		if (typeof track == "string") {
			local result = null;

			// search current playlist if loaded
			if (playlist != null) {
				result = playlist.FindTrack(track);

				if (result != null) {
					Play(result);
					return result;
				}
			}

			// search all playlists if none loaded
			foreach(list in playlists) {

				// skip loaded playlist
				if (list == playlist) {
					continue;
				}

				result = list.FindTrack(track);
				if (result != null) {
					break;
				}
			}

			if (result != null) {
				Play(result);
			} else {
				error(__FILE__ + " -- PlayTrack -- Could not find track named '" + track + "'\n");
			}

			return result;
		}
	}

	/**
	 * Stop the current track
	 */
	function Stop() {
		if (sound_ent != null && sound_ent.IsValid()) {
			AddThinkToEnt(sound_ent, null);
			EntFireByHandle(sound_ent, "StopSound", null, -1, null, null);
			EntFireByHandle(sound_ent, "Kill", null, -1, null, null);
		}

		sound_ent = null;
		playing_track = null;
	}

	/**
	 * Fade the current track out over a duration
	 * Fade out continues to happen even if a new track is played
	 * @param {float} duration The time it takes to fade out and destroy the ambient_generic
	 */
	function FadeOut(duration) {
		if (sound_ent != null && sound_ent.IsValid()) {
			AddThinkToEnt(sound_ent, null);
			EntFireByHandle(sound_ent, "FadeOut", duration.tostring(), -1, null, null);
			EntFireByHandle(sound_ent, "Kill", null, duration.tostring(), null, null);
		}

		sound_ent = null;
		playing_track = null;
	}

	/**
	 * Load a playlist into the jukebox
	 * @param {string} name Name of the playlist
	 * @return {bool} True if found and loaded, false if not
	 */
	function LoadPlaylist(name) {
		if (name in playlists) {
			playlist = playlists[name];
			return true;
		} else {
			error(__FILE__ + " -- LoadPlaylist -- Playlist not found: " + name + "\n");
			return false;
		}
	}

	/**
	 * Play a track
	 * Spawns an ambient_generic if one does not exist.
	 * Adds a think function to replay if the sound is not a cue point wave.
	 * @param {Track} track Track instance to play
	 */
	function Play(track) {
		Stop();

		sound_ent = SpawnEntityFromTable("ambient_generic", {
			targetname = "jukebox"
			message = (track.soundname != null) ? track.soundname : "#" + track.file
			spawnflags = 17
			health = 10
		});

		EntFireByHandle(sound_ent, "PlaySound", null, -1, null, null);
		playing_track = track;

		// loop non-looping files
		if (!track.cue) {
			AddReplayThink(track);
		}

		// fire relay if specified
		if (track.relay) {
			EntFire(track.relay, "Trigger");
		}

		// print track name to chat
		if (track.name) {
			ClientPrint(null, Constants.EHudNotify.HUD_PRINTTALK, "Now playing: " + track.name);
		}
	}

	/**
	 * Add a think function to the ambient_generic to replay it after the track's duration
	 */
	function AddReplayThink(track) {
		sound_ent.ValidateScriptScope();

		local scope = sound_ent.GetScriptScope();

		scope.played <- Time();
		scope.length <- track.length + 0.03;
		scope.Replay <-  function() {
			local time = Time();

			if (time >= played + length) {
				EntFireByHandle(self, "StopSound", null, -1, null, null);
				EntFireByHandle(self, "PlaySound", null, -1, null, null);
				played = time;
			}

			return -1;
		};

		AddThinkToEnt(sound_ent, "Replay");
	}

	/**
	 * Reset the variables for loaded track and playlist, and ambient_generic entity
	 * on round restart
	 */
	RoundReset = function() {
		playlist = null;
		playing_track = null;
		sound_ent = null;
	}

	/**
	 * Create a packlist for use with CompilePal to pack all your music
	 * Stores the file in tf/scriptdata/jukebox/mapname_packlist.txt
	 * Add it to the 'PACK' step using the 'Include File List' parameter
	 *
	 * gamepath should look similar to this:
	 * C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/
	 *
	 * If using the custom dir, state that instead. Only one dir can be stated
	 * C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/custom/my_assets
	 *
	 * @param {string} gamepath Full path to your root asset directory. Default is C:/...
	 */
	CreatePacklist = function(gamepath = "C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/") {
		// add trailing slash if it doesn't exist
		if (gamepath[gamepath.len() - 1] != '/') {
			gamepath = gamepath + "/";
		}

		local filepath = format("jukebox/%s_packlist.txt", GetMapName());
		local buffer = "";

		foreach(playlist in playlists) {
			foreach(track in playlist.tracks) {
				if (track.file != null) {
					buffer += "sound/" + track.file + "\n";
					buffer += gamepath + "sound/" + track.file + "\n";
				}
			}
		}

		StringToFile(filepath, buffer);
		printl(__FILE__ + " -- Packlist created at " + filepath);
		print(buffer);
		printl(__FILE__ + " -- Add this to the CompilePal 'PACK' step by adding the 'Include File List' parameter");
	}
};


/**
 * Track class
 * Takes a table with the following parameters
 * Supply either a soundscript name or file, not both
 *
 * {string} soundname   Soundscript name
 * {string} file        File path and filename relative to tf without # prefix
 * {float} length       Duration of the track in seconds
 * {bool} has_cuepoint  If the track is a wave, true if it has a cue point
 *
 * @param {table} table Table of values
 */
::Track <- class {
	constructor(table) {

		// sound is a soundscript or filename
		if ("soundname" in table) {
			soundname = table.soundname;
			if (!PrecacheScriptSound(soundname)) {
				error(this + " -- soundscript entry not found: '" + soundname + "'\n");
				invalid = true;
			}
		} else if ("file" in table) {
			file = table.file;
			PrecacheSound(file);
		} else {
			error(this + " -- track with no soundname or file\n");
			invalid = true;
		}

		// cue point waves do not require a length
		if ("has_cuepoint" in table && table.has_cuepoint == true) {
			cue = true;
		} else {
			if ("length" in table && typeof table.length == "float") {
				length = table.length
			} else {
				error(this + " -- track with no length, or length is not a float\n");
				invalid = true;
			}
		}

		if ("name" in table && typeof table.name == "string") {
			name = table.name;
		}

		if ("relay" in table && typeof table.relay == "string") {
			relay = table.relay;
		}
	}

	soundname = null;
	file = null;
	length = null;
	cue = false;
	name = null;
	relay = null;
	invalid = null;
};


/**
 * Playlist class
 * Takes a playlist table structure!
 * See playlists.nut for details.
 * @param {table} table Playlist table structure
 */
::Playlist <- class {
	constructor(table) {
		tracks = [];
		playlist = [];

		// return if no tracks or list not an array
		if (!("tracks" in table) || typeof table.tracks != "array") {
			error(__FILE__ + " -- Playlist -- No track list found in playlist\n");
			return;
		}

		foreach(value in table.tracks) {
			local track = Track(value);

			if (track.invalid == true) {
				error(this + " -- a track had a problem so wasn't added to a playlist\n");
				DumpObject(value);
			} else {
				tracks.append(track);
				playlist.append(track);
			}
		}

		if ("shuffle" in table && table.shuffle) {
			ShufflePlaylist();
		}
	}

	tracks = null // track list in order they are added, used for numerical selection
	playlist = null // playlist used for loading a track on a cycle

	/**
	 * Get the next track from the playlist array
	 * @return {Track} Track instance
	 */
	function LoadNextTrack() {
		local track = playlist.remove(0);
		playlist.append(track);
		return track;
	}

	/**
	 * Shuffle the playlist
	 */
	function ShufflePlaylist() {
		local array = [];

		while (playlist.len() > 0) {
			array.push(playlist.remove(RandomInt(0, playlist.len() - 1)));
		}

		playlist = array;
	}

	/**
	 * Given a search term, checks each track filename, soundname and name
	 * in that order for a match. Returns the first result it finds.
	 * @param {string} search_term Case-sensitive search term
	 * @return {Track} Track instance if found, null if not
	 */
	function FindTrack(search_term) {
		foreach(track in tracks) {
			if (track.file != null && track.file.find(search_term) != null) {
				return track;
			} else if (track.soundname != null && track.soundname.find(search_term) != null) {
				return track;
			} else if (track.name != null && track.name.find(search_term) != null) {
				return track;
			}
		}

		return null;
	}
}


// Only development notes below

// Notes about assignment in script root:
// Defining an array in the root of a script's scope:
//      array <- []
//      local array = []
// Each method works or doesn't work with some stuff?
// If you define an object or table, use <- without local
// you must use the table slot operator when defining an instance of a class in script root


/*

## Behaviour
* Music is stopped by the game on round restart because we are using ambient_generic
    We could use EmitSoundEx but we would not be able to fade in or out unless we can change volume?
    We would need to interpolate and use multiple calls
* If a music track is not allowed to play for thirty seconds, we will start it again on the next round
* Three playlist modes: Cycle, shuffle once, random with no recent repeats

## Later stuff
* Holiday playlists
* Integrate with holidays.nut?
	* Chance to play seasonal tracks? Fallback to other playlist?

### Jukebox
Anti-short round protection options
1. Replay track if not played for longer than thirty seconds last round
2. Reposition track in next playlist slot after current round to avoid immediate repeat

### Playlists
Track Weighting

### Tracks
#### Properties
* Number of times played (full rounds only?)
* 'Intensity' rating integer
* Keywords/tags for filtering?

ficool2
if you want it to loop seamlessly then add a cue point
otherwise manual looping with vscript can also work but you will need to do ping compensation (otherwise it will be off by ~0.1s)
and the sound must be marked as streamed (* prefix) to prevent hitching (edited)

*/