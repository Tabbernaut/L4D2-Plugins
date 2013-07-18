#include <sourcemod.inc>
#include <sdkhooks>
#include <sdktools>
#include <left4downtown>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

#define TEAM_SURVIVOR       2

#define TEAMSIZE_DEFAULT    4.0

#define DST_SCALING         1
#define DST_REDUCTION       2

#define MAX_REPORTLINES     15
#define STR_REPLINELENGTH   256
#define MAX_CHARACTERS      4

/*
    This is CanadaRox's damage_bonus plugin, modified for flexibility,
    so people can tweak settings to experiment with damage bonus.
    
    Default settings are:
        sm_static_bonus         static survival bonus
        sm_max_damage           absolute damage taken to give 0 bonus
        sm_damage_multi         the standard multiplier for points of damage to count towards total absolute damage taken
        
    New settings:
        sm_dmgflx_base              default total bonus value to award (damage calculation is scaled back to 0-<this value> range for bonus) (0 = disable, keep equal to max damage)
        sm_dmgflx_solid_factor      float: how to value the first 100 points of solid health-damage for survivors
        sm_dmgflx_distance_scaling  [mode] whether and how to scale the bonus accounting for distance
        sm_dmgflx_distance_base     base distance -- if there's distance scaling, a map gets <distance> / <this value> times the bonus
        sm_dmgflx_distance_factor   float: how much the scaling should weigh: 1.0 = distance = 2* greater = bonus is 2* higher; 0.5 = distance is 2* greater = bonus is 1.5* higher
        
        sm_dmgflx_display_only      whether to merely display the bonus and not actually apply it (for comparison purposes)
        
    Warning:    
        This plugin won't work with > 4 survivors (data is tracked per player model (m_survivorCharacter).
        This plugin won't work with mods that change / allow changing survivor characters mid-round.
*/

public Plugin:myinfo =
{
    name = "Damage Scoring - Flexible Version",
    author = "CanadaRox, Tabun",
    description = "Custom damage scoring based on damage survivors take. With adjustable scoring calculation.",
    version = "0.9.2",
    url = "https://github.com/Tabbernaut/L4D2-Plugins/tree/master/damage_bonus_flexible"
};


// plugin internals
new     bool:       g_bLateLoad;

// game cvars
new     Handle:     g_hCvarTeamSize;
new     Handle:     g_hCvarSurvivalBonus;
new                 g_iDefaultSurvivalBonus;
new     Handle:     g_hCvarTieBreakBonus;
new                 g_iDefaultTieBreakBonus;

// plugin cvars
new     Handle:     g_hCvarStaticBonus;
new     Handle:     g_hCvarMaxDamage;
new     Handle:     g_hCvarDamageMulti;

new     Handle:     g_hCvarDisplayOnly;
new     Handle:     g_hCvarBonusBase;
new     Handle:     g_hCvarSolidFactor;
new     Handle:     g_hCvarDistScaling;
new     Handle:     g_hCvarDistBase;
new     Handle:     g_hCvarDistFactor;

// tracking damage
new                 iHealth[MAX_CHARACTERS];
new                 bTookDamage[MAX_CHARACTERS];
new                 iTotalDamage[2];                        // actual damage done
new                 iSolidHealthDamage[2];                  // damage done to first 100h of each survivor
new     bool:       bHasWiped[2];                           // true if they didn't get the bonus...
new     bool:       bRoundOver[2];                          // whether the bonus will still change or not
new                 iStoreBonus[2];                         // what was the actual bonus?
new                 iStoreSurvivors[2];                     // how many survived that round?

