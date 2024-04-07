// clear parent on all cameras right before round restart
function OnGameEvent_scorestats_accumulated_update(params) {
	local camera = null;
    while (camera = Entities.FindByClassname(camera, "point_viewcontrol")) {
        EntFireByHandle(camera, "ClearParent", null, -1, null, null);
    }
}

// hook game event just after entity spawn, avoiding ClearGameEventCallbacks
function Precache() {
    __CollectGameEventCallbacks(self.GetScriptScope());
}
