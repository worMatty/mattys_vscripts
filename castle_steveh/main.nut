// Castle Steveh 2d VScript

IncludeScript("matty/stocks2.nut");

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