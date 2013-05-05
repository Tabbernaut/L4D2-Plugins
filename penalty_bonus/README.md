Penalty Bonus System
====================

Plugin
------
This penalty bonus plugin allows survivors to receive bonuses even when they fail to survive the round.


Why and how?
------------
There are bonus plugins that can give you custom survival bonus. They do this by modifying the vs_survival_bonus cvar before the round ends.
Until now, however, there was no easy or clean way to give survivors a bonus even if they wipe -- a bonus that does not require survivors to make the end saferoom.

The trick used is to set the defib penalty (vs_defib_penalty) to a negative value, then modify the amount of defibs used in the round. The game then obligingly gives the survivors a negative penalty, which increases their score. This completely avoids the hacky SetCampaignScores approach that causes inconsistencies in the GUI.


Usage
-----
The plugin offers the option to give a simple static bonuses for killing tanks and witches. They are disabled by default.
Set the following to anything but 0 to enable these.
<pre>
	sm_pbonus_tank [value]
	sm_pbonus_witch [value]
</pre>

The plugin has built-in end-round reporting, on by default, which can be disabled with:
<pre>
	sm_pbonus_display 0
</pre>

