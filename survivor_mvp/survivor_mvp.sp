#pragma semicolon 1

#include <sourcemod.inc>
#include <sdkhooks>
#include <sdktools>
#include <left4downtown>
#include <timers.inc>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#define TEAM_SPECTATOR          1 
#define TEAM_SURVIVOR           2 
#define TEAM_INFECTED           3
#define FLAG_SPECTATOR          (1 << TEAM_SPECTATOR)
#define FLAG_SURVIVOR           (1 << TEAM_SURVIVOR)
#define FLAG_INFECTED           (1 << TEAM_INFECTED)

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

#define BREV_SI                 1
#define BREV_CI                 2
#define BREV_FF                 4
#define BREV_RANK               8
//#define BREV_???              16
#define BREV_PERCENT            32
#define BREV_ABSOLUTE           64

#define CONBUFSIZE              1024
#define CONBUFSIZELARGE         2048

#define CHARTHRESHOLD           160         // detecting unicode stuff

/*
        Changelog
        ---------
        0.2d
            - fixed tank/witch damage not displaying in console table
            
        0.2c
            - added console output table for more stats, fixed it's display
            - fixed console display to always display each player on the survivor team
            
        0.1
            - fixed common MVP ranks being messed up.
            - finally worked in PluginEnabled cvar
            - made FF tracking switch to enabled automatically if brevity flag 4 is unset
            - fixed a bug that caused FF to always report as "no friendly fire" when tracking was disabled
            - adjusted formatting a bit
            - made FF stat hidden by default
            - made convars actually get tracked (doh)
            - added friendly fire tracking (sm_survivor_mvp_trackff 1/0)
            - added brevity-flags cvar for changing verbosity of MVP report (sm_survivor_mvp_brevity bitwise, as shown)
            - discount FF damage before match is live if RUP is active.
            - fixed problem with clients disconnecting before mvp report
            - improved consistency after client reconnect (name-based)
            - fixed mvp stats double showing in scavenge (round starts)
            - now shows if MVP is a bot
            - cleaned up code
            - fixed for scavenge, now shows stats for every scavenge round
            - fixed damage/kills getting recorded for infected players, skewing MVP stats
            - added rank display for non-MVP clients
 */
/*
    Brevity flags:
        1       leave out SI stats
        2       leave out CI stats
        4       leave out FF stats
        8       leave out rank notification
        16   (reserved)
        32      leave out percentages
        64      leave out absolutes
        
 */

public Plugin:myinfo =
{
    name = "Survivor MVP notification",
    author = "Tabun",
    description = "Shows MVP for survivor team at end of round",
    version = "0.2d",
    url = "nope"
};


new     Handle:     hPluginEnabled =    INVALID_HANDLE;

new     Handle:     hCountTankDamage =  INVALID_HANDLE;         // whether we're tracking tank damage for MVP-selection
new     Handle:     hCountWitchDamage = INVALID_HANDLE;         // whether we're tracking witch damage for MVP-selection
new     Handle:     hTrackFF =          INVALID_HANDLE;         // whether we're tracking friendly-fire damage (separate stat)
new     Handle:     hBrevityFlags =     INVALID_HANDLE;         // how verbose/brief the output should be:
new     Handle:     hRUPActive =        INVALID_HANDLE;         // whether the ready up mod is active
new     Handle:     hTeamSize =         INVALID_HANDLE;         // amount of players in team

new     bool:       bCountTankDamage;
new     bool:       bCountWitchDamage;
new     bool:       bTrackFF;
new                 iBrevityFlags;
new     bool:       bRUPActive;

new     Handle:     hGameMode = INVALID_HANDLE;
new     String:     sGameMode[24] = "\0";

new     String:     sClientName[MAXPLAYERS + 1][64];            // which name is connected to the clientId?

new                 iGotKills[MAXPLAYERS + 1];                  // SI kills             track for each client
new                 iGotCommon[MAXPLAYERS + 1];                 // CI kills
new                 iDidDamage[MAXPLAYERS + 1];                 // SI only              these are a bit redundant, but will keep anyway for now
new                 iDidDamageAll[MAXPLAYERS + 1];              // SI + tank + witch
new                 iDidDamageTank[MAXPLAYERS + 1];             // tank only
new                 iDidDamageWitch[MAXPLAYERS + 1];            // witch only
new                 iDidFF[MAXPLAYERS + 1];                     // friendly fire damage

new                 iTotalKills;                                // prolly more efficient to store than to recalculate
new                 iTotalCommon;
new                 iTotalDamage;
new                 iTotalDamageTank;
new                 iTotalDamageWitch;
new                 iTotalDamageAll;
new                 iTotalFF;

new                 iRoundNumber;
new     bool:       bInRound;
new     bool:       bPlayerLeftStartArea;                       // used for tracking FF when RUP enabled

new     String:     sConsoleBuf[CONBUFSIZE];                    // used for spamming table of stats to console
new     String:     sTmpString[MAX_NAME_LENGTH];                // just used because I'm not going to break my head over why string assignment parameter passing doesn't work

/*
 *      Natives
 *      =======
 */
 
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("SURVMVP_GetMVP", Native_GetMVP);
    CreateNative("SURVMVP_GetMVPDmgCount", Native_GetMVPDmgCount);
    CreateNative("SURVMVP_GetMVPKills", Native_GetMVPKills);
    CreateNative("SURVMVP_GetMVPDmgPercent", Native_GetMVPDmgPercent);
    CreateNative("SURVMVP_GetMVPCI", Native_GetMVPCI);
    CreateNative("SURVMVP_GetMVPCIKills", Native_GetMVPCIKills);
    CreateNative("SURVMVP_GetMVPCIPercent", Native_GetMVPCIPercent);
    
    return APLRes_Success;
}