new                 iPlayerDamage[MAX_CHARACTERS];              // the damage a player has taken individually (for finding solid health damage)
new     bool:       bPlayerHasBeenIncapped[MAX_CHARACTERS];     // only true after the survivor has been incapped at least once


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart()
{
    // hooks
    HookEvent("door_close", DoorClose_Event);
    HookEvent("player_death", PlayerDeath_Event);
    HookEvent("finale_vehicle_leaving", FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);
    HookEvent("player_ledge_grab", PlayerLedgeGrab_Event);
    HookEvent("player_incapacitated", PlayerIncap_Event);
    HookEvent("round_start", RoundStart_Event);
    HookEvent("round_end", RoundEnd_Event);
    
    // save default game cvar values
    g_hCvarTeamSize = FindConVar("survivor_limit");
    g_hCvarSurvivalBonus = FindConVar("vs_survival_bonus");
    g_hCvarTieBreakBonus = FindConVar("vs_tiebreak_bonus");
    g_iDefaultSurvivalBonus = GetConVarInt(g_hCvarSurvivalBonus);
    g_iDefaultTieBreakBonus = GetConVarInt(g_hCvarTieBreakBonus);

    // plugin cvars
    g_hCvarStaticBonus = CreateConVar(      "sm_static_bonus",              "0.0",      "Extra static bonus that is awarded per survivor for completing the map", FCVAR_PLUGIN, true, 0.0);
    g_hCvarMaxDamage = CreateConVar(        "sm_max_damage",              "800.0",      "Max damage used for calculation (controls x in [x - damage])", FCVAR_PLUGIN);
    g_hCvarDamageMulti = CreateConVar(      "sm_damage_multi",              "1.0",      "Multiplier to apply to damage before subtracting it from the max damage", FCVAR_PLUGIN, true, 0.0);
    
    g_hCvarBonusBase = CreateConVar(        "sm_dmgflx_base",               "0.0",      "Base bonus value. Max damage - taken damage is scaled back to 0 - <this value> range for the base bonus.", FCVAR_PLUGIN, true, 0.0);
    g_hCvarSolidFactor = CreateConVar(      "sm_dmgflx_solid_factor",       "1.0",      "The value of damage done to survivors before their first incap -- as a factor of other damage.", FCVAR_PLUGIN, true, 0.0);
    g_hCvarDistScaling = CreateConVar(      "sm_dmgflx_distance_scaling",   "1",        "Distance scaling mode: 1 = entire bonus is scaled against base distance; 2 = max. damage is decreased for shorter distance.", FCVAR_PLUGIN, true, 0.0);
    g_hCvarDistBase = CreateConVar(         "sm_dmgflx_distance_base",    "400.0",      "For distance scaling. Base against which map distance is used to scale bonus (a map with this distance has a 1.0 * bonus).", FCVAR_PLUGIN, true, 0.0);
    g_hCvarDistFactor = CreateConVar(       "sm_dmgflx_distance_factor",    "1.0",      "For distance scaling. Factor by which bonus changes for shorter/longer maps (factor of damage change).", FCVAR_PLUGIN, true, 0.0);
    g_hCvarDisplayOnly = CreateConVar(      "sm_dmgflx_display_only",       "0",        "Whether to display the bonus only (for comparison with other scoring systems).", FCVAR_PLUGIN, true, 0.0, true, 1.0);

    // chat & commands
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
    RegConsoleCmd("sm_damage", Damage_Cmd, "Prints the (current) bonus for both teams.");
    RegConsoleCmd("sm_health", Damage_Cmd, "Prints the (current) bonus for both teams.(Legacy)");
    
    RegConsoleCmd("sm_damage_explain", Explain_Cmd, "Shows an explanation of the damage bonus calculation.");
    RegConsoleCmd("sm_health_explain", Explain_Cmd, "Shows an explanation of the damage bonus calculation.");
    
    // hooks
    if (g_bLateLoad)
    {
        for (new i=1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                OnClientPutInServer(i);
            }
        }
    }
}

public OnPluginEnd()
{
    if (!GetConVarBool(g_hCvarDisplayOnly))
    {
        SetConVarInt(g_hCvarSurvivalBonus, g_iDefaultSurvivalBonus);
        SetConVarInt(g_hCvarTieBreakBonus, g_iDefaultTieBreakBonus);
    }
}

