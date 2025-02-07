/*
	Holidays v0.2 by worMatty
	A more advanced holiday control system than using tf_logic_on_holiday alone.

	Features
	* logic_relays are triggered on round restart for active holidays
	* You can make your own custom holidays
	* You can check if a holiday is active in your own code using the global functions
	* If a server is forcing on a holiday like Hallowe'en for cosmetics, you can fall back to a date range
	* Holidays are configured in a separate script file, so you can have one per map
	* Priority system to prevent seasonal aesthetics from clashing
	* Force a holiday on for development purposes, or manually override the current date

	Requirements:
	* My stocks2.nut stocks file must be present in tf/scripts/vscripts/matty
	* A copy of the holiday_list.nut file, which contains holiday data

	Usage:
	1. Place holidays.nut in the vscripts dir. I suggest tf/scripts/vscripts/matty
		Add the script to a logic_script entity's vscripts field.
		Pathnames in this field are relative to tf/scripts/vscripts.
		You only need to enter matty/holidays.nut.
	2. Customise holiday_list.nut and add it to the same logic_script entity.
		I recommend saving the file as tf/vscripts/mapname/holiday_list.nut.
		Both scripts should be listed in the entity's field separated by a space.
		The pathname for this script would be mapname/holiday_list.nut.
	3. Add a logic_relay for each holiday you want the script to trigger.
		The targetname of each relay should be structured like so:
			relay_holiday_christmas
		The holiday name is the same as the one in holidays_list.nut.
		You can have more than one relay with the same name.
		The script supports targetnames with extra stuff on the end:
			relay_holiday_christmas_trees
*/

/*
	Troubleshooting

	The first time the script is run, it will read the data from the holiday list.
	If it finds a problem, it will print an error to console.
	Check the console for these error messages if your holiday isn't working.

	You can force a reload of the holiday data using this console command:
		script delete holidays
	Then force a round restart using `mp_restartgame 1`.
	If the map is arena mode this will not work, so you will need to force
	a round restart either by joining an empty team, or killing its players.

	If you have the 'developer' cvar set to 1 or higher,
	the script will print debug messages for certain events to console.
	This can help reassure you that things are working as they should.
*/

/*
	Tips for mappers

	In the holiday list file you can force a specific holiday on all the time.
	This is useful while testing a holiday but make sure it's turned off
	before you release the map.

	If the 'developer' cvar is set to 1 or higher, the names of any holidays
	that have been triggered will be printed to console on round restart.

	The logic_branch entity can be used to check if a certain condition is
	true or false, and fire a different set of outputs for each.
	It can be used to check if a holiday is active according to the script.
	Simply use a holiday logic_relay to set the value of the branch	to 1.

	Alternatively, you can use a RunScriptCode input and check if a given
	holiday is active, and perform an input on the target entity if so:
		OnWhatever > input_entity > RunScriptCode
		if (holidays.IsActive(`christmas`)) self.AcceptInput(`Input`, null, null, null)
	Replace 'Input' with the input you wish to fire. e.g. 'Trigger'.
	If you want to use the priority system, replace IsActive
	with IsActivePriority.

	You can override the current month and day like so:
		script holidays.OverrideDate(1, 1)
	Provide the month number from 1-12 and day number from 1.
	The function will then test each holiday against the new date range
	and tell you if it would fire.
	This is a great fast way to make sure your date ranges work properly.
	Note that the overridden date is not reset on round restart.

	Scripters:
	Check the holidays root table below for useful methods.
*/

/*
	Changelog
		0.2.2
			* Replaced date checking code
			* Bug fix: Date check was not checking end day properly
			* Bug fix: Date ranges spannig two years were not working properly
			* New feature: holidays.OverrideDate() function to override current date
			* Improved instructions
		0.2.1
			* Holiday relay trigger now triggers all instances of the named logic_relay instead of the first
			* Wildcard character (*) added to end of logic_relay targetname search pattern, for mapper flexibility
		0.2
			* Priority system
			* separate holiday config file
*/

/*
	My date testing process, if you're interested

	Test each of the following holiday ranges using these
	Dates:
		day is before start
		day is on start
		day is within range
		day is on end
		day is after end
	Ranges:
		start and end happen in same year in different months
		range starts in one year and ends in the next
		start and end month are the same

	holidays.OverrideDate(1, 1) can be used to override the current
	date and produce a list of then-active holidays
*/

/*
	Known issues

	There seems to be a bug in VScript where OnPostSpawn is called once for each script in a logic_script.
	This resulted in holiday logic_relays being triggered twice. To mitigate the issue I have added a boolean
	check. I will update the script in future if there is a better solution.
*/

/*
	Acknowledgments
	arctic_dino for testing and reporting bugs
*/


IncludeScript("matty/stocks2.nut");
local HOLIDAY_TABLE_NAME = "myholidays";
local OnPostSpawn_called = false;

