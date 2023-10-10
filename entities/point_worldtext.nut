
/**
 * Functions to aid you in replacing the message of a point_worldtext
 *
 * Put phrases in the 'phrases' table and add 'phrases.phrase_name' to your point_worldtext's
 * message field and this script will change it on spawn
 *
 * If you want to use a line break in your message, read below
 *
 * You can use SetText to change the message. If that's all you want, you don't need this
 */

/*

Important info about strings:

ficool2 — 09/04/2023 21:35
the SetText input works
but it can eventually crash from allocating too many strings
not an issue if your strings arent unique
if they are, its possible to delete those strings
spawning an entity with the targetname of that string, setting m_bForcePurgeFixedupStrings netprop to true and killing the entity will free that string
these strings are also cleared on round restarts
dumpgamestringtable will show if your strings are 'leaking' like this

*/

/*

Info about point_worldtext and line break characters \n

if the entity's message field in Hammer contains a line break character, then when it is loaded by
a (Windows?) dedicated server, its s_zText property will be empty.

Outputs created in Hammer which set the message using AddOutput or RunScriptCode() are apparently
deleted if they contain a line break character.

The only option available appears to be to put the phrases in a script and load them from there.

*/

local phrases = {
	example = "This is an\nexample phrase"
	kill_silently = "Kill\nsilently"
	long = "Terminal text text text text\nTerminal text text text text\nTerminal text text text text\nTerminal text text text text\nTerminal text text text text\nTerminal text text text text\nTerminal text text text text\nTerminal text text text text\nTerminal text text text text\nTerminal text text text text\n"
}

// ----------------------------------------------------------------------------------------------------

function SetMessage(message) {
	// NetProps.SetPropString(self, "m_szText", message);   // this crashes the game
	message = message.tostring();
	EntFireByHandle(self, "AddOutput", format("message %s", message), -1, activator, caller);
	// EntFireByHandle(self, "CallScriptFunction", "PostSetMessage", 0.0, activator, caller);
}
// todo: Check for phrases

function OnPostSpawn() {
	local message = NetProps.GetPropString(self, "m_szText");

	if (startswith(message, "phrases.")) {
		local phrase = message.slice(8);

		if (phrase in phrases) {
			SetMessage(phrases[phrase]);
		} else {
			SetMessage("Phrase not found:\n" + message);
		}
	}
}

// ----------------------------------------------------------------------------------------------------

if (!("phrases" in getroottable())) {
	getroottable().phrases <- {};
}

foreach(key, val in phrases) {
	if (!(key in getroottable().phrases)) {
		getroottable().phrases[key] <- val;
	}
}

// old debugging stuff
// ----------------------------------------------------------------------------------------------------

// function OnPostSpawn() {
// 	local message = NetProps.GetPropString(self, "m_szText");
// 	printl(self + " message: " + message);
// }

// I was investigating if it was possible to alter the alignment of the text
// function PostSetMessage() {
// netprops
// printl(self + "m_vecMinsPreScaled = " + NetProps.GetPropVector(self, "m_vecMinsPreScaled"));
// printl(self + "m_vecMaxsPreScaled = " + NetProps.GetPropVector(self, "m_vecMaxsPreScaled"));
// printl(self + "m_vecMins = " + NetProps.GetPropVector(self, "m_vecMins"));
// printl(self + "m_vecMaxs = " + NetProps.GetPropVector(self, "m_vecMaxs"));
// printl(self + "m_vecSpecifiedSurroundingMinsPreScaled = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMinsPreScaled"));
// printl(self + "m_vecSpecifiedSurroundingMaxsPreScaled = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMaxsPreScaled"));
// printl(self + "m_vecSpecifiedSurroundingMins = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMins"));
// printl(self + "m_vecSpecifiedSurroundingMaxs = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMaxs"));

// printl(self + "m_nSurroundType = " + NetProps.GetPropInt(self, "m_nSurroundType"));

// // datamaps
// printl(self + "m_rgflCoordinateFrame = " + NetProps.GetPropInt(self, "m_rgflCoordinateFrame"));

// none of the above contained useful data

// local netprops = {};
// NetProps.GetTable(self, 0, netprops);
// printl(self + " -- Dumping netprops --");
// DumpObject(netprops);

// local datamaps = {};
// NetProps.GetTable(self, 1, datamaps);   // this crashes

// local my_lovely_table = {};
// NetProps.GetTable(self, 1, my_lovely_table);
// printl(self + " -- Dumping datamaps --");
// printl(datamaps);
// DumpObject(datamaps);
// }