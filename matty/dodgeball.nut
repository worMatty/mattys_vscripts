/*
	A work-in-progress Dodgeball script by worMatty
	Version 0.1 I guess, until it's used in something
*/

/*
	Changelog
		Changes from Gamer_X's version
			* Rockets are now independent, enabling the possibility of having more than one in play
			* Think frequency is increased to per-frame, which should make rocket motion smoother
			* Rocket changes are no longer tied to think frequency, they are tied to frame time
			* Rockets switch team each time they're spawned
			* Reduced the number of entities required in the VMF
			* Add point_templates to the EntityGroup fields to spawn and kill templated entities
			* Game code and entities are only active while game is active, and are cleaned up when it stops, including templated ents
			* Game stops automatically on round end
			* Options to not remove other weapons and to change all to pyro
			* Only stock flamethrower and degreaser are allowed - i.e. weapons where the airblast functions normally
			* Script will *not* replace an existing weapon if it's allowed, to let people use their personal weapons
			* When changing class, script does not change player's desired class, so they spawn as their previous class next round
			* Rocket targetting methods expanded from just 'closest' to 'random' and 'fair'
			* Rocket increases speed over time while airborne
			* Rockets are no longer crit on spawn. Instead they have a chance to become crit and receive extra speed
			* Rocket turn rate increase smoothly while airborne and no longer has defined periods.
				This results in slightly janky initial deflection flight but makes rocket changes more predictable. May need tweaking
			* Game settings are configurable using RunScriptCode input

*/

/*
	Optional:
	* Alternate rocket team if a team member is struck dead by a rocket - done
	* Don't always start on blue team - done
	* Don't remove player's other weapons - done
	* Do not change desired class - done
	* Sound effects:
		- Rocket spawned - done
		- Rocket found new target - done
		- Rocket bounced
	* Movement code to rocket ent - done
	* Make rockets independent so we can spawn more than one - done
	* Pick a random target instead of the closest - done
	* Occasional special rockets (what for? They all one-shot)
		* Bigger blast radius?
		* Leaves behind flames?
		* Leaves behind radioactivity?
		* Additional slow-moving rocket
		* Possible to do by spawning a hidden rocket launcher and adjusting its properties?!
	* Decrease turn rate when think rate is per-frame - done
	* Multiple rockets (would require unique targets. Lots of work)
		* Would need to evaluate targets before spawning
		* Spawn a rocket for each time at the same time?
	* Increasing difficulty over time
		* Increase initial rocket speed over  by keeping track of seconds since game started
		* Would need to reduce the speed increase of rockets post deflect
	* Optionally use weapon mimic in EntityGroup
		* Multiple mimics would be stored in an array and we would rotate shooting out of them
		* If a mimic has a TeamNum KV, we would only shoot rockets owned by that team from them
	* Assign rocket spawners to rockets, creating them if they don't exist - done
	* Ramp rocket speed over time while in flight - done
		* Not sure this would be felt since the flight time is quite low
		* The idea would be to encourage long flights so the rocket reaches its target at a higher speed
		* Could encourage enemy players to get closer, though they don't need encouragement if they are fighting for rockets
	* Rocket speed starts slightly faster when deflected to simulate the push from airblast - Won't do
		* Would encourage close play. Is that something we want to encourage, though?
	* Make changes to rocket trajectory independent of think function's tick rate - done
	* remove rocket speed cap - Done by setting it to 0 but it's madness
	* Self destruct rockets that orbit too long? Nah turn rate increase is fine - Won't do
	* Combine the post-airblast and post-default turn rate changes into one calculation that uses a logarithmic curve - Won't do
		Start with a low turn rate, rapidly increase, then gradually increase (inverse exponential curve?)
	* Set rocket settings for game using RunScriptCode
	* New target selection method: Turns - done (turned into fair)
		* Team mates that haven't yet been targeted are targeted
		* When all team mates have been targeted, it resets
	* New target selection method: fair - WIP
		* Try to store that the player was targeted and deflected their rocket
		* This ensures people who have their rocket stolen keep getting chances
		* We could store the number of times targeted and number of deflections done
		* targeted - deflections = sort
	* Don't kill rocket if no targets and instead just don't change its trajectory
	* Modify rocket properties in given table
	* No-homing mode. Rockets do not home after initial deflect. Players must aim
		* May need to increase rocket speed more quickly
*/

/*
	Problems identified during a playtest
	* tf_arena_use_queue needs to be disabled - done
	* If you blast a rocket into the ground, it will hit the ground and explode
	* People can get outside the map
	* Orbiting is hard. Make a solo mode and test with it - done
	* On resurrecting them manually, some players' games crashed. Could it be a result of being respawned too quickly earlier?
	* Try targeting the player's eye position instead of their center. - test
		Try a point between their center and eyes, or go back to center and deal with floor collision
	* People still spawn in the center - test
		Attempted fix by hiding player spawn event because I think it gets triggered by people on team 0
	* Rocket collides with ground too often. Could increase turn rate on deflect for a little bit?
		Would not look as good. Could try clamping pitch
	* Run out of primary ammo and your weapon switches, and you can't switch back
	* Check to see if modifications to weapons are carried into the next round.
		* If they are, see if there is a way to mark the weapon for deletion on round restart
			Could try adding a flag or parenting it to the logic_script
		* Add regeneration to our StopGame function, if the round is still active

	Turn rate stuff
	* Adjusting turn rate to match speed works but it removes the long orbiting penalty
	* We could introduce a timer which explodes the rocket after a time
	* Find what turn rate matches what speed and plot a range.
		Then on deflect, start the turn rate at the match for the speed and increase
		it over time by double the speed match, based on the seconds post deflect
	* IIRC I had a problem where the rocket could be orbited while the player is standing still.
		To combat that the rocket would need a good enough turn radius to be able to hit the player.
		I should perform thirdperson tests to sidestep the rocket to cause it to orbit, to see
		what turn rate enables it to hit me. I suppose it would either need a turn rate that takes it closer
		to me over time or one which causes it to stop and hit me. To facilitate normal orbiting
		I would need to be able to side step and have the rocket miss me. May be worth seeing what
		the SourceMod plugins do. Probably took a lot of trial and error.
*/

