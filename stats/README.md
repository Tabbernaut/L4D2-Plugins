Stats
=====

[ WORK IN PROGRESS ]

This plugin replaces survivor_mvp. It adds a lot of (optional) statistics
that may be of interest:

Relies on <b>l4d2_skill_detect</b> for displaying of the stats (though it will otherwise function fine without it).


Commands:
---------

<b>/stats</b><br />
<pre>
|------------------------------------------------------------------------------|
| /stats command help      in chat:    '/stats <type> [argument [argument]]'         |
|                          in console: 'sm_stats <type> [arguments...]'              |
|------------------------------------------------------------------------------|
| stat type:   'general':  general statistics about the game, as in campaign   |
|              'mvp'    :  SI damage, common kills    (extra argument: 'tank') |
|              'skill'  :  skeets, levels, crowns, tongue cuts, etc            |
|              'ff'     :  friendly fire damage (per type of weapon)           |
|              'acc'    :  accuracy details           (extra argument: 'more') |
|              'inf'    :  special infected stats (dp's, damage done etc)      |
|------------------------------------------------------------------------------|
| arguments:                                                                   |
|------------------------------------------------------------------------------|
|   'round' ('r') / 'game' ('g') : for this round; or for entire game so far   |
|   'team' ('t') / 'all' ('a')   : current survivor team only; or all players  |
|   'other' ('o')                : for the other team (that is now infected)   |
|   'tank'          [ MVP only ] : show stats for tank fight                   |
|   'more'    [ ACC & MVP only ] : show more stats ( MVP time / SI/tank hits ) |
|------------------------------------------------------------------------------|
| examples:                                                                    |
|------------------------------------------------------------------------------|
|   '/stats skill round all' => shows skeets etc for all players, this round   |
|   '/stats ff team game'    => shows friendly fire for your team, this round  |
|   '/stats acc'             => shows accuracy stats (your team, this round)   |
|   '/stats mvp tank'        => shows survivor action while tank is/was up     |
|------------------------------------------------------------------------------|
</pre>


<b>/mvp</b><br />
<b>/skill</b><br />
<b>/ff</b><br />
<b>/acc</b><br />
These commands are shortcuts to the stats command (for the respective type arguments).
The same arguments can be passed for these as for /stats.


<b>sm_stats_auto</b><br />
This command can be used to set a client-side preference for automatically showing stats at round end.
If set, this will override the server default. Set to 0 at any time to use server default.
Usage:
<pre>
   /stats_auto ?               get some more info on how to use this command
   /stats_auto #               set sum of flags for auto-print preference (see table above)
   /stats_auto -1              don't show anything automatically
   /stats_auto 0               use server default [default setting]
   /stats_auto test            show a preview of what will be auto-printed with current setting
</pre>
The autoprint flag value is stored in a Sourcemod cookie (named: 'sm_stats_autoprintflags').


ADMIN: <b>statsreset</b><br />
This command resets all stats back to 0. 'change map' admin level required.


CVars:
------

<b>sm_survivor_mvp_brevity</b><br />
legacy-named cvar for configuring the way MVP chat prints will look.<br />
Sum of flags in the following list:
<pre>
BREV_SI                 1       // hide SI damage
BREV_CI                 2       // hide commons killed
BREV_FF                 4       // hide friendly fire damage
BREV_RANK               8       // hide "your rank" line
BREV_PERCENT            32      // hide percentage values (only shows absolutes)
BREV_ABSOLUTE           64      // hide absolute values (only shows percentages)
</pre>
Default: [4].


<b>sm_stats_autoprint_vs_round</b><br />
<b>sm_stats_autoprint_coop_round</b><br />
Set what stats are automatically shown on round-end (in versus and campaign mode, respectively).<br />
Sum of the flags in the following list:
<pre>
AUTO_MVPCHAT_ROUND      1       // chat: mvp for this round
AUTO_MVPCHAT_GAME       2       // chat: mvp for entire game until this round
AUTO_MVPCON_ROUND       4       // console table: mvp this round
AUTO_MVPCON_GAME        8       // console table: mvp game
AUTO_MVPCON_TANK        16      // console table: tankfight stats (this round)
AUTO_FFCON_ROUND        32      // friendly fire
AUTO_FFCON_GAME         64
AUTO_SKILLCON_ROUND     128     // special 'skill' stats: skeets, crowns, etc
AUTO_SKILLCON_GAME      256
AUTO_ACCCON_ROUND       512     // accuracy general stats
AUTO_ACCCON_GAME        1024
AUTO_ACCCON_MORE_ROUND  2048    // accuracy stats on SI / tank hits
AUTO_ACCCON_MORE_GAME   4096
AUTO_FUNFACT_ROUND      8192    // fun fact, relevant to the round
AUTO_FUNFACT_GAME       16384
AUTO_MVPCON_MORE_ROUND  32768   // console table: more mvp stats, time alive, etc
AUTO_MVPCON_MORE_GAME   65536
</pre>
Default: vs: [133], coop: [1289].


<b>sm_stats_showbots</b><br />
[0/1] Show bots in all tables. Default is on. When off, bots are hidden from anywhere but general MVP and friendly fire taken tables.<br />

<b>sm_stats_percentdecimal</b><br />
[0/1] If enabled, shows (most) percentages with single decimal precision (###.#%). Default is off (rounded to ###%). Percentages in MVP chat prints are not affected by this setting.<br />

