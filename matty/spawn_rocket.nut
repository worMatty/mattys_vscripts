/**
 * This script was taken from the VDC wiki. I was using it to experiment with rocket entities,
 * traces and angles.
 * The sad fact is we cannot set the damage of a rocket projectile directly as that property
 * is inaccessible to VScript (at the moment). You could instead create a tf_point_weapon_mimic
 */

local spawn_points = [];

local spawn_point = null;
while (spawn_point = Entities.FindByName(spawn_point, "rocket_spawn")) {
	spawn_points.push(spawn_point);
}

function SpawnRocket() {
	foreach(spawn_point in spawn_points) {
		local rocket = SpawnEntityFromTable("tf_projectile_rocket", {
			basevelocity = 250
			// teamnum = activator.GetTeam()
			teamnum = 3 // blue
			origin = spawn_point.EyePosition() + spawn_point.EyeAngles().Forward() * 32
			angles = spawn_point.EyeAngles()
		})

		// rocket.SetOwner(activator) // make it not collide with owner and give proper kill credits
	}
}

function CreateRocketSpawner() {
	local spawner =
}