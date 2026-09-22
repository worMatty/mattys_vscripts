/*
	Holidays v0.3 by worMatty

	Automatic triggering of holiday logic. Supports custom holidays with defined date and day ranges.
	Features a priority system and detects when the server is forcing a holiday, enabling you to avoid clashing aesthetics.
	Tools for easy development of holiday features in your map or script.

	Features
	* Trigger aptly-named logic_relay, logic_case, and set the value of logic_branch on round restart
	* Check if a holiday is active in RunScriptCode inputs, and do certain things if so
	* Priority system to stop clashing holidays like Hallow'en and Christmas
	* Support for native TF holidays, and custom holidays with date and weekday ranges
	* Check to see if the server is forcing a holiday on, and fall back to a given date range if so
	* Easy development and debugging tools, and extra console messages with developer mode enabled

	Usage
	* Add the script to a logic_script entity.
		Please note the script has an OnPostSpawn function that may get overwritten by other scripts added to the same entity.
	* Configure a holiday table in a separate script file and add it to the logic_script entity.  See holiday_lists.nut for examples.
	* Create one of the logic entities detailed below. They will be triggered on round restart

	Further usage
	* Disable or enable triggering logic entities automatically on round restart using the following input:
		any entity > RunScriptCode > holidays.SetAutoTrigger(false)
	  This setting will persist through rounds so you will need to set it to true to return to normal operation
	* Force a holiday on for testing using holidays.SetForcedOn(`<name>`, true), or false to return to normal
	* Force a holiday off for testing using holidays.SetForcedOff(`<name>`, true), or false to return to normal

	Logic entities triggered on round restart. <name> is the holiday name
	* logic_relay with targetname `relay_holiday_<name>*` receives Trigger
	* logic_branch with targetname `branch_holiday_<name>*` receives SetValue 1
	* logic_case with targetname `case_holidays*` receives InValue <name> (yes, logic_case supports strings)
	Note the inclusion of the asterisk character, indicating you can suffix anything to the targetname and it will still be called.
	The wildcard character is a standard feature of Source's I/O system.

	Priority system
	* When there are multiple holidays that qualify to be active at once, if any of them have a priority number,
	  only the highest number will be activated. For example, if one holiday has a priority of 2 and another
	  has a priority of 1, the first holiday will activate and the second will not.
	* All holidays with a priority of 0 (the default) will be activated regardless
	* You can use negative numbers to place a holiday's priority lower than the default
	* holidays.IsActive() takes priority into account and returns false if the holiday has been superceded

	Development and debugging
	* Enable `developer 1` or higher in console and extra information will be printed to the server console
	* holidays.SetOverrideDate(day, month) can be used to fake the current day and month
	* To refresh holiday data, type `script delete holidays` in server console and restart the round

	Scripting
	* holidays.IsActive(`<name>`) is in global scope and can be used to check if a holiday is active
	* IsHolidayForcedOn(int) can be used to check if the server is forcing a holiday using the tf_force_holiday convar.
	  Replace int with the holiday number. Scroll to the bottom of this script to see them. Global function.
	* The script looks for any tables with 'holidays' in their name, that have been added to the logic_script entity.
	  This means you do not need to use holiday_list.nut and can put the table(s) in your own script file(s) if you wish
	* Constants.EHoliday is folded into root scope for convenience

	Troubleshooting
	* Carefully check the server console for error messages pertaining to incorrectly-configured holidays
	* Enable developer mode (`developer 1`) for more information and peace of mind that things are working
	* Do note that holiday data is stored once on the first round and is not refreshed or replaced.
	  If you make changes you will need to delete the holiday data using the method listed above, or restart the map.
*/

/*
	Changelog
		Version 0.3 - Rewrite
		Force off to ensure a holiday stays disabled, for testing
		Force on and off functions that can be used in server console for convenience (see the root table)
		IsHolidayForcedOn function now also checks combined cvar values 9 and 10 (halloween + full moon + valentines)
		IsHolidayForcedOn function moved to global scope for scripters, and for mappers to use in I/O
		logic_relay triggering is now done using EntFire with a delay of -1 for simplicity
		In addition, we now send the InValue input to logic_cases with a certain name. The passed value is the holiday name string ("case_holidays*")
		We also SetValue of named logic_branches to 1 ("branch_holiday_<name>*")
		Simplified code
		Holiday data loaded from any script in the entity's script scope containing a table with the word 'holidays' in its name
		No longer needs stocks2.nut
		Priority system is built in (note: 0 priority always triggers. < 0 priority won't trigger if there are any with 0)
		holidays.SetAutoTrigger(true) function to conveniently enable or disable automatic triggering on round restart
		Check days of the week. Configuration uses 1-7 Sunday to Saturday. Month and day date are not used.
*/

