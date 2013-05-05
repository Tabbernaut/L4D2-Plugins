/*
  Includes for Penalty bonus system (l4d2_penalty_bonus)
  ------------------------------------------------------
*/

// Get the bonus for the current round
//    returns int
native PBONUS_GetRoundBonus();

// Resets the bonus for the current round to 0 (does not do a change-report!)
native PBONUS_SetRoundBonus();

// Set the bonus for the current round
native PBONUS_SetRoundBonus(bonus);

// Adds points to the bonus for the current round
native PBONUS_AddRoundBonus(bonus);

// Get the amount of defibs used in the current round
//    returns int
native PBONUS_GetDefibsUsed();