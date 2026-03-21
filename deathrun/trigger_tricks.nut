/*
	Trigger Tricks v0.2
	Do stuff to entities inside a trigger.
	Intended for use as an easy way to re-use a spawn trigger for killing AFK players.
	But can be used to perform operations on any touching entities, provided the
	trigger's spawnflags allows them to trigger it.

	Usage:
	Add the script to a trigger.
	Send it CallScriptFunction > KillPlayers or KillPlayersSilently.
	Alternatively perform actions on the arrays directly:
		RunScriptCode > foreach(entity in touching) entity.TakeDamage(...)
		RunScriptCode > foreach(player in GetPlayers()) player.Stun(...)
		RunScriptCode > foreach(entity in GetNonPlayers()) entity.Kill()
*/

/*
	Changelog
	0.2
		Removed stun and 'kill by trigger_hurt' functions
		Code cleanup
		Default damage type now includes DMG_PREVENT_PHYSICS_FORCE to stop flinging corpses
		Changed the scope of the script 's intent to allow operations on non-player entities
*/

local worldspawn = Entities.FindByClassname(null, "worldspawn");
local DMG_GENERIC = 0;
local DMG_PREVENT_PHYSICS_FORCE = Constants.FDmgType.DMG_PREVENT_PHYSICS_FORCE;
local default_damage_type = DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE;

touching <- [];

self.ConnectOutput("OnStartTouch", "OnStartTouch");
self.ConnectOutput("OnEndTouch", "OnEndTouch");

function OnStartTouch() touching.push(activator);
function OnEndTouch() {
	local index = touching.find(activator);
	if (index != null) touching.remove(index);
	else touching = touching.filter(function(index, entity) {
		return entity.IsValid();
	});
}
function GetPlayers() return touching.filter(function(index, ent) return ent instanceof CTFPlayer);
function GetNonPlayers() return touching.filter(function(index, ent) return !(ent instanceof CTFPlayer));

function Damage(entity, amount, type = default_damage_type) {
	entity.TakeDamageCustom(self, self, self, Vector(), Vector(), amount.tofloat(), type, 0);
}
function KillPlayer(player) {
	Damage(player, player.GetHealth());
	// if (player.IsAlive()) player.TakeDamage(player.GetHealth(), 0, worldspawn); // take damage from world
}
function KillPlayerSilently(player) {
	NetProps.SetPropInt(player, "m_iObserverLastMode", 5); // third person chase cam
	local team = player.GetTeam();
	NetProps.SetPropInt(player, "m_iTeamNum", 1);
	player.DispatchSpawn();
	NetProps.SetPropInt(player, "m_iTeamNum", team);
}
function KillPlayers() foreach(player in GetPlayers()) KillPlayer(player);
function KillPlayersSilently() foreach(player in GetPlayers()) KillPlayerSilently(player);

/*
	Notes
	m_hTouchingEntities seems to be where touching entities are stored.
	It's not an array, and GetPropType returns null.
	This indicates it's not found.
*/