IncludeScript("matty/stocks2.nut");

local game_active = false;
local game_settings = {};
local point_templates = [];
local rockets = [];
local last_time_with_rockets = 0;

// you can supply these in the RunScriptCode StartGame function call
local game_defaults = {
	change_to_pyro = false // all players are changed to pyro class
	delete_other_weapons = true // delete any non-primary weapons in player slots
	wait_time = 3.0 // seconds before spawning the next rocket when there are none
	delay_before_rockets_start = 0.0 // delay before rockets begin to fire. useful in preparing player loadout before the game begins
	stop_when_team_dead = true // automatically stop the game when the round is not active or one team has no live players

	// testing
	solo_mode = false // rockets change teams one second after deflection
}

local rocket_defaults = {
	// basic properties
	damage = 400 // minimum amount required for an airblasted rocket from a mimic to one-shot a pyro is 400
	crit_on_spawn = false // rockets should be crit on spawn. recommended to be disabled, as crit rockets receive extra speed on deflect in my version of the game
	target_acquisition_method = "fair" // method of target acquisition. "closest", "random", "fair". Fair takes steal amount into account

	// deflection
	deflect_crit_chance = 0.10 // roll percentage chance rocket will become crit on deflect
	increase_deflect_crit_chance = true // crit roll will be performed once per the rocket's accumulated deflections, increasing crit chance each deflection
	add_speed_on_deflect = 50 // extra speed per deflection
	add_speed_on_deflect_crit = 100 // extra speed per deflection if the rocket is crit

	// speed and turn rate
	initial_speed = 450 // initial rocket speed in units per second. recommended default 450
	max_speed = 3500 // rocket speed cap. set to 0 to disable
	turn_rate = 0.075 // multiplies difference between rocket's forward vector and direction of target to cause gradual turns
	// turn_rate = 0.059 // multiplies difference between rocket's forward vector and direction of target to cause gradual turns
	turn_rate_post_airblast = null // turn rate will be set to this value after the rocket is airblasted. 'null' means no change
	// turn_rate_post_airblast = 0 // turn rate will be set to this value after the rocket is airblasted.
	// turn_rate_increase_step = 0 // increase turn rate by this every frame until hitting default
	// turn_rate_increase_step = 0.015 // increase turn rate by this every frame until hitting default
	// turn_rate_increase_step_post_default = 0 // increase turn rate by this amount each frame after hitting default
	// turn_rate_increase_step_post_default = 0.001 // increase turn rate by this amount each frame after hitting default
}

/**
 * Sounds
 * Do not edit these. Instead, create a custom soundscript
 * and specify the sound names below in that, as replacements.
 * e.g. dodgeball.rocket.target_acquired
 */
local sounds = {
	rocket = {
		target_acquired = "weapons/sentry_spot.wav" // played to all other player
		targeted_you = "weapons/sentry_spot_client.wav" // played to target player
		deflect = "common/null.wav" // played from deflector on deflect
		deflect_crit = "weapons/rocket_ll_shoot_crit.wav" // played from crit rockets on deflect
		// both spawn1 and 2 are played at the same time
		spawn1 = "weapons/sentry_rocket.wav" // played from rocket spawn point upon spawn
		spawn2 = "weapons/rocket_jumper_explode1.wav"
	}
}

// replace wave files with game sound names if they are used
foreach(cat_key, category in sounds) {
	foreach(event_key, wave in category) {
		local scriptsound = "dodgeball." + cat_key + "." + event_key;
		if (PrecacheScriptSound(scriptsound)) {
			category[event_key] = scriptsound;
		}
	}
}

/**
 * Player properties
 */
if ("dodgeball" in CTFPlayer == false) {
	CTFPlayer.dodgeball <- null; //
	CTFBot.dodgeball <- null;
};

/**
 * Store point_templates for later spawning and killing of entities
 */
function OnPostSpawn() {
	if (!("EntityGroup" in self.GetScriptScope())) {
		return;
	}

	foreach(ent in EntityGroup) {
		if (ent != null && ent.GetClassname() == "point_template") {
			if (developer()) printl(__FILE__ + " -- Found point_template named " + ent.GetName());
			point_templates.append(ent);
			ent.ValidateScriptScope();
			local scope = ent.GetScriptScope();

			scope.spawned_targetnames <- {};
			scope.PreSpawnInstance <-  function(classname, targetname) {};

			// add targetnames of spawned entities to internal list
			scope.PostSpawn <-  function(entities) {
				foreach(targetname, value in entities) {
					if (developer()) printl(__FILE__ + " -- Spawned " + targetname);
					spawned_targetnames[targetname] <- value;
				}
			};

			// kill spawned targetnames
			scope.Cleanup <-  function() {
				foreach(targetname, ent in spawned_targetnames) {
					if (developer()) printl(__FILE__ + " -- Killing " + targetname);
					EntFire(targetname, "kill");
				}
				spawned_targetnames = {};
			}
		}
	}
}

/**
 * Set ConVars
 */
