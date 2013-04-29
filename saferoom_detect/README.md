Saferoom Detect
===============

L4D2Lib, with its mapinfo.txt offers a way of manipulating start- and end saferoom items. It does this with a coordinate + radius check. Any item within the radius is treated as 'in the saferoom'. This may be enough for most purposes, but sometimes more precision is required.

Saferoom detect can check with more precision if an entity/client is actually in the saferoom, and anywhere in it. It uses a coordinate-in-box check: two coordinates per saferoom are stored and can be used to find out whether anything is within the rectangular area defined by them.

The saferoom coordinates were manually gathered and tested, because yes, I am a hardworking nerd. Some saferooms are 'rotated' (Dark Carnival 4/5, Blood Harvest 4/5 caboose, etc.) to make the simple box-check possible.

Some saferooms work less reliably. I will make a fix for them later:
- Death Toll 3/4 church saferoom: it has a two-part non-boxy shape
- Dead Air 1 greenhouse saferoom: it extends an upper area over a non-saferoom lower area

Uses sourcemod/configs/saferoominfo.txt for coordinates. (So make sure you stick that in the right place!)