public OnMapStart()
{
    for (new i=0; i < 2; i++)
    {
        iTotalDamage[i] = 0;
        iSolidHealthDamage[i] = 0;
        iStoreBonus[i] = 0;
        iStoreSurvivors[i] = 0;
        bRoundOver[i] = false;
        bHasWiped[i] = false;
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public Action:Damage_Cmd(client, args)
{
    DisplayBonus(client);
    return Plugin_Handled;
}

public Action:Explain_Cmd(client, args)
{
    DisplayBonusExplanation(client);
    return Plugin_Handled;
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new i=0; i < MAX_CHARACTERS; i++)
    {
        iPlayerDamage[i] = 0;
        bPlayerHasBeenIncapped[i] = false;
    }
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    // set whether the round was a wipe or not
    if (!GetUprightSurvivors()) {
        bHasWiped[GameRules_GetProp("m_bInSecondHalfOfRound")] = true;
    }

    // when round is over, 
    bRoundOver[GameRules_GetProp("m_bInSecondHalfOfRound")] = true;

    new reason = GetEventInt(event, "reason");
    if (reason == 5)
    {
        DisplayBonus();
    }
}

public DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (GetEventBool(event, "checkpoint"))
    {
        SetBonus(CalculateSurvivalBonus());
    }
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (client && IsSurvivor(client))
    {
        SetBonus(CalculateSurvivalBonus());
        
        // check solid health
        new srvchr = GetPlayerCharacter(client);
        if (iPlayerDamage[srvchr] < 100)
        {
            iSolidHealthDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += (100 - iPlayerDamage[srvchr]);
            iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += (100 - iPlayerDamage[srvchr]);
            iPlayerDamage[srvchr] = 100;
        }
    }
}

public FinaleVehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new i = 1; i < MaxClients; i++)
    {
        if (IsClientInGame(i) && IsSurvivor(i) && IsPlayerIncap(i))
        {
            ForcePlayerSuicide(i);
        }
    }

    SetBonus(CalculateSurvivalBonus());
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
    new srvchr = GetPlayerCharacter(victim);
    iHealth[srvchr] = (!IsSurvivor(victim) || IsPlayerIncap(victim)) ? 0 : (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
    bTookDamage[srvchr] = true;
}

public PlayerLedgeGrab_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new health = GetEntData(client, 14804, 4);
    new temphealth = GetEntData(client, 14808, 4);
    
    iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += health + temphealth;
    
    new srvchr = GetPlayerCharacter(client);
    if (!bPlayerHasBeenIncapped[srvchr])
    {
        iPlayerDamage[srvchr] += health + temphealth;
        iSolidHealthDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += health + temphealth;
    }
}

public PlayerIncap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new srvchr = GetPlayerCharacter(client);
    
    bPlayerHasBeenIncapped[srvchr] = true;
    
    // check solid health
    if (iPlayerDamage[srvchr] < 100) {
        iSolidHealthDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += (100 - iPlayerDamage[srvchr]);
        iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += (100 - iPlayerDamage[srvchr]);
        iPlayerDamage[srvchr] = 100;
    }
}