if (startswith(GetMapName(), "db_") && IsInArenaMode()) {
	if (Convars.IsConVarOnAllowList("tf_arena_use_queue")) {
		Convars.SetValue("tf_arena_use_queue", 0);
		if (developer()) printl(__FILE__ + " -- Disabled Arena queue");
	} else {
		printl(__FILE__ + " -- Cannot disable Arena queue because the console variable is not whitelisted on the server");
	}
}


// Event hooks
// ----------------------------------------------------------------------------------------------------

/**
 * Populate the player's CTFPlayer dodgeball member with a table
 */
function OnGameEvent_player_initial_spawn(params) {
	local player = PlayerInstanceFromIndex(params.index);
	if (self.IsValid() && player != null && player.IsValid()) {
		// if (developer()) printl(__FILE__ + " -- Adding Dodgeball table to scope of " + player);
		player.dodgeball = {
			targeted = 0
			deflected = 0
			last_targeted = 0
			Reset = function() {
				targeted = 0
				deflected = 0
			}
			GetStolen = function() {
				local stolen = deflected - targeted; // todo: Wrong. What if they die and are respawned? Add to 'stolen' when deflected but not targeted
				stolen = (stolen < 0) ? 0 : stolen;
				return stolen;
			}
		};
	}
}

/**
 * Change player class to pyro if game settings dictate
 * Commented out because I think it's spawning new joiners immediately at origin
 */
// function OnGameEvent_player_spawn(params) {
// 	// self.IsValid() is required to prevent the event firing in future rounds
// 	if (self.IsValid() == false) {
// 		return;
// 	}

// 	local player = GetPlayerFromUserID(params.userid);
// 	if (player != null && game_active) {
// 		if (game_settings.change_to_pyro && player.GetPlayerClass() != TF_CLASS_PYRO) {
// 			ChangePlayerClass(player, TF_CLASS_PYRO);
// 		}
// 	}
// }

/**
 * Ensure the player has a useable flamethrower post-respawn
 * TODO: Do I need to add a delay to this to counter deathrun plugin interference
 */
function OnGameEvent_post_inventory_application(params) {
	// self.IsValid() is required to prevent the event firing in future rounds
	if (self.IsValid() == false) {
		return;
	}

	local player = GetPlayerFromUserID(params.userid);
	if (player != null && game_active) {
		// change to pyro on next frame
		if (game_settings.change_to_pyro && player.GetPlayerClass() != TF_CLASS_PYRO) {
			EntFireByHandle(self, "RunScriptCode", "ChangePlayerClass(activator, TF_CLASS_PYRO);", 0, player, null);
			// ChangePlayerClass(player, TF_CLASS_PYRO);
		}
		// ensure they have a flamethrower with required attributes
		else {
			ProcessWeapons(player, game_settings.delete_other_weapons);
		}
	}
}

__CollectGameEventCallbacks(this);

// Game functions
// ----------------------------------------------------------------------------------------------------

/**
 * Start the game
 * Prepares players by setting class, respawning or giving flamethrowers.
 * Begins the rocket spawn timer and starts spawning rockets!
 * @param {table} options Game settings you wish to change from default. See the start of the script
 */
function StartGame(options = null) {
	if (game_active || !IsRoundActive() || !LiveTeams()) {
		return;
	}

	// ensure options table exists and populate it with unspecified defaults
	options = (typeof options == "table") ? options : {};
	foreach(key, value in game_defaults) {
		if (key in options == false) {
			options[key] <- value;
		}
	}

	game_settings = options;
	game_active = true

	// spawn templated entities
	foreach(template in point_templates) {
		template.AcceptInput("ForceSpawn", null, null, null);
	}

	// reset player stats, set class and modify weapons
	local players = GetPlayers();
	players = players.filter(function(index, player) {
		player.dodgeball.Reset();
		return player.IsAlive();
	});

	foreach(player in players) {
		local tfclass = player.GetPlayerClass();

		// if the player is not a pyro
		if (tfclass != TF_CLASS_PYRO) {
			if (options.change_to_pyro) {
				ChangePlayerClass(player, TF_CLASS_PYRO);
			} else {
				ProcessWeapons(player, options.delete_other_weapons);
			}
		}
		// player is already a pyro
		else {
			ProcessWeapons(player, options.delete_other_weapons);
		}
	}

	// grant extra health to blue players if they face off multiple of five reds
	// TODO: Check if this works for players who are respawned
	local reds_len = LiveReds().len();
	local blues = LiveBlues();
	// reds_len = reds_len / blues.len(); // ratio for multiple activators
	local health_mult = (reds_len / 5).tointeger();

	if (health_mult > 0) {
		foreach(blue in blues) {
			local extra_hp = (rocket_defaults.damage * health_mult);
			blue.AddCustomAttribute("max health additive bonus", extra_hp.tointeger(), -1);
			// EntFireByHandle(blue, "RunScriptCode", "self.SetHealth(self.GetHealth())", 0, null, null);
			blue.SetHealth(blue.GetMaxHealth());
			ChatMsg(null, blue.CName() + " health scaled to " + blue.GetMaxHealth());
		}
	}

	// start the think function, optionally after a delay
	if (options.delay_before_rockets_start > 0.0) {
		EntFireByHandle(self, "RunScriptCode", "AddThinkToEnt(self, `Think`)", options.delay_before_rockets_start, null, null);
	} else {
		AddThinkToEnt(self, "Think");
	}
}

/**
 * Stop the game and clean up entities
 */
