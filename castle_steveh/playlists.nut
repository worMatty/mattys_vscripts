/**
 * Playlists for use by jukebox.nut v0.2
 */

/*
	Example:

	playlist_name	Name of your playlist. It will be used to call functions
	shuffle			Whether to shuffle the playlist when it's created
					Note this only affects the play order when playing the next track.
					You can still play specific tracks using their track number.
	file			Filepath and filename if using an MP3 or wave file
					If the sound isn't found the game will play it regardless and it will be silent
	soundname		Soundscript entry/game sound name
					If the soundscript entry can't be found, the game will know and it will not be added to a playlist!
	length			Duration of the track as a float value (e.g. 153.247).
					To get this, open the track's properties in foobar2000 or a wave editor like GoldWave or Audacity
	has_cuepoint	Supply `true` if the file is a wave format with a cue point
					No need to specify length with a cue point as the client will loop it
	relay			The string targetname of a logic_relay to Trigger when this track is played.

	playlists.playlist_name <- {
		shuffle = true

		tracks = [{
				file = "steamworks_extreme/music/core_looped_192.mp3"
				length = 163.227
				name = "Jason Dagenet - Core (OpenGameArt.org)"
			},
			{
				soundname = "Music.Mechanical_Choir"
				length = 168.687
				name = "Gobusto - Mechanical Choir (OpenGameArt.org)"
			},
			{
				file = "castle_steveh/death_egg_zone_loop.wav"
				name = "Death Egg Zone"
				has_cuepoint = true
				relay = "relay_death_egg_surprise"
			}
		]
	};
*/

playlists.arena <- {
	shuffle = true

	tracks = [{
			file = "music/hl1_song3.mp3"
			length = 131.8
			name = "Half Life (Kelly Bailey) - Vague Voices"
		},
		{
			file = "music/hl1_song10.mp3"
			length = 104.0
			name = "Half Life (Kelly Bailey) - Diabolical Adrenaline Guitar"
		},
		{
			file = "music/hl1_song14.mp3"
			length = 90.0
			name = "Half Life (Kelly Bailey) - Sirens in the Distance"
		},
		{
			file = "music/hl1_song15.mp3"
			length = 120.0
			name = "Half Life (Kelly Bailey) - Nuclear Mission Jam"
		}
	]
};
