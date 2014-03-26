#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

#define DEBUG_MODE              0

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define TIMER_CHECKPUNCH        0.025   // interval for checking 'flight' of punched survivors
#define TELEFIX_DOWN_DISTANCE   20.0    // how far to teleport player down to get them out of ceiling
#define ROOF_DISTANCE   65.0             // dist between client and roof

#define PUNCH_WAIT  0
#define PUNCH_CHECK 1
#define PUNCH_STOP  2

new     bool:       g_bLateLoad                                 = false;
new     bool:       g_bPlayerFlight         [MAXPLAYERS + 1];                           // is a player in (potentially stuckable) punched flight?
new     Float:      g_fPlayerStuck          [MAXPLAYERS + 1];                           // when did the (potential) 'stuckness' occur?
new     Float:      g_fPlayerLocation       [MAXPLAYERS + 1][3];                        // where was the survivor last during the flight?

new     Handle:     g_hCvarPluginEnabled                        = INVALID_HANDLE;       // convar: enable fix
new     Handle:     g_hCvarDeStuckTime                          = INVALID_HANDLE;       // convar: how long to wait and de-stuckify a punched player
new     Float:      g_fCvarDeStuckTime;
new     bool:       g_bCvarPluginEnabled;
new     bool:       g_bSet, g_bTempBlock[MAXPLAYERS+1], bool:g_bIsTankInGame;

new const g_iSeqFlight[][] =
{
    { 537, 629 }, // Bill, Nick
    { 546, 637 }, // Zoey, Rochelle
    { 537, 629 }, // Louis, Coach
    { 540, 634 }  // Francis, Ellis
};

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
    name =          "[L4D] Tank Punch Ceiling Stuck Fix",
    author =        "Tabun, raziEiL [disawar1]",
    description =   "Fixes the problem where tank-punches get a survivor stuck in the roof.",
    version =       "0.3",
    url =           "nope"
}

/* -------------------------------
 *      Init
 * ------------------------------- */

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart()
{
    // cvars
    g_hCvarPluginEnabled = CreateConVar(    "sm_punchstuckfix_enabled",         "1",        "Enable the fix.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hCvarDeStuckTime = CreateConVar(      "sm_punchstuckfix_unstucktime",     "0.5",      "How many seconds to wait before detecting and unstucking a punched motionless player.", FCVAR_PLUGIN, true, 0.05, false);

    // hooks
    HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);

    HookConVarChange(g_hCvarPluginEnabled, OnCvarChange_PluginEnablede);
    HookConVarChange(g_hCvarDeStuckTime, OnCvarChange_DeStuckTime);
    g_bCvarPluginEnabled = GetConVarBool(g_hCvarPluginEnabled);
    g_fCvarDeStuckTime = GetConVarFloat(g_hCvarDeStuckTime);
    
    // hook already existing clients if loading late
    if (g_bCvarPluginEnabled && g_bLateLoad) {
        for (new i = 1; i <= MaxClients; i++) {
            if (IsTank(i)) {
               L4D2_OnTankFirstSpawn(0);
               break;
            }
        }
    }
}

/* --------------------------------------
 *      General hooks / events
 * -------------------------------------- */

public OnClientPutInServer(client)
{
    if (IsPluginEnabled() && client){

        g_bTempBlock[client] = false;
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public OnMapEnd()
{
    g_bIsTankInGame = false;
}

public EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!IsPluginEnabled()) return;

    g_bIsTankInGame = false;
    ToggleHook(false);
}

public L4D2_OnTankFirstSpawn(tankClient)
{
    if (!g_bCvarPluginEnabled || g_bIsTankInGame) return;

    g_bSet = IsL4D2SurvivorsSet();
    PrintDebug("[test] l4d%s survivors set", g_bSet ? "2" : "1");

    g_bIsTankInGame = true;
    ToggleHook(true);
}

