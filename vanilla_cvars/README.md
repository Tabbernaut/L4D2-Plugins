Vanilla CVars setter
====================


Plugin
------
This plugin sets cvars that it loads from a KeyValues configuration file and applies them when it is loaded. It resets the cvars to their original value upon being unloaded.


Why?
----
The only way to configure your vanilla game (its default starting mode) is to change the server.cfg. That can break compatibility with confogl configs however, since configs are written from the assumption that all variables aree left at default.

Changing tank speed (z_tank_speed) in server.cfg, for instance, would seriously break most of the configs that would be run on the server.

This plugin fixes that problem by only setting the vanilla cvars when the l4d_vanilla_cvars plugin is loaded. Since it is unloaded by confogl plugin management, the cvar are all reset again.


Installation
------------
Just put the compiled *l4d_vanilla_cvars* in your /addons/sourcemod/plugins directory (not the optional one!).
Put the *server_vanilla_cvars.txt* in /cfg/ and add any cvars you want only for vanilla as key-value pairs in there.

The syntaxis for that file is simple:

"DefaultCVars"
{
    "sm_cvar"
    {
	"<variable name>" "<value>"
	<etc>
    }
}

Just add variable names and values. Remember to use correct KeyValue syntax for this. Only CVars can be added, not commands.

Don't forget to remove the cvars from server.cfg.