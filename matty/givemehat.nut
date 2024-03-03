/**
 * Give me a hat! - v0.1.1 by worMatty, for arctic dino
 * Gives a hat to any prop_dynamic model which requests it.
 *
 * Usage:
 * 1. Add to a logic_script
 * 2. Create an output in Hammer to the logic_script with the input RunScriptCode and parameter GiveMeHat(`targetname`).
 *      Targetname is one or more prop_dynamic with attachment points suited to the hat/cosmetic.
 *      You can use a wildcard character (*)!
 * 3. Alternatively the function will take a CBaseAnimating entity instance handle. You can use this via some
 *      other code, or as a Hammer output by sending the prop_dynamic a RunScriptCode input with the following parameter:
 *      EntFire(`script_hat`, `RunScriptCode`, `GiveMeHat(activator)`, -1, self)
 *      This is useful for point_templates with name fixup.
 */

/**
 * Hat table!
 * Add the model name as a key and provide an array of hats for it to wear.
 * A hat will be picked at random for each model.
 */
hats <- {
	"models/player/heavy.mdl": [
		"models/player/items/heavy/capones_capper.mdl"
		"models/workshop/player/items/heavy/fwk_heavy_bandanahair/fwk_heavy_bandanahair.mdl"
	]
	"models/player/pyro.mdl": [
		"models/player/items/pyro/fireman_helmet.mdl"
	]
}

/**
 * Precache the hats so they don't cause a client crash
 * Note that models which don't exist will not cause a crash but will show as an error model
 */
function Precache() {
	foreach(set in hats) {
		foreach(hat in set) {
			PrecacheModel(hat);
		}
	}
}

/**
 * Give a model a hat!
 * Supply a targetname and all props will be matched. Supports wildcard *
 * Or supply an instance handle (activator, caller, self, etc.)
 * @param {string} prop Targetname of the prop(s)
 * @param {instance} prop Instance handle of the prop
 */
function GiveMeHat(prop) {
	local props = [];

	// targetname
	if (typeof prop == "string") {
		local ent = null;
		while (ent = Entities.FindByName(ent, prop)) {
			props.append(ent);
		}
	}

	// instance
	else if (typeof prop == "instance") {
		props.append(prop);
	}

	// pick and apply hat function
	local GiveHat = function(prop) {
		if (!(prop instanceof CBaseAnimating)) {
			return;
		}

		local prop_model = prop.GetModelName();

		if (prop_model in hats) {
			local model_hats = hats[prop_model];
			local len = model_hats.len();

			if (len) {
				local prop_name = prop.GetName();

				// give prop a targetname if it doesn't have one
				if (prop_name == null) {
					prop_name = "hat_recipient_" + prop.entindex();
					EntFireByHandle(prop, "AddOutput", "targetname " + prop_name, -1, null, null);
				}

				// pick a hat and spawn it on the wearer
				local hat = model_hats[RandomInt(0, len - 1)];
				local ent = SpawnEntityFromTable("prop_dynamic_ornament", {
					model = hat
					InitialOwner = prop_name
				});
			}
		}
	}

	foreach(prop in props) {
		GiveHat(prop);
	}
}