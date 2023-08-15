/**
 * Simple player teleporter/ Work-in-progress
 *
 * trigger_teleport preserve's the player's momentum as they are teleported.
 * So does point_teleport.
 * This can result in players sliding back into the return teleport trigger.
 * This script effectively stops the player in-place when they arrive to stop that.
 * The original intention was to preserve momentum but change the movement direction
 * to match the destination entity but I could not work out how to do that at the time.
 * This script is being developed alongside Steamworks Extreme
 */

TeleportPlayer <- function(player, targetname)
{
	local destination = Entities.FindByName(null, targetname);

	if (destination != null)
	{
		player.SetAbsOrigin(destination.GetOrigin());
		player.SnapEyeAngles(destination.GetAbsAngles());
		player.SetAbsVelocity(destination.GetAbsVelocity());
	}
	else
	{
		printl("TeleportPlayer(): Entity with targetname '" + targetname + "' not found");
	}
}