if ("holidays" in getroottable() == false) {

	/**
	 * Holiday class
	 * @param {string} _name Holiday name
	 * @param {table} params Holiday parameters
	 */
	::Holiday <- class {
		constructor(_name, params) {
			foreach(key, value in params) {
				this[key] = value;
			}

			// assign name
			if (this.name == null) {
				this.name = _name;
			}

			// error checking
			if (start_date == null || end_date == null) {
				if (tfholiday == null) {
					error(__FILE__ + " -- Holiday '" + name + "' has no start or end date but does not specify a tfholiday\n");
					invalid = true;
				}

				if (use_dates_if_forced == true) {
					error(__FILE__ + " -- Holiday '" + name + "' has no start or end date but has use_dates_if_forced set to true\nWhen the server is forcing it, this holiday will not trigger\n");
				}
			}

			// start date checking
			if (start_date != null) {
				if (end_date == null) {
					error(__FILE__ + " -- Holiday '" + name + "' has a start date but no end date\n");
					invalid = true;
				}

				// add start month if it does not exist
				if (!("month" in start_date)) {
					start_date.month <- holidays.current_date.month;
				}

				// add start day if it does not exist
				if (!("day" in start_date)) {
					start_date.day <- holidays.current_date.day;
				}
			}

			// end date checking
			if (end_date != null) {
				if (start_date == null) {
					error(__FILE__ + " -- Holiday '" + name + "' has an end date but no start date\n");
					invalid = true;
				}

				// add end month if it does not exist
				if (!("month" in end_date)) {
					end_date.month <- holidays.current_date.month;
				}

				// add end day if it does not exist
				if (!("day" in end_date)) {
					end_date.day <- holidays.current_date.day;
				}
			}

			// check if holiday is forced on in config
			if (forced_on) {
				printl(__FILE__ + " -- Holiday '" + name + "' has been forced on in config!");
			}
		}

		name = null
		tfholiday = null
		start_date = null
		end_date = null
		use_dates_if_forced = null
		forced_on = false
		priority = 0
		invalid = null

		/**
		 * Check if the holiday is active
		 * @return {bool} True if active, false if not
		 */
		function IsActive() {
			if (forced_on) {
				return true;
			}

			if (IsTFHolidayActive()) {
				if (use_dates_if_forced) {
					if (!IsForcedByConvar()) {
						return true;
					} else if (InDateRange()) {
						return true;
					}
				} else {
					return true;
				}
			}

			// custom holidays
			if (tfholiday == null && InDateRange()) {
				return true;
			}

			return false;
		}

		/**
		 * Check if the TF holiday is active
		 * @return {bool} True if active, false if not
		 */
		function IsTFHolidayActive() {
			return (tfholiday != null && IsHolidayActive(tfholiday));
		}

		/**
		 * Check if the TF holiday is being forced on by the server.
		 * It checks if the TF holiday's enum value is equivalent to the
		 * value of tf_forced_holiday.
		 * @return {bool} True if TF holiday is forced on by server
		 */
		function IsForcedByConvar() {
			return (tfholiday != null && tfholiday == holidays.forced_holiday);
		}

		/**
		 * Check if the server time is within the date range of the
		 * holiday. Server time is recorded on round restart.
		 * @return {bool} True if server time is within holiday date range
		 */
		function InDateRange() {
			local month = holidays.current_date.month;
			local day = holidays.current_date.day;

			local startMonth = start_date.month;
			local startDay = start_date.day;
			local endMonth = end_date.month;
			local endDay = end_date.day;

			// holiday starts in one month and ends in a future month
			if (endMonth > startMonth) {
				// check that day falls within holiday range
				local past_start = ((month > startMonth) || (month == startMonth && day >= startDay));
				local before_end = ((month < endMonth) || (month == endMonth && day <= endDay));
				local within_range = (past_start && before_end);
				return within_range;
			}
			// holiday starts in one year and ends in the next
			else if (startMonth > endMonth) {
				local past_end = ((month > endMonth) || (month == endMonth && day > endDay));
				local before_start = ((month < startMonth) || (month == startMonth && day < startDay));
				local outside_range = (past_end && before_start);
				return (!outside_range);
			}
			// start and end month are the same
			else if (startMonth == endMonth) {
				return ((month == startMonth) && (day >= startDay && day <= endDay))
			}
		}

		/**
		 * Trigger a logic_relay named after this holiday.
		 * Relay targetname format: relay_holiday_<name>
		 */
		function Trigger() {
			local relay = null;
			while (relay = Entities.FindByName(relay, format("relay_holiday_%s*", name)))
				relay.AcceptInput("Trigger", null, null, null);
		}
	}

	/**
	 * holidays root table
	 * Containing methods and the table of Holiday instances
	 */
	getroottable().holidays <- {
		_holidays = {}
		trigger_on_restart = true
		override_date = null

		/**
		 * Add holidays to the internal table as Holiday instances
		 * @param {table} table Table of holidays
		 */
		function AddHolidays(table) {
			foreach(key, value in table) {
				local holiday = Holiday(key, value);

				// invalid holiday config
				if (holiday.invalid == true) {
					error(__FILE__ + " -- Holiday with incomplete configuration '" + key + "'. Not added\n");
					DumpObject(value);
				} else {
					_holidays[key] <- holiday;
				}
			}
		}

		/**
		 * Get an array of all Holiday instances in the holiday table
		 */
		function GetHolidays() {
			return _holidays.values();
		}

		/**
		 * Get array of active holidays, ignoring priority
		 */
		function GetActive() {
			local holidays = GetHolidays();

			holidays = holidays.filter(function(index, val) {
				return val.IsActive();
			});

			return holidays;
		}

		/**
		 * Get array of active holidays, using the priority system
		 */
		function GetActivePriority() {
			local holidays = GetActive();
			local prio = 0;

			holidays.sort(function(a, b) {
				return a.priority <=> b.priority
			})

			// filter out holidays with a lower priority than the highest
			holidays = holidays.filter(function(index, val) {
				if (prio == 0 && val.priority > prio) {
					prio = val.priority
				}
				return (val.priority == prio || val.priority == 0)
			});

			return holidays;
		}

		/**
		 * Is named holiday active
		 * @param {string} name Name of holiday
		 */
		function IsActive(name) {
			return _holidays[name].IsActive();
		}

		/**
		 * Is holiday active, using priority system
		 * @param {string} name Name of the holiday
		 */
		function IsActivePriority(name) {
			local holidays = GetActivePriority();
			return (holidays.filter(function(index, val) {
				return val.name == name;
			}).len() > 0);
		}

		/**
		 * Print holiday data for debugging
		 */
		function Print() {
			local holidays = GetHolidays();
			printl(__FILE__ + " -- Holidays: " + holidays.len());
			foreach(holiday in holidays) {
				printl(__FILE__ + " -- Holiday '" + holiday.name + "' is " + (holiday.IsActive() ? "active" : "not active"));
			}

			local holidays = GetActivePriority();
			printl(__FILE__ + " -- Holidays that will be triggered: " + holidays.len());
			foreach(holiday in holidays) {
				printl(__FILE__ + " -- Holiday '" + holiday.name + "'. Priority: " + holiday.priority);
			}
		}

		/**
		 * Trigger a holiday manually
		 * @param {string} name Name of the holiday to trigger
		 */
		function Trigger(name) {
			if (name in _holidays) {
				_holidays.name.Trigger();
			}
		}

		/**
		 * Trigger active holidays
		 * @param {bool} priority Whether to use priority system
		 */
		function TriggerActive(priority = true) {
			local holidays = (priority) ? GetActivePriority() : GetActive();
			foreach(holiday in holidays) {
				if (developer()) printl(__FILE__ + " -- Triggering holiday " + holiday.name + " (priority " + holiday.priority + ")");
				holiday.Trigger();
			}
		}

		/**
		 * Override the date
		 * @param {int} month Month number between 1-12
		 * @param {int} day Day number starting from 1
		 */
		function OverrideDate(month, day) {
			override_date = {
				month = month
				day = day
			}
			foreach(key, val in override_date) {
				current_date[key] = val;
			}
			printl(__FILE__ + " -- Overriding month and day. Following holidays are now active:");
			local active_holidays = GetActive();
			foreach (key, val in active_holidays) {
				printl(__FILE__ + " " + val.name);
			}
		}
	};
};