function StopGame() {
	if (!game_active) {
		return;
	}

	// mark game as inactive and stop think
	game_active = false;
	AddThinkToEnt(self, "");
	last_time_with_rockets = 0;

	// kill rockets
	foreach(rocket in rockets) {
		if (rocket.IsValid()) {
			rocket.Kill();
		}
	}
	rockets.clear();

	// kill entities spawned by templates
	foreach(template in point_templates) {
		template.GetScriptScope().Cleanup();
	}
}

/**
 * Ensure the player has an allowed flamethrower and apply attributes to it.
 * Switch them to the flamethrower.
 * Optionally delete all other weapons.
 * @param {instance} player Player handle
 * @param {bool} delete_other_weapons True to delete all other weapons the player holds
 */
function ProcessWeapons(player, delete_other_weapons) {
	// get primary weapon
	local primary_weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", 0);
	local GetWeaponIDI = function(weapon) {
		return NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex");
	};

	// give flamethrower if no weapon, not a flamethrower, is phlog or dragon's fury
	if (primary_weapon == null ||
		primary_weapon.GetClassname() != "tf_weapon_flamethrower" ||
		GetWeaponIDI(primary_weapon) == 594 ||
		GetWeaponIDI(primary_weapon) == 1178) {
		local new_weapon = GivePlayerWeapon(player, "tf_weapon_flamethrower", 21);
		// old weapon in the same slot is deleted by the Give function
		primary_weapon = new_weapon;
	}

	// grant free airblast and flames and replenish primary ammo
	primary_weapon.AddAttribute("airblast cost decreased", 0, -1);
	primary_weapon.AddAttribute("flame ammopersec decreased", 0.0, -1);
	NetProps.SetPropIntArray(player, "m_iAmmo", 200, 1);

	// switch player to weapon
	player.Weapon_Switch(primary_weapon);

	// remove other weapons
	if (delete_other_weapons) {
		for (local i = 6; i > 0; i--) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i);
			if (weapon != null && weapon.IsValid()) {
				weapon.Destroy();
			}
		}
	}
}

/**
 * Game think
 */
function Think() {
	if (!game_active) {
		return;
	}

	// stop game if round not active or one team has no live players
	if (!IsRoundActive() || (game_settings.stop_when_team_dead && !LiveTeams())) {
		StopGame();
		return;
	}

	// validate rockets
	rockets = rockets.filter(function(index, rocket) {
		return rocket.IsValid();
	});

	// spawn rockets
	if (rockets.len() == 0) {
		if ((Time() - last_time_with_rockets) > game_settings.wait_time || last_time_with_rockets == 0) {

			// determine team
			local team;
			if ("last_targeted_team" in this == false) {
				team = RandomInt(TF_TEAM_RED, TF_TEAM_BLUE);
				this.last_targeted_team <- team;
			} else if (last_targeted_team == TF_TEAM_RED) {
				team = TF_TEAM_BLUE;
			} else {
				team = TF_TEAM_RED;
			}

			// spawn rocket and note team and time
			local rocket = SpawnRocket(team);
			if (rocket != null) {
				rockets.append(rocket);
				last_targeted_team = team;
				last_time_with_rockets = Time();
			}
		}
	} else {
		// record time if we have rockets
		last_time_with_rockets = Time();
	}

	return 1; // no point in doing it any faster
}

// Rocket functions
// ----------------------------------------------------------------------------------------------------

/**
 * Spawn a rocket into the game
 * @param {int} team Team index the rocket belongs to. The opposing team will become the target
 * @param {table} params Table of optional parameters to override. See start of script
 */
