# VScript Quick Reference
## Scripting Basics
VScript files have a .nut extension and live in tf/scripts/vscripts.
### Creating a function to use in the script
```js
function PrintMessage(message1, message2 = "World")
{
    printl(message1 + message2);
}

PrintMessage("Hello ");
// would print "Hello World" to console
```
* *message1* and *message2* are parameters. *message2* has a default value
* Parameters with default values should be towards the end
### Creating a function in global scope to use outside the script
```js
::DoSomeStuff <- function()
{
    // code
}
```
* The `::` means it goes in the root script scope
* This function can be used by any script and will work on any entity you send the RunScriptCode input to
### Declaring variables
In your script, if you declare variables before the functions, they can be used by any function that requires them.
```js
local gravity = 800;        // a single integer value
local name = "my lord";     // a string value
local players <- [];        // an empty array
local player_weapons <- {}; // an empty keyvalue table

function SetGravity(new_value)
{
    gravity = new_value;
    // changes the value of the gravity variables
}

function DisplayGravity()
{
    printl("Gravity is " + gravity + " " + name);
    // displays the value of the gravity variable in console
}
```
You can declare variables inside a function that are 'local' to that function, and can't be read by others. They are deleted after the function call has finished.
```js
function SomeMaths()
{
    local ten = 10;
    local five = 5;

    printl("Ten minus five is " + (ten - five));
}
```
* Variables in Squirrel must always be declared with a value
* You can use `null` as a default value
* Variables are dynamically-typed. You can change their value to a different type later
### Formatting text
Use the `format` function to format a string to include and display outside values.
```js
format("This is an integer: %d", 100);
format("This is a float: %f", 1.0);                 // displays 1.00000000
format("This is a float: %.2f", 1.0);               // displays 1.00
format("This is a string: %s", "some text");
format("This is a hexadecimal value: %x", 65535);   // displays FFFF

local string = format("%s has %d kills", name, kills);
// we set these variables elsewhere
printl(string);
```
## Using in Hammer
### Where to use a script
Create a *logic_script* entity and add the script to its *Entity Scripts* keyvalue. The tf/scripts/vscripts path is assumed, so you don't need to add that.

You can actually add a script to any entity in Hammer. You could make a script designed to augment the standard functionality of an entity like *trigger_multiple* with new features and improvements. The script can respond to inputs like `OnStartTouch`.

Most entities are killed and respawned when the round restarts, including logic_script. This makes it very useful for clearing out any old data and starting afresh. However if you wish to store data that persists across rounds, you can attach the script to a preserved entity such as *info_target*. You can also add data to the VScript global scope but that is a more advanced topic.


----------------------------------------------------------------------------------------------------


### Sending VScript function calls in Hammer
*All* entities now support two new inputs:

__RunScriptCode__
Using `RunScriptCode` you can run VScript code directly on the entity without the need of a script file. You can also use it to call a function in the entity's attached script and pass it some parameters. You can make multiple function calls in the same input by separating them with a semi-colon (';'). The built-in variables `activator`, `caller` and `self` are filled in by the game automatically. You can use them the same way you would use `!activator`, etc. in Hammer
```
(func_button) OnPressed -> (logic_script) RunScriptCode
SetGravity(300); ClientPrint(activator, Constants.EHudNotify.HUD_PRINTTALK, `Gravity has been set to ` + gravity);
```
Hammer does not support the double quote character so if you are providing a string value you need to surround it in backticks (\`). Using double quotes in Hammer will break your VMF.

__CallScriptFunction__
`CallScriptFunction` lets you call a function in a script without passing any parameters. This is just like calling an entity's simple input that requires no parameters. e.g. *Trigger*.
## Other Stuff
### Iterating across players
```js
local maxclients = MaxClients();

for (local i = 1; i <= maxclients; i++)
{
    local player = PlayerInstanceFromIndex(i);

    if (player != null && player.IsValid())
    {
        // some code
    }
}
```
Storing the value of *MaxClients()* in a variable is more efficient than calling the function every time the loop iterates.
### Getting and setting entity properties
This is an example function that won't work properly in reality. It demonstrates the ability to both retrieve, and optionally set, a player's `m_flMaxspeed` property, in the same function.
```js
/**
 * Get or set a player's max run speed
 * @param {float} max_speed Max run speed
 * @return {float} Player's max run speed
 */
function MaxSpeed(player, max_speed = null)
{
    if (max_speed != null) {
        NetProps.SetPropFloat(player, "m_flMaxspeed", max_speed);
    }
	return NetProps.GetPropFloat(player, "m_flMaxspeed");
}
```
### Iterate across entities
By classname
```js
local entity = null;

while (entity = Entity.FindByClassname(entity, "func_physbox"))
{
    EntFireByHandle(entity, "Wake", "", 0.0, null, null);
}
```
By targetname, with wildcard support
```js
local entity = null;

// Find entities with a targetname beginning with 'music'
// In this example it's assumed they are all ambient_generic
while (entity = Entity.FindByName(entity, "music*"))
{
    // If the entity is marked as being active
    if (NetProps.GetPropBool(entity, "m_fActive"))
    {
        // Send it a FadeOut input with parameter 3.0, and StopSound after 3.0 seconds
        entity.AcceptInput("FadeOut", "3.0", null, null);
        EntFireByHandle(entity, "StopSound", "", 3.0, null, null);
    }
}
```
### Working with vectors
Vectors are 'objects', and they contain three values: X, Y and Z. You access them by suffixing the object name with the property you wish to access.
```js
local player_angles = activator.getAngles();
printl("The player's X angle is " + player_angles.x);
```


----------------------------------------------------------------------------------------------------



### Storing data in the player's script scope
Each entity can have a 'script scope' where you can store data and functions. Most entities don't have one as standard, so you must first create one. Call `ValidateScriptScope()` on the entity instance, which checks if an entity has a script scope, and creates it if not. It's safe to call it even if an entity already has one.
```js
player.ValidateScriptScope();
local scope = player.GetScriptScope();
scope.currency <- 300;  // Create or replace the table slot, with the value 300
scope.currency = 200;   // Change the value to 200
printl("Player's currency: " + scope.currency);
```
Player entities do not reset on round start, so values carry across rounds. You will need to reset values yourself on round start.
### Scripting in the command line
Use the console command `script` to freely execute a line of code. Useful for testing. If you're running a listen server/client, you can use `ent_fire entityname RunScriptCode` or `CallScriptFunction` to execute code on an entity or call its functions.
## More info
Check the pages on the Valve Developer Community wiki for more information on Squirrel, VScript, and for some code examples. If you want to know if there's a function for something, then do a text search on the TF2 VScript Functions page.