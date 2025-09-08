/*
	Playlists for use by Jukebox v0.3
	=================================

	For an example playlist and explanatory text, please scroll down past the template.

	Packing music
	-------------
	If you do not use a soundscript for your music tracks, they will not be packed automatically by apps
	such as CompilePal. Instead, you must pack them manually, or create a pack list text file.
	Jukebox has a function you can use to generate a pack list from your playlists.
	I will detail how to use that below.

	Alternatively, CompilePal has some custom syntax you can add to a VScript file, which
	causes it to pack a file. This is easier to use but requires you to add
	a comment for each track. I have added them to the template to demonstrate.

	Using Jukebox's packlist function to make a pack list for CompilePal:
		Load your map and in the console type:
			script jukebox.CreatePacklist("C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf")
		If you installed Team Fortress 2 somewhere else, then use that path. You should use forward slashes (/).
		This will create a packlist you can use with CompilePal, in tf/scriptdata/jukebox.
		If you store your assets in a folder in tf/custom then you must use that path:
			script jukebox.CreatePacklist("C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/custom/my_assets")

*/

playlists.course <- {
	shuffle = true
	tracks = [{
			file = "mymap/music/track01.mp3"
			length = 120.0
			name = "Artist = Track Name"
		}
		// !CompilePal::IncludeFile("my_project/music/my_music_file.mp3")
		{
			soundname = "mymap.music.track01"
			length = 120.0
			name = "Artist = Track Name"
		}
		// !CompilePal::IncludeFile("my_project/music/my_music_file.mp3")
	]
}

playlists.minigames <- {
	tracks = [{
			file = "mymap/music/minigame01.mp3"
			length = 60.0
		}
		// !CompilePal::IncludeFile("my_project/music/my_music_file.mp3")
		{
			soundname = "mymap.music.minigame01"
			length = 60.0
		}
		// !CompilePal::IncludeFile("my_project/music/my_music_file.mp3")
	]
}

// ----------------------------------------------------------------------------------------------------

return; // this ensures the example playlist underneath is not added

/*
	Example Playlist
	----------------

	Create one of these tables for each playlist you wish to make.
	Group tracks for certain areas together in the same playlist.
	Or create one playlist for your whole map/deathrun course.
*/

playlists.playlist_name <- {
	tracks = [
		// track #1
		{
			file = "my_map/music/track01.mp3" // .wav or mp3
			length = 163.227 // specify a length if you want it to repeat or progress automatically
			name = "Gamey McGameFace - My Game is Cool" // specify a track name if you want it to be printed to chat when played
		},
		// track #2
		{
			soundname = "MyMap.Music.BigMapper" // here we use a soundscript sound
			length = 168.687
			name = "Mappertron - Big Mapper (Hammer++ remix)"
			has_cuepoint = true // the file is a looping .wav with a cue point. this slightly changes how the script repeats the track, making it more seamless
		},
		// track #3
		{
			file = "my_map/music/track06.mp3"
			relay = "relay_boss" // this logic_relay will be triggered when this track plays
			// note this file does not have a length specified, so the script cannot repeat it or progress the playlist
		}
	]

	// optional playlist properties
	// you only need to add these if you want to set them
	// they will use their default settings otherwise.
	shuffle = true // default: false
	mode = "loop_list" // playlist mode. default: "loop_tracks"
	transition = "fade_out" // transition style. default: "instant"
	fade_time = 3.0 // fade transition duration
};

/*
	Playlist Name
	-------------

	playlist_name
		The name of your playlist. You will use this when loading it and playing tracks from it in Hammer.

	Track Data
	----------

	file
		MP3 or .wav file relative to tf/sounds. e.g. mymap/music/track01.mp3
		The script doesn't know if a sound file is present, so if you use an incorrect filepath/name,
		the track will just be silence.

	soundname
		A game sound name, from your custom soundscript file.
		The script will know if the soundscript sound exists or not when the playlist is loaded, and will
		print an error to console, which is very useful for debugging.
		Using a soundscript will guarantee CompilePal will pack your music!
		Please add a '#' character to the start of the sound's wave value in your soundscript.
		This ensures the music is played using the music channel, and is volume controllable by clients.

	length
		Duration of the track as a float value (e.g. 153.247).
		To get this, open the track's properties in a music player like foobar2000,
		or a wave editor like GoldWave or Audacity.

		The length is necessary if you want the script to automatically repeat the track if it is an MP3 file,
		or a .wav file without a cue point, or if you want the script to automatically progress onto the next
		track in the playlist, if the playlist is configured for it. TF2 server does not know the length of a music file itself.

		You do not need to specify a length if the music does not need to be repeated, or if it is
		a looping .wav file with a cue point.

	has_cuepoint
		Set this to true if the music file is a looping .wav file (it has a cuepoint at its end).
		If a length has been set, the script will not repeat the music track itself when it reaches the end.
		Instead, it will allow the client to loop it itself, which is more seamless.
		This results in a slightly better player experience, especially if the track is very short.

	relay
		The targetname of a logic_relay to Trigger when this track is played.

	Playlist Properties
	-------------------

	shuffle
		The play order of the tracks will be shuffled oncewhen first loaded.
		When using PlayNext to play the next track in a playlist, it will be different from the track list
		order specified in this file. This is useful in providing the appearance of randomisation
		in your map whilst ensuring there are no repeats.

		Note: This does not change the original track numbers. You can still use them to play specific tracks.

	mode
		1. "loop_tracks"
			Jukebox will loop the track until told to stop or change.
			This is the default option, so if you want this behaviour you do not need to add this option.
		2. "loop_list"
			Jukebox will play each track in the playlist then repeat the playlist.

	transition
		1. "instant"
			Tracks will be played normally with no fading between them.
		2. "fade_out"
			The track will fade out before the next one plays.

	fade_time
		When using "fade_out" transition, this is the time it takes for each track to fade out.
		The next track will begin to play half-way through this period. So if the fade time is 3.0 seconds,
		the next track begins playing at 1.5. Note that the next track does not fade in.
*/