public Action:L4D2_OnRevived(client)
{
    new health = GetSurvivorPermanentHealth(client);
    new temphealth = GetSurvivorTempHealth(client);

    iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] -= (health + temphealth);
    
    new srvchr = GetPlayerCharacter(client);
    if (!bPlayerHasBeenIncapped[srvchr]) {
        iPlayerDamage[srvchr] -= (health + temphealth);
        iSolidHealthDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] -= (health + temphealth);
    }
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
    new srvchr = GetPlayerCharacter(victim);
    
    if (iHealth[srvchr])
    {
        if (!IsPlayerAlive(victim) || (IsPlayerIncap(victim) && !IsPlayerHanging(victim)))
        {
            iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += iHealth[srvchr];
        }
        else if (!IsPlayerHanging(victim))
        {
            iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += iHealth[srvchr] - (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
            
            if (!bPlayerHasBeenIncapped[srvchr])
            {
                iPlayerDamage[srvchr] += iHealth[srvchr] - (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
                iSolidHealthDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += iHealth[srvchr] - (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
                
                if (iPlayerDamage[srvchr] > 100)
                {
                    iSolidHealthDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] -= (100 - iPlayerDamage[srvchr]);
                    bPlayerHasBeenIncapped[srvchr] = true;
                }
            }
        }
        iHealth[srvchr] = (!IsSurvivor(victim) || IsPlayerIncap(victim)) ? 0 : (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
    }
}

public Action:Command_Say(client, const String:command[], args)
{
    if (IsChatTrigger())
    {
        decl String:sMessage[MAX_NAME_LENGTH];
        GetCmdArg(1, sMessage, sizeof(sMessage));

        if (StrEqual(sMessage, "!damage")) return Plugin_Handled;
        else if (StrEqual (sMessage, "!sm_damage")) return Plugin_Handled;
        else if (StrEqual (sMessage, "!health")) return Plugin_Handled;
        else if (StrEqual (sMessage, "!sm_health")) return Plugin_Handled;
    }

    return Plugin_Continue;
}

stock GetDamage(round=-1)
{
    return (round == -1) ? iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] : iTotalDamage[round];
}

stock SetBonus(iBonus)
{
    if (!GetConVarBool(g_hCvarDisplayOnly))
    {
        SetConVarInt(g_hCvarSurvivalBonus, iBonus);
    }
    StoreBonus(iBonus);
}

stock StoreBonus(iBonus)
{
    // store bonus for display
    new round = GameRules_GetProp("m_bInSecondHalfOfRound");
    new aliveSurvs = GetAliveSurvivors();

    iStoreBonus[round] = iBonus * aliveSurvs;
    iStoreSurvivors[round] = GetAliveSurvivors();
}

stock DisplayBonus(client=-1)
{
    new String:msgPartHdr[64];
    new String:msgPartDmg[64];

    for (new round = 0; round <= GameRules_GetProp("m_bInSecondHalfOfRound"); round++)
    {
        if (bRoundOver[round]) {
            Format(msgPartHdr, sizeof(msgPartHdr), "Round \x05%i\x01 bonus", round+1);
        } else {
            Format(msgPartHdr, sizeof(msgPartHdr), "Current Bonus");
        }

        if (bHasWiped[round]) {
            Format(msgPartDmg, sizeof(msgPartDmg), "\x03wipe\x01 (\x05%4i\x01 damage)", iTotalDamage[round]);
        } else {
            Format(msgPartDmg, sizeof(msgPartDmg), "\x04%4i\x01 (\x05%4i\x01 damage)",
                    (bRoundOver[round]) ? iStoreBonus[round] : CalculateSurvivalBonus() * GetAliveSurvivors(),
                    iTotalDamage[round]
                  );
        }

        if (GetConVarBool(g_hCvarDisplayOnly)) {
            Format(msgPartHdr, sizeof(msgPartHdr), "[DB] %s", msgPartHdr);
            Format(msgPartDmg, sizeof(msgPartDmg), "%s [\x04not applied!\x01]", msgPartDmg);
        }
        
        if (client == -1) {
            PrintToChatAll("\x01%s: %s", msgPartHdr, msgPartDmg);
        } else if (client) {
            PrintToChat(client, "\x01%s: %s", msgPartHdr, msgPartDmg);
        } else {
            PrintToServer("\x01%s: %s", msgPartHdr, msgPartDmg);
        }
    }
}

stock DisplayBonusExplanation(client=-1)
{
    // show exactly how the calculated bonus is constructed
    
    new String: sReport[MAX_REPORTLINES][STR_REPLINELENGTH];
    new iLine = 0;
    
    new round = GameRules_GetProp("m_bInSecondHalfOfRound");
    new living = (bRoundOver[round]) ? iStoreSurvivors[round] : GetAliveSurvivors();
    
    new Float: fCalcMaxDamage = GetConVarFloat(g_hCvarMaxDamage);
    new Float: fCalcTakenDamage = float(iTotalDamage[round]);
    new Float: fBaseBonus = fCalcMaxDamage;
    new Float: fPerc = 0.0;
    new Float: fScaleBonusBase = (GetConVarFloat(g_hCvarBonusBase) == 0.0) ? 1.0 : GetConVarFloat(g_hCvarBonusBase) / GetConVarFloat(g_hCvarMaxDamage);

    
    
    // damage taken
    Format(sReport[iLine], STR_REPLINELENGTH, "Total damage taken: \x05%i\x01", iTotalDamage[round]);
    if (GetConVarFloat(g_hCvarSolidFactor) != 1.0) {
        Format(sReport[iLine], STR_REPLINELENGTH, "%s (\x04%i\x01 of which solid health dmg).", sReport[iLine], iSolidHealthDamage[round]);
    } else {
        Format(sReport[iLine], STR_REPLINELENGTH, "%s.", sReport[iLine]);
    }
    iLine++;
    
    // base bonus to max damage calc
    fBaseBonus = fCalcMaxDamage - ( fCalcTakenDamage * GetConVarFloat(g_hCvarDamageMulti) );
    fPerc = ( (fCalcTakenDamage * GetConVarFloat(g_hCvarDamageMulti)) / fCalcMaxDamage ) * 100.0;
    if (fBaseBonus < 0.0) { fBaseBonus = 0.0; fPerc = 0.0; }
    
    if (GetConVarFloat(g_hCvarDamageMulti) != 1.0) {
        // damage scaled 
        Format(sReport[iLine], STR_REPLINELENGTH, "dmg vs. maximum: (\x05%.f\x01 * %.2f) out of \x05%.f\x01 [\x04%.1f%%\x01] => base bonus: \x03%i\x01",
                fCalcTakenDamage, GetConVarFloat(g_hCvarDamageMulti), fCalcMaxDamage,
                fPerc,
                RoundToFloor( fBaseBonus / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT)
            );
        fCalcTakenDamage = fCalcTakenDamage * GetConVarFloat(g_hCvarDamageMulti);
    }
    else {
        // 1-1
        Format(sReport[iLine], STR_REPLINELENGTH, "dmg vs. maximum: \x05%.f\x01 out of \x05%.f\x01 [\x04%.1f%%\x01] => base bonus: \x03%i\x01",
                fCalcTakenDamage, fCalcMaxDamage,
                (fCalcTakenDamage / fCalcMaxDamage) * 100.0,
                RoundToFloor( fBaseBonus )
            );
    }
    iLine++;
    
    // factoring in the solid-health damage
    if (GetConVarFloat(g_hCvarSolidFactor) != 1.0)
    {
        fCalcTakenDamage = ( float( iTotalDamage[round] - iSolidHealthDamage[round] ) * GetConVarFloat(g_hCvarDamageMulti) ) + ( float(iSolidHealthDamage[round]) * GetConVarFloat(g_hCvarDamageMulti) * GetConVarFloat(g_hCvarSolidFactor) );
        new Float: fCalcMaxDamageSolidPart = TEAMSIZE_DEFAULT * 100.0 * GetConVarFloat(g_hCvarDamageMulti);
        fCalcMaxDamage = (GetConVarFloat(g_hCvarMaxDamage) - fCalcMaxDamageSolidPart ) + ( fCalcMaxDamageSolidPart * GetConVarFloat(g_hCvarSolidFactor) );
        // scale basebonus back to the maxdamage count
        fBaseBonus = ( fCalcMaxDamage - fCalcTakenDamage ) * ( GetConVarFloat(g_hCvarMaxDamage) / fCalcMaxDamage );
        fPerc = ( fCalcTakenDamage / fCalcMaxDamage ) * 100.0;
        if (fBaseBonus < 0.0) { fBaseBonus = 0.0; fPerc = 0.0; }
        
        Format(sReport[iLine], STR_REPLINELENGTH, "Solid-health fact.: (\x05%.f\x01+(\x04%.f\x01*\x05%.1f\x01)) out of (\x05%.f\x01+(\x04%.f\x01*\x05%.1f\x01)) [\x04%.1f%%\x01] => \x03%i\x01",
                float(iTotalDamage[round] - iSolidHealthDamage[round]) * GetConVarFloat(g_hCvarDamageMulti),
                float(iSolidHealthDamage[round]) * GetConVarFloat(g_hCvarDamageMulti),
                GetConVarFloat(g_hCvarSolidFactor),
                
                GetConVarFloat(g_hCvarMaxDamage) - ( TEAMSIZE_DEFAULT * 100.0 * GetConVarFloat(g_hCvarDamageMulti)),
                TEAMSIZE_DEFAULT * 100.0 * GetConVarFloat(g_hCvarDamageMulti),
                GetConVarFloat(g_hCvarSolidFactor),
                
                fPerc,
                RoundToFloor( fBaseBonus / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT)
            );
    }
    iLine++;
    
    // scale for distance
    if (L4D_GetVersusMaxCompletionScore() != GetConVarInt(g_hCvarDistBase))
    {
        switch (GetConVarInt(g_hCvarDistScaling))
        {
            case DST_SCALING:
            {
                if (GetConVarFloat(g_hCvarDistFactor) == 1.0)
                {
                    fBaseBonus = fBaseBonus * ( float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase) );
                    Format(sReport[iLine], STR_REPLINELENGTH, "Distance (scaling): \x04%i\x01 / \x05%i\x01 [base] = factor \x04%.2f\x01 => \x03%i\x01",
                            L4D_GetVersusMaxCompletionScore(),
                            GetConVarInt(g_hCvarDistBase),
                            float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase),
                            RoundToFloor( fBaseBonus / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT)
                        );
                }
                else
                {
                    new iOldBonus = RoundFloat( fBaseBonus * ( float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase) ) );
                    if (GetConVarFloat(g_hCvarDistFactor) < 1.0) {
                        fBaseBonus = fBaseBonus * (1.0 - GetConVarFloat(g_hCvarDistFactor))
                                + ( fBaseBonus * ( float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase) ) ) * GetConVarFloat(g_hCvarDistFactor);
                    }
                    else {
                        fBaseBonus = ( fBaseBonus
                                + ( fBaseBonus * ( float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase) ) ) * GetConVarFloat(g_hCvarDistFactor) )
                                / (GetConVarFloat(g_hCvarDistFactor) + 1.0);
                    }
                    Format(sReport[iLine], STR_REPLINELENGTH, "Distance (scaling): \x04%i\x01 / \x05%i\x01 [base] = factor \x04%.2f\x01 => \x05%i\x01, weighted as \x04%.2f\x01x => \x03%i\x01",
                            L4D_GetVersusMaxCompletionScore(),
                            GetConVarInt(g_hCvarDistBase),
                            float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase),
                            iOldBonus,
                            GetConVarFloat(g_hCvarDistFactor),
                            RoundToFloor( fBaseBonus / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT)
                        );
                }
            }
            
            case DST_REDUCTION:
            {
                if (GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore() > 0)
                {
                    if (GetConVarFloat(g_hCvarSolidFactor) != 1.0)
                    {
                        new Float: fBaseMaxDamage = GetConVarFloat(g_hCvarMaxDamage);
                        fBaseMaxDamage -= ( float(GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore()) * GetConVarFloat(g_hCvarDistFactor) );
                        new Float: fCalcMaxDamageSolidPart = MIN( fBaseMaxDamage , TEAMSIZE_DEFAULT * 100.0 );
                        fCalcMaxDamage = ( fBaseMaxDamage - fCalcMaxDamageSolidPart ) + ( fCalcMaxDamageSolidPart * GetConVarFloat(g_hCvarSolidFactor) );
                        fBaseBonus = (fCalcMaxDamage - fCalcTakenDamage ) * ( GetConVarFloat(g_hCvarMaxDamage) / fCalcMaxDamage );
                    }
                    else {
                        fCalcMaxDamage -= ( float(GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore()) * GetConVarFloat(g_hCvarDistFactor) );
                        fBaseBonus = fCalcMaxDamage - fCalcTakenDamage;
                    }
                }
                fPerc = ( fCalcTakenDamage / fCalcMaxDamage ) * 100.0;
                if (fBaseBonus < 0.0) { fBaseBonus = 0.0; fPerc = 0.0; }
                
                if (GetConVarFloat(g_hCvarDistFactor) == 1.0) {
                    Format(sReport[iLine], STR_REPLINELENGTH, "Distance (max reduction): \x04%i\x01 diff. => new dmg: [\x04%.1f%%\x01] out of \x05%.f\x01 max => \x03%i\x01",
                            L4D_GetVersusMaxCompletionScore() - GetConVarInt(g_hCvarDistBase),
                            fPerc,
                            (GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore() > 0) ? (GetConVarFloat(g_hCvarMaxDamage) - float(GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore())) : GetConVarFloat(g_hCvarDistBase),
                            RoundToFloor( fBaseBonus / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT)
                        );
                }
                else {
                    Format(sReport[iLine], STR_REPLINELENGTH, "Distance (max reduction): \x04%i\x01 diff., weighed \x05%.2f\x01x => new dmg: [\x04%.1f%%\x01] out of \x05%.f\x01 max => \x03%i\x01",
                            L4D_GetVersusMaxCompletionScore() - GetConVarInt(g_hCvarDistBase),
                            GetConVarFloat(g_hCvarDistFactor),
                            fPerc,
                            (GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore() > 0) ?
                                (GetConVarFloat(g_hCvarMaxDamage) - ( float(GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore()) * GetConVarFloat(g_hCvarDistFactor) ) )
                                : GetConVarFloat(g_hCvarDistBase),
                            RoundToFloor( fBaseBonus / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT)
                        );
                }
            }
        }
        iLine++;
    }
    
    // scale for bonus base value
    if (fScaleBonusBase != 1.0)
    {
        fBaseBonus = fBaseBonus * fScaleBonusBase;
        Format(sReport[iLine], STR_REPLINELENGTH, "Scaled for bonus base: ([base] \x04%i\x01 / [max dmg] \x05%i\x01) x bonus => \x03%i\x01",
                    GetConVarInt(g_hCvarBonusBase),
                    GetConVarInt(g_hCvarMaxDamage),
                    RoundToFloor( fBaseBonus / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT)
                    
                );
        fBaseBonus = fBaseBonus * fScaleBonusBase;
        iLine++;
    }
    
    // scale for survivors
    new iTmpBonus;
    iTmpBonus = RoundToFloor( (fBaseBonus * ( float(living) / TEAMSIZE_DEFAULT )) / TEAMSIZE_DEFAULT ) * RoundFloat(TEAMSIZE_DEFAULT); 
    if (living != TEAMSIZE_DEFAULT)
    {
        iTmpBonus = RoundToFloor( fBaseBonus * ( float(living) / TEAMSIZE_DEFAULT ) );
        Format(sReport[iLine], STR_REPLINELENGTH, "Scaled for survivors: \x05%i\x01 living [\x04%.1f%%\x01] => bonus: \x03%i\x01",
                    living,
                    (float(living) / TEAMSIZE_DEFAULT) * 100.0,
                    iTmpBonus
                );
        iLine++;
    }
    
    // add static survival bonus
    if (GetConVarInt(g_hCvarStaticBonus) > 0)
    {
        Format(sReport[iLine], STR_REPLINELENGTH, "Static survival bonus: +\x04%i\x01 x \x05%i\x01 => \x03%i\x01",
                    GetConVarInt(g_hCvarStaticBonus),
                    living,
                    iTmpBonus + ( GetConVarInt(g_hCvarStaticBonus) * living )
                );
        iLine++;
    }
    
    // compare to actual bonus:
    new iDiff = ( iTmpBonus + ( GetConVarInt(g_hCvarStaticBonus) * living ) ) - ( CalculateSurvivalBonus() * living );
    if (iDiff != 0)
    {
        Format(sReport[iLine], STR_REPLINELENGTH, "(ignore \x04%i\x01 points diff. from actual bonus (expl. rounding error))", iDiff);
        iLine++;
    }
    
    // send the report
    for (new i=0; i < iLine; i++)
    {
        if (client == -1) {
            PrintToChatAll("\x01%s", sReport[i]);
        }
        else if (client) {
            PrintToChat(client, "\x01%s", sReport[i]);
        }
        else {
            PrintToServer("\x01%s", sReport[i]);
        }
    }
}


