#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions> 
#include <sdkhooks>
#include <timers.inc>


#define DEBUG_MODE              0

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define SEQ_FLIGHT_COACH        629
#define SEQ_FLIGHT_ELLIS        634
#define SEQ_FLIGHT_ROCHELLE     637
#define SEQ_FLIGHT_BILL         537
#define SEQ_FLIGHT_FRANCIS      540
#define SEQ_FLIGHT_ZOEY         546

#define TIMER_CHECKPUNCH        0.025   // interval for checking 'flight' of punched survivors
#define TIME_CHECK_UNTIL        0.5     // try this long to find a stuck-position, then assume it's OK
#define TIME_UNTIL_MOVERESET    0.25    // how long to wait before unsetting 'noclip'
#define TELEFIX_DOWN_DISTANCE   20.0    // how far to teleport player down to get them out of ceiling


enum eTankWeapon
{
    TANKWEAPON
}

new     bool:       g_bLateLoad                                 = false;
new     Handle:     g_hInflictorTrie                            = INVALID_HANDLE;       // names to look up

new     Float:      g_fPlayerPunch          [MAXPLAYERS + 1];                           // when was the last tank punch on this player?
new     bool:       g_bPlayerFlight         [MAXPLAYERS + 1];                           // is a player in (potentially stuckable) punched flight?
new     Float:      g_fPlayerStuck          [MAXPLAYERS + 1];                           // when did the (potential) 'stuckness' occur?
new     Float:      g_fPlayerLocation       [MAXPLAYERS + 1][3];                        // where was the survivor last during the flight?

new     Handle:     g_hCvarPluginEnabled                        = INVALID_HANDLE;       // convar: enable fix
new     Handle:     g_hCvarDeStuckTime                          = INVALID_HANDLE;       // convar: how long to wait and de-stuckify a punched player



/*
    -----------------------------------------------------------------------------------------------------------------------------------------------------


    Here's the idea:
        - When a tank punches a survivors stuck in a ceiling, the survivor also gets
            stuck in a 'flying' state, lets in the air and all.
        - After a tank punch that lands on a survivor (ie. does damage?),
            do a check on the m_nSequence of the survivor
            - if it does not reach 634 within [0.5 or so] seconds, it wasn't a problematic punch
            - if it does, keep checking it
                if it doesn't change for [2 or so] seconds AND the survivor's location doesn't change,
                it's a stuckpunch - teleport survivor a bit lower and see what happens...


    Changelog
    ---------
        0.2.1
            -   Working fix (as tested by epilimic). Cleaned up code.
        
        0.1.1
            -   First version that attempts a detect + fix combo.
                Does a sequence, time and location-based stuckness detection and teleports player downwards
                for an attempt at a fix.


    -----------------------------------------------------------------------------------------------------------------------------------------------------
 */


public Plugin:myinfo = 
{
    name =          "Tank Punch Ceiling Stuck Fix",
    author =        "Tabun",
    description =   "Fixes the problem where tank-punches get a survivor stuck in the roof.",
    version =       "0.2.1",
    url =           "nope"
}

