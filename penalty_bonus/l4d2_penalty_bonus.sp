#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <l4d2_direct>
#include <l4d2util>

#define DEBUG_MODE false

/*

    To Do
    =========
        ?
        
        
    Changelog
    =========
        
        0.0.1
            - optional simple tank/witch kill bonus (off by default).
            - optional bonus reporting on round end.
            - allows setting bonus through natives.
            - bonus calculation, taking defib use into account.
            
        
*/


public Plugin:myinfo = 
{
    name = "Penalty bonus system",
    author = "Tabun",
    description = "Allows other plugins to set bonuses for a round that will be given even if the saferoom is not reached. Uses negative defib penalty trick.",
    version = "0.0.1",
    url = ""
}



new     Handle:         g_hCvarDoDisplay                                    = INVALID_HANDLE;
new     Handle:         g_hCvarBonusTank                                    = INVALID_HANDLE;
new     Handle:         g_hCvarBonusWitch                                   = INVALID_HANDLE;

new     Handle:         g_hCvarDefibPenalty                                 = INVALID_HANDLE;
new                     g_iOriginalPenalty                                  = 25;                   // original defib penalty

new     bool:           g_bRoundOver[2]                                     = {false,...};          // tank/witch deaths don't count after this true
new                     g_iDefibsUsed[2]                                    = {0,...};              // defibs used this round
new                     g_iCurrentBonus                                     = 0;                    // bonus to be added when this round ends




// Natives
// -------
 
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("PBONUS_GetRoundBonus", Native_GetRoundBonus);
    CreateNative("PBONUS_SetRoundBonus", Native_SetRoundBonus);
    CreateNative("PBONUS_AddRoundBonus", Native_AddRoundBonus);
    return APLRes_Success;
}

public Native_GetRoundBonus(Handle:plugin, numParams)
{
    return _: g_iCurrentBonus;
}
public Native_SetRoundBonus(Handle:plugin, numParams)
{
    new bonus = GetNativeCell(1);
    g_iCurrentBonus = bonus;
}
public Native_AddRoundBonus(Handle:plugin, numParams)
{
    new bonus = GetNativeCell(1);
    g_iCurrentBonus += bonus;
}



// Init and round handling
// -----------------------

public OnPluginStart()
{
    // store original penalty
    g_hCvarDefibPenalty = FindConVar("vs_defib_penalty");
    g_iOriginalPenalty = GetConVarInt(g_hCvarDefibPenalty);

    // cvars
    g_hCvarDoDisplay = CreateConVar(    "sm_pbonus_display",    "1",    "Whether to display bonus at round-end.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hCvarBonusTank = CreateConVar(    "sm_pbonus_tank",       "0",    "Give this much bonus when a tank is killed (0 to disable entirely).", FCVAR_PLUGIN, true, 0.0);
    g_hCvarBonusWitch = CreateConVar(   "sm_pbonus_witch",      "0",    "Give this much bonus when a witch is killed (0 to disable entirely).", FCVAR_PLUGIN, true, 0.0);
    
    // hook events
    HookEvent("defibrillator_used",         Event_DefibUsed,            EventHookMode_PostNoCopy);

    HookEvent("witch_killed",               Event_WitchKilled,          EventHookMode_PostNoCopy);
    HookEvent("player_death",               Event_PlayerDeath,          EventHookMode_Post);
    
    HookEvent("door_close",                 Event_DoorClose,            EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving",     Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy);
    
}

public OnPluginEnd()
{
    SetConVarInt(g_hCvarDefibPenalty, g_iOriginalPenalty);
}

public OnMapStart()
{
    SetConVarInt(g_hCvarDefibPenalty, g_iOriginalPenalty);
    
    g_bRoundOver[0] = false;
    g_bRoundOver[1] = false;
    g_iDefibsUsed[0] = 0;
    g_iDefibsUsed[1] = 0;
}

public OnRoundStart()
{
    // reset
    SetConVarInt(g_hCvarDefibPenalty, g_iOriginalPenalty);
    
    g_iCurrentBonus = 0;
}

public OnRoundEnd()
{
    g_bRoundOver[GameRules_GetProp("m_bInSecondHalfOfRound")] = true;
    
    if (GetConVarBool(g_hCvarDoDisplay))
    {
        DisplayBonus();
    }
}


// Round-end tracking
// ------------------

public Event_DoorClose(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (GetEventBool(event, "checkpoint"))
    {
        SetBonus();
    }
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (client && IsSurvivor(client))
    {
        SetBonus();
    }
    else if (client && IsTank(client))
    {
        TankKilled();
    }
}

public Event_FinaleVehicleLeaving(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new i = 1; i < MaxClients; i++)
    {
        if (IsClientInGame(i) && IsSurvivor(i) && (IsIncapacitated(i) || IsHangingFromLedge(i)))
        {
            ForcePlayerSuicide(i);
        }
    }

    SetBonus();
}


// Tank and Witch tracking
// -----------------------

public TankKilled()
{
    if ( GetConVarInt(g_hCvarBonusTank) == 0 || g_bRoundOver[GameRules_GetProp("m_bInSecondHalfOfRound")] ) { return; }
    
    g_iCurrentBonus += GetConVarInt(g_hCvarBonusTank);
}

public Action: Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( GetConVarInt(g_hCvarBonusWitch) == 0 || g_bRoundOver[GameRules_GetProp("m_bInSecondHalfOfRound")] ) { return Plugin_Continue; }
    
    g_iCurrentBonus += GetConVarInt(g_hCvarBonusWitch);
    
    return Plugin_Continue;
}