// simply return current round MVP client
public Native_GetMVP(Handle:plugin, numParams)
{
    new client = findMVPSI();
    return _:client;
}

// return damage percent of client
public Native_GetMVPDmgPercent(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new Float: dmgprc;
    
    if (client && iTotalDamageAll > 0) {
        dmgprc = (float(iDidDamageAll[client]) / float(iTotalDamageAll)) * 100;
    } else {
        dmgprc = 0.0;
    }
    return _:dmgprc;
}

// return damage of client
public Native_GetMVPDmgCount(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new dmg;
    
    if (client && iTotalDamageAll > 0) {
        dmg = iDidDamageAll[client];
    } else {
        dmg = 0;
    }
    return _:dmg;
}

// return SI kills of client
public Native_GetMVPKills(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new dmg;
    
    if (client && iTotalKills > 0) {
        dmg = iGotKills[client];
    } else {
        dmg = 0;
    }
    return _:dmg;
}

// simply return current round MVP client (Common)
public Native_GetMVPCI(Handle:plugin, numParams)
{
    new client = findMVPCommon();
    return _:client;
}

// return common kills for client
public Native_GetMVPCIKills(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new dmg;
    
    if (client && iTotalCommon > 0) {
        dmg = iGotCommon[client];
    } else {
        dmg = 0;
    }
    return _:dmg;
}

// return CI percent of client
public Native_GetMVPCIPercent(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new Float: dmgprc;
    
    if (client && iTotalCommon > 0) {
        dmgprc = (float(iGotCommon[client]) / float(iTotalCommon)) * 100;
    } else {
        dmgprc = 0.0;
    }
    return _:dmgprc;
}


/*
 *      init
 *      ====
 */