// everything that happens on round restart
function OnPostSpawn() {
	// prevent function being called more than once
	if ("OnPostSpawn_called" in this) return;
	this.OnPostSpawn_called <- true;

	// record new round data
	holidays.force_convar_val = Convars.GetInt("tf_forced_holiday");
	if (!holidays.date_overridden) {
		LocalTime(holidays.current_date);
	} else {
		printl(__FILE__ + " -- Warning: Current date is still overridden!");
	}

	// add holidays
	if (!holidays.holidays.len()) {
		printl(__FILE__ + " -- Adding holidays to global table. This should only happen on the first round");
		local tables_found = 0;

		foreach(key, val in this) {
			if (key.find("holidays") && typeof val == "table") { // check if there is a table with a name containing the word 'holidays'
				if (developer()) {
					printl(__FILE__ + " -- Found table named '" + key + "'. Key names:");
					DumpObject(val.keys());
				}

				tables_found++;
				foreach(holiday_name, holiday_data in val) {
					local holiday = Holiday(holiday_name, holiday_data);

					if (holiday.is_valid) {
						holidays.holidays[holiday_name] <- holiday;
						if (developer()) printl(__FILE__ + " -- Added holiday " + holiday_name);
					} else {
						error(__FILE__ + " -- Error: Holiday '" + holiday_name + "' has invalid data. Please see error messages above. Thanks!\n");
					}
				}
			}
		}

		if (!tables_found) {
			error(__FILE__ + format(" -- Error: No holiday data tables were found. Make sure you're adding them in a separate script file to this logic_script entity (%s), and that the table names contain the word 'holidays'"), self.GetName());
		}
	}
	if (!holidays.holidays.len()) {
		return; // exit early as there are no holidays lol
	}

	// no triggering if globally disabled
	if (!holidays.trigger_on_round_restart) {
		if (developer()) printl(__FILE__ + " -- Triggering no holidays on round restart as holidays.trigger_on_round_restart is set to false");
		return;
	}

	// get active holidays
	local active_holidays = [];
	foreach(holiday in holidays.holidays) {
		holiday.is_active = null; // reset previous check
		if (holiday.IsActive()) {
			active_holidays.append(holiday); // store active holidays
		}
	}
	if (!active_holidays.len()) { // exit early if no active holidays
		if (developer()) printl(__FILE__ + " -- No activate holidays");
		return;
	}

	// sort active by priority
	active_holidays.sort(function(a, b) {
		return b.priority <=> a.priority; // sort active holidays by priority in descending order
	})

	// filter out those with a lower priority than the highest, unless their priority is 0
	local highest_priority = active_holidays[0].priority; // get highest priority
	active_holidays = active_holidays.filter(function(index, holiday) {
		return (holiday.priority == highest_priority || holiday.priority == 0);
	});

	// trigger holidays
	foreach(holiday in active_holidays) {
		if (holiday.trigger_on_round_restart) {
			holiday.Trigger();
			if (developer()) printl(__FILE__ + " -- Triggering active holiday '" + holiday.name + "'");
		}
	}
}

if ("holidays" in getroottable()) return; // exit early to avoid redoing global stuff
if (!("kHoliday_None" in getroottable())) foreach(key, val in Constants.EHoliday) getroottable()[key] <- (val == null) ? 0 : val;

