/*
Enables a map author to view feedback for their map

Todo
3. Show positions of feedback by a sprite in the world set to render over geometry
4. Cycle to the pos and view angles of each piece of feedback using a command or controls
5. When cycling, show feedback in text, csay, hsay training message or TA
6. Show CONSOLE feedback in text
7. Spawn a prop or sprite at the location of feedback because the TA's origin is hard to spot
8. Move overlapping feedback apart
*/

/*
Bugs
*/

local FEEDBACK_TIMER = "timer_feedback";

// ----------------------------------------------------------------------------------------------------

feedback <- {
	comments = []
	timer = null
};

// ----------------------------------------------------------------------------------------------------

feedback.On <-  function(rate = 1.0) {
	feedback.StartTimer(rate);
	EntFire(FEEDBACK_TIMER, "FireTimer", null, -1, null);
}

feedback.Off <-  function() {
	feedback.StopTimer();
	feedback.HideAll();
}

// ----------------------------------------------------------------------------------------------------

/**
 * Comment class
 * @param {integer} id Unique id number to ensure the training annotation is not overridden
 * @param {table} table Table of comment data
 */
class Comment {
	constructor(_id, table) {
		id = _id;
		author_name = table.author_name;
		pos = table.pos;
		angles = table.angles;
		time = table.time;
		text = table.text;
		full_text = author_name + ": " + text;
		BreakLine();

		local trace = {
			start = pos
			end = pos + angles.Forward() * 32768.0
		};
		TraceLineEx(trace);
		tracepos = trace.pos;
	}

	id = null
	author_name = null
	pos = null
	angles = null
	time = null
	text = null
	full_text = null
	tracepos = null
	expanded = null

	/**
	 * Check if there are any players near to this comment
	 * Display the expanded text if there are, else display collapsed text ("...")
	 * @param {float} radius Radius to check for player entities
	 */
	function CheckDistance(radius) {
		local ent = null;

		// player is within radius
		if (ent = Entities.FindByClassnameWithin(ent, "player", tracepos, radius)) {
			if (!expanded) {
				DisplayFull();
			}
			return true;
		}

		// player is outside radius
		else {
			if (expanded || expanded == null) {
				DisplayCollapsed();
			}
			return false;
		}
	}

	/**
	 * Display the full text and set expanded status to true
	 */
	function DisplayFull() {
		expanded = true;
		ShowTA();
	}

	/**
	 * Display collapsed text and set expanded status to false
	 */
	function DisplayCollapsed() {
		expanded = false;
		ShowTA("...");
	}

	/**
	 * Override the TA with a new message with a lifetime of 0sec to 'hide' it,
	 * and set expanded status to null
	 */
	function Hide() {
		expanded = null;
		ShowTA("Goodbye!", 0);
	}

	/**
	 * Break the comment up into two lines
	 */
	function BreakLine() {
		local len = full_text.len();
		if (len > 20) {
			local index = full_text.find(" ", (len * 0.45).tointeger());
			full_text = full_text.slice(0, index) + "\n" + full_text.slice(index + 1);
		}
	}

	/**
	 * Show a training annotation in the world for this comment
	 * @param {string} _text Message to display in the TA
	 * @param {integer} _lifetime Time to display the TA for. Default one hour, which should be plenty
	 */
	function ShowTA(_text = null, _lifetime = 3600) {
		if (_text == null) {
			_text = full_text;
		};

		local params = {
			text = _text
			worldPosX = tracepos.x
			worldPosY = tracepos.y
			worldPosZ = tracepos.z
			id = id

			// extra options
			lifetime = _lifetime
			// play_sound = "common/null.wav"
			show_distance = false
			show_effect = false

			// worldNormalX = options.worldNormalX
			// worldNormalY = options.worldNormalY
			// worldNormalZ = options.worldNormalZ
		}

		SendGlobalGameEvent("show_annotation", params);
	}
}

// ----------------------------------------------------------------------------------------------------

/**
 * Import feedback comment data from feedback/mapname.nut
 */
feedback.ImportFeedback <-  function() {
	DoIncludeScript("feedback/" + GetMapName() + ".nut", getroottable());
	foreach(index, table in feedback.imported) {
		local comment = Comment(index, table);
		feedback.comments.append(comment);
	}
	printl(__FILE__ + " -- Imported " + feedback.comments.len() + " comments");
};

/**
 * Show all feedback as training annotations with their full text
 */
feedback.ShowAll <-  function() {
	foreach(comment in feedback.comments) {
		comment.DisplayFull();
	}
};

/**
 * 'Hide' all comments by overriding them with a new message with a lifetime of 0sec
 */
feedback.HideAll <-  function() {
	foreach(comment in feedback.comments) {
		comment.Hide();
	}
}

/**
 * Create a logic_timer to check for players in range of comments
 * @param {float} rate Timer refire time
 */
feedback.StartTimer <-  function(rate) {
	feedback.timer = SpawnEntityFromTable("logic_timer", {
		RefireTime = rate
		StartDisabled = false
		targetname = FEEDBACK_TIMER
		"OnTimer#1": "worldspawn,RunScriptCode,feedback.CheckDistance(),-1,-1"
	});
}

/**
 * Kill the timer
 */
feedback.StopTimer <-  function() {
	EntFire(FEEDBACK_TIMER, "Kill", null, -1, null);
}

/**
 * Cause all comments to do a radius check for players
 * This function is called by the timer
 */
feedback.CheckDistance <-  function(radius = 512) {
	if (caller == feedback.timer) {
		foreach(comment in feedback.comments) {
			comment.CheckDistance(radius);
		}
	} else if (caller.GetName() == FEEDBACK_TIMER) {
		caller.Kill();
		printl(__FILE__ + " -- Killed old timer");
	}
}

// ----------------------------------------------------------------------------------------------------

feedback.ImportFeedback();