function SpawnRocket(team, params = null) {
	params = (typeof params == "table") ? params : {};

	// parameters
	foreach(key, value in rocket_defaults) {
		if (!(key in params)) {
			params[key] <- value;
		}
	}

	// create tf_point_weapon_mimic, then fire once
	local weapon_mimic = SpawnEntityFromTable("tf_point_weapon_mimic", {
		damage = params.damage - (params.damage / 3)
		modelscale = 0
		angles = "90 0 0"
		origin = self.GetOrigin()
	})
	weapon_mimic.AcceptInput("FireOnce", null, null, null);

	// fetch rocket for processing
	local rocket = null;
	while (rocket = Entities.FindByClassname(rocket, "tf_projectile_rocket")) {
		if (NetProps.GetPropEntity(rocket, "m_hOwnerEntity") == weapon_mimic) {
			break;
		}
	}
	if (rocket == null) {
		error(__FILE__ + " -- SpawnRocket -- No tf_projectile_rocket owned by the spawner were found\n");
		weapon_mimic.Kill();
		return null;
	}
	rocket.AcceptInput("AddOutput", "targetname homing_rocket_" + rocket.entindex(), null, null);
	weapon_mimic.AcceptInput("SetParent", "!activator", rocket, null); // for cleanup
	// initial properties
	rocket.SetTeam(team);
	rocket.SetSkin((team == TF_TEAM_BLUE) ? 0 : 1);
	NetProps.SetPropBool(rocket, "m_bCritical", params.crit_on_spawn);

	// changing the Deflected value with 100 damage
	// 0 = 100 for each team
	// 1 = 136 for blue puppet bot, 67 for red me and I got a crit sound
	// 2 = 136 for blue puppet bot, 67 for red me and I got a crit sound
	// 3 = 67 for red puppet bot, 67 for blue me and I got a crit sound
	// 4 = 67 for red puppet bot, 67 for blue me and I got a crit sound
	// it seems the damage does down with each deflection

	// airblasting with 100 damage
	// 100 caused 35
	// 200 caused 71
	// 300 caused 106
	// 400 caused 141
	// 500 caused 176
	// not airblasting caused full damage

	// script scope
	rocket.ValidateScriptScope();
	local scope = rocket.GetScriptScope();
	local rocket_members = {
		// properties
		mimic = weapon_mimic
		params = params
		target_team = GetOpposingTeam(team)
		target = null
		glow_particle_ent = null
		speed = params.initial_speed
		turn_rate = params.turn_rate
		last_deflected = Time()

		// methods
		GetOpposingTeam = GetOpposingTeam
		GetDeflections = function() {
			return NetProps.GetPropInt(self, "m_iDeflected");
		}
		IsCrit = function() {
			return NetProps.GetPropBool(rocket, "m_bCritical");
		}
		SetCrit = function(crit) {
			NetProps.SetPropBool(rocket, "m_bCritical", crit);
		}
	};
	foreach(key, val in rocket_members) {
		scope[key] <- val;
	};
	// local scope = rocket.GetScriptScope();
	// scope.mimic <- weapon_mimic;
	// scope.params <- params;
	// scope.target_team <- GetOpposingTeam(team);
	// scope.target <- null;
	// scope.glow_particle_ent <- null;
	// scope.speed <- params.initial_speed;
	// scope.turn_rate <- params.turn_rate;
	// scope.last_deflected <- Time();

	// spawn sounds
	PlaySound(sounds.rocket.spawn1, {
		entity = rocket
	});
	PlaySound(sounds.rocket.spawn2, {
		entity = rocket
	});

	// particle effects
	// EntFireByHandle(rocket, "DispatchEffect", "ParticleEffectStop", 0, null, null)

	// model
	// rocket.SetModelScale(0, 0)

	// scope.GetOpposingTeam <- GetOpposingTeam;
	// scope.GetDeflections <-  function() {
	// 	return NetProps.GetPropInt(self, "m_iDeflected");
	// }
	// scope.IsCrit <-  function() {
	// 	return NetProps.GetPropBool(rocket, "m_bCritical");
	// }
	// scope.SetCrit <-  function(crit) {
	// 	NetProps.SetPropBool(rocket, "m_bCritical", crit);
	// }

	/**
	 * Have the rocket acquire a new target
	 * @param {int} target_team Target team index
	 * @param {string} type Type of target acquisition method: closest, random, fair
	 */
	scope.AcquireTarget <-  function(target_team, type) {
		local new_target = null;

		// get live opposing players
		local targets = GetPlayers({
			team = target_team,
			alive = true
		});

		// exit early if there are no targets
		if (targets.len() == 0) {
			new_target == null;
			return;
		}

		// get closest target
		if (type == "closest") {
			local closest_distance = 1000000.0;

			foreach(player in targets) {
				local direction = player.GetCenter() - self.GetOrigin();
				direction.Norm();
				local distance = (self.GetOrigin() - player.GetCenter()).Length() * (-direction.Dot(self.GetAbsAngles().Forward()) + 2);
				if (distance < closest_distance) // closer than the current closest player, mark this player as the closest
				{
					new_target = player;
					closest_distance = distance;
				}
			}
		}
		// get random target
		else if (type == "random") {
			new_target = targets[RandomInt(0, targets.len() - 1)];
		}
		// fair method - prefer those who have deflected least
		else if (type == "fair") {
			// get possible targets and shuffle
			// sort by deflections - targeted
			// pick the first player (or a player from the first third of the array)
			// record the target number on the player's scope

			// will need to:
			// on deflect, record in the player's scope
			// reset counts on game start

			// problem:
			// if a player's deflections matches their targets, they will be 0 and will always be at the top
			// we should randomise the array pre-sort or include the time last targeted if players' difference matches

			// sort like this:
			// shuffle to begin with
			// order by targeted, pushing people with more deflections lower down
			// ultimately what we want is fair targeting but reduced targeting for people who steal
			targets = RandomiseArray(targets);
			targets = targets.sort(function(player1, player2) {
				return player1.dodgeball.deflected <=> player2.dodgeball.deflected;
			})
			targets = targets.sort(function(player1, player2) {
				return player1.dodgeball.targeted <=> player2.dodgeball.targeted;
			})

			// if (developer()) {
			// 	printl("Rocket think target method 'fair' array of targets:");
			// 	foreach(index, target in targets) {
			// 		printl(format("%2d: %32s Targeted: %d Deflections: %d Stolen: %d", index, target.Name(), target.dodgeball.targeted, target.dodgeball.deflected, target.dodgeball.GetStolen()));
			// 	}
			// }

			local max = ((targets.len() - 1) / 2).tointeger();
			new_target = targets[RandomInt(0, max)];
		}

		new_target.dodgeball.targeted += 1;
		return new_target;
	};

	// target acquired sounds
	scope.TargetSounds <-  function(targeted_player) {
		local players = GetPlayers();
		foreach(player in players) {
			// for target
			if (player == targeted_player) {
				PlaySoundToClient(player, sounds.rocket.targeted_you, {
					origin = self.GetOrigin()
					sound_level = 0
				});
			}
			// for others
			else {
				PlaySoundToClient(player, sounds.rocket.target_acquired, {
					origin = self.GetOrigin()
					sound_level = 40
				});
			}
		}
	}

	/**
	 * Calculate the rocket's movement
	 */
	scope.MoveThink <-  function() {
		local velocity = null;

		if (target.IsValid()) {
			// local target_pos = target.EyePosition();
			local target_pos = target.GetCenter();
			local difference = (target_pos - self.GetOrigin());
			// local distance = difference.Length(); // Length() gets the distance to the point in space from 0,0,0
			difference.Norm(); // Norm() scales the vector to fit between 0.0 and 1.0
			// local velocity = self.GetAbsVelocity();
			local direction = self.GetForwardVector(); // get the rocket's current trajectory in the form 1.0, 0.0, -1.0

			// get current trajectory
			// add (normalized difference - trajectory forward vector) multipled by a reducing value
			// smaller number causes more gradual turn
			// turn rate spreads the turn out so it's not instant
			// problems are: if the rocket think rate is per-frame, higher tick servers cause shorter turns
			// large changes in direction still take the same amount of time as short changes
			// if a rocket is airblasted backwards it will probably change direction unrealistically
			// however, turn rate is set to 0 on airblast so this probably removes the problem
			direction = direction + (difference - direction) * turn_rate; // smoothly turn the rocket towards the target
			velocity = direction * speed;
			speed += (20.0 * FrameTime()); // add ten units per
		}

		self.SetAbsVelocity(velocity);
		self.SetForwardVector(velocity);
		// turn_rate = 0.11;
		local time_since_deflect = Time() - last_deflected;
		turn_rate = (speed + (speed * (time_since_deflect * 0.1))) * 0.0001;
		// turn rate testing
		// constant 0.1 enables easy orbiting, and arc gets wider with speed
		// multiply speed * 0.0001 gives turn rate that enables permanent orbiting, with an arc that stays roughly the same with speed
		// multiply speed * 0.0002 gives turn rate that makes orbiting quite difficult to perform. Unknown if permanent orbiting is possible
		// multiply speed * (speed again over ten seconds) * 0.0001 causes easy orbiting at start, afk orbiting for a few seconds, then a tight arc and eventual collision

		// turn rate is set to 0 on airblast
		// ramp up turn rate until it hits the default turn rate
		// if (turn_rate < params.turn_rate) {
		// 	turn_rate += params.turn_rate_increase_step // slowly increase the turn rate up to the default value
		// }
		// // increase turn rate by a smaller amount after it hits the default
		// else {
		// 	turn_rate += params.turn_rate_increase_step_post_default // prevent people from orbiting forever by increasing turn rate even further. after a while it will be straight up impossible to dodge
		// }
		// // cap turn rate
		// if (turn_rate > 1.0) {
		// 	turn_rate = 1.0
		// }
	};

	/**
	 * Rocket think function
	 */
	scope.Think <-  function() {
		// airblasted (owning team is the same as target team)
		if (target_team == self.GetTeam()) {
			// record deflection
			local owner = self.GetOwner();
			if (owner instanceof CTFPlayer) {
				owner.dodgeball.deflected += 1;
				// if (developer()) ChatMsg(null, "Deflections for " + owner.Name() + ": " + owner.dodgeball.deflected);
			}
			last_deflected = Time();

			// change team properties and skin
			local team = self.GetTeam();
			target_team = GetOpposingTeam(team);
			target = null;
			self.SetSkin((team == TF_TEAM_BLUE) ? 0 : 1);

			// play deflect sound
			PlaySound(sounds.rocket.deflect, {
				origin = owner.GetOrigin()
				pitch = "95,105"
				sound_level = 120
			});

			// roll crit chance
			if (IsCrit() == false && params.deflect_crit_chance > 0.0) {
				// dice rolls for crit chance
				local rolls = 1;

				// optionally increase number of dice rolls
				if (params.increase_deflect_crit_chance) {
					local rolls = GetDeflections();
				}

				for (local i = 0; i < rolls; i++) {
					if (RandomFloat(0.0, 1.0) < params.deflect_crit_chance) {
						SetCrit(true);
						break;
					}
				}
			}
			// crit damage notes
			// mimic damage of 500 equates to 176 on airblast, which becomes 243 when it's crit
			// is rocket damage hard-coded? or deflected rocket damage hard-coded?

			// crit effects
			if (IsCrit()) {
				// reset glow particle
				if (glow_particle_ent != null && glow_particle_ent.IsValid()) {
					glow_particle_ent.Kill();
				}

				// glow particle effect
				glow_particle_ent = SpawnEntityFromTable("info_particle_system", {
					effect_name = ((team == TF_TEAM_RED) ? "spell_fireball_small_red" : "spell_fireball_small_blue")
					start_active = "1"
					targetname = self.GetName() + "_trail"
					origin = self.GetOrigin()
				});

				glow_particle_ent.AcceptInput("SetParent", "!activator", self, null);
				glow_particle_ent.AcceptInput("SetParentAttachment", "trail", null, null);

				// crit sound
				PlaySound(sounds.rocket.deflect_crit, {
					sound_level = 0
				});
				// PlaySound("weapons/weapon_crit_charged_on.wav", {	// had to disable because stocks2 isn't stopping the sound on death
				// 	looping = true
				// });
			}

			// reset the turn rate (to allow for flicks and orbiting)
			if (params.turn_rate_post_airblast != null) {
				turn_rate = params.turn_rate_post_airblast;
			}

			// increase speed
			speed += (IsCrit()) ? params.add_speed_on_deflect_crit : params.add_speed_on_deflect;
			if (speed > params.max_speed && params.max_speed > 0) {
				speed = params.max_speed // cap speed to max
			}

			// acquire new target
			// target = AcquireTarget(target_team, params.target_acquisition_method);
			// if (target == null) {
			// 	AddThinkToEnt(self, null);
			// 	// self.Kill();
			// 	return;
			// } else {
			// 	TargetSounds(target);
			// }
		}

		// no target or target no longer exists
		if (target == null || !target.IsValid() || !target.IsAlive() || target.GetTeam() != target_team) {
			target = AcquireTarget(target_team, params.target_acquisition_method);
			if (target == null) {
				AddThinkToEnt(self, null);
				// self.Kill();
				return;
			} else {
				TargetSounds(target);
			}
		}

		// solo mode
		if (game_settings.solo_mode) {
			local player1 = EntIndexToHScript(1);
			local enemy_team = GetPlayers({
				alive = true,
				team = GetOpposingTeam(player1.GetTeam())
			});
			if (Time() > last_deflected + 1.0 && player1 != null && player1.IsAlive() && target_team != player1.GetTeam() && enemy_team.len()) {
				// change rocket owner to current target team
				self.SetTeam(target_team);
				self.SetOwner(enemy_team[0]);
			}
		}
		// note on a crash bug:
		// making the rocket owned by the mimic after it had been deflected by the player
		// caused a crash when it hit the player again. stack trace ended on
		// server_srv.so!EconItemInterface_OnOwnerKillEaterEvent_Batched(IEconItemInterface*, CTFPlayer*, CTFPlayer*, kill_eater_event_t, int) + 0x21

		// calculate movement
		MoveThink();
		// if (developer()) CenterMsg(null, "Speed: " + speed + "\nTurn rate: " + turn_rate + "\nOwner entity: " + self.GetOwner());
		// return 0.1;
		return -1;
	}

	AddThinkToEnt(rocket, "Think");
	return rocket;
}

