/*
Spawn something when the barrel breaks.
Fling it into the air in a random direction.
*/

ForceEnableUpgrades(2); // shows money hud element
local count = FileToString("castle_steveh/barrels.txt");
printl(__FILE__ + " -- count from file is typeof " + typeof count + " and value " + count);
count = (count == null) ? 0 : count.tointeger();

objects <- [
	bomb <- {
		classname = "prop_physics_multiplayer"
		keyvalues = {
			model = "models/props_lakeside_event/bomb_temp.mdl"
			ExplodeDamage = 120
			ExplodeRadius = 40
			OnUser1 = "!self,Break,,3.0,1"
		}
	},
	// small_money <- {
	// 	classname = "item_currencypack_small"
	// 	keyvalues = {
	// 		OnPlayerTouch = "!activator,RunScriptCode,self.AddCurrency(5),-1,1"
	// 		OnPlayerTouch = "!self,Kill,,-1,1"
	// 		OnUser1 = "!self,Kill,,10.0,1"
	// 	}
	// },
	medium_money <- {
		classname = "item_currencypack_medium"
		keyvalues = {
			// OnPlayerTouch#1 = "!activator,RunScriptCode,self.AddCurrency(10),-1,1"
			// OnPlayerTouch#2 = "!self,Kill,,-1,1"
			"OnPlayerTouch#1" : "!activator,RunScriptCode,self.AddCurrency(10),-1,1"
			"OnPlayerTouch#2" : "!self,Kill,,-1,1"
			OnUser1 = "!self,Kill,,10.0,1"
		}
	},
	// big_money <- {
	// 	classname = "item_currencypack_large"
	// 	keyvalues = {
	// 		OnPlayerTouch = "!activator,RunScriptCode,self.AddCurrency(25),-1,1"
	// 		OnPlayerTouch = "!self,Kill,,-1,1"
	// 		OnUser1 = "!self,Kill,,10.0,1"
	// 	}
	// }
];

function Precache() {
	foreach(object in objects) {
		if ("model" in object.keyvalues) {
			PrecacheModel(object.keyvalues.model);
		}
	}
}

SpawnSomething <-  function() {
	if (caller == null || !caller.IsValid()) {
		return;
	}

	local origin = caller.GetOrigin();

	// find ground position under self
	local trace = {
		start = origin
		end = origin + Vector(0, 0, -1000)
	};
	TraceLineEx(trace);

	// create object
	local object = objects[RandomInt(0, objects.len() - 1)];
	local ent = SpawnEntityFromTable(object.classname, object.keyvalues);

	if (ent == null) {
		return;
	}

	// set velocity and impulse
	local vel = Vector(RandomFloat(-45, 45), RandomFloat(-45, 45), 250);
	local angular_impulse = Vector(0, 0, RandomFloat(-300, 300));

	// debug output
	// ClientPrint(null, 2, "Velocity: " + vel + "\nAngular impulse: " + angular_impulse);
	// ClientPrint(null, 4, "Velocity: " + vel + "\nAngular impulse: " + angular_impulse);

	// teleport and add velocity
	ent.SetAbsOrigin(trace.pos + Vector(0, 0, ent.GetBoundingMins().z * -1.0));
	ent.Teleport(false, Vector(), false, QAngle(), true, vel); // *
	ent.ApplyLocalAngularVelocityImpulse(angular_impulse);

	// fire user 1 output
	EntFireByHandle(ent, "FireUser1", null, -1, null, null);

	StringToFile("castle_steveh/barrels.txt", (++count).tostring());
	printl("New count is " + count);

	// * I used SetAbsOrigin instead of Teleport because with Teleport there was a noticeable judder
	// after the bomb spawned before it got its velocity.
	// Teleport was still necessary to update its position as SetAbsOrigin did not teleport the bomb.
}
SpawnBomb <- SpawnSomething;