
/**
 * Purpose
 *
 * Give activator the Disciplinary Action speed buff OnStartTouch.
 * Then set their maxspeed value to 600.
 *
 * OnEndTouch, remove their speed buff.
 * This causes the game to recalculate their maxspeed value.
 *
 * Note that run speed is capped to 520 by TF2.
 */

self.ConnectOutput("OnStartTouch", "Output_OnStartTouch");
self.ConnectOutput("OnEndTouch", "Output_OnEndTouch");

speed_cond <- Constants.ETFCond.TF_COND_SPEED_BOOST;

function Output_OnStartTouch()
{
    activator.AddCond(speed_cond);
    NetProps.SetPropFloat(activator, "m_flMaxspeed", 600.0);
}

function Output_OnEndTouch()
{
    activator.RemoveCond(speed_cond);
}