public L4D2_OnTankDeath(tankClient)
{
    if (!IsPluginEnabled()) return;

    g_bIsTankInGame = false;
    ToggleHook(false);
}

/* --------------------------------------
 *     GOT MY EYES ON YOU, PUNCH
 * -------------------------------------- */

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
    // only check player-to-player damage
    if (!IsPluginEnabled() || g_bTempBlock[victim] || !inflictor || !IsValidEntity(inflictor) ||
        !IsClientAndInGame(victim) || !IsClientAndInGame(attacker)) { return Plugin_Continue; }

    decl String:classname[64];
    if (attacker == inflictor)                                              // for claws
    {
        GetClientWeapon(inflictor, classname, sizeof(classname));
    }
    else
    {
        GetEntityClassname(inflictor, classname, sizeof(classname));         // for tank punch/rock
    }

    // only check tank punch (also rules out anything but infected-to-survivor damage)
    if (!StrEqual("weapon_tank_claw", classname)) { return Plugin_Continue; }

    // tank punched survivor, check the result

    ResetVars(victim);

    g_bTempBlock[victim] = true;
    CreateTimer(TIMER_CHECKPUNCH, Timer_CheckPunch, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

public Action:Timer_CheckPunch(Handle:hTimer, any:client)
{
    // stop the timer when we no longer have a proper client
    if (!IsSurvivor(client)){

        g_bTempBlock[client] = false;
        return Plugin_Stop;
    }

    new iCharIndex = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    if (iCharIndex < 0 || iCharIndex > 3)
        return Plugin_Stop;

    new iSeq = GetEntProp(client, Prop_Send, "m_nSequence"), iFixStage = PUNCH_WAIT;

    if (iSeq == g_iSeqFlight[iCharIndex][g_bSet])
        iFixStage = PUNCH_CHECK;
    else if (iSeq > g_iSeqFlight[iCharIndex][g_bSet])
        iFixStage = PUNCH_STOP;

    // if the player is not in flight, check if they are
    if (iFixStage == PUNCH_CHECK)
    {
        decl Float: vOrigin[3];
        GetClientAbsOrigin(client, vOrigin);

        if (!g_bPlayerFlight[client])
        {
            // if the player is not detected as in punch-flight, they are now
            g_bPlayerFlight[client] = true;
            g_fPlayerLocation[client] = vOrigin;

            PrintDebug("[test] %N - flight start [seq:%4i][loc:%.f %.f %.f]", client, iSeq, vOrigin[0], vOrigin[1], vOrigin[2]);
        }
        else
        {
            // if the player is in punch-flight, check location / difference to detect stuckness
            if (!GetVectorDistance(g_fPlayerLocation[client], vOrigin)) {

                // are we /still/ in the same position? (ie. if stucktime is recorded)
                if (!g_fPlayerStuck[client])
                {
                    g_fPlayerStuck[client] = GetTickedTime();

                    PrintDebug("[test] %N - stuck start [loc:%.f %.f %.f]", client, vOrigin[0], vOrigin[1], vOrigin[2]);
                }
                else
                {
                    PrintDebug("[test] tickettime %.2f, stucktime %.2f, maxstucktime %.2f", GetTickedTime(), GetTickedTime() - g_fPlayerStuck[client], g_fCvarDeStuckTime);
                    if (GetTickedTime() - g_fPlayerStuck[client] >= g_fCvarDeStuckTime)
                    {
                        // time passed, player is stuck! fix.

                        if (IsStuckInRoof(vOrigin)){

                            new Float:fFloor = GetFloorDist(vOrigin);
                            new Float:fTeleDownDist = (TELEFIX_DOWN_DISTANCE > fFloor ? TELEFIX_DOWN_DISTANCE - fFloor : TELEFIX_DOWN_DISTANCE);
                            vOrigin[2] -= fTeleDownDist;
                            TeleportEntity(client, vOrigin, NULL_VECTOR, NULL_VECTOR);
                            PrintDebug("[test] %N - stuckness FIX triggered! Tel down %.1f", client, fTeleDownDist);
                            PrintDebug("[test] %N - stuckness FIX triggered!", client);
                        }
                        else
                            PrintDebug("[test] %N - stuckness triggered but false detected!", client);

                        ResetVars(client);
                        g_bTempBlock[client] = false;

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

                    PrintDebug("[test] %N - stuck end (previously detected, now gone) [loc:%.f %.f %.f]", client, vOrigin[0], vOrigin[1], vOrigin[2]);
                }
            }
        }
    }
    else if (iFixStage == PUNCH_STOP)
    {
        PrintDebug("[test] %N - flight end (natural)", client);
        g_bTempBlock[client] = false;
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

bool:IsStuckInRoof(const Float:pos[3])
{
    new Handle:trace = TR_TraceRayFilterEx(pos, Float:{ 270.0, 0.0, 0.0 }, CONTENTS_SOLID, RayType_Infinite, TraceEntityFilter);

    if (TR_DidHit(trace)){

        if (TR_GetEntityIndex(trace) > 0){

            CloseHandle(trace);
            return false;
        }

        decl Float:posEnd[3];
        TR_GetEndPosition(posEnd, trace);

        new Float:fDist = GetVectorDistance(pos, posEnd);

        PrintDebug("Roof dist %.1f, endpos %.1f %.1f %.1f", fDist, posEnd[0], posEnd[1], posEnd[2]);

        return fDist < ROOF_DISTANCE;
    }

    CloseHandle(trace);
    return false;
}

Float:GetFloorDist(const Float:pos[3])
{
    new Handle:trace = TR_TraceRayFilterEx(pos, Float:{ 90.0, 0.0, 0.0 }, CONTENTS_SOLID, RayType_Infinite, TraceEntityFilter);

    if (TR_DidHit(trace)){

        if (TR_GetEntityIndex(trace) > 0){

            CloseHandle(trace);
            return 0.0;
        }

        decl Float:posEnd[3];
        TR_GetEndPosition(posEnd, trace);

        return GetVectorDistance(pos, posEnd);
    }

    CloseHandle(trace);
    return 0.0;
}

public bool:TraceEntityFilter(entity, contentsMask)
{
    return entity == 0;
}

/* --------------------------------------
 *     Shared function(s)
 * -------------------------------------- */

bool:IsClientAndInGame(index) return (index > 0 && index <= MaxClients && IsClientInGame(index));

bool:IsPluginEnabled()
{
    return g_bCvarPluginEnabled && g_bIsTankInGame;
}

bool:IsL4D2SurvivorsSet()
{
    decl SurvivorCharacter:iCharIndex;

    for (new i = 1; i <= MaxClients; i++){

        if ((iCharIndex = IdentifySurvivor(i)) != SC_NONE){

            if (iCharIndex <= SC_ELLIS)
                return true;
            break;
        }
    }
    return false;
}

ResetVars(i)
{
    g_bPlayerFlight[i] = false;
    g_fPlayerStuck[i] = 0.0;
    g_fPlayerLocation[i][0] = 0.0;
    g_fPlayerLocation[i][1] = 0.0;
    g_fPlayerLocation[i][2] = 0.0;
}

ToggleHook(bool:bHook)
{
    PrintDebug("[test] hook = %d", bHook);

    for (new i = 1; i <= MaxClients; i++){

        if (!IsClientInGame(i)) continue;

        if (bHook)
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        else
            SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public OnCvarChange_PluginEnablede(Handle:hndl, const String:oldValue[], const String:newValue[])
{
    if (!StrEqual(oldValue, newValue))
        g_bCvarPluginEnabled = GetConVarBool(hndl);
}

public OnCvarChange_DeStuckTime(Handle:hndl, const String:oldValue[], const String:newValue[])
{
    if (!StrEqual(oldValue, newValue))
        g_fCvarDeStuckTime = GetConVarFloat(hndl);
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