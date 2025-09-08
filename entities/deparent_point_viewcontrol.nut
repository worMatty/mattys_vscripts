/*
    Go through each point_viewcontrol and clear their parent
    just before round end. This prevents them being killed.
*/

local EventsID = UniqueString();

getroottable()[EventsID] <- {
	// clear parent on all cameras right before round restart
	function OnGameEvent_scorestats_accumulated_update(params) {
		local camera = null;
		while (camera = Entities.FindByClassname(camera, "point_viewcontrol")) {
			camera.AcceptInput("ClearParent", null, null, null);
		}
	}

	// clean up event hooks before round restarts
	OnGameEvent_scorestats_accumulated_update = function(_) {
		delete getroottable()[EventsID];
	}
}

local EventsTable = getroottable()[EventsID];

foreach(name, callback in EventsTable) {
	EventsTable[name] = callback.bindenv(this)
	__CollectGameEventCallbacks(EventsTable)
}