/**
 * Bounce the rocket away from the trigger
 */
function BounceRocket(pitch, yaw, roll) {
	if (activator.GetClassname() == "tf_projectile_rocket") {
		// if (developer()) ChatMsg(null, "Rocket " + activator + " bounced from trigger " + self);
		local angles = QAngle(pitch, yaw, roll)
		local coordinates = activator.GetOrigin()
		local surface_normal = angles.Up()
		local rocket_vector = activator.GetForwardVector()

		if (surface_normal.Dot(rocket_vector) < 0) // this ensures that rockets are only reflected if the rocket is going *into* the surface, rather than *out* of it
		{
			local current_rocket_speed = activator.GetAbsVelocity().Length()
			rocket_vector = rocket_vector - surface_normal * (rocket_vector.Dot(surface_normal)) * 2 // mirror a vector around a surface using the surface normal
			rocket_vector.Norm()
			activator.SetForwardVector(rocket_vector)
			activator.SetAbsVelocity(rocket_vector * current_rocket_speed)
			// activator.PrecacheSoundScript("MVM_Weapon_Bottle.HitFlesh")
			// activator.EmitSound("MVM_Weapon_Bottle.HitFlesh")
			DispatchParticleEffect("bonk_text", coordinates, Vector(0, 0, 0))
			// if (turn_rate < 1) // to prevent rockets from bouncing like 20 times in a row, just increase the turn rate with each bounce
			// 	turn_rate + 0.1
			// else
			// 	turn_rate = 1
		}
	}
}