// set date and time on round restart
holidays.current_date <- {};
LocalTime(holidays.current_date);

// override date if specified
if (holidays.override_date != null) {
	foreach(key, val in holidays.override_date) {
		holidays.current_date[key] = val;
	}
}

// grab server forced holiday cvar value
holidays.forced_holiday <- Convars.GetInt("tf_forced_holiday");

function OnPostSpawn() {
	if (OnPostSpawn_called) {
		return;
	} else {
		OnPostSpawn_called = true;
	}

	if (holidays.GetHolidays().len() == 0) {
		Assert(HOLIDAY_TABLE_NAME in this, __FILE__ + " -- Holiday table not found. Did you forget to add a holiday list file to the logic_script?");
		holidays.AddHolidays(self.GetScriptScope()[HOLIDAY_TABLE_NAME]);
		if (developer()) printl(__FILE__ + " -- Added " + holidays.GetHolidays().len() + " holidays");
	}

	// trigger holidays on round restart
	if (holidays.trigger_on_restart) {
		holidays.TriggerActive();
	}
}

/*
	Findings during development for my future sanity

	local options = {...} was required for Holidays class constructor to access options.
	options <- {...} resulted in unknown reference.
	Same happened with current_date.

	Script's holidays table and global ::holidays table seem to be the same.
	They have the same instance handle.
	`delete holidays` does not seem to delete it.
	Killing the logic_script doesn't appear to affect the global table.
	EDIT: It seems if you DumpObject(logic_script.GetScriptScope().holidays)
	it will actually show you the contents of the global holidays table.
	Doing DumpObject(logic_script.GetScriptScope()) shows the local holidays
	table no longer exists.

*/

/*
	Date ranges spanning two years:
	Christmas period was set to the following:

		// testing date range which spans two years
		start_date = {
			month = 12
			day = 1
		}
		end_date = {
			month = 1
			day = 7
		}
		use_dates_if_forced = true

	The date range reversion worked fine.
*/

/*
	Future plans
	* Holiday on specific days of the week
	* Reset date range check for each holiday on round restart
	* Evaluate 'active' and 'priority' checks on round restart and store to reuse
*/