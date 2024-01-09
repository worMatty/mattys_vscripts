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

playlists.manual <- {
	shuffle = true

	tracks = [{
			file = "steamworks_extreme/music/city of scrap v1_0.mp3"
			length = 265.418
			name = "FoxSynergy - City of Scrap (OpenGameArt.org)"
			relay = "relay_city_of_scrap"
		},
		{
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
			file = "steamworks_extreme/music/pyro.mp3"
			length = 214.741
			name = "James Gargette - Pyro (OpenGameArt.org)"
		}
	]
};

playlists.auto <- {
	shuffle = true

	tracks = [{
			file = "steamworks_extreme/music/wickot_substance1.mp3"
			length = 330.24
			name = "Wickot - Substance (soundcloud.com/wickot - used with permission)"
		},
		{
			file = "steamworks_extreme/music/js_egg_instr1.mp3"
			length = 303.047
			name = "Music: Jun Senoue - E.G.G.M.A.N. Instrumental (Sonic Adventure 2)"
		}
	]
};