#if defined  _damage_bonus_included_
        #endinput
#endif
#define _damage_bonus_included_

/**
 * Gives the current bonus for the current round assuming no more damage taken.
 *
 * @return              The current bonus
 */
native DamageBonus_GetCurrentBonus();

/**
 * Gets the real bonus for the specific round.  This only reports for completed
 * rounds.  Value otherwise should be 0.
 *
 * @param roundNumber   The round to get the bonus from (0 or 1)
 */
native DamageBonus_GetRoundBonus(roundNumber);

/**
 * Gets the real damage for the specific round.  This includes incomplete
 * rounds.
 *
 * @param roundNumber   The round to get the bonus from (0 or 1)
 */
native DamageBonus_GetRoundDamage(roundNumber);


public SharedPlugin:__pl_damage_bonus =
{
        name = "l4d2_damagebonus",
        file = "damage_bonus_flexible.smx",
#if defined REQUIRE_PLUGIN
        required = 1,
#else
        required = 0,
#endif
};

public __pl_damage_bonus_SetNTVOptional()
{
        MarkNativeAsOptional("DamageBonus_GetCurrentBonus");
        MarkNativeAsOptional("DamageBonus_GetRoundBonus");
        MarkNativeAsOptional("DamageBonus_GetRoundDamage");
}

// vim: ft=sourcepawn et sw=8
