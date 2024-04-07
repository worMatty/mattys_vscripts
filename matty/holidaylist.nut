
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
myholidays <- {

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