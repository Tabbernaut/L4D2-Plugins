Skill Detect
============

[ WORK IN PROGRESS ]

The name is pretty tongue in cheek. What this plugin does is track stuff that
survivors (and infected) can do and (if cvars are set) report these actions
and send global forwards so other plugins can make use of the tracking.

Forwards this:
 *      OnSkeet( survivor, hunter )
 *      OnSkeetMelee( survivor, hunter )
 *      OnSkeetSniper( survivor, hunter )
 *      OnSkeetHurt( survivor, hunter, damage, isOverkill )
 *      OnSkeetMeleeHurt( survivor, hunter, damage, isOverkill )
 *      OnSkeetSniperHurt( survivor, hunter, damage, isOverkill )
 *      OnHunterDeadstop( survivor, hunter )
 *      OnBoomerPop( survivor, boomer )
 *      OnChargerLevel( survivor, charger )
 *      OnChargerLevelHurt( survivor, charger, damage )
 *      OnWitchCrown( survivor, damage )
 *      OnWitchCrownHurt( survivor, damage, chipdamage )
 *      OnHighPounce( hunter, victim, damage )
 *      OnDeathCharge( charger, victim )
 *      OnRockSkeeted( survivor )
 *      OnTongueCut( survivor, victim )


CVars:
------
<b>sm_skill_reportskeet</b><br />
<b>sm_skill_reporthurtskeet</b><br />
<b>sm_skill_reportlevel</b><br />
<b>sm_skill_reporthurtlevel</b><br />
<b>sm_skill_reportdeadstop</b><br />
0/1, whether to report these actions in chat.<br />


<b>sm_skill_skeet_allowmelee</b><br />
<b>sm_skill_skeet_allowsniper</b><br />
1/0, whether to count melee skeets and sniper/magnum headshots as skeets (if not, doesn't forward either)<br />