public OnPluginStart()
{
    // Round triggers
    //HookEvent("door_close", DoorClose_Event);
    //HookEvent("finale_vehicle_leaving", FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("scavenge_round_start", EventHook:ScavRoundStart);
    HookEvent("player_left_start_area", PlayerLeftStartArea);
    
    // Catching data
    HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    HookEvent("infected_hurt" ,InfectedHurt_Event, EventHookMode_Post);
    HookEvent("infected_death", InfectedDeath_Event, EventHookMode_Post);
    
    // check gamemode (for scavenge fix)
    hGameMode = FindConVar("mp_gamemode");
    
    // Cvars
    hPluginEnabled =    CreateConVar("sm_survivor_mvp_enabled", "1", "Enable display of MVP at end of round", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    hCountTankDamage =  CreateConVar("sm_survivor_mvp_counttank", "0", "Damage on tank counts towards MVP-selection if enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    hCountWitchDamage = CreateConVar("sm_survivor_mvp_countwitch", "0", "Damage on witch counts towards MVP-selection if enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    hTrackFF =          CreateConVar("sm_survivor_mvp_showff", "0", "Track Friendly-fire stat.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    hBrevityFlags =     CreateConVar("sm_survivor_mvp_brevity", "4", "Flags for setting brevity of MVP report (hide 1:SI, 2:CI, 4:FF, 8:rank, 32:perc, 64:abs).", FCVAR_PLUGIN, true, 0.0);
    
    hTeamSize =         FindConVar("survivor_limit");
    
    bCountTankDamage =  GetConVarBool(hCountTankDamage);
    bCountWitchDamage = GetConVarBool(hCountWitchDamage);
    bTrackFF =          GetConVarBool(hTrackFF);
    iBrevityFlags =     GetConVarInt(hBrevityFlags);
    
    
    
    // for now, force FF tracking on:
    bTrackFF = true;
    
    HookConVarChange(hCountTankDamage, ConVarChange_CountTankDamage);
    HookConVarChange(hCountWitchDamage, ConVarChange_CountWitchDamage);
    HookConVarChange(hTrackFF, ConVarChange_TrackFF);
    HookConVarChange(hBrevityFlags, ConVarChange_BrevityFlags);
    
    if (!(iBrevityFlags & BREV_FF)) { bTrackFF = true; } // force tracking on if we're showing FF
    
    // RUP?
    hRUPActive = FindConVar("l4d_ready_enabled");
    if (hRUPActive != INVALID_HANDLE)
    {
        // hook changes for this, and set state appropriately
        bRUPActive = GetConVarBool(hRUPActive);
        HookConVarChange(hRUPActive, ConVarChange_RUPActive);
    } else {
        // not loaded
        bRUPActive = false;
    }
    bPlayerLeftStartArea = false;
    
    // Commands
    RegConsoleCmd("sm_mvp", SurvivorMVP_Cmd, "Prints the current MVP for the survivor team");
    RegConsoleCmd("sm_mvpme", ShowMVPStats_Cmd, "Prints the client's own MVP-related stats");
    
    RegConsoleCmd("say", Say_Cmd);
    RegConsoleCmd("say_team", Say_Cmd);
}

/*
public OnPluginEnd()
{
    // nothing
}
*/

public OnClientPutInServer(client)
{
    decl String:tmpBuffer[64];
    GetClientName(client, tmpBuffer, sizeof(tmpBuffer));
    
    // if previously stored name for same client is not the same, delete stats & overwrite name
    if (strcmp(tmpBuffer, sClientName[client], true) != 0)
    {
        iGotKills[client] = 0;
        iGotCommon[client] = 0;
        iDidDamage[client] = 0;
        iDidDamageAll[client] = 0;
        iDidDamageWitch[client] = 0;
        iDidDamageTank[client] = 0;
        iDidFF[client] = 0;
        
        // store name for later reference
        strcopy(sClientName[client], 64, tmpBuffer);
    }
}

/*
 *      convar changes
 *      ==============
 */

public ConVarChange_CountTankDamage(Handle:cvar, const String:oldValue[], const String:newValue[]) {
    if (StringToInt(newValue) == 0) { bCountTankDamage = false; } else { bCountTankDamage = true; }
}
public ConVarChange_CountWitchDamage(Handle:cvar, const String:oldValue[], const String:newValue[]) {
    if (StringToInt(newValue) == 0) { bCountWitchDamage = false; } else { bCountWitchDamage = true; }
}
public ConVarChange_TrackFF(Handle:cvar, const String:oldValue[], const String:newValue[]) {
    //if (StringToInt(newValue) == 0) { bTrackFF = false; } else { bTrackFF = true; }
    // for now, disable FF tracking toggle (always on)
}
public ConVarChange_BrevityFlags(Handle:cvar, const String:oldValue[], const String:newValue[]) {
    iBrevityFlags = StringToInt(newValue);
    if (!(iBrevityFlags & BREV_FF)) { bTrackFF = true; } // force tracking on if we're showing FF
}

public ConVarChange_RUPActive(Handle:cvar, const String:oldValue[], const String:newValue[]) {
    if (StringToInt(newValue) == 0) { bRUPActive = false; } else { bRUPActive = true; }
}

/*
 *      map load / round start/end
 *      ==========================
 */

public Action:PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
    // if RUP active, now we can start tracking FF
    bPlayerLeftStartArea = true;
}

public OnMapStart()
{
    bPlayerLeftStartArea = false;
    // get gamemode string for scavenge fix
    GetConVarString(hGameMode, sGameMode, sizeof(sGameMode));
}

public OnMapEnd()
{
    iRoundNumber = 0;
    bInRound = false;
}

public ScavRoundStart(Handle:event)
{
    // clear mvp stats
    new i, maxplayers = MaxClients;
    for (i = 1; i <= maxplayers; i++)
    {
        iGotKills[i] = 0;
        iGotCommon[i] = 0;
        iDidDamage[i] = 0;
        iDidDamageAll[i] = 0;
        iDidDamageWitch[i] = 0;
        iDidDamageTank[i] = 0;
        iDidFF[i] = 0;
    }
    iTotalKills = 0;
    iTotalCommon = 0;
    iTotalDamage = 0;
    iTotalDamageTank = 0;
    iTotalDamageWitch = 0;
    iTotalDamageAll = 0;
    iTotalFF = 0;
    
    bInRound = true;
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    bPlayerLeftStartArea = false;
    
    if (!bInRound)
    {
        bInRound = true;
        iRoundNumber++;
    }
    
    // clear mvp stats
    new i, maxplayers = MaxClients;
    for (i = 1; i <= maxplayers; i++)
    {
        iGotKills[i] = 0;
        iGotCommon[i] = 0;
        iDidDamage[i] = 0;
        iDidDamageAll[i] = 0;
        iDidDamageWitch[i] = 0;
        iDidDamageTank[i] = 0;
        iDidFF[i] = 0;
    }
    iTotalKills = 0;
    iTotalCommon = 0;
    iTotalDamage = 0;
    iTotalDamageAll = 0;
    iTotalFF = 0;
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (StrEqual(sGameMode, "scavenge", false))
    {
        if (bInRound)
        {
            if (GetConVarBool(hPluginEnabled))
                    CreateTimer(2.0, delayedMVPPrint);   // shorter delay for scavenge.
            bInRound = false;
        }
    }
    else
    {
        // versus or other
        if (bInRound)
        {
            // only show / log stuff when the round is done "the first time"
            if (GetConVarBool(hPluginEnabled))
                    CreateTimer(4.0, delayedMVPPrint);
            bInRound = false;
        }
    }
}


/*
 *      cmds / reports
 *      ==============
 */

public Action:Say_Cmd(client, args)
{
    if (!client) { return Plugin_Continue; }
    
    decl String:sMessage[MAX_NAME_LENGTH];
    GetCmdArg(1, sMessage, sizeof(sMessage));
    
    if (StrEqual(sMessage, "!mvp") || StrEqual(sMessage, "!mvpme")) { return Plugin_Handled; }
    
    return Plugin_Continue;
}

public Action:SurvivorMVP_Cmd(client, args)
{
    decl String:printBuffer[512];
    
    printBuffer = GetMVPString();
    PrintConsoleReport(client);
    
    if (client && IsClientConnected(client))
    {
        PrintToChat(client, "\x01%s", printBuffer);
    }
    else
    {
        PrintToServer("\x01%s", printBuffer);
    }
}

public Action:ShowMVPStats_Cmd(client, args)
{
    // show mvp in this round
    if (client && IsClientConnected(client))
    {
        decl String:printBuffer[512];
        decl String:tmpBuffer[256];
        
        printBuffer = "";
        
        if (!(iBrevityFlags & BREV_SI))
        {
            if (iTotalDamageAll > 0)
            {
                if (iBrevityFlags & BREV_PERCENT) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] You - SI: (\x05%d \x01dmg,\x05 %d \x01kills)\n", iDidDamageAll[client], iGotKills[client]);
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] You - SI: (dmg \x04%2.0f%%\x01, kills \x04%.0f%%\x01)\n", (float(iDidDamageAll[client]) / float(iTotalDamageAll)) * 100, (float(iGotKills[client]) / float(iTotalKills)) * 100);
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] You - SI: (\x05%d \x01dmg [\x04%.0f%%\x01],\x05 %d \x01kills [\x04%.0f%%\x01])\n", iDidDamageAll[client], (float(iDidDamageAll[client]) / float(iTotalDamageAll)) * 100, iGotKills[client], (float(iGotKills[client]) / float(iTotalKills)) * 100);
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
            else
            {
                StrCat(printBuffer, sizeof(printBuffer), "\x01[You] SI: (nada)\n");
            }
        }
        
        if (!(iBrevityFlags & BREV_CI))
        {
            if (iTotalCommon > 0)
            {
                if (iBrevityFlags & BREV_PERCENT) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] You - CI: (\x05%d \x01common)\n", iGotCommon[client]);
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] You - CI: (\x04%.0f%%\x01)\n", (float(iGotCommon[client]) / float(iTotalCommon)) * 100);
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] You - CI: (\x05%d \x01common [\x04%.0f%%\x01])\n", iGotCommon[client], (float(iGotCommon[client]) / float(iTotalCommon)) * 100);
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
        }
        
        PrintToChat(client, "\x01%s", printBuffer);
        
        // leave this like so for now. might let brevityflags block this too.
        if (!(iBrevityFlags & BREV_FF) && bTrackFF) {
            PrintToChat(client, "\x01You - FF: (\x05%d \x01friendly dmg [\x04%.0f%%\x01])\n", iDidFF[client], (float(iDidFF[client]) / float(iTotalFF)) * 100);
        }
        
    }
}

