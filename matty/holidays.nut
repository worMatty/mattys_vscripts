/**
 * Holidays v0.1
 *
 * A replacement for the tf_logic_on_holiday logic
 *
 * Features
 * * Fire relays on round restart for active holidays
 * * Custom holiday periods
 * * State checking of holidays
 * * Optionally revert to date range when server is forcing holiday
 *
 * Custom holidays:
 * Custom holidays require a start date and end date.
 * Supply both the month and day, or just the day for a recurring monthly holiday.
 * See the holidays table for examples.
 *
 * How it works when the server forces a particular holiday using tf_forced_holiday:
 * Sometimes a server operator will use the console variable `tf_forced_holiday` to
 * force a particular holiday - such as Hallowe'en - in order to use its cosmetics and effects.
 * This will cause any map logic for that holiday to be triggered. This can be undesirable,
 * if for example you don't want spooky skeletons to appear outside Hallowe'en.
 *
 * To fix that problem, you can give a holiday a date range and add ignore_forced = true.
 * If the server is forcing that holiday, the script will revert to the date range.
 * If you set ignore_forced = true and don't add a date range, the script will just
 * not trigger that holiday if it's being forced, even if it's enabled by the game.
 *
 * Forcing is most-often done for Hallowe'en. There is a SourceMod plugin by
 * Mikusch which grants all its cosmetic features without forcing the holiday.
 * Please tell the server operator about this so they do not falsely trigger holiday map logic.
 */

/**
 * How to use:
 *
 * 1. Add this script to a logic_script.
 * 2. Have a look at the holidays table further down to understand it and
 * 	add any custom holidays you want
 * 3. Create logic_relays named `relay_holiday_<name>` where `<name>`
 * 	is replaced by the holiday name in the table. e.g. `relay_holiday_aprilfools`.
 * 4. Check if a holiday is active using Hammer logic/VScript by running
 * 		`holidays.<name>.IsActive()`
 * 	It will return true if the holiday is active.
 *
 * Tip: If you prefer using entities, add a logic_branch for a holiday and in the relay,
 * set its value to 'true'. Then you can use the branch as a state check. You can also
 * use logic_branch_listener to respond to state changes.
 */

// options
local options = {
	trigger_on_spawn = true // trigger relays on round reset
	debug_mode = false // print extra console messages. disable on production/release maps
};

/**
 * Holidays
 *
 * ~ indicates an approximate date based on history
 *
 * Valentines		6	kHoliday_Valentines		February 14th
 * April Fools		11	kHoliday_AprilFools		April 1st
 * Soldier			12	kHoliday_Soldier		April 8th
 * Summer			13	kHoliday_Summer			Range currently unknown
 * Birthday			1	kHoliday_TFBirthday		~August 23rd
 * Hallowe'en		2	kHoliday_Halloween		~October 1st - ~November 7th
 * Christmas		3	kHoliday_Christmas		~December 1st - ~January 7th
 *
 * Full Moon		8	kHoliday_FullMoon		Every 28 days
 */

/**
 * This is a list of all the holidays the script will check for, and will fire a logic_relay for if they are active.
 * It's safe to leave any holidays here that you do not intend to use.
 *
 * Date ranges are required for any custom holiday you create. They are not required for TF holidays, unless you wish to
 * provide a backup date range for when the game server is forcing the holiday using tf_forced_holiday. In reality
 * only Hallowe'en is likely to be forced, but this practice is redundant with Mikusch's holiday cosmetics plugin.
 * Both start date and end date must have both a month and a day.
 *
 * If you want to override a TF holiday with your own date ranges it's as simple as deleting the tfholiday property and
 * supplying a date range. It will be classed as a custom holiday and only the date range will be used. ignore_forced will be redundant.
 *
 * @param {integer} tfholiday kHoliday enum name or integer. Not required by a custom holiday
 * @param {table} start_date Start month and day for custom holiday or forced backup
 * @param {table} end_date End month and day for custom holiday or forced backup
 * @param {bool} ignore_forced If tf_forced_holiday matches the holiday number, revert to date range, or just be inactive
 * @param {bool} forced_on Force the holiday to be active, for testing purposes
 */

