/*
	Holiday list
	Create a copy of this list for your map like so:
	tf/vscripts/mapname/holiday_list.nut
	Add the script to the logic_script entity you made for holidays.nut.
	Both scripts should be in the field. This script's data will be added to the entity.
	Customise the holidays in the 'myholidays' table. Examples are further down.
	Custom holiday ranges only require a date range.

	How to use the holiday priority system:
	The priority system ensures no conflicting holidays will be triggered at once.
	e.g. Christmas and Hallowe'en at the same time would ruin your aesthetic.
	If any active holidays have a priority number, only those matching the lowest number will trigger.
	e.g. Christmas = 1 and Hallowe'en = 2. Christmas would trigger and Hallowe'en would not.
	Active holidays without a priority will still trigger.

	Useful info for mappers:
	Use 'forced_on = true' to force a holiday on during development.
	Alternatively, you can override the date using a console command.
	See holidays.nut for info on how to do this.
*/

// this is the table you can modify
myholidays <- {

	valentines = {
		tfholiday = kHoliday_Valentines
	}

	aprilfools = {
		tfholiday = kHoliday_AprilFools
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
		use_dates_if_forced = true // use date range if server forces this holiday
		priority = 2
	}

	christmas = {
		tfholiday = kHoliday_Christmas
		priority = 1
		// forced_on = true
	}

	fullmoon = {
		tfholiday = kHoliday_FullMoon
		// forced_on = true
	}
}

// these are just examples and won't be used
// custom holidays only require a date range
examples <- {

	// overriding a custom holiday using a date range when the
	// server is forcing this holiday on all the time.
	// prevents situations like Hallowe'en all year round
	halloween = { // name used in the logic_relay: relay_holiday_halloween
		tfholiday = kHoliday_Halloween // this is a TF2 native holiday and is activated by the game code on the server
		start_date = { // specify a date range if you wish to fall back to it if a server is forcing this holiday using console variable
			month = 10 // holiday starts in October. Without a day specified, it starts on the 1st
		}
		end_date = {
			month = 11
			day = 7 // holiday is active up to and including November the 7th
		}
		use_dates_if_forced = true // if the server is forcing this holiday using a console variable, the script will revert to the date range
		priority = 2 // see the info on priority at the top of this doc
	}

	// a custom pride holiday
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

	// date ranges used for testing the code
	same_year = {
		start_date = {
			month = 4
			day = 1
		}
		end_date = {
			month = 8
			day = 1
		}
	}

	next_year = {
		start_date = {
			month = 12
			day = 1
		}
		end_date = {
			month = 1
			day = 31
		}
	}

	same_month = {
		start_date = {
			month = 3
			day = 1
		}
		end_date = {
			month = 3
			day = 31
		}
	}
}

/*
	TF2 holiday info
	~ indicates an approximate date based on history

	Name			Game code number/enum		Date range
	----			---------------------		----------
	Valentines		6	kHoliday_Valentines		February 14th
	April Fools		11	kHoliday_AprilFools		April 1st
	Soldier			12	kHoliday_Soldier		April 8th
	Summer			13	kHoliday_Summer			Range currently unknown
	Birthday		1	kHoliday_TFBirthday		~August 23rd
	Hallowe'en		2	kHoliday_Halloween		~October 1st - ~November 7th
	Christmas		3	kHoliday_Christmas		~December 1st - ~January 7th
	Full Moon		8	kHoliday_FullMoon		Every 28 days
*/