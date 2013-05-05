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
        
        
    Changelog
    =========
        
        0.0.4
            - fixed for config-set custom defib penalty values.
            
        0.0.3
            - optional report of changes to bonus as they happen.
            - removed sm_bonus command effects when display mode is off.
            - fixed report error.
        
        0.0.2
            - added sm_bonus command to display bonus.
            
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
    version = "0.0.4",
    url = ""
}



new     Handle:         g_hCvarDoDisplay                                    = INVALID_HANDLE;
new     Handle:         g_hCvarReportChange                                 = INVALID_HANDLE;
new     Handle:         g_hCvarBonusTank                                    = INVALID_HANDLE;
new     Handle:         g_hCvarBonusWitch                                   = INVALID_HANDLE;

new     bool:           g_bFirstMapStartDone                                = false;                // so we can set the config-set defib penalty

new     Handle:         g_hCvarDefibPenalty                                 = INVALID_HANDLE;
new                     g_iOriginalPenalty                                  = 25;                   // original defib penalty

new     bool:           g_bRoundOver[2]                                     = {false,...};          // tank/witch deaths don't count after this true
new                     g_iDefibsUsed[2]                                    = {0,...};              // defibs used this round
new                     g_iBonus[2]                                         = {0,...};              // bonus to be added when this round ends




// Natives
// -------
 
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("PBONUS_GetRoundBonus", Native_GetRoundBonus);
    CreateNative("PBONUS_ResetRoundBonus", Native_ResetRoundBonus);
    CreateNative("PBONUS_SetRoundBonus", Native_SetRoundBonus);
    CreateNative("PBONUS_AddRoundBonus", Native_AddRoundBonus);
    CreateNative("PBONUS_GetDefibsUsed", Native_GetDefibsUsed);
    
    return APLRes_Success;
}

public Native_GetRoundBonus(Handle:plugin, numParams)
{
    return _: g_iBonus[RoundNum()];
}

public Native_ResetRoundBonus(Handle:plugin, numParams)
{
    g_iBonus[RoundNum()] = 0;
}

public Native_SetRoundBonus(Handle:plugin, numParams)
{
    new bonus = GetNativeCell(1);
    g_iBonus[RoundNum()] = bonus;
    
    if (GetConVarBool(g_hCvarReportChange)) { ReportChange(0, -1, true); }
}

public Native_AddRoundBonus(Handle:plugin, numParams)
{
    new bonus = GetNativeCell(1);
    g_iBonus[RoundNum()] += bonus;
    
    if (GetConVarBool(g_hCvarReportChange)) { ReportChange(bonus); }
}

public Native_GetDefibsUsed(Handle:plugin, numParams)
{
    return _: g_iDefibsUsed[RoundNum()];
}


// Init and round handling
// -----------------------

public OnPluginStart()
{
    // store original penalty
    g_hCvarDefibPenalty = FindConVar("vs_defib_penalty");

    // cvars
    g_hCvarDoDisplay = CreateConVar(    "sm_pbonus_display",        "1",    "Whether to display bonus at round-end and with !bonus.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hCvarReportChange = CreateConVar( "sm_pbonus_reportchanges",  "1",    "Whether to report changes when they are made to the current bonus.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hCvarBonusTank = CreateConVar(    "sm_pbonus_tank",           "0",    "Give this much bonus when a tank is killed (0 to disable entirely).", FCVAR_PLUGIN, true, 0.0);
    g_hCvarBonusWitch = CreateConVar(   "sm_pbonus_witch",          "0",    "Give this much bonus when a witch is killed (0 to disable entirely).", FCVAR_PLUGIN, true, 0.0);
    
    // hook events
    HookEvent("defibrillator_used",         Event_DefibUsed,            EventHookMode_PostNoCopy);

    HookEvent("witch_killed",               Event_WitchKilled,          EventHookMode_PostNoCopy);
    HookEvent("player_death",               Event_PlayerDeath,          EventHookMode_Post);
    
    HookEvent("door_close",                 Event_DoorClose,            EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving",     Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy);
 
    // Chat cleaning
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");

    RegConsoleCmd("sm_bonus", Cmd_Bonus, "Prints the current extra bonus(es) for this round.");
    
}

public OnPluginEnd()
{
    SetConVarInt(g_hCvarDefibPenalty, g_iOriginalPenalty);
}

public OnMapStart()
{
    // save original defib penalty setting
    if (!g_bFirstMapStart)
    {
        g_iOriginalPenalty = GetConVarInt(g_hCvarDefibPenalty);
        g_bFirstMapStart = true;
    }
    
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
    
    g_iBonus[RoundNum()] = 0;
}

public OnRoundEnd()
{
    g_bRoundOver[RoundNum()] = true;
    
    if (GetConVarBool(g_hCvarDoDisplay))
    {
        DisplayBonus();
    }
}

public Action: Cmd_Bonus(client, args)
{
    if (!GetConVarBool(g_hCvarDoDisplay)) { return Plugin_Continue; }
    
    DisplayBonus(client);
    return Plugin_Handled;
}

public Action:Command_Say(client, const String:command[], args)
{
    if (!GetConVarBool(g_hCvarDoDisplay)) { return Plugin_Continue; }
    
    if (IsChatTrigger())
    {
        decl String:sMessage[MAX_NAME_LENGTH];
        GetCmdArg(1, sMessage, sizeof(sMessage));

        if (StrEqual(sMessage, "!bonus")) return Plugin_Handled;
        else if (StrEqual (sMessage, "!sm_bonus")) return Plugin_Handled;
    }

    return Plugin_Continue;
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
    if ( GetConVarInt(g_hCvarBonusTank) == 0 || g_bRoundOver[RoundNum()] ) { return; }
    
    g_iBonus[RoundNum()] += GetConVarInt(g_hCvarBonusTank);
    ReportChange( GetConVarInt(g_hCvarBonusTank) );
}

public Action: Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( GetConVarInt(g_hCvarBonusWitch) == 0 || g_bRoundOver[RoundNum()] ) { return Plugin_Continue; }
    
    g_iBonus[RoundNum()] += GetConVarInt(g_hCvarBonusWitch);
    ReportChange( GetConVarInt(g_hCvarBonusWitch) );
    
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
    return ( g_iOriginalPenalty * g_iDefibsUsed[RoundNum()] ) - g_iBonus[RoundNum()];
}

stock DisplayBonus(client=-1)
{
    new String:msgPartHdr[48];
    new String:msgPartBon[48];
    
    for (new round = 0; round <= RoundNum(); round++)
    {
        if (g_bRoundOver[round]) {
            Format(msgPartHdr, sizeof(msgPartHdr), "Round \x05%i\x01 extra bonus", round+1);
        } else {
            Format(msgPartHdr, sizeof(msgPartHdr), "Current extra bonus");
        }
        
        Format(msgPartBon, sizeof(msgPartBon), "\x04%4d\x01", g_iBonus[RoundNum()]);

        if (g_iDefibsUsed[round]) {
            Format(msgPartBon, sizeof(msgPartBon), "%s (- \x04%d\x01 defib penalty)", msgPartBon, g_iOriginalPenalty * g_iDefibsUsed[RoundNum()] );
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

stock ReportChange(bonusChange, client=-1, absoluteSet=false)
{
    if (bonusChange == 0 && !absoluteSet) { return; }
    
    // report bonus to all
    new String:msgPartBon[48];
    
    if (absoluteSet) {  // set to a specific value
        Format(msgPartBon, sizeof(msgPartBon), "Extra bonus set to: \x04%i\x01", g_iBonus[RoundNum()]);
    } else {
        Format(msgPartBon, sizeof(msgPartBon), "Extra bonus change: %s\x04%i\x01",
                (bonusChange > 0) ? "\x04+\x01" : "\x03-\x01",
                bonusChange
            );
    }
    
    if (client == -1) {
        PrintToChatAll("\x01%s", msgPartBon);
    } else if (client) {
        PrintToChat(client, "\x01%s", msgPartBon);
    } else {
        PrintToServer("\x01%s", msgPartBon);
    }
}


// Defib tracking
// --------------

public Event_DefibUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_iDefibsUsed[RoundNum()]++;
}


// Support functions
// -----------------

RoundNum()
{
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

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