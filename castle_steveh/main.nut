// Castle Steveh 2d VScript

IncludeScript("matty/stocks2.nut");

local respawn_cost = 100;

function RoundActive() {
	// easy mode
	local reds = Players().Team(TF_TEAM_RED).Array();

	if (reds.len() <= 15 && reds.len() > 0) {
		EntFire("relay_easy_mode", "Trigger");
	}

	// enable gallery teleporter
	foreach(player in reds) {
		player.ValidateScriptScope();
		if ("gallery_ticket" in player.GetScriptScope() && player.GetScriptScope().gallery_ticket == true) {
			EntFire("relay_open_gallery", "Trigger");
			break;
		}
	}
}

function CheckForGalleryTicket() {
	activator.ValidateScriptScope();
	if ("gallery_ticket" in activator.GetScriptScope() && activator.GetScriptScope().gallery_ticket == true) {
		EntFire("relay_gallery_admission", "Trigger", null, 0, activator);
	}
}

function GrantWinnerTicket() {
	activator.ValidateScriptScope();
	activator.GetScriptScope().gallery_ticket <- true;
}

/**
 * Attempt to purchase a respawn of a red player.
 * Successful transaction results in red player respawning, teleporting to activator and a sound & response played.
 * Cost is deducted from activator wallet.
 * @return {instance} Script handle of resurrected player if the transaction was successful, or null if not
 */
function BuyRespawn() {
	local cash = activator.GetCurrency();

	if (cash >= respawn_cost) {
		local player = RespawnOneRed();

		if (player != null) {
			// teleport player and play sound & response
			TeleportStuff(player, activator);
			PlaySound("misc/halloween/duck_pickup_pos_01.wav", { volume = 0.5, source = player });
			EntFireByHandle(player, "SpeakResponseConcept", "TLK_RESURRECTED", 0.5, activator, caller);

			// deduct cost and announce action
			cash -= respawn_cost;
			activator.SetCurrency(cash);
			ChatMsg(null, activator.CName() + " paid $" + respawn_cost + " to respawn " + player.CName());

			return player;
		} else {
			ChatMsg(activator, "There are no dead reds to respawn");
			return null;
		}
	} else {
		ChatMsg(activator, "You don't have enough cash to purchase a respawn");
		return null;
	}
}

/**
 * Pick a dead red player and respawn them
 * @return {instance} Script handle of the respawned player, or null if there were no dead players
 */
function RespawnOneRed() {
	local candidates = Players().Team(TF_TEAM_RED).Dead().Shuffle().Array();
	if (candidates.len() == 0) {
		return null;
	}
	local player = candidates[0];
	player.ForceRespawn();
	return player;
}

/**
 * Add a think to zombie spawners which enables them while reds are within 512 units
 */
function OnPostSpawn() {
	local CheckForReds = function() {
		local enabled = !(NetProps.GetPropInt(self, "m_iDisabled"));
		local players_nearby = (Players().Radius(self.GetOrigin(), 512.0).Team(TF_TEAM_RED).players.len());

		if (players_nearby) {
			if (!enabled) {
				EntFireByHandle(self, "Enable", "", -1, null, null);
			}
		} else if (enabled) {
			EntFireByHandle(self, "Disable", "", -1, null, null);
		}

		return 1;
	};

	local zombie_spawners = FindAllByName("zombie_outerfloor");

	foreach(spawner in zombie_spawners) {
		spawner.ValidateScriptScope();
		spawner.GetScriptScope().CheckForReds <- CheckForReds;
		AddThinkToEnt(spawner, "CheckForReds");
	}
}

function FindAllByName(name) {
	local ents = []
	local ent = null;

	while (ent = Entities.FindByName(ent, name)) {
		ents.append(ent);
	}

	return ents;
}