public Action:delayedMVPPrint(Handle:timer)
{
    decl String:printBuffer[512];
    decl String:tmpBuffer[512];
    printBuffer = GetMVPString();
    PrintToServer("\x01%s", printBuffer);
    PrintToChatAll("\x01%s", printBuffer);
    PrintConsoleReport(0); // to all
    
    // also find the three non-mvp survivors and tell them they sucked
    // tell them they sucked with SI
    if (iTotalDamageAll > 0 && !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_SI))
    {
        new mvp_SI = findMVPSI();
        new mvp_SI_losers[3];
        mvp_SI_losers[0] = findMVPSI(int:mvp_SI);                                                   // second place
        mvp_SI_losers[1] = findMVPSI(int:mvp_SI, int:mvp_SI_losers[0]);                             // third
        mvp_SI_losers[2] = findMVPSI(int:mvp_SI, int:mvp_SI_losers[0], int:mvp_SI_losers[1]);       // fourth
        
        for (new i = 0; i <= 2; i++)
        {
            if (IsClientAndInGame(mvp_SI_losers[i]) && !IsFakeClient(mvp_SI_losers[i])) {
                if (iBrevityFlags & BREV_PERCENT) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg,\x05 %d \x01kills)", (i + 2), iDidDamageAll[mvp_SI_losers[i]], iGotKills[mvp_SI_losers[i]]);
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - SI: #\x03%d \x01(dmg \x04%.0f%%\x01, kills \x04%.0f%%\x01)", (i + 2), (float(iDidDamageAll[mvp_SI_losers[i]]) / float(iTotalDamageAll)) * 100, (float(iGotKills[mvp_SI_losers[i]]) / float(iTotalKills)) * 100);
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg [\x04%.0f%%\x01],\x05 %d \x01kills [\x04%.0f%%\x01])", (i + 2), iDidDamageAll[mvp_SI_losers[i]], (float(iDidDamageAll[mvp_SI_losers[i]]) / float(iTotalDamageAll)) * 100, iGotKills[mvp_SI_losers[i]], (float(iGotKills[mvp_SI_losers[i]]) / float(iTotalKills)) * 100);
                }
                PrintToChat(mvp_SI_losers[i], "\x01%s", tmpBuffer);
            }
        }
    }
    
    // tell them they sucked with Common
    if (iTotalCommon > 0 && !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_CI))
    {
        new mvp_CI = findMVPCommon();
        new mvp_CI_losers[3];
        mvp_CI_losers[0] = findMVPCommon(int:mvp_CI);                                                   // second place
        mvp_CI_losers[1] = findMVPCommon(int:mvp_CI, int:mvp_CI_losers[0]);                             // third
        mvp_CI_losers[2] = findMVPCommon(int:mvp_CI, int:mvp_CI_losers[0], int:mvp_CI_losers[1]);       // fourth
        
        for (new i = 0; i <= 2; i++)
        {
            if (IsClientAndInGame(mvp_CI_losers[i]) && !IsFakeClient(mvp_CI_losers[i])) {
                if (iBrevityFlags & BREV_PERCENT) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - CI: #\x03%d \x01(\x05%d \x01kills)", (i + 2), iGotCommon[mvp_CI_losers[i]]);
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - CI: #\x03%d \x01(kills \x04%.0f%%\x01)", (i + 2), (float(iGotCommon[mvp_CI_losers[i]]) / float(iTotalCommon)) * 100);
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - CI: #\x03%d \x01(\x05%d \x01kills [\x04%.0f%%\x01])", (i + 2), iGotCommon[mvp_CI_losers[i]], (float(iGotCommon[mvp_CI_losers[i]]) / float(iTotalCommon)) * 100);
                }
                PrintToChat(mvp_CI_losers[i], "\x01%s", tmpBuffer);
            }
        }
    }
    
    // tell them they were better with FF (I know, I know, losers = winners)
    if (iTotalFF > 0 && bTrackFF && !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_FF))
    {
        new mvp_FF = findLVPFF();
        new mvp_FF_losers[3];
        mvp_FF_losers[0] = findLVPFF(int:mvp_FF);                                                   // second place
        mvp_FF_losers[1] = findLVPFF(int:mvp_FF, int:mvp_FF_losers[0]);                             // third
        mvp_FF_losers[2] = findLVPFF(int:mvp_FF, int:mvp_FF_losers[0], int:mvp_FF_losers[1]);       // fourth
        
        for (new i = 0; i <= 2; i++)
        {
            if (IsClientAndInGame(mvp_FF_losers[i]) && !IsFakeClient(mvp_FF_losers[i])) {
                if (iBrevityFlags & BREV_PERCENT) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - FF: #\x03%d \x01(\x05%d \x01dmg)", (i + 2), iDidFF[mvp_FF_losers[i]]);
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - FF: #\x03%d \x01(dmg \x04%.0f%%\x01)", (i + 2), (float(iDidFF[mvp_FF_losers[i]]) / float(iTotalFF)) * 100);
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - FF: #\x03%d \x01(\x05%d \x01dmg [\x04%.0f%%\x01])", (i + 2), iDidFF[mvp_FF_losers[i]], (float(iDidFF[mvp_FF_losers[i]]) / float(iTotalFF)) * 100);
                }
                PrintToChat(mvp_FF_losers[i], "\x01%s", tmpBuffer);
            }
        }
    }
    
}

