Holdout Bonus
=============

Plugin
------
This, in combination with penalty_bonus, makes the game award a survival bonus to survivors
for various camping events in the game. The point of this is to make the round's score match
actual survivor progress (in terms of performance) slightly better -- especially for harder
or more wipable configs.

For example, if survivors make it halfway through waiting for the ferry on Swamp Fever map 1,
they get half the bonus value for that map. They also get half the bonus if two survivors die
before the event starts, and the other two make it onto the ferry.

With the default configuration, this plugin converts a certain portion of the map's distance value
into a bonus for (partially) surviving a camping event. It can be configured to leave the distance
unchanged, see below.


Convars
-------
<b>sm_hbonus_pointsmode</b><br />
[2] Sets the way the plugin sets and awards the bonus points.<br />
<pre>
    0   disabled, no bonus awarded
    1   gives bonus, leaves map distance unaltered
    2   gives bonus, removes bonus value from total map distance
</pre>
Default is set at 2 for this cvar, so without configuration, total map points would be
the same as without holdout_bonus.<br />

<b>sm_hbonus_report</b><br />
[2] Sets when the plugin reports bonus status.<br />
<pre>
    0   no reports
    1   reports after round ends (only if there was a holdout event this map)
    2   reports after round ends and after the holdout event is over
    3   reports after round ends, after the holdout event and announces event when it starts
</pre>
<br />

<b>sm_hbonus_configpath</b><br />
[configs/holdoutmapinfo.txt] Sets where the plugin should read its holdout bonus information for each map from.<br />
You can use this to make config-specific holdout setups. See /configs/holdoutmapinfo.txt for more details.<br />

Install
-------
Make sure you have all the plugins this depends on. Added the plugin to your config (and/or /sourcemod/plugins/ dir).
Add the holdoutmapinfo.txt to /sourcemod/configs/.


Dependencies
------------
Requires <b>l4d2_penalty_bonus</b>.<br />


Forwards
--------
Global forwards this plugin performs:
<pre>
    forward OnHoldOutBonusSet( bonus, distance, time, bool:distanceChanged )
    forward OnHoldOutBonusStart( time )
    forward OnHoldOutBonusEnd( bonus, time )
</pre>
See the inc file for further details.<br />



To Do
-----
Make it possible to have multiple holdout bonuses/events in a map.
