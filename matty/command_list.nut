/*
	Commands v0.1 by worMatty - Command group template
	--------------------------------------------------

	How to use:
		Copy this file to scripts/vscripts/mapname and add your commands below.
		Add permitted Steam ids to the group or add them as a root user.
		Read the script comments for more info.
		Uncomment each setting in the table if you wish to set a custom value.

	About Steam ids
		The script uses Steam 3 ids, the same engine id format TF2 uses. You can get yours from the in-game console command `status`
		or from https://steamid.io.
*/

// add a command group named group1
m_commands.AddCommandGroup("group1", {
		// the group will be enabled on creation
		// enabled = true

		// only permitted Steam ids can use the commands
		// id_required = true

		// array of one or more steam 3 ids permitted to use this group's commands. separate them using a comma
		// steam_ids = ["[U:1:1047392]", "[U:1:1047392]"]

		/**
		 * Example function
		 * @param {CTFPlayer} player Handle of player using the command. null if command used by the dedicated server console
		 * @param {array} args Array of string arguments. If none were given the array will be empty, with a length of 0
		 */
		start = function(player, args) {
			StartFeature();
			ReplyToCommand(player, "Feature started"); // prints a message to the command user's chat, or to dedicated server console if player == null
		}

		/**
		 * Example of how to prevent server console executing code that depends on the user being a player entity
		 */
		name = function(player, args) {
			if (!player) return ReplyToCommand(player, "You're the server console so you don't have a name :-(");
			ReplyToCommand(player, "Your name is %s", player.Name());
			// note: CTFPlayer.Name() is a method provided by stocks2.nut.
		}

		/**
		 * Example feature switch
		 * If first argument is "on" or "off", the feature will be enabled or disabled.
		 * If no arguments were given, the command usage info will instead be printed.
		 * FeatureEnable() and FeatureDisable() are example function names, presumed to be added in the same script scope
		 */
		feature = function(player, args) {
			if (!args.len()) return ReplyToCommand(player, "Usage: feature <on/off>");
			if (args[0] == "on") {
				FeatureEnable();
				ReplyToCommand(player, "Feature is now enabled");
			} else if (args[0] == "off") {
				FeatureDisable();
				ReplyToCommand(player, "Feature is now disabled");
			}
		}

		/**
		 * Example of setting globals for your script.
		 * If you store values in root scope so they persist across rounds this can be used to turn them on or off.
		 * For the example we'll pretend there's a table in root named 'my_globals'
		 */
		settings = function(player, args) {
			if (!args.len()) return ReplyToCommand(player, "Usage: settings <setting> <on/off>"); // no args
			local setting = arg[0], new_val = null;
			if (!(setting in my_globals)) return ReplyToCommand(player, "No setting in my_globals named '%s' was found", setting); // setting not found
			if (args.len() == 1) return ReplyToCommand(player, "%s is currently %s", setting, my_globals[setting] ? "on" : "off"); // print current value if only setting specified
			if (arg[1] == "on") new_val = true;
			else if (arg[1] == "off") new_val = false;
			if (new_val == null) return ReplyToCommand(player, "Unrecognised argument '%s'", arg[1]); // neither "on" or "off" were supplied. do nothing
			my_globals[setting] = new_val; // all good. set the new value
			ReplyToCommand(player, "%s turned %s", setting, new_val ? "on" : "off");
		}

		/**
		 * Example of a multi-target function that uses partial name matching.
		 * Targetting system also supports @me, @red, @blue and @all
		 */
		heal = function(player, args) {
			local targets = [];
			if (!args.len())
				if (player) targets.append(player); // if no args given, add self if not server console (player != null)
				else return; // server console - do nothing and exit early
			else targets = FindPlayersByName(player, args[0]); // find players matching the arg
			if (!targets.len()) return ReplyToCommand(player, "No players found matching the search string '" + args[0] + "'");
			targets = targets.filter(function(index, target) { // heal live players and filter out dead
				if (!target.IsAlive()) return false;
				target.SetHealth(target.GetMaxHealth());
				ChatMsg(target, "You were healed to full");
				return true;
			});
			ReplyToCommand(player, "Healed " + targets.len() + " players");
		}
	},
	self.GetScriptScope()
);

// grant one or more steam ids root command permission
m_commands.AddRootUser("[U:1:1047392]"); // wormatty

/*
	If you wish to create multiple command groups, you can copy the m_commands.AddCommandGroup code block and change the command group name.
	Alternatively, put command groups in a table and iterate it using a foreach loop.
*/