public PrintConsoleReport(client)
{
    
    decl String:buf[CONBUFSIZELARGE];
    Format(buf, CONBUFSIZELARGE, "\n");
    Format(buf, CONBUFSIZELARGE, "%s| Name                 | Damage   | Percent | SI Kills | Commons  | Percent | Tank   | Witch  | FF           |\n", buf);
    Format(buf, CONBUFSIZELARGE, "%s|----------------------|----------|---------|----------|----------|---------|--------|--------|--------------|\n", buf);
    Format(buf, CONBUFSIZELARGE, "%s%s", buf, sConsoleBuf);
    Format(buf, CONBUFSIZELARGE, "%s|------------------------------------------------------------------------------------------------------------|", buf);
    
    if (!client) {
        PrintToConsoleAll("%s", buf);
    } else {
        PrintToConsoleClient(client, "%s", buf);
    }
}


/*
 *      track damage/kills
 *      ==================
 */

public PlayerHurt_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new zombieClass = 0;
    
    new victimId = GetEventInt(event, "userid");
    new victim = GetClientOfUserId(victimId);
    
    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    
    new damageDone = GetEventInt(event, "dmg_health");
    
    // no world damage or flukes or whatevs, no bot attackers, no infected-to-infected damage
    if (victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker))
    {
        if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_INFECTED)
        {
            // survivor on zombie action
            zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
            
            // separately store SI and tank damage
            if (zombieClass >= ZC_SMOKER && zombieClass < ZC_WITCH)
            {
                iDidDamage[attacker] += damageDone;
                iDidDamageAll[attacker] += damageDone;
                iTotalDamage += damageDone;
                iTotalDamageAll += damageDone;
            }
            else if (zombieClass == ZC_TANK)
            {
                if (bCountTankDamage) {
                    iDidDamageAll[attacker] += damageDone;
                    iTotalDamageAll += damageDone;
                }
                iDidDamageTank[attacker] += damageDone;
                iTotalDamageTank += damageDone;
            }
        }
        else if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_SURVIVOR && bTrackFF)                // survivor on survivor action == FF
        {
            if (!bRUPActive || GetEntityMoveType(victim) != MOVETYPE_NONE || bPlayerLeftStartArea) {
                // but don't record while frozen in readyup / before leaving saferoom
                iDidFF[attacker] += damageDone;
                iTotalFF += damageDone;
            }
        }
    }
}

