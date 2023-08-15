/**
 * Jukebox
 * -------
 *
 * Work-in-progress ambient_generic music controller.
 */


/* Inputs
------
Pick a random track
Pick tracks sequentially
Pick a track based on intensity
Pick a specific track
Pick a track randomly based on weighting per track
Fade in / out (if ambient_generic)
Stop
Set volume of track / fade to volume / 'duck' for a time and volume

Settings
--------
Loop same
Play next automatically
Stop after finishing
Use specific channel

Required data
-------------
Track length
Sound file name / soundscript entry name

Possible approaches
-------------------
Each player has their own jukebox
Spawns ambient_generic for fading in and out
Put tracks into albums (sets)

Investigate
-----------
Playing a sound from a certain point
    - Grab the client command and look at the code for it
is it possible to stop a sound? */


/**
 * Notes
 *
 * It may be better to set these ambient_generics as 'NOT looping' and use 'Is Active' as their playing state.
 * Setting it to true when we start it and false when we stop it. The game should stop it itself when round restarts.
 * Update: If a n on-looping sound is 'active' it will not play. It needs to be looping to use that.
 * I suggest setting active to false when fading out and stopping.
 *
 * Consider adding Play inputs and stuff to the ambient_generic itself via entity script or attach to class.
 * We might be able to do that in this script.
 *
 * Consider spawning a logic_relay for queuing and cancelling timed outputs
 */

/**
 * Findings
 *
 * A 30.316-second track in 320kbps VBR joint stereo 44.1k MP3 misreported its duration as 13.6215s
 * When compressed to 128 it reported as 10.9971. GoldWave reports this version of the sound as MP3 (ACM)
 * The original is reported as just 'MP3'
 *
 * A 44.1k 128kbps mono sound reported by GoldWave as simply MP3 (no ACM or LAME) seemingly has no trouble with duration
 *
 * Wickot - Substance is reported as 119.839 when in reality it is 5:30.28 (330.28)
 *
 */



tracks <- {};
default_track_prefix <- "music_*";
default_fade_time <- 3.0;
trim_delay <- 0.03;

/**
 * Get/set the name of the logic_script entity the script is attached to
 * and store it in a global variable
 */
function OnPostSpawn()
{
    if (self.GetName() == null)
    {
        self.KeyValueFromString("targetname", "jukebox");
    }

    // TODO - construct track list
    // TODO - ensure track entities are configured correctly (looping flag etc.)
}


/**
 * Pick and loop play a random track
 *
 * @param {string} targetname Wildcard targetname string to match against
 * @noreturn
 */
function PlayRandom(targetname = default_track_prefix)
{
    local tracks = FindNamedSounds(targetname);

    if (tracks.len())
    {
        local index = RandomInt(0, tracks.len() - 1);
        local track = tracks[index];

        PlayLooping(track);
    }
}

// "PlayLooping(null, `music_deathegg`)"
// "CrossFadeInto(null, `music_theywant`)"

/**
 * Play a music track and set it to play itself again when it finishes.
 * This is accomplished by getting the duration of the sound and adding
 * an output to it set to fire when the time has elapsed. This output calls
 * this script entity with the LoopingTrackFinished function.
 *
 * @param {instance} entity Instance of the sound entity to play
 * @param {string} targetname Wildcard targetname string to match against
 * @noreturn
 */
function PlayLooping(entity = null, targetname = null)
{
    if (targetname != null)
    {
        entity = Entities.FindByName(null, targetname);
    }

    if (entity == null)
    {
        printl(self + " -- PlayLooping() called without a valid entity");
        return;
    }

    // TODO Stop other tracks
    FadeOutActive(default_track_prefix, 0.0);

    // Set the track as looping - necessary for the ability to stop it
    NetProps.SetPropBool(entity, "m_fLooping", true);

    // Playing the sound will set m_fActive to true
    EntFireByHandle(entity, "PlaySound", "", 0.0, null, null);

    printl(self + " -- Playing sound: " + entity + "  Duration: " + GetEntitySoundDuration(entity));
    PrintToChatAll(format("Music: %s", entity.GetName()));

    local duration = GetEntitySoundDuration(entity);

    if (duration != 0)
    {
        /**
         * 1. Add an output to the entity which calls the LoopingTrackFinished function after a delay
         *      the same duration as the track length
         * 2. When the output is fired, the function checks if the track is still active
         * 3. if the track is active, it starts it again (best method for looping wavs?)
         */

        if (EntityOutputs.HasAction(entity, "OnUser1"))
        {
            printl(self + " -- PlayLooping -- " + entity + " already has OnUser1 output");
        }
        else
        {
            EntityOutputs.AddOutput(entity, "OnUser1", self.GetName(), "CallScriptFunction", "LoopingTrackFinished", duration - trim_delay, -1);
        }

        EntFireByHandle(entity, "FireUser1", "", 0.0, entity, null);

        // TODO Replace 'is active' check with a flag in the script scope so we know we've
        // stopped it in case it detects activity while being faded out
        // Or investigate possible use of m_dpv to check if fading
    }
}

/**
 * When a music track has finished, play it from the beginning
 *
 * @noreturn
 */