getroottable().holidays <- {
	force_convar_val = 0
	current_date = {} // current date. set on round restart and used by checks, to avoid holidays changing mid round
	date_overridden = false // date has been overridden with custom values for testing
	trigger_on_round_restart = true // trigger active holidays on round restart
	holidays = {} // table of holiday classes indexed by holiday name

	IsActive = function(key_name) {
		if (key_name in holidays) {
			return holidays[key_name].IsActive();
		} else {
			error(__FILE__ + " -- holidays.IsActive() -- No holiday named " + key_name + "\n");
			return false;
		}
	}
	Trigger = function(key_name) {
		if (key_name in holidays) {
			holidays[key_name].Trigger();
		} else {
			error(__FILE__ + " -- holidays.Trigger() -- No holiday named " + key_name + "\n");
		}
	}
	SetAutoTrigger = function(set = true) {
		trigger_on_round_restart = set;
		printl(__FILE__ + " -- Round restart triggering of holidays has been " + (set ? "enabled" : "disabled"));
	}

	// debugging
	SetForcedOn = function(key_name, set) {
		if (key_name in holidays) {
			holidays[key_name].forced_on = set;
			printl(__FILE__ + " -- Forced on holiday " + key_name);
		}
	}
	SetForcedOff = function(key_name, set) {
		if (key_name in holidays) {
			holidays[key_name].forced_off = set;
			printl(__FILE__ + " -- Forced off holiday " + key_name);
		}
	}
	SetOverrideDate = function(day = null, month = null) {
		if (day == null && month == null) {
			printl("SetOverrideDate usage: SetOverrideDate(int day, int month). Values start at 1. Supply null in either arg to keep current");
			return;
		}
		if (day != null) current_date.day <- day;
		if (month != null) current_date.month <- month;
		printl("Overrode date. New current date:");
		DumpObject(current_date);
		printl("Use ClearOverrideDate() to reset");
		date_overridden = true;
	}
	ClearOverrideDate = function() {
		date_overridden = false;
		LocalTime(current_date);
		printl("Date reset. New current date:");
		DumpObject(current_date);
	}
};

/**
 * Check if a TF holiday is forced on by the server using tf_forced_holiday. Compares integer values directly
 * and also checks 'combined' holiday values 9 and 10 (halloween + full moon + valentines).
 * @param {integer} tfholiday Constants.EHoliday integer value of the holiday. e.g. 1 is Birthday.
 * @return {bool} True if holiday is being forced
 */
::IsHolidayForcedOn <- function(tfholiday) {
	local forced_val = Convars.GetInt("tf_forced_holiday");
	if (!forced_val) return false;
	if (tfholiday == forced_val) return true;
	if (forced_val == kHoliday_HalloweenOrFullMoon && (tfholiday == kHoliday_Halloween || tfholiday == kHoliday_FullMoon)) {
		return true;
	}
	if (forced_val == kHoliday_HalloweenOrFullMoonOrValentines && (tfholiday == kHoliday_Halloween || tfholiday == kHoliday_FullMoon || tfholiday == kHoliday_Valentines)) {
		return true;
	}
	return false;
};

