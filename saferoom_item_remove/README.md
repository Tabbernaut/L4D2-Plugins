Saferoom Item Remove
====================

Removes any items it finds in a saferoom.

This plugin requires l4d2_saferoom_detect. It will work even when l4d2lib's check doesn't,
though then it won't work for obscure custom campaigns.


CVars:
------
<b>sm_safeitemkill_saferooms</b><br />
Controls which saferooms are emptied:<br />
1 = end saferoom<br />
2 = start saferoom<br />
These are flags, add them up to empty both. Default is 1 (only end saferoom).

<b>sm_safeitemkill_items</b><br />
Controls which item types are removed:<br />
1 = health items<br />
2 = weapons<br />
4 = any other item<br />
These are flags, add them up to remove various things. Default is 3 (health and weapons).
