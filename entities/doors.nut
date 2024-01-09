/**
 * Make door sounds work without playing multiple times on a server
 * On spawn, takes the sound keyvalues and stores them in script scope
 * Hooks door outputs and plays the sounds itself from the entity
 *
 * UNFINISHED
 */

local sounds = {
    start =
    close =
    start_close =
    stop_close =
}

// Just fix the problem, Matty!

/*
Door notes

Dedicated server with 'loop move sound'

    Open
        Start moving:   Unlocked, Start
        While moving:   Start close (played once per tick, then stopped when finished. Extreme noise due to multiple instances)
        Stop moving:    Stop

    Close
        Start moving:   Start close
        While moving:   Start (played once per tick, then stopped when finished)
        Stop moving:    Stop

Dedicated server without 'loop move sound'

    Open
        Start moving:   Unlocked, Start
        Stop moving:    Stop

    Close
        Start moving:   Start close
        Stop moving:    Stop

Summary: Loop move sound is broken and should not be used. Substitute the moving sound somehow.

Sounds

Start Sound (noise1)                    DoorSound.DefaultMove
Stop Sound (noise2)                     DoorSound.DefaultArrive
Start Close Sound (startclosesound)     Start Sound (noise1)
Stop Close Sound (closesound)           Stop Sound (noise2)
Locked Sound (locked_sound)             DoorSound.DefaultLocked
Unlocked Sound (unlocked_sound)         DoorSound.Null

Open > Unlocked, Start. Stop when finished.
Close > Start close. Stop when finished



*/

// Check each field and replace with null if empty