holidays <- {

	valentines = {
		tfholiday = kHoliday_Valentines
	}

	aprilfools = {
		tfholiday = kHoliday_AprilFools
		// forced_on = true // you can force trigger a holiday for testing purpose
	}

	soldier = {
		tfholiday = kHoliday_Soldier
	}

	summer = {
		tfholiday = kHoliday_Summer
	}

	birthday = {
		tfholiday = kHoliday_TFBirthday
	}

	halloween = {
		tfholiday = kHoliday_Halloween
		start_date = {
			month = 10
		}
		end_date = {
			month = 11
			day = 7
		}
		// ignore_forced = true	// use date range if server forces this holiday
	}

	christmas = {
		tfholiday = kHoliday_Christmas
	}

	fullmoon = {
		tfholiday = kHoliday_FullMoon
	}

	// a custom holiday
	pride = {
		start_date = {
			month = 6
			day = 1
		}
		end_date = {
			month = 6
			day = 31
		}
	}

	// a holiday every 9th day of the month
	nineday = {
		start_date = {
			day = 9
		}
		end_date = {
			day = 9
		}
	}
}


// Nothing modifiable below here
// --------------------------------------------------------------------------------

local current_date = {};
LocalTime(current_date);
local forced_holiday = Convars.GetInt("tf_forced_holiday");

if (!("holidays" in getroottable())) {
	foreach(key, value in Constants.EHoliday) {
		if (!(key in getroottable())) {
			getroottable()[key] <- value;
		}
	}
}

/**
 * Holiday class
 * Do not edit this
 */
