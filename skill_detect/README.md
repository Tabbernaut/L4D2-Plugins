Skill Detect
============

The name is pretty tongue in cheek. What this plugin does is track stuff that
survivors (and infected) can do and (if cvars are set) report these actions
and send global forwards so other plugins can make use of the tracking.

Forwards this:
 *      OnSkeet( survivor, hunter )
 *      OnSkeetMelee( survivor, hunter )
 *      OnSkeetGL( survivor, hunter )
 *      OnSkeetSniper( survivor, hunter )
 *      OnSkeetHurt( survivor, hunter, damage, isOverkill )
 *      OnSkeetMeleeHurt( survivor, hunter, damage, isOverkill )
 *      OnSkeetSniperHurt( survivor, hunter, damage, isOverkill )
 *      OnHunterDeadstop( survivor, hunter )
 *      OnBoomerPop( survivor, boomer, shoveCount, Float:timeAlive )
 *      OnChargerLevel( survivor, charger )
 *      OnChargerLevelHurt( survivor, charger, damage )
 *      OnWitchCrown( survivor, damage )
 *      OnWitchCrownHurt( survivor, damage, chipdamage )
 *      OnTongueCut( survivor, smoker )
 *      OnSmokerSelfClear( survivor, smoker, withShove )
 *      OnTankRockSkeeted( survivor, tank )
 *      OnTankRockEaten( tank, survivor )
 *      OnHunterHighPounce( hunter, victim, actualDamage, Float:calculatedDamage, Float:height )
 *      OnJockeyHighPounce( jockey, victim, Float:height )
 *      OnDeathCharge( charger, victim, Float: height, Float: distance, wasCarried )
 *      OnSpecialShoved( survivor, infected, zombieClass )
 *      OnSpecialClear( clearer, pinner, pinvictim, zombieClass, Float:timeA, Float:timeB, withShove )
 *      OnBoomerVomitLanded( boomer, amount )
 *      OnBunnyHopStreak( survivor, streak, Float:maxVelocity )
 *      OnCarAlarmTriggered( survivor, infected, reason )

CVars:
------
<b>sm_skill_report_enable</b><br />
[0/1], whether to report the actions added up in _flags in chat.<br />

<b>sm_skill_report_flags</b><br />
[581685], bitflags. Add the values up for everything you want it to display in reports:<br/>
<pre>
REP_SKEET               1               *
REP_HURTSKEET           2
REP_LEVEL               4               *
REP_HURTLEVEL           8
REP_CROWN               16              *
REP_DRAWCROWN           32              *
REP_TONGUECUT           64
REP_SELFCLEAR           128
REP_SELFCLEARSHOVE      256
REP_ROCKSKEET           512
REP_DEADSTOP            1024
REP_POP                 2048
REP_SHOVE               4096
REP_HUNTERDP            8192            *
REP_JOCKEYDP            16384           *
REP_DEATHCHARGE         32768           *
REP_DC_ASSIST           65536
REP_INSTACLEAR          131072
REP_BHOPSTREAK          262144
REP_CARALARM            524288          *
</pre>
( * = enabled by default )<br />

<b>sm_skill_drawcrown_damage</b><br />
[500] How much damage a survivor must at least do in the final shot for it to count as a drawcrown.<br />

<b>sm_skill_selfclear_damage</b><br />
[200] How much damage a survivor must at least do while pulled for it to count as a self-clear from a smoker tongue.<br />

<b>sm_skill_skeet_allowmelee</b><br />
<b>sm_skill_skeet_allowsniper</b><br />
<b>sm_skill_skeet_allowgl</b><br />
[1/0], whether to count melee skeets, sniper/magnum headshots, and/or grenade launcher air-kills as skeets (if not, doesn't forward either)<br />

<b>sm_skill_hunterdp_damage</b><br />
[15] How much damage a hunter must do in a pounce for it to count as a 'high pounce'<br />

<b>sm_skill_jockeydp_height</b><br />
[300] The mininum height for a jockey pounce for it to count as a 'high pounce'.<br />

<b>sm_skill_deathcharge_height</b><br />
[400] The mininum height for a survivor to have been charged down, for it to be reported as a death charge.<br />

<b>sm_skill_instaclear_time</b><br />
[0.75] The maximum amount of time a clear can take to still count as 'insta'.<br />

<b>sm_skill_bhopstreak</b><br />
[3] The minimum amount of bhops before the streak is reported (if the flag is set).<br />

<b>sm_skill_bhopinitspeed</b><br />
[150] The minimum initial speed at the first hop, before the streak counts (if the flag is set).<br />

<b>sm_skill_bhopkeepspeed</b><br />
[300] The minimum speed at which non-accelerating hops will still count as continued bhaps.<br />


<b>sm_skill_hidefakedamage</b><br />
[0/1], whether hide any damage on witch or level that exceeds the maximum health (this WILL make it harder to get drawcrowns and full levels!)<br />