// Bonus
// -----

public SetBonus()
{
    // set the bonus as though only 1 defib was used: so 1 * CalculateBonus
    new bonus = CalculateBonus();
    SetConVarInt( g_hCvarDefibPenalty, bonus );
    
    // only set the amount of defibs used to 1 if there is a bonus to set
    GameRules_SetProp("m_iVersusDefibsUsed", (bonus != 0) ? 1 : 0, 4, GameRules_GetProp("m_bAreTeamsFlipped", 4, 0) );     // set to 1 defib used
    
    //PrintDebug("[penbon] set bonus to %i * %i.", (bonus != 0) ? 1 : 0, bonus);
}

public CalculateBonus()
{
    // negative = actual bonus, otherwise it is a penalty
    return ( g_iOriginalPenalty * g_iDefibsUsed[GameRules_GetProp("m_bInSecondHalfOfRound")] ) - g_iCurrentBonus;
}

stock DisplayBonus(client=-1)
{
    new String:msgPartHdr[48];
    new String:msgPartBon[48];
    
    for (new round = 0; round <= GameRules_GetProp("m_bInSecondHalfOfRound"); round++)
    {
        if (g_bRoundOver[round]) {
            Format(msgPartHdr, sizeof(msgPartHdr), "Round \x05%i\x01 extra bonus", round+1);
        } else {
            Format(msgPartHdr, sizeof(msgPartHdr), "Current extra bonus");
        }
        
        Format(msgPartBon, sizeof(msgPartBon), "\x04%4d\x01", g_iCurrentBonus);

        if (g_iDefibsUsed[round]) {
            Format(msgPartBon, sizeof(msgPartBon), "%s (- \x04%d\x01 defib penalty)", msgPartBon, g_iOriginalPenalty * g_iDefibsUsed[GameRules_GetProp("m_bInSecondHalfOfRound")] );
        }
        
        if (client == -1) {
            PrintToChatAll("\x01%s: %s", msgPartHdr, msgPartBon);
        } else if (client) {
            PrintToChat(client, "\x01%s: %s", msgPartHdr, msgPartBon);
        } else {
            PrintToServer("\x01%s: %s", msgPartHdr, msgPartBon);
        }
    }
}



// Defib tracking
// --------------

public Event_DefibUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_iDefibsUsed[GameRules_GetProp("m_bInSecondHalfOfRound")]++;
}


// Support functions
// -----------------
/*
public PrintDebug(const String:Message[], any:...)
{
    #if DEBUG_MODE
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
        //PrintToServer(DebugBuff);
        //PrintToChatAll(DebugBuff);
    #endif
}
*/