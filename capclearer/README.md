# 2v2 CapClearer

A plugin that can auto-clear survivors from being dominated (grabbed by smokers, chargers, jockeys and hunters).

This is intended for use with 2v2 (or maybe 3v3) competitive configs so that survivors can struggle through maps a bit further; tnis is made for newbies like myself that get double-capped in 2v2 games and hate that this instantly ends the round.



## Cvars

`capclear_debug` (integer, default `0`)
Debugging mode. Settings this higher shows more debug prints (in the server console). Set it to 10 to show every debug line.

`capclear_check_delay` (float, default `0.5`)
Wait this long after a clearable cap situation is detected before clearing it. If you set this higher, the damage done by the cappers is more likely to end the round anyway.

`capclear_punish_damage` (integer, default `33`)
When the survivors are automatically cleared of cappers, they get this much damage done to them. This is intended as a punishment to survivors, so that they don't get too happy about a double cap. The higher this is, the better is it for survivors to try and prevent the double cap at the cost of letting their teammate be capped a bit longer.

`capclear_punish_points` (integer, default `0`)
Using the penalty bonus plugin (where available), this punishes survivors in terms of points for each cleared cap situation.
This makes most sense to use if survivors make it to the end saferoom despite the current maximum caps (see below), or when there is no limit to the amount of caps cleared.

`capclear_maximum_clears` (integer, default: `3`)
After this many clears, the survivors will not be cleared again this round (`0` for no limit). The first time the survivors get fully capped after this many clears is game over for them.

`capclear_clear_last_upright` (boolean, default `1`)
Whether the last upright survivor should be cleared when dominated as others are incapped.

`capclear_clear_last_alive` (boolean, default `0`)
Whether the last living survivor should be cleared when dominated.

`capclear_clear_from_incapped` (boolean, default `0`)
Whether we should also clear the dominator from incapped survivors aswell.
