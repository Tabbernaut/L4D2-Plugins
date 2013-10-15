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
 *      OnTongueCut( survivor, victim )
 *      OnSmokerSelfClear( survivor, smoker )
 *      OnHighPounce( hunter, victim, damage )
 *      OnDeathCharge( charger, victim )
 *      OnTankRockSkeeted( survivor, tank )
 *      OnTankRockEaten( tank, survivor )


CVars:
------
<b>sm_skill_reportskeet</b><br />
<b>sm_skill_reporthurtskeet</b><br />
<b>sm_skill_reportlevel</b><br />
<b>sm_skill_reporthurtlevel</b><br />
<b>sm_skill_reportdeadstop</b><br />
<b>sm_skill_reportcrown</b><br />
<b>sm_skill_reportdrawcrown</b><br />
<b>sm_skill_reporttonguecut</b><br />
<b>sm_skill_reportselfclear</b><br />
0/1, whether to report these actions in chat.<br />
Note: for ...selfclear: set to '2' to also report selfclears by shoving the smoker in time.<br />

<b>sm_skill_drawcrown_damage</b><br />
How much damage a survivor must at least do in the final shot for it to count as a drawcrown.<br />

<b>sm_skill_selfclear_damage</b><br />
How much damage a survivor must at least do while pulled for it to count as a self-clear from a smoker tongue.<br />

<b>sm_skill_skeet_allowmelee</b><br />
<b>sm_skill_skeet_allowsniper</b><br />
1/0, whether to count melee skeets and sniper/magnum headshots as skeets (if not, doesn't forward either)<br />

<b>sm_skill_hidefakedamage</b><br />
0/1, whether hide any damage on witch that exceeds her maximum health<br />
