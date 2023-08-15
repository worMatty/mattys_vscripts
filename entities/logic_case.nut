/**
 * WORK IN PROGRESS
 * UNFINISHED
 * NOT FUNCTIONAL
 */

function PickInSequence()
{
    /* for (local i = 1; i <= 16; i++)
    {
        local output = format("OnCase%02d", i);

        if (EntityOutputs.HasAction(self, output))
        {
            printl("Attempting to fire InValue " i.tostring());
            EntFireByHandle(self, "InValue", i.tostring(), 0.0, activator, caller);
            break;
        }
    } */

/* The following code will always choose the first item if there are infinite refires.
Maybe we need to use a global sequence number afterall? */

    for (local i = 1; i <= 16; i++)
    {
        local output = format("OnCase%02d", i);

        if (EntityOutputs.HasAction(self, output))
        {
            printl("Attempting to fire InValue " + i.tostring());
            EntFireByHandle(self, "InValue", i.tostring(), 0.0, activator, caller);
            break;
        }
    }
}

/* To do
Find out if we can fire outputs directly.
If not, grab the case's input value and use that. If one doesn't exist, create it. */

/*
Build a case map and iterate through it */

/*
Knowledge

m_nLastShuffleCase is set to -1 when the entity spawns.

CLogicCase::BuildCaseMap
Goes through each possible case output and checks if there is a valid output.
Adds each valid case to a map (an array of characters).
Each character is the ASCII equivalent of the case number.
Returns the number of cases.

CLogicCase::InputPickRandom
Calls BuildCaseMap. This gets an up-to-date list of valid case outputs.
Eventually it does this:
m_OnCase[nCase].FireOutput( inputdata.pActivator, this );
Can we tell a case output to fire itself in VScript?

EntityOutputs.HasOutput returns true if the entity supports that output.
EntityOutputs.HasAction returns true if the entity has an action registered for the output

*/