// Helper functions
// ----------------------------------------------------------------------------------------------------

/**
 * Check if the round is active.
 * Arena mode uses 'stalemate' as its round running state
 * @return {bool} True if the round state is 'running' or 'stalemate'
 */
function IsRoundActive() {
	return (GetRoundState() == GR_STATE_RND_RUNNING || GetRoundState() == GR_STATE_STALEMATE);
}

/**
 * Check if both teams have live players
 * @return {bool} True if both teams have at least one live player
 */
function LiveTeams() {
	return (LiveReds().len() && LiveBlues().len());
}

/**
 * Given a team index, return the enemy team index
 * @return {int} Opposing team index. Default TF_TEAM_RED (2)
 */
function GetOpposingTeam(team) {
	return ((team == TF_TEAM_RED) ? TF_TEAM_BLUE : TF_TEAM_RED);
}

/**
 * Change a player's class, regenerate them and teleport them to their previous transform
 * @param {instance} player Player handle
 * @param {integer} tfclass TF class index
 */
function ChangePlayerClass(player, tfclass) {
	local desired_class = NetProps.GetPropInt(player, "m_Shared.m_iDesiredPlayerClass");
	local pos = player.GetOrigin();
	local ang = player.EyeAngles();
	local vel = player.GetAbsVelocity();
	NetProps.SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", tfclass);
	player.ForceRegenerateAndRespawn();
	player.Teleport(true, pos, true, ang, true, vel);
	NetProps.SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", desired_class);
}

/**
 * Give a player a weapon
 * Deletes the old weapon in the slot.
 * Note: The function contains a constant for the maximum number of weapons.
 * @param {instance} player Player handle
 * @param {string} classname Classname of weapon to give
 * @param {integer} item_def_index Item definition index of weapon to give
 * @return {instance} Handle of weapon entity
 */
function GivePlayerWeapon(player, classname, item_def_index) {
	local weapon = Entities.CreateByClassname(classname);

	NetProps.SetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", item_def_index);
	NetProps.SetPropBool(weapon, "m_AttributeManager.m_Item.m_bInitialized", true);
	NetProps.SetPropBool(weapon, "m_bValidatedAttachedEntity", true);
	weapon.SetTeam(player.GetTeam());

	Entities.DispatchSpawn(weapon);

	// remove existing weapon in same slot
	for (local i = 0; i < 8; i++) {
		local heldWeapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i);
		if (heldWeapon == null)
			continue;
		if (heldWeapon.GetSlot() != weapon.GetSlot())
			continue;
		heldWeapon.Destroy();
		NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i);
		break;
	}

	player.Weapon_Equip(weapon);

	return weapon;
}

// Notes
// ----------------------------------------------------------------------------------------------------