public InfectedHurt_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    // catch damage done to witch
    new victimEntId = GetEventInt(event, "entityid");

    if (IsWitch(victimEntId))
    {
        new attackerId = GetEventInt(event, "attacker");
        new attacker = GetClientOfUserId(attackerId);
        new damageDone = GetEventInt(event, "amount");
        
        // no world damage or flukes or whatevs, no bot attackers
        if (attackerId && IsClientAndInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
        {
            if (bCountWitchDamage) {
                iDidDamageAll[attacker] += damageDone;
                iTotalDamageAll += damageDone;
            }
            iDidDamageWitch[attacker] += damageDone;
            iTotalDamageWitch += damageDone;
            
        }
    }
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new zombieClass = 0;
    
    new victimId = GetEventInt(event, "userid");
    new victim = GetClientOfUserId(victimId);
    
    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    
    //new bool:headshot = GetEventBool(event, "headshot");
    
    // no world kills or flukes or whatevs, no bot attackers
    if (victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
    {
        zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        
        // only SI, not the tank && only player-attackers
        if (zombieClass >= ZC_SMOKER && zombieClass < ZC_WITCH)
        {
            // store kill to count for attacker id
            iGotKills[attacker]++;
            iTotalKills++;
        }
    }
}

public InfectedDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    // catch amount of common killed
    //new victimId = GetEventInt(event, "infected_id");
    //new victimType = GetEventInt(event, "gender");

    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    
    if (attackerId && IsClientAndInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
    {
        iGotCommon[attacker]++;
        iTotalCommon++;
        // if victimType > 2, it's an "uncommon" (of some type or other) -- do nothing with this ftpresent.
    }
}



/*
 *      MVP string & 'sorting'
 *      ======================
 */

String: GetMVPString()
{
    decl String:printBuffer[512];
    decl String:tmpBuffer[256];
    
    decl String:tmpName[64];
    decl String:mvp_SI_name[64];
    decl String:mvp_Common_name[64];
    decl String:mvp_FF_name[64];
    
    printBuffer = "";
    new mvp_SI = 0;
    new mvp_Common = 0;
    new mvp_FF = 0;
    
    // calculate MVP per category:
    //  1. SI damage & SI kills + damage to tank/witch
    //  2. common kills
    
    // SI MVP
    if (!(iBrevityFlags & BREV_SI))
    {
        mvp_SI = findMVPSI();
        if (mvp_SI > 0)
        {
            // get name from client if connected -- if not, use sClientName array
            if (IsClientConnected(mvp_SI))
            {
                GetClientName(mvp_SI, tmpName, sizeof(tmpName));
                if (IsFakeClient(mvp_SI))
                {
                    StrCat(tmpName, 64, " \x01[BOT]");
                }
            } else {
                strcopy(tmpName, 64, sClientName[mvp_SI]);
            }
            mvp_SI_name = tmpName;
        } else {
            mvp_SI_name = "(nobody)";
        }
    }
    
    // Common MVP
    if (!(iBrevityFlags & BREV_CI))
    {
        mvp_Common = findMVPCommon();
        if (mvp_Common > 0)
        {
            // get name from client if connected -- if not, use sClientName array
            if (IsClientConnected(mvp_Common))
            {
                GetClientName(mvp_Common, tmpName, sizeof(tmpName));
                if (IsFakeClient(mvp_Common))
                {
                    StrCat(tmpName, 64, " \x01[BOT]");
                }
            } else {
                strcopy(tmpName, 64, sClientName[mvp_Common]);
            }
            mvp_Common_name = tmpName;
        } else {
            mvp_Common_name = "(nobody)";
        }
    }
    
    // FF LVP
    if (!(iBrevityFlags & BREV_FF) && bTrackFF)
    {
        mvp_FF = findLVPFF();
        if (mvp_FF > 0)
        {
            // get name from client if connected -- if not, use sClientName array
            if (IsClientConnected(mvp_FF))
            {
                GetClientName(mvp_FF, tmpName, sizeof(tmpName));
                if (IsFakeClient(mvp_FF))
                {
                    StrCat(tmpName, 64, " \x01[BOT]");
                }
            } else {
                strcopy(tmpName, 64, sClientName[mvp_FF]);
            }
            mvp_FF_name = tmpName;
        } else {
            mvp_FF_name = "(nobody)";
        }
    }
    
    // report
    
    if (mvp_SI == 0 && mvp_Common == 0 && !(iBrevityFlags & BREV_SI && iBrevityFlags & BREV_CI))
    {
        Format(tmpBuffer, sizeof(tmpBuffer), "MVP: (not enough action yet)\n");
        StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
    }
    else
    {
        if (!(iBrevityFlags & BREV_SI))
        {
            if (mvp_SI > 0)
            {
                if (iBrevityFlags & BREV_PERCENT) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] SI:\x03 %s \x01(\x05%d \x01dmg,\x05 %d \x01kills)\n", mvp_SI_name, iDidDamageAll[mvp_SI], iGotKills[mvp_SI]);
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] SI:\x03 %s \x01(dmg \x04%2.0f%%\x01, kills \x04%.0f%%\x01)\n", mvp_SI_name, (float(iDidDamageAll[mvp_SI]) / float(iTotalDamageAll)) * 100, (float(iGotKills[mvp_SI]) / float(iTotalKills)) * 100);
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] SI:\x03 %s \x01(\x05%d \x01dmg[\x04%.0f%%\x01],\x05 %d \x01kills [\x04%.0f%%\x01])\n", mvp_SI_name, iDidDamageAll[mvp_SI], (float(iDidDamageAll[mvp_SI]) / float(iTotalDamageAll)) * 100, iGotKills[mvp_SI], (float(iGotKills[mvp_SI]) / float(iTotalKills)) * 100);
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
            else
            {
                StrCat(printBuffer, sizeof(printBuffer), "[MVP] SI: \x03(nobody)\x01\n");
            }
        }
        
        if (!(iBrevityFlags & BREV_CI))
        {
            if (mvp_Common > 0)
            {
                if (iBrevityFlags & BREV_PERCENT) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] CI:\x03 %s \x01(\x05%d \x01common)\n", mvp_Common_name, iGotCommon[mvp_Common]);
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] CI:\x03 %s \x01(\x04%.0f%%\x01)\n", mvp_Common_name, (float(iGotCommon[mvp_Common]) / float(iTotalCommon)) * 100);
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] CI:\x03 %s \x01(\x05%d \x01common [\x04%.0f%%\x01])\n", mvp_Common_name, iGotCommon[mvp_Common], (float(iGotCommon[mvp_Common]) / float(iTotalCommon)) * 100);
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
        }
    }
    
    // FF
    if (!(iBrevityFlags & BREV_FF) && bTrackFF)
    {
        if (mvp_FF == 0)
        {
            Format(tmpBuffer, sizeof(tmpBuffer), "LVP - FF: no friendly fire at all!\n");
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
        else
        {
            if (iBrevityFlags & BREV_PERCENT) {
                Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] FF:\x03 %s \x01(\x05%d \x01dmg)\n", mvp_FF_name, iDidFF[mvp_FF]);
            } else if (iBrevityFlags & BREV_ABSOLUTE) {
                Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] FF:\x03 %s \x01(\x04%.0f%%\x01)\n", mvp_FF_name, (float(iDidFF[mvp_FF]) / float(iTotalFF)) * 100);
            } else {
                Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] FF:\x03 %s \x01(\x05%d \x01dmg [\x04%.0f%%\x01])\n", mvp_FF_name, iDidFF[mvp_FF], (float(iDidFF[mvp_FF]) / float(iTotalFF)) * 100);
            }
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
    }
    

    // build console buffer
    // -----------------------------------
    sConsoleBuf = "";
    new const max_name_len = 20;
    new const s_len = 15;
    decl String:name[MAX_NAME_LENGTH];
    decl String:sikills[s_len], String:sidamage[s_len], String:cikills[s_len];
    decl String:siprc[s_len], String:ciprc[s_len];
    decl String:tankdmg[s_len], String:witchdmg[s_len], String:ff[s_len];
    
    new teamCount = GetConVarInt(hTeamSize);
    new i;  // tmp clientid
    new mpv_done[4];
    new mvp_losers[3];
    
    /*
    new tot_sidmg, tot_sikills, tot_cikills, tot_tank, tot_witch;
    new Float: tot_siprc = 0.0;
    new Float: tot_ciprc = 0.0;
    */
    
    for (new j = 1; j <= teamCount; j++)
    {
        /*
            try and sort a list by MVP SI; then by MVP CI,
            if neither's available, just walk through the survivors
         */
        if (mvp_SI) {
            switch (j) {
                case 1: { i = mvp_SI; }
                case 2: { i = mvp_losers[j - 2] = findMVPSI(int:mvp_SI); }
                case 3: { i = mvp_losers[j - 2] = findMVPSI(int:mvp_SI, int:mvp_losers[0]); }
                case 4: { i = mvp_losers[j - 2] = findMVPSI(int:mvp_SI, int:mvp_losers[0], int:mvp_losers[1]); }
            }
            if (!i) { i = getSurvivor(mpv_done); }
        } else if (mvp_Common) {
            switch (j) {
                case 1: { i = mvp_Common; }
                case 2: { i = mvp_losers[j - 2] = findMVPCommon(int:mvp_Common); }
                case 3: { i = mvp_losers[j - 2] = findMVPCommon(int:mvp_Common, int:mvp_losers[0]); }
                case 4: { i = mvp_losers[j - 2] = findMVPCommon(int:mvp_Common, int:mvp_losers[0], int:mvp_losers[1]); }
            }
            if (!i) { i = getSurvivor(mpv_done); }
        } else {
            i = getSurvivor(mpv_done);
        }
        
        mpv_done[j - 1] = i;    // track so we can fall back on 'getSurvivor' approach on empty stats
        
        if (IsClientAndInGame(i) && IsClientConnected(i)) {
            GetClientName(i, name, sizeof(name));
            if (IsFakeClient(i)) { StrCat(name, sizeof(name), " [BOT]"); }
        } else {
            strcopy(name, sizeof(name), sClientName[i]);
        }
        stripUnicode(name);
        name = sTmpString;
        name[max_name_len] = 0;                     // terminates name at max length
        
        // count some things
        /*
        tot_sidmg += iDidDamageAll[i];
        tot_sikills += iGotKills[i];
        tot_siprc += (float(iDidDamageAll[i]) / float(iTotalDamageAll)) * 100;
        tot_cikills += iGotCommon[i];
        tot_ciprc += (float(iGotCommon[i]) / float(iTotalCommon)) * 100;
        tot_tank += iDidDamageTank[i];
        tot_witch += iDidDamageWitch[i];
        */
        
        Format(sidamage,    s_len, "%8d",   iDidDamageAll[i]);
        Format(siprc,       s_len, "%7.1f", (float(iDidDamageAll[i]) / float(iTotalDamageAll)) * 100 );
        Format(sikills,     s_len, "%8d",   iGotKills[i]);
        Format(cikills,     s_len, "%8d",   iGotCommon[i]);
        Format(ciprc,       s_len, "%7.1f", (float(iGotCommon[i]) / float(iTotalCommon)) * 100 );
        Format(tankdmg,     s_len, "%6d",   iDidDamageTank[i]);
        Format(witchdmg,    s_len, "%6d",   iDidDamageWitch[i]);
        Format(ff,          s_len, "%6d",   iDidFF[i]);
/*
        Format(buf, CONBUFSIZELARGE, "%s| Name                 | Damage   | Percent | SI Kills | Commons  | Percent | Tank   | Witch  | FF           |\n", buf);
        Format(buf, CONBUFSIZELARGE, "%s|----------------------|----------|---------|----------|----------|---------|--------|--------|--------------|\n", buf);
*/
        Format(sConsoleBuf, CONBUFSIZE,
            "%s| %20s | %8s | %7s | %8s | %8s | %7s | %6s | %6s | %6s       |\n",
            sConsoleBuf, name, sidamage, siprc, sikills, cikills, ciprc, tankdmg, witchdmg, ff
        );
            
    }
    
    /*
    Format(sConsoleBuf, CONBUFSIZE, "%s|----------------------|----------|---------|----------|----------|---------|--------|--------|--------------|\n", sConsoleBuf);
    
    Format(sidamage,    s_len, "%8d",   iTotalDamageAll - tot_sidmg);
    Format(siprc,       s_len, "%7.1f", 100.0 - (float(iTotalDamageAll) / float(tot_sidmg)) * 100 );
    Format(sikills,     s_len, "%8d",   iTotalKills - tot_sikills);
    Format(cikills,     s_len, "%8d",   iTotalCommon - tot_cikills);
    Format(ciprc,       s_len, "%7.1f", 100.0 - (float(iTotalCommon) / float(tot_cikills)) * 100 );
    Format(tankdmg,     s_len, "%6d",   iTotalDamageTank - tot_tank);
    Format(witchdmg,    s_len, "%6d",   iTotalDamageWitch - tot_witch);
    
    Format(sConsoleBuf, CONBUFSIZE,
            "%s| %20s | %8s | %7s | %8s | %8s | %7s | %6s | %6s |              |\n",
            sConsoleBuf, "(others)", sidamage, siprc, sikills, cikills, ciprc, tankdmg, witchdmg
        );
    */
    
    return printBuffer;
}