stock bool:IsPlayerIncap(client) return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
stock bool:IsPlayerHanging(client) return bool:GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
stock bool:IsPlayerLedgedAtAll(client) return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));

stock GetSurvivorTempHealth(client)
{
    new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
    return (temphp > 0 ? temphp : 0);
}

stock GetSurvivorPermanentHealth(client) return GetEntProp(client, Prop_Send, "m_iHealth");

stock CalculateSurvivalBonus()
{
    new iRound = GameRules_GetProp("m_bInSecondHalfOfRound");

    new iDistMode = GetConVarInt(g_hCvarDistScaling);
    new Float: fDistFactor = GetConVarFloat(g_hCvarDistFactor);
    
    new Float: fBonus = 0.0;
    new iBonusPart;
    new Float: fBaseMaxDamage = GetConVarFloat(g_hCvarMaxDamage);
    
    // distance reduction (needs be done before dmg calc)
    if (iDistMode == DST_REDUCTION)
    {
        fBaseMaxDamage -= ( float( MAX( GetConVarInt(g_hCvarDistBase) - L4D_GetVersusMaxCompletionScore() , 0 ) ) * GetConVarFloat(g_hCvarDistFactor) );
    }
    
    // damage calc: solid health damage, damage multiplier, max - taken damage (+ scaled back to 0-maxdmg range)
    new iDmg = GetDamage();
    new Float: fMaxDamageSolidPart = MIN( fBaseMaxDamage , TEAMSIZE_DEFAULT * 100.0 );
    new Float: fTakenDamage = ( float( iDmg - iSolidHealthDamage[iRound] ) * GetConVarFloat(g_hCvarDamageMulti) ) + ( float(iSolidHealthDamage[iRound]) * GetConVarFloat(g_hCvarDamageMulti) * GetConVarFloat(g_hCvarSolidFactor) );
    new Float: fMaxDamage = ( fBaseMaxDamage - fMaxDamageSolidPart ) + ( fMaxDamageSolidPart * GetConVarFloat(g_hCvarSolidFactor) );

    // calculate bonus
    fBonus = ( fMaxDamage - fTakenDamage ) * ( GetConVarFloat(g_hCvarMaxDamage) / fMaxDamage );
    
    // distance scaling (+ factor weighing)
    if (iDistMode == DST_SCALING)
    {
        if (fDistFactor < 1.0)
        {
            fBonus = fBonus * (1.0 - fDistFactor) + ( fBonus * ( float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase) ) * fDistFactor );
        }
        else if (fDistFactor > 1.0)
        {
            fBonus = ( fBonus + ( fBonus * ( float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase) ) ) * fDistFactor ) / (fDistFactor + 1.0);
        }
        else {  // factor 1.0
            fBonus = fBonus * ( float(L4D_GetVersusMaxCompletionScore()) / GetConVarFloat(g_hCvarDistBase) );
        }
    }
    
    // scale for base
    if (GetConVarFloat(g_hCvarBonusBase) != 0.0)
    {
        fBonus = fBonus * GetConVarFloat(g_hCvarBonusBase) / GetConVarFloat(g_hCvarMaxDamage);
    }
    
    // min 0
    fBonus = MAX(fBonus, 0.0);
    
    // scale for living + static
    iBonusPart = RoundToFloor( fBonus / TEAMSIZE_DEFAULT + GetConVarFloat(g_hCvarStaticBonus) );
    
    return iBonusPart;
}