/* -------------------------------
 *      Init
 * ------------------------------- */

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart()
{
    // hook already existing clients if loading late
    if (g_bLateLoad) {
        for (new i = 1; i < MaxClients+1; i++) {
            if (IsClientInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
    
    // cvars
    g_hCvarPluginEnabled = CreateConVar(    "sm_punchstuckfix_enabled",         "1",        "Enable the fix.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hCvarDeStuckTime = CreateConVar(      "sm_punchstuckfix_unstucktime",     "1.0",      "How many seconds to wait before detecting and unstucking a punched motionless player.", FCVAR_PLUGIN, true, 0.05, false);
    
    // hooks
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    
    // trie
    g_hInflictorTrie = BuildInflictorTrie();
}



/* --------------------------------------
 *      General hooks / events
 * -------------------------------------- */

public OnClientPostAdminCheck(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnMapStart()
{
    setCleanSlate();
}

public Action: RoundStart_Event (Handle:event, const String:name[], bool:dontBroadcast)
{
    setCleanSlate();
}


/* --------------------------------------
 *     GOT MY EYES ON YOU, PUNCH
 * -------------------------------------- */

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
    if (!GetConVarBool(g_hCvarPluginEnabled)) { return Plugin_Continue; }
    if (!inflictor || !attacker || !IsSurvivor(victim) || !IsValidEdict(inflictor)) { return Plugin_Continue; }
    
    // only check player-to-player damage
    decl String:classname[64];
    if (IsClientAndInGame(attacker) && IsClientAndInGame(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
    {
        if (attacker == inflictor)                                              // for claws
        {
            GetClientWeapon(inflictor, classname, sizeof(classname));
        }
        else
        {
            GetEdictClassname(inflictor, classname, sizeof(classname));         // for tank punch/rock
        }
    }
    else { return Plugin_Continue; }
    
    // only check tank punch (also rules out anything but infected-to-survivor damage)
    new eTankWeapon: inflictorID;
    if (!GetTrieValue(g_hInflictorTrie, classname, inflictorID)) { return Plugin_Continue; }
    
    // tank punched survivor, check the result
    g_fPlayerPunch[victim] = GetTickedTime();
    g_bPlayerFlight[victim] = false;
    g_fPlayerStuck[victim] = 0.0;
    g_fPlayerLocation[victim][0] = 0.0;
    g_fPlayerLocation[victim][1] = 0.0;
    g_fPlayerLocation[victim][2] = 0.0;
    
    CreateTimer(TIMER_CHECKPUNCH, Timer_CheckPunch, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Continue;
}

public Action: Timer_CheckPunch(Handle:hTimer, any:client)
{
    // stop the timer when we no longer have a proper client
    if (!IsSurvivor(client)) { return Plugin_Stop; }
    
    // stop the time if we're passed the time for checking
    if (GetTickedTime() - g_fPlayerPunch[client] > TIME_CHECK_UNTIL && g_fPlayerStuck[client])
    {
        g_fPlayerPunch[client] = 0.0;
        g_bPlayerFlight[client] = false;
        g_fPlayerStuck[client] = 0.0;
        
        return Plugin_Stop;
    }
    
    // get current animation frame and location of survivor
    new iSeq = GetEntProp(client, Prop_Send, "m_nSequence");
    
    
    // if the player is not in flight, check if they are
    if (iSeq == SEQ_FLIGHT_COACH ||  iSeq == SEQ_FLIGHT_ELLIS ||  iSeq == SEQ_FLIGHT_ROCHELLE ||  iSeq == SEQ_FLIGHT_BILL ||  iSeq == SEQ_FLIGHT_FRANCIS ||  iSeq == SEQ_FLIGHT_ZOEY)
    {
        
        new Float: vOrigin[3];
        GetEntPropVector(client, Prop_Send, "m_vecOrigin", vOrigin);
        
        if (!g_bPlayerFlight[client])
        {
            // if the player is not detected as in punch-flight, they are now
            g_bPlayerFlight[client] = true;
            g_fPlayerLocation[client] = vOrigin;
            
            PrintDebug("[test] %i - flight start [seq:%4i][loc:%.f %.f %.f]", client, iSeq, vOrigin[0], vOrigin[1], vOrigin[2]);
        }
        else
        {
            // if the player is in punch-flight, check location / difference to detect stuckness
            if (GetVectorDistance(g_fPlayerLocation[client], vOrigin) == 0.0) {
                
                // are we /still/ in the same position? (ie. if stucktime is recorded)
                if (g_fPlayerStuck[client])
                {
                    g_fPlayerStuck[client] = GetTickedTime();
                    
                    PrintDebug("[test] %i - stuck start [loc:%.f %.f %.f]", client, vOrigin[0], vOrigin[1], vOrigin[2]);
                }
                else
                {
                    if (GetTickedTime() - g_fPlayerStuck[client] > GetConVarFloat(g_hCvarDeStuckTime))
                    {
                        // time passed, player is stuck! fix.
                        PrintDebug("[test] %i - stuckness FIX triggered!", client);
                        
                        g_fPlayerPunch[client] = 0.0;
                        g_bPlayerFlight[client] = false;
                        g_fPlayerStuck[client] = 0.0;
                        
                        SetEntityMoveType(client, MOVETYPE_NOCLIP);
                        CreateTimer(TIME_UNTIL_MOVERESET, Timer_UnStuckCommand, client, TIMER_FLAG_NO_MAPCHANGE);
                        vOrigin[2] -= TELEFIX_DOWN_DISTANCE;
                        TeleportEntity(client, vOrigin, NULL_VECTOR, NULL_VECTOR);
                        
                        return Plugin_Stop;
                    }
                }
            }
            else
            {
                // if we were detected as stuck, undetect
                if (g_fPlayerStuck[client])
                {
                    g_fPlayerStuck[client] = 0.0;
                    
                    PrintDebug("[test] %i - stuck end (previously detected, now gone) [loc:%.f %.f %.f]", client, vOrigin[0], vOrigin[1], vOrigin[2]);
                }
            }
        }
    }
    else if (iSeq == SEQ_FLIGHT_COACH+1 ||  iSeq == SEQ_FLIGHT_ELLIS+1 ||  iSeq == SEQ_FLIGHT_ROCHELLE+1 ||  iSeq == SEQ_FLIGHT_BILL+1 ||  iSeq == SEQ_FLIGHT_FRANCIS+1 ||  iSeq == SEQ_FLIGHT_ZOEY+1)
    {
        if (g_bPlayerFlight[client])
        {
            // landing frame, so not stuck
            g_fPlayerPunch[client] = 0.0;
            g_bPlayerFlight[client] = false;
            g_fPlayerStuck[client] = 0.0;
            
            PrintDebug("[test] %i - flight end (natural)", client);
        }
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}


public Action: Timer_UnStuckCommand(Handle:hTimer, any:client)
{
    SetEntityMoveType(client, MOVETYPE_WALK);
}


/* --------------------------------------
 *     Shared function(s)
 * -------------------------------------- */

stock bool:IsClientAndInGame(index) return (index > 0 && index <= MaxClients && IsClientInGame(index));
stock bool:IsSurvivor(client)
{
    if (IsClientAndInGame(client)) {
        return GetClientTeam(client) == TEAM_SURVIVOR;
    }
    return false;
}


stock setCleanSlate()
{
    new i, maxplayers = MaxClients;
    for (i = 1; i <= maxplayers; i++)
    {
        g_fPlayerPunch[i] = 0.0;
        g_bPlayerFlight[i] = false;
        g_fPlayerStuck[i] = 0.0;
        g_fPlayerLocation[i][0] = 0.0;
        g_fPlayerLocation[i][1] = 0.0;
        g_fPlayerLocation[i][2] = 0.0;
    }
}

public PrintDebug(const String:Message[], any:...)
{
    #if DEBUG_MODE
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        //LogMessage(DebugBuff);
        //PrintToServer(DebugBuff);
        PrintToChatAll(DebugBuff);
    #endif
}

stock Handle: BuildInflictorTrie()
{
    new Handle: trie = CreateTrie();
    SetTrieValue(trie, "weapon_tank_claw",      TANKWEAPON);
    /*
    SetTrieValue(trie, "tank_rock",             TANKWEAPON);
    */
    return trie;    
}