findMVPSI(excludeMeA = 0, excludeMeB = 0, excludeMeC = 0)
{
    new i, maxIndex = 0;
    for(i = 1; i < sizeof(iDidDamageAll); i++)
    {
        if(iDidDamageAll[i] > iDidDamageAll[maxIndex]  && i != excludeMeA && i != excludeMeB && i != excludeMeC)
            maxIndex = i;
    }
    return maxIndex;
}

findMVPCommon(excludeMeA = 0, excludeMeB = 0, excludeMeC = 0)
{
    new i, maxIndex = 0;
    for(i = 1; i < sizeof(iGotCommon); i++)
    {
        if(iGotCommon[i] > iGotCommon[maxIndex] && i != excludeMeA && i != excludeMeB && i != excludeMeC)
            maxIndex = i;
    }
    return maxIndex;
}

findLVPFF(excludeMeA = 0, excludeMeB = 0, excludeMeC = 0)
{
    new i, maxIndex = 0;
    for(i = 1; i < sizeof(iDidFF); i++)
    {
        if(iDidFF[i] > iDidFF[maxIndex]  && i != excludeMeA && i != excludeMeB && i != excludeMeC)
            maxIndex = i;
    }
    return maxIndex;
}


/*
 *      general functions
 *      =================
 */


stock bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