stock GetAliveSurvivors()
{
    new iAliveCount;
    new iSurvivorCount;
    new maxSurvs = (g_hCvarTeamSize != INVALID_HANDLE) ? GetConVarInt(g_hCvarTeamSize) : 4;
    for (new i = 1; i < MaxClients && iSurvivorCount < maxSurvs; i++)
    {
        if (IsSurvivor(i))
        {
            iSurvivorCount++;
            if (IsPlayerAlive(i)) iAliveCount++;
        }
    }
    return iAliveCount;
}

stock GetUprightSurvivors()
{
    new iAliveCount;
    new iSurvivorCount;
    new maxSurvs = (g_hCvarTeamSize != INVALID_HANDLE) ? GetConVarInt(g_hCvarTeamSize) : 4;
    for (new i=1; i < MaxClients && iSurvivorCount < maxSurvs; i++) {
        if (IsSurvivor(i)) {
            iSurvivorCount++;
            if (IsPlayerAlive(i) && !IsPlayerIncap(i) && !IsPlayerLedgedAtAll(i)) {
                iAliveCount++;
            }
        }
    }
    return iAliveCount;
}

stock bool:IsSurvivor(client)
{
    return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool:IsClientAndInGame(index) return (index > 0 && index <= MaxClients && IsClientInGame(index));

stock GetPlayerCharacter(client)
{
    new tmpChr = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    
    // use models when incorrect character returned
    if (tmpChr < 0 || tmpChr > 3)
    {
        LogMessage("[dmgflx] Incorrect character code: %i (using model instead)", tmpChr);
        
        decl String:model[256];
        GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
        
        if (StrContains(model, "gambler") != -1) {          tmpChr = 0; }
        else if (StrContains(model, "coach") != -1) {       tmpChr = 2; }
        else if (StrContains(model, "mechanic") != -1) {    tmpChr = 3; }
        else if (StrContains(model, "producer") != -1) {    tmpChr = 1; }
        else if (StrContains(model, "namvet") != -1) {      tmpChr = 0; }
        else if (StrContains(model, "teengirl") != -1) {    tmpChr = 1; }
        else if (StrContains(model, "biker") != -1) {       tmpChr = 3; }
        else if (StrContains(model, "manager") != -1) {     tmpChr = 2; }
        else {                                              tmpChr = 0; }
    }
    
    return tmpChr;
}