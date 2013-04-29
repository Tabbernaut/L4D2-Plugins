General Fixes for Glitches
==========================

block heatseeking charger
-------------------------
If a client with a spawned up and charging charger drops (either disconnects or gets tank), the newly AI charger does something weird: it becomes heatseeking, able to change direction while charging. This means the charger is nearly impossible to dodge (and harder to kill aswell, see ai_damagefix). This plugins detects when this happens and stops the charge.


unsilent jockey
---------------
Sometimes jockeys spawn up without making their distinctive giggles. This means the jockey can be silent for a long time and reach survivors in total stealth. This is generally bad for (competitive) play, so this plugin detects whether the jockey has made any sound for a short duration since it spawned, if not, it forces a sound.


tank punch stuck fix
--------------------
You shouldn't trust this one. It's on the to-do list, but not working reliably yet. It is intended to detect and fix situations where tankpunches get a survivors stuck in a ceiling/wall. Its detection works well: it detects how long a survivor is stuck in a 'flying' animation frame, too long in a single spot, and they're stuck. Getting them unstuck is the hard part -- this has caused some problems, including survivors getting *more* stuck than before, in floors and such. WIP.
