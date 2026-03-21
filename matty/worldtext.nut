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

// functions table. these will be added to point_worldtext scriptscope
local functions = {
	FormatMessage = function(message) {
		if (startswith(message, "phrases.") && "phrases" in getroottable()) { // replace phrase key with value
			message = ::phrases[message.slice(8)];
		} else { // replace // with newline
			local index = 0;
			while ((index = message.find("//")) != null) {
				message = message.slice(0, index) + "\n" + message.slice(index + 2);
			}
		}
		return message;
	}
	GetMessage = function() {
		return NetProps.GetPropString(self, "m_szText");
	}
	SetMessage = function(message) {
		message = FormatMessage(message);
		self.AcceptInput("AddOutput", "message " + message, null, null);
	}
	PostSpawnCheck = function() {
		SetMessage(FormatMessage(GetMessage())); // check the stored message, format it and set it
	}
}

// add functions to an entity
function AddFunctions(ent) {
	ent.ValidateScriptScope();
	local scope = ent.GetScriptScope();
	foreach(key, val in functions) {
		scope[key] <- val;
	}
}

// check each point_worldtext and replace messages that need fixing
function OnPostSpawn() {
	local ent = null;
	while (ent = Entities.FindByClassname(ent, "point_worldtext")) {
		AddFunctions(ent);
		ent.GetScriptScope().PostSpawnCheck();
	}
}

// old debugging stuff
// ----------------------------------------------------------------------------------------------------

// function OnPostSpawn() {
// 	local message = NetProps.GetPropString(self, "m_szText");
// 	printl(__FILE__ + " message: " + message);
// }

// I was investigating if it was possible to alter the alignment of the text
// function PostSetMessage() {
// netprops
// printl(__FILE__ + "m_vecMinsPreScaled = " + NetProps.GetPropVector(self, "m_vecMinsPreScaled"));
// printl(__FILE__ + "m_vecMaxsPreScaled = " + NetProps.GetPropVector(self, "m_vecMaxsPreScaled"));
// printl(__FILE__ + "m_vecMins = " + NetProps.GetPropVector(self, "m_vecMins"));
// printl(__FILE__ + "m_vecMaxs = " + NetProps.GetPropVector(self, "m_vecMaxs"));
// printl(__FILE__ + "m_vecSpecifiedSurroundingMinsPreScaled = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMinsPreScaled"));
// printl(__FILE__ + "m_vecSpecifiedSurroundingMaxsPreScaled = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMaxsPreScaled"));
// printl(__FILE__ + "m_vecSpecifiedSurroundingMins = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMins"));
// printl(__FILE__ + "m_vecSpecifiedSurroundingMaxs = " + NetProps.GetPropVector(self, "m_vecSpecifiedSurroundingMaxs"));

// printl(__FILE__ + "m_nSurroundType = " + NetProps.GetPropInt(self, "m_nSurroundType"));

// // datamaps
// printl(__FILE__ + "m_rgflCoordinateFrame = " + NetProps.GetPropInt(self, "m_rgflCoordinateFrame"));

// none of the above contained useful data

// local netprops = {};
// NetProps.GetTable(self, 0, netprops);
// printl(__FILE__ + " -- Dumping netprops --");
// DumpObject(netprops);

// local datamaps = {};
// NetProps.GetTable(self, 1, datamaps);   // this crashes

// local my_lovely_table = {};
// NetProps.GetTable(self, 1, my_lovely_table);
// printl(__FILE__ + " -- Dumping datamaps --");
// printl(datamaps);
// DumpObject(datamaps);
// }


/*
	Notes

	Using the following method of changing a pwt's message field crashes the game:
		NetProps.SetPropString(self, "m_szText", message);
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