function LoopingTrackFinished()
{
    local sound = activator;

    // TODO Check if we're stopping this sound via fadeout so we don't restart it
    if (IsSoundActive(sound))
    {
        printl(self + " -- LoopingTrackFinished -- Restarting " + activator);
        EntFireByHandle(sound, "StopSound", "", 0.0, null, null);
        EntFireByHandle(sound, "PlaySound", "", 0.0, null, null);
        EntFireByHandle(sound, "FireUser1", "", 0.0, sound, null);
    }
    else
    {
        printl(self + " -- LoopingTrackFinished -- " + activator + " finished and will not be restarted");
    }
}

function CrossFadeInto(entity = null, targetname = null, fade_time = default_fade_time)
{
    if (targetname != null)
    {
        entity = Entities.FindByName(null, targetname);
    }

    if (entity == null)
    {
        printl(self + " -- CrossfadeInto() called without a valid entity");
        return;
    }

    FadeOutActive(default_track_prefix, fade_time);
    EntFireByHandle(entity, "Volume", "0", fade_time / 2, null, null);
    EntFireByHandle(entity, "FadeIn", fade_time.tostring(), fade_time / 2, null, null);
}

/**
 * Stops any active ambient_generics with the given targetname wildcard
 *
 * @param {string} targetname Wildcard targetname string to match against
 * @noreturns
 */
function Stop(targetname = default_track_prefix)
{
    local entity = null;

    while (entity = Entities.FindByName(entity, targetname))
    {
        if (entity.GetClassname() == "ambient_generic" && IsSoundActive(entity))
        {
            EntFireByHandle(entity, "StopSound", "", 0.0, null, null);
        }
    }
}

/**
 * Scan for all ambient_generics matching the targetname and fade them out
 *
 * @param {string} targetname Wildcard string to match targetnames against
 * @param {float} fade_time Time the sound should take to fade out and stop
 * @noreturn
 */
function FadeOutActive(targetname = default_track_prefix, fade_time = default_fade_time)
{
    local entity = null;

    // while (entity = Entities.FindByClassname(entity, "ambient_generic"))
    while (entity = Entities.FindByName(entity, targetname))
    {
        if (entity.GetClassname() == "ambient_generic" && IsSoundActive(entity))
        {
            printl(self + " -- FadeOutActive -- Fading out " + entity + " over " + fade_time + " seconds");

            // Set the sound as being inactive so our looping code does not restart it
            // NetProp.SetPropBool(entity, "m_fActive", false);
            // TODO test if we can still fade it out and stop it if not active
            // Update: This won't work as StopSound merely sends Toggle
            EntFireByHandle(entity, "FadeOut", fade_time.tostring(), 0.00, null, null);
            EntFireByHandle(entity, "StopSound", "", fade_time, null, null);
        }
    }
}

/**
 * Generate and return an array of ambient_generics matching
 * the targetname wildcard string
 *
 * @param {string} targetname Wildcard targetname string to match against
 * @returns {array} Array of ambient_generic entities matching the targetname
 */
function FindNamedSounds(targetname)
{
    local sounds = [];
    local entity = null;

    while (entity = Entities.FindByName(entity, targetname))
    {
        if (entity.GetClassname() == "ambient_generic")
        {
            sounds.push(entity);
        }
    }

    return sounds;
}

/**
 * Display data about all found sounds.
 * Note that duration is not visible unless a client is connected.
 *
 * @noreturn
 */
function DisplayTrackData()
{
    local sounds = FindNamedSounds(default_track_prefix);

    if (sounds.len())
    {
        for (local i = 0; i < sounds.len(); i++)
        {
            local sound = sounds[i];
            printl(sound);

            printl("-- Duration: " + GetEntitySoundDuration(sound));

            printl("-- m_dpv type: " + NetProps.GetPropType(sound, "m_dpv"));
            printl("-- m_dpv size: " + NetProps.GetPropArraySize(sound, "m_dpv"));
            printl("-- m_dpv string: " + NetProps.GetPropString(sound, "m_dpv"));

            // printl("-- m_dpv 7 (fadein): " + NetProps.GetPropIntArray(sound, "m_dpv", 7));
            // printl("-- m_dpv 8 (fadeout): " + NetProps.GetPropIntArray(sound, "m_dpv", 8));
            // printl("-- m_dpv 8 (fadeout float): " + NetProps.GetPropFloatArray(sound, "m_dpv", 8));
            // printl("-- m_dpv 19 (vol): " + NetProps.GetPropIntArray(sound, "m_dpv", 19));
            // printl("-- m_dpv int: " + NetProps.GetPropInt(sound, "m_dpv"));


            // 7 and 8 are fadein and fadeout
            // 19 is vol
        }
    }
}

/**
 * Get the duration of a sound/music track
 *
 * @param {instance} entity The instance of the entity
 * @returns {float} Duration of the sound/music track
 */
function GetEntitySoundDuration(entity)
{
    local soundname = NetProps.GetPropString(entity, "m_iszSound");
    local duration = GetSoundDuration(soundname, "");

    // printl(self + " -- GetEntitySoundDuration -- GetSoundDuration(" + soundname + ") == " + duration);
    // printl(self + " -- GetEntitySoundDuration -- Entities.GetSoundDuration(" + soundname + ") == " + entity.GetSoundDuration(soundname, ""));

    return duration;
}

/**
 * Check if an ambient_generic is marked as active in its entity properties
 *
 * @param {instance} entity The instance of the entity
 * @returns {bool} True if active, false if not
 */
function IsSoundActive(entity)
{
    return NetProps.GetPropBool(entity, "m_fActive");
}