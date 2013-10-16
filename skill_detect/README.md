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
 *      OnHunterHighPounce( hunter, victim, Float:damage, Float:height )
 *      OnJockeyHighPounce( jockey, victim, Float:height )

CVars:
------
<b>sm_skill_report_enable</b><br />
[0/1], whether to report the actions added up in _flags in chat.<br />

<b>sm_skill_report_flags</b><br />
bitflags.<br/>
<br/>
Add the values up for everything you want it to display:<br/>
<pre>
REP_SKEET               1
REP_HURTSKEET           2
REP_LEVEL               4
REP_HURTLEVEL           8
REP_CROWN               16
REP_DRAWCROWN           32
REP_TONGUECUT           64
REP_SELFCLEAR           128
REP_SELFCLEARSHOVE      256
REP_ROCKSKEET           512
REP_DEADSTOP            1024
REP_POP                 2048
REP_SHOVE               4096
REP_HUNTERDP            8192
REP_JOCKEYDP            16384
</pre>

<b>sm_skill_drawcrown_damage</b><br />
[500] How much damage a survivor must at least do in the final shot for it to count as a drawcrown.<br />

<b>sm_skill_selfclear_damage</b><br />
[200] How much damage a survivor must at least do while pulled for it to count as a self-clear from a smoker tongue.<br />

<b>sm_skill_skeet_allowmelee</b><br />
<b>sm_skill_skeet_allowsniper</b><br />
[1/0], whether to count melee skeets and sniper/magnum headshots as skeets (if not, doesn't forward either)<br />

<b>sm_skill_hunterdp_damage</b><br />
[15] How much damage a hunter must do in a pounce for it to count as a 'high pounce'<br />

<b>sm_skill_jockeydp_height</b><br />
[300] The mininum height for a jockey pounce for it to count as a 'high pounce'.<br />
<b>sm_skill_hidefakedamage</b><br />
[0/1], whether hide any damage on witch that exceeds her maximum health<br />