Holiday <- class {
	constructor(table) {
		foreach(key, value in table) {
			this[key] = value;
		}

		// error checking
		if (start_date == null || end_date == null) {
			if (tfholiday == null) {
				error("Holidays -- Holiday '" + name + "' has no start or end date but does not specify a tfholiday\n");
				invalid = true;
			}

			if (ignore_forced == true && options.debug_mode) {
				printl("Holidays -- Holiday '" + name + "' has no start or end date but has ignore_forced set to true\nWhen the server is forcing it, this holiday will not trigger");
			}
		}

		// start date checking
		if (start_date != null) {
			if (end_date == null) {
				error("Holidays -- Holiday '" + name + "' has a start date but no end date\n");
				invalid = true;
			}

			// add start month if it does not exist
			if (!("month" in start_date)) {
				start_date.month <- current_date.month;
			}

			// add start day if it does not exist
			if (!("day" in start_date)) {
				start_date.day <- current_date.day;
			}
		}

		// end date checking
		if (end_date != null) {
			if (start_date == null) {
				error("Holidays -- Holiday '" + name + "' has an end date but no start date\n");
				invalid = true;
			}

			// add end month if it does not exist
			if (!("month" in end_date)) {
				end_date.month <- current_date.month;
			}

			// add end day if it does not exist
			if (!("day" in end_date)) {
				end_date.day <- current_date.day;
			}
		}

		// check if holiday is forced on in config
		if (forced_on) {
			printl("Holidays -- Holiday '" + name + "' has been forced on in config!");
		}
	}

	name = null
	tfholiday = null
	start_date = null
	end_date = null
	ignore_forced = null
	forced_on = false
	priority = 0
	in_date_range = null // to save having to check date range repeatedly
	invalid = null

	/**
	 * Check if a holiday is active
	 * @return {bool} True if active, false if not
	 */
	function IsActive() {
		if (forced_on) {
			return true;
		}

		if (IsTFHolidayActive()) {
			if (ignore_forced) {
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
		return (tfholiday != null && tfholiday == forced_holiday);
	}

	/**
	 * Check if the server time is within the date range of the
	 * holiday. Server time is recorded on round restart.
	 * @return {bool} True if server time is within holiday date range
	 */
	function InDateRange() {
		if (in_date_range != null) {
			return in_date_range;
		}

		if (start_date && end_date) {
			local month = current_date.month;
			local day = current_date.day;

			local startMonth = start_date.month;
			local startDay = start_date.day;
			local endMonth = end_date.month;
			local endDay = end_date.day;

			if (month == startMonth && day >= startDay) {
				in_date_range = true;
			} else if (month == endMonth && day <= endDay) {
				in_date_range = true;
			} else if (month > startMonth && month < endMonth) {
				in_date_range = true;
			} else {
				in_date_range = false;
			}
		} else {
			// no start date or end date set
			in_date_range = false;
		}

		return in_date_range;
	}

	/**
	 * Trigger a logic_relay named after this holiday.
	 * Relay targetname format: relay_holiday_<name>
	 */
	function TriggerRelay() {
		if (options.debug_mode) {
			printl("Holidays -- Debug mode -- Triggering relay for holiday '" + name + "'");
		}
		EntFire(format("relay_holiday_%s", name), "Trigger", null, -1);
	}
};

// create/reset global holidays table
::holidays <- {};

// convert tables into Holiday instances
foreach(key, value in holidays) {
	if (!("name" in value)) {
		value.name <- key;
	}

	local holiday = Holiday(value);
	// holidays[key] <- holiday;
	::holidays[key] <- holiday;

	// invalid holidays may not work properly
	if (holiday.invalid == true) {
		error("Holidays -- Holiday with incomplete configuration '" + key + "'\n");
		DumpObject(value);
	}
}

// delete local holidays table
delete holidays;

// debug function to display active holidays to server console
function CheckHolidays() {
	foreach(key, holiday in holidays) {
		if (holiday.IsActive()) {
			printl("Holidays -- Debug mode -- Holiday '" + key + "' is active");
		}
	}
}

/**
 * Cause each active holiday to trigger its logic_relay
 */
function TriggerHolidays() {
	if (options.debug_mode) {
		printl("Holidays -- Debug mode -- Triggering holidays");
	}

	foreach(holiday in holidays) {
		if (holiday.IsActive()) {
			holiday.TriggerRelay();
		}
	}
}

/**
 * Check if holidays are active and print to console
 * Only works id debug mode is enabled
 */
if (options.debug_mode) {
	printl("Holidays -- Debug mode -- Checking holidays");
	CheckHolidays();
}

/**
 * Trigger relays for active holidays
 * Only happens if 'trigger on spawn' option is enabled
 */
if (options.trigger_on_spawn) {
	TriggerHolidays();
}

// Work in progress priority stuff below here
// --------------------------------------------------------------------------------

// get a list of holidays, sort them by priority and return only the top values
// function TriggerPriority() {
// 	local array = [];

// 	foreach(key, value in holidays) {
// 		array.push(value);
// 	}

// 	array.sort(SortByPriority);

// 	local priority = null;

// 	foreach(value in array) {
// 		if (priority == null) {
// 			priority = value.priority;
// 		}

// 		local new_priority = value.priority;

// 		if (new_priority < priority) {
// 			break;
// 		}

// 		printl("Triggering relay for " + value.name);
// 		value.TriggerRelay();
// 	}
// }

/**
 * Better way to do this would be:
 * Iterate over table entries
 * Get highest priority of active holiday
 * Iterate again and trigger any active holidays with the same priority
 */

/**
 * Trigger active holidays with the highest priority.
 */
function TriggerPriority() {
	local highest = 0;

	foreach(holiday in holidays) {
		highest = (holiday.priority > highest) ? holiday.priority : highest;
	}

	foreach(holiday in holidays) {
		if (holiday.priority == highest) {
			holiday.TriggerRelay();
			printl("TriggerPriority() -- Triggering " + holiday.name);
		}
	}
}

// custom comparison function to sort by priority
function SortByPriority(holiday1, holiday2) {
	return holiday2.priority <=> holiday1.priority;
}

// Depelopment notes
// --------------------------------------------------------------------------------

/**
 * Plans
 *
 * Offer to rotate between active holidays or choose randomly
 * 	If rotating, incoporate round length forgiveness
 *
 * Internal variable to force on for testing
 *
 * Holiday priority
 * 	Full Moon over Halloween
 * 	Full Moon over Christmas
 * 	Christmas over Halloween
 * 	Halloween under everything else
 *
 * Method:
 *
 * Replace check with a function for each holiday which checks arbitrary things:
 * 	TFHoliday status
 * 	Date range
 *
 * Other stuff:
 * 	How does TF2 get the full moon times?
 * 	When checking if some holidays are forced, check the other cvar values.
 * 		Is there a simple solution using bit checks? Should we ignore combined holiday values?
 */

/**
 * Changes to make
 *
 * Only trigger if holiday is active
 *
 * Opt to only use priority when certain holidays are active
 * i.e. do not only allow one holiday to trigger. Have priority between two holidays. e.g. Full Moon and Halloween.
 * The rest are triggered if active.
 * Maybe make some mutually exclusive? Specify which holidays should not be triggered simultaneously.
 * How can we rotate them?
 */

/*
Findings

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
	ignore_forced = true

The date range reversion worked fine.
*/