/*
	Bot player was killed by first-spawned rocket:

	Server event "player_hurt", Tick 544873:
	- "userid" = "2"
	- "health" = "0"
	- "attacker" = "0"									// interesting
	- "damageamount" = "500"							// same as mimic keyvalue
	- "custom" = "0"
	- "showdisguisedcrit" = "0"
	- "crit" = "0"										// not crit?
	- "minicrit" = "0"
	- "allseecrit" = "0"
	- "weaponid" = "0"									// interesting
	- "bonuseffect" = "0"
	Server event "player_death", Tick 544873:
	- "userid" = "2"
	- "victim_entindex" = "1"
	- "inflictor_entindex" = "78"						// rocket entity index
	- "attacker" = "0"									// userid
	- "weapon" = "tf_projectile_rocket"					// interesting
	- "weaponid" = "22"									// ??
	- "damagebits" = "3407936"							// DMG_BLAST | DMG_RADIATION | DMG_ACID | DMG_SLOWBURN
	- "customkill" = "0"
	- "assister" = "-1"
	- "weapon_logclassname" = "tf_projectile_rocket"	// interesting
	- "stun_flags" = "0"
	- "death_flags" = "128"
	- "silent_kill" = "0"
	- "playerpenetratecount" = "0"
	- "assister_fallback" = ""
	- "kill_streak_total" = "0"
	- "kill_streak_wep" = "0"
	- "kill_streak_assist" = "0"
	- "kill_streak_victim" = "0"
	- "ducks_streaked" = "0"
	- "duck_streak_total" = "0"
	- "duck_streak_assist" = "0"
	- "duck_streak_victim" = "0"
	- "rocket_jump" = "0"
	- "weapon_def_index" = "65535"						// interesting
	- "crit_type" = "2"

	Bot player killed by my rocket launcher:

	Server event "player_hurt", Tick 578183:
	- "userid" = "52"
	- "health" = "0"
	- "attacker" = "2"									// different
	- "damageamount" = "95"
	- "custom" = "0"
	- "showdisguisedcrit" = "0"
	- "crit" = "0"
	- "minicrit" = "0"
	- "allseecrit" = "0"
	- "weaponid" = "22"									// different
	- "bonuseffect" = "4"								// different
	Server event "player_death", Tick 578183:
	- "userid" = "52"
	- "victim_entindex" = "2"
	- "inflictor_entindex" = "57"
	- "attacker" = "2"									// different
	- "weapon" = "tf_projectile_rocket"
	- "weaponid" = "22"
	- "damagebits" = "2359360"							// different. no DMG_ACID. Is that for crits?: DMG_BLAST | DMG_RADIATION | DMG_SLOWBURN
	- "customkill" = "0"
	- "assister" = "-1"
	- "weapon_logclassname" = "tf_projectile_rocket"
	- "stun_flags" = "0"
	- "death_flags" = "0"
	- "silent_kill" = "0"
	- "playerpenetratecount" = "0"
	- "assister_fallback" = ""
	- "kill_streak_total" = "0"
	- "kill_streak_wep" = "0"
	- "kill_streak_assist" = "0"
	- "kill_streak_victim" = "0"
	- "ducks_streaked" = "0"
	- "duck_streak_total" = "0"
	- "duck_streak_assist" = "0"
	- "duck_streak_victim" = "0"
	- "rocket_jump" = "0"
	- "weapon_def_index" = "15057"						// different
	- "crit_type" = "0"									// different

	Bot player killed by a rocket I deflected:

	Server event "player_hurt", Tick 1106224:
	- "userid" = "57"
	- "health" = "0"
	- "attacker" = "2"									// userid is now valid
	- "damageamount" = "479"
	- "custom" = "0"
	- "showdisguisedcrit" = "0"
	- "crit" = "1"
	- "minicrit" = "0"
	- "allseecrit" = "0"
	- "weaponid" = "25"
	- "bonuseffect" = "4"
	Server event "player_death", Tick 1106224:
	- "userid" = "57"
	- "victim_entindex" = "7"
	- "inflictor_entindex" = "54"						// still the index of the rocket
	- "attacker" = "2"									// userid is now valid
	- "weapon" = "deflect_rocket"						// new classname
	- "weaponid" = "22"
	- "damagebits" = "3407936"
	- "customkill" = "0"
	- "assister" = "-1"
	- "weapon_logclassname" = "deflect_rocket"
	- "stun_flags" = "0"
	- "death_flags" = "128"
	- "silent_kill" = "0"
	- "playerpenetratecount" = "0"
	- "assister_fallback" = ""
	- "kill_streak_total" = "0"
	- "kill_streak_wep" = "0"
	- "kill_streak_assist" = "0"
	- "kill_streak_victim" = "0"
	- "ducks_streaked" = "0"
	- "duck_streak_total" = "0"
	- "duck_streak_assist" = "0"
	- "duck_streak_victim" = "0"
	- "rocket_jump" = "0"
	- "weapon_def_index" = "21"
	- "crit_type" = "2"

	Findings:
	* All rockets have m_iInitialTeamNum set to -1
	* Spawned rockets start on blue team (3)
	* Setting the mimic teamnum to 0 doesn't change rocket initial owner
	* Newly-spawned rockets have the same values for:
		NetProps.GetPropInt(ent, "m_flAnimTime")
		NetProps.GetPropInt(ent, "m_flSimulationTime")
	* Weapon mimics spawned by the script deal 150% their damage. Must compensate by operating on the input figure
	* m_iDeflected is a count of the number of times deflected
	* When the rocket is owned by the mimic, it deals the damage set in the mimic. When it's deflected, it deals some value relating to the deflecting player.
		One solution would be to change the owner back to the mimic. Another is to look at the game code to see how damage is calculated based on the new owner.

*/