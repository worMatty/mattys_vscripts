/*
	Thirdperson v2.3
	By worMatty

	Put players into thirdperson and back into firstperson.
	Very useful for minigames where the player benefits from seeing themselves, such as spinners,
	platforming, or when the player is affected by something such as a loss of control effect.

	If a player has had their perspective changed via external means, such as a server plugin,
	the script will not change it, out of respect for their preference.

	Usage:
		Add the script to a logic_script.

		If you want to put players in and out of thirdperson while inside a trigger,
		add the following outputs to it:
			OnStartTouch > !activator > RunScriptCode > self.SetThirdPerson()
			OnEndTouch > !activator > RunScriptCode > self.SetFirstPerson()

		If you want to put all players into and out of thirdperson using logic, do this:
			OnWhatever > player > RunScriptCode > self.SetThirdPerson()
			OnWhatever > player > RunScriptCode > self.SetFirstPerson()

		If you only want to put live red players into and out of thirdperson, do this:
			OnWhatever > player > RunScriptCode >
			if (self.IsAlive() && self.GetTeam == Constants.ETFTeam.TF_TEAM_RED) self.SetThirdPerson()

		Players will be returned to firstperson on round restart.
		If you do not want this to happen, send the following input to any entity, including this one:
			OnWhatever > worldspawn > RunScriptCode > thirdperson.firstperson_on_round_restart = false
*/

/*
	Changelog
		2.3
			Changed how the script works.
			It now adds two functions to CTFPlayer, SetThirdPerson() and SetFirstPerson().
			Properties that track if the player is in thirdperson or should be ignored are stored on the player.
			Players are still put back in firstperson on round restart but this is now able to be disabled.
			The mapper can set thirdperson.firstperson_on_round_restart to false.
			CTFBot is given dummy functions to prevent errors when calling inputs on bots.
		2.2
			Improved documentation
			Script searches for all triggers with the same targetname as those entered in EntityGroup fields
			Removed the player array helper functions as they are superceded by those in stocks2.nut.
		2.1
			MakeTP and ReturnToFP can be used with CallScriptFunction and activator
*/

if (!("MakeThirdPerson" in CTFPlayer)) {
	getroottable().thirdperson <- {
		firstperson_on_round_restart = true
	};

	local methods_props = {
		in_thirdperson = null
		ignore_thirdperson = null

		/**
		 * Put player into thirdperson.
		 * If a player was put into thirdperson by external means when this is called,
		 * the player will be marked to be ignored by future perspective changes from the script.
		 */
		MakeThirdPerson = function() {
			// don't change players who control their own perspective
			if (this.ignore_thirdperson) {
				return;
			}

			// player is already in thirdperson perspective and we did not put them there
			if (NetProps.GetPropInt(this, "m_nForceTauntCam")) {
				if (this.in_thirdperson == false) {
					this.ignore_thirdperson = true; // mark them to be ignored
				}
			}
			// make them thirdperson
			else {
				this.in_thirdperson = true;
				this.AcceptInput("SetForcedTauntCam", "1", null, null);
			}
		}

		/**
		 * Put the player into first person.
		 * Will only affect players that were previously put into thirdperson by the script.
		 */
		MakeFirstPerson = function() {
			// player was put in thirdperson by the script and is still in thirdperson perspective
			if (this.in_thirdperson && NetProps.GetPropInt(this, "m_nForceTauntCam")) {
				this.in_thirdperson = false;
				this.AcceptInput("SetForcedTauntCam", "0", null, null);
			}
			this.ignore_thirdperson = null;
		}
	}

	foreach(key, val in methods_props) {
		CTFPlayer[key] <- val;
		CTFBot[key] <- (typeof val == "function") ? function() {
			return;
		} : null; // give bots a dummy function
	}
}

if (thirdperson.firstperson_on_round_restart) {
	EntFire("player", "RunScriptCode", "self.MakeFirstPerson()", -1);
}


// Notes
// --------------------------------------------------------------------------------------------------------------

/*
	Notes on the 'forced taunt cam perspective' property

	Forced Taunt Cam Perspective (FTCP) can only be enabled using an input on the player.
	When enabled, the player's property m_nForcedTauntCam is set to 1.
	When taunting, this property is not affected!
	When finishing a taunt, this property will not be reset and the player will remain in FTCP!
	This makes it ideal for forcing thirdperson because it's not overridden by taunts.
	This script checks if a player is already in FTPC on entrance, and if so, does not change it at all.
	This respects server plugins which allow players to freely toggle thirdperson.
*/