::Holiday <- class {
	constructor(holiday_name, params) {
		foreach(key, value in params) if (key in this) this[key] = value;
		name = holiday_name;

		// error checking
		if (!start_date || !end_date) {
			if (tfholiday == null) {
				error(__FILE__ + " -- Holiday '" + name + "' has no start or end date but does not specify a tfholiday\n");
				is_valid = false;
			}
			if (use_dates_if_forced) error(__FILE__ + " -- Holiday '" + name + "' has no start or end date but has use_dates_if_forced set to true. When the server is forcing it, this holiday will not trigger without a date range\n");
		}

		// start date checking
		if (start_date) {
			if (!end_date) {
				error(__FILE__ + " -- Holiday '" + name + "' has a start date but no end date\n");
				is_valid = false;
			}
			if (!("month" in start_date)) start_date.month <- holidays.current_date.month; // add start month if it does not exist
			if (!("day" in start_date)) start_date.day <- holidays.current_date.day; // add start day if it does not exist
		}

		// end date checking
		if (end_date) {
			if (!start_date) {
				error(__FILE__ + " -- Holiday '" + name + "' has an end date but no start date\n");
				is_valid = false;
			}
			if (!("month" in end_date)) end_date.month <- holidays.current_date.month; // add end month if it does not exist
			if (!("day" in end_date)) end_date.day <- holidays.current_date.day; // add end day if it does not exist
		}

		// check if holiday is forced on or off in config
		if (forced_on) printl(__FILE__ + " -- Warning: Holiday '" + name + "' has been forced ON in config!");
		if (forced_off) printl(__FILE__ + " -- Warning: Holiday '" + name + "' has been forced OFF in config!");
	}

	static RELAY_TARGETNAME_PREFIX = "relay_holiday_"
	static BRANCH_TARGETNAME_PREFIX = "branch_holiday_"
	static CASE_TARGETNAME = "case_holidays"

	// parameters
	name = null // holiday name. used to target specific entities with I/O (relays etc.). same as table slot key
	tfholiday = null // official TF holiday value
	priority = 0 // holidays with highest priority are activated when there is some contention. 0 always activates
	use_dates_if_forced = false // true to ignore the force cvar if it's set to this tfholiday enum val and fall back to supplied date range
	trigger_on_round_restart = true // trigger this holiday's logic_relays and logic_cases on round restart
	forced_on = false // force this holiday on for debugging
	forced_off = false // force this holiday off for debugging
	start_date = null // day and month the holiday starts
	end_date = null // day and month the holiday ends

	// internal
	is_valid = true // set on construction. invalid holidays won't work and should be deleted
	is_active = null // this is set the first time IsActive is called. saves future processing time

	InDateRange = function() {
		local month = holidays.current_date.month;
		local day = holidays.current_date.day;
		local weekday = holidays.current_date.dayofweek + 1; // add one because our config uses 1-7

		local startMonth = start_date.month;
		local startDay = start_date.day;
		local endMonth = end_date.month;
		local endDay = end_date.day;
		local startWeekday = ("weekday" in start_date) ? start_date.weekday : null;
		local endWeekday = ("weekday" in end_date) ? end_date.weekday : null;

		// days of week only
		if (startWeekday != null && endWeekday != null) {
			if (endWeekday > startWeekday) { // ends this week
				local past_start = (weekday >= startWeekday);
				local before_end = (weekday <= endWeekday);
				return (past_start && before_end); // true if within range
			}
			if (startWeekday > endWeekday) { // ends in  next week
				local past_end = (weekday > endWeekday);
				local before_start = (weekday < startWeekday);
				local outside_range = (past_end && before_start);
				return !outside_range;
			}
		}

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

	IsActive = function() {
		if (forced_on) return true;
		if (forced_off) return false;
		if (is_active != null) return is_active;

		if (tfholiday && IsHolidayActive(tfholiday)) { // this holiday is configured with a tfholiday number, and it is active on the server
			if (use_dates_if_forced) {
				if (!IsHolidayForcedOn(tfholiday)) { // the holiday is not being forced on by the server, so we are genuinely in this holiday period
					is_active = true;
				} else { // the server is forcing the holiday on
					if (InDateRange()) { // the holiday has been configured with a date range, and the current date is within it
						printl(__FILE__ + " -- Holiday is forced on by server convar but we'll fall back to date range: " + name);
						is_active = true;
					} else { // the current date is not within the holiday's configured date range
						is_active = false;
					}
				}
			} else { // we don't care if the holiday is being forced on by the server
				is_active = true;
			}
		} else if (tfholiday == null && InDateRange()) { // this is a custom holiday, and the current date is within its range
			is_active = true;
		}

		return is_active;
	}

	Trigger = function() {
		EntFire(RELAY_TARGETNAME_PREFIX + name + "*", "Trigger", null, -1, null); // logic_relay Trigger
		EntFire(BRANCH_TARGETNAME_PREFIX + name + "*", "SetValue", 1, -1, null); // logic_branch SetValue
		EntFire(CASE_TARGETNAME + "*", "InValue", name, -1, null); // logic_case InValue
	}
}

/*
	TF Holiday enum
		Constants.EHoliday
			Name 										Value
			kHoliday_None 								0
			kHoliday_TFBirthday 						1
			kHoliday_Halloween 							2
			kHoliday_Christmas 							3
			kHoliday_CommunityUpdate 					4
			kHoliday_EOTL 								5
			kHoliday_Valentines 						6
			kHoliday_MeetThePyro 						7
			kHoliday_FullMoon 							8
			kHoliday_HalloweenOrFullMoon 				9
			kHoliday_HalloweenOrFullMoonOrValentines 	10
			kHoliday_AprilFools 						11
			kHoliday_Soldier 							12
			kHoliday_Summer 							13
			kHolidayCount 								14
*/