stock bool:IsSurvivor(client)
{
    return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool:IsInfected(client)
{
    return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_INFECTED;
}

stock bool:IsWitch(iEntity)
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "witch");
    }
    return false;
}

stock getSurvivor(exclude[4])
{
    for(new i=1; i <= MaxClients; i++) {
        if (IsSurvivor(i)) {
            new tagged = false;
            // exclude already tagged survs
            for (new j=0; j < 4; j++) {
                if (exclude[j] == i) { tagged = true; }
            }
            if (!tagged) {
                return i;
            }
        }
    }
    return 0;
}

PrintToConsoleAll(const String:format[], any:...)
{
    decl String:buffer[CONBUFSIZELARGE];

    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientAndInGame(i))
        {
            VFormat(buffer, sizeof(buffer), format, 2);
            PrintToConsole(i, buffer);
        }
    }
}

PrintToConsoleClient(client, const String:format[], any:...)
{
    decl String:buffer[CONBUFSIZELARGE];

    if(IsClientAndInGame(client))
    {
        VFormat(buffer, sizeof(buffer), format, 3);
        PrintToConsole(client, buffer);
    }
}


public stripUnicode(String:testString[MAX_NAME_LENGTH])
{
    new const maxlength = MAX_NAME_LENGTH;
    //strcopy(testString, maxlength, sTmpString);
    sTmpString = testString;
    
    new uni=0;
    new currentChar;
    new tmpCharLength = 0;
    //new iReplace[MAX_NAME_LENGTH];      // replace these chars
    
    for (new i=0; i < maxlength - 3 && sTmpString[i] != 0; i++)
    {
        // estimate current character value
        if ((sTmpString[i]&0x80) == 0) // single byte character?
        {
            currentChar=sTmpString[i]; tmpCharLength = 0;
        } else if (((sTmpString[i]&0xE0) == 0xC0) && ((sTmpString[i+1]&0xC0) == 0x80)) // two byte character?
        {
            currentChar=(sTmpString[i++] & 0x1f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i] & 0x3f); 
            tmpCharLength = 1;
        } else if (((sTmpString[i]&0xF0) == 0xE0) && ((sTmpString[i+1]&0xC0) == 0x80) && ((sTmpString[i+2]&0xC0) == 0x80)) // three byte character?
        {
            currentChar=(sTmpString[i++] & 0x0f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i] & 0x3f);
            tmpCharLength = 2;
        } else if (((sTmpString[i]&0xF8) == 0xF0) && ((sTmpString[i+1]&0xC0) == 0x80) && ((sTmpString[i+2]&0xC0) == 0x80) && ((sTmpString[i+3]&0xC0) == 0x80)) // four byte character?
        {
            currentChar=(sTmpString[i++] & 0x07); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i] & 0x3f);
            tmpCharLength = 3;
        } else 
        {
            currentChar=CHARTHRESHOLD + 1; // reaching this may be caused by bug in sourcemod or some kind of bug using by the user - for unicode users I do assume last ...
            tmpCharLength = 0;
        }
        
        // decide if character is allowed
        if (currentChar > CHARTHRESHOLD)
        {
            uni++;
            // replace this character // 95 = _, 32 = space
            for (new j=tmpCharLength; j >= 0; j--) {
                sTmpString[i - j] = 95; 
            }
        }
    }
}

/*
stock bool:IsCommonInfected(iEntity)
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "infected");
    }
    return false;
}
*/