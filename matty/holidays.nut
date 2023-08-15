/**
 * Holidays
 *
 * A replacement for the tf_logic_on_holiday logic
 *
 * How it works:
 * - Modify the holidays in the table further down the page to your requirements.
 * - You can use both the normal TF holidays or create your own custom holidays.
 * - TF holidays are active when the server tells them to be by default, which is standard behaviour.
 * - You can opt to ignore when the server operators is forcing a holiday using the tf_forced_holiday convar
 * - When ignoring forcing, the holiday will revert to a date range, if one has been set
 * - Custom holidays require a date range
 * - The table slot key name (holiday name) is used to construct the targetname of the logic_relay you can trigger. e.g. relay_holiday_christmas
 * - To check if a holiday is active, use `holidays.name.IsActive()`
 */

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


// store current date once
local current_date = {};
LocalTime(current_date);

// options
local option_trigger_on_spawn = true; // trigger relays on round reset
local option_debug_mode = true; // print active holidays to server console on round reset

// put enum names in root for convenience and speed
foreach(key, value in Constants.EHoliday) {
	if (!(key in getroottable())) {
		getroottable()[key] <- value;
	}
}

// get forced convar value once
local forced_holiday = Convars.GetInt("tf_forced_holiday");

/**
 * Holiday class
 * Do not edit this
 */
local Holiday = class {
	constructor(table) {
		foreach(key, value in table) {
			this[key] = value;
		}
	}

	tfholiday = null;
	start_date = null;
	end_date = null;
	ignore_forced = null;
	active = null;
	name = "unknown";
	forced_on = false;
	priority = 0;

	function IsActive() {
		if (forced_on) {
			printl(format("WARNING: holidays.nut -- %s holiday is currently forced on!", name));
			return true;
		}

		if (active != null) {
			return active;
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

	function IsTFHolidayActive() {
		if (tfholiday != null) {
			return IsHolidayActive(tfholiday);
		}

		return false;
	}

	function IsForcedByConvar() {
		if (tfholiday != null) {
			if (tfholiday == forced_holiday) {
				return true;
			}
		}

		return false;
	}

	function InDateRange() {
		if (start_date && end_date) {
			local month = current_date.month;
			local day = current_date.day;

			local startMonth = start_date.month;
			local startDay = start_date.day;
			local endMonth = end_date.month;
			local endDay = end_date.day;

			if (month == startMonth && day >= startDay) {
				return true;
			} else if (month == endMonth && day <= endDay) {
				return true;
			} else if (month > startMonth && month < endMonth) {
				return true;
			} else {
				return false;
			}
		}

		return false;
	}

	function TriggerRelay() {
		local relayname = format("relay_holiday_%s", name);
		EntFire(relayname, "Trigger", null, 0, null);
	}
}

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
 * @param {integer} tfholiday EHoliday enum name or integer. null if making a custom holiday
 * @param {table} start_date Start month and day. Both must be provided. Only needed if making a custom holiday or wishing to restrict to date range when the holiday is forced via cvar
 * @param {table} end_date End month and day. Same as above
 * @param {bool} ignore_forced Ignore when the server tries to force it, and reverts to the date range if supplied
 * @param {bool} forced_on Force the holiday to be active, for testing purposes
 */

local holidays = {
	valentines = Holiday({
		tfholiday = kHoliday_Valentines
	})
	april_fools = Holiday({
		tfholiday = kHoliday_AprilFools
	})
	soldier = Holiday({
		tfholiday = kHoliday_Soldier
		forced_on = true
	})
	summer = Holiday({
		tfholiday = kHoliday_Summer
	})
	birthday = Holiday({
		tfholiday = kHoliday_TFBirthday
	})
	halloween = Holiday({
		tfholiday = kHoliday_Halloween,
		start_date = {
			month = 10
		}
		end_date = {
			month = 11
			day = 7
		}
		ignore_forced = true
	})
	christmas = Holiday({
		tfholiday = kHoliday_Christmas
		start_date = {
			month = 12
			day = 1
		}
		end_date = {
			month = 1
			day = 7
		}
	})
	fullmoon = Holiday({
		tfholiday = kHoliday_FullMoon
		ignore_forced = true
	})
	pride = Holiday({
		start_date = {
			month = 6
			day = 1
		}
		end_date = {
			month = 6
			day = 31
		}
	})
}

// store the name of each holiday when the script runs
foreach(key, holiday in holidays) {
	holiday.name = key;
};

// sort the table by priority
// table.sort(holidays, SortByPriority);

// debug function to display active holidays to server console
function CheckHolidays() {
	foreach(key, holiday in holidays) {
		if (holiday.IsActive()) {
			printl(format("%s is active", key));
		}
	}
}

// cause each active holiday to trigger its logic_relay
function TriggerHolidays() {
	foreach(key, holiday in holidays) {
		if (holiday.IsActive()) {
			holiday.TriggerRelay();
		}
	}
}

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

/**
 * Better way to do this would be:
 * Iterate over table entries
 * Get highest priority of active holiday
 * Iterate again and trigger any active holidays with the same priority
 */

// trigger active by priority
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
	return holiday2.priority <= > holiday1.priority;
}

// called automatically on round restart
function OnPostSpawn() {
	if (option_debug_mode) {
		printl("Checking holidays");
		CheckHolidays();
	}

	if (option_trigger_on_spawn) {
		TriggerHolidays();
	}
}