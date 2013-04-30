#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6

#define POUNCE_TIMER            0.1


// CVars
new     bool:           bLateLoad                                               = false;
new     Handle:         hCvarPounceInterrupt                                    = INVALID_HANDLE;

new                     iHunterSkeetDamage[MAXPLAYERS+1];                                               // how much damage done in a single hunter leap so far
new     bool:           bIsPouncing[MAXPLAYERS+1];                                                      // whether hunter player is currently pouncing/lunging


/*
    
    Notes
    -----
        For some reason, m_isLunging cannot be trusted. Some hunters that are obviously lunging have
        it set to 0 and thus stay unskeetable. Have to go with the clunky tracking for now.
        
                abilityEnt = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
                new bool:isLunging = false;
                if (abilityEnt > 0) {
                    isLunging = bool:GetEntProp(abilityEnt, Prop_Send, "m_isLunging");
                }
                
    Changelog
    ---------
        
        1.0.1
            - Fixed incorrect bracketing that caused error spam.
        
        1.0.0
            - Blocked AI scratches-while-stumbling from doing any damage.
            - Replaced clunky charger tracking with simple netprop check.
        
        0.0.5 and older
            - Small fix for chargers getting 1 damage for 0-damage events.
            - simulates human-charger damage behavior while charging for AI chargers.
            - simulates human-hunter skeet behavior for AI hunters.

    -----------------------------------------------------------------------------------------------------------------------------------------------------
 */

public Plugin:myinfo =
{
    name = "Bot SI skeet/level damage fix",
    author = "Tabun",
    description = "Makes AI SI take (and do) damage like human SI.",
    version = "1.0.1",
    url = "nope"
}

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}


public OnPluginStart()
{
    // cvars
    hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
    
    // events
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_shoved", Event_PlayerShoved, EventHookMode_Post);
    HookEvent("ability_use", Event_AbilityUse, EventHookMode_Post);
    
    // hook when loading late
    if (bLateLoad) {
        for (new i = 1; i < MaxClients + 1; i++) {
            if (IsClientAndInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
}


public OnClientPostAdminCheck(client)
{
    // hook bots spawning
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}



public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    if (!IsClientAndInGame(victim) || !IsClientAndInGame(attacker) || damage == 0.0) { return Plugin_Continue; }
    
    // AI taking damage
    if (GetClientTeam(victim) == TEAM_INFECTED && IsFakeClient(victim))
    {
        // check if AI is hit while in lunge/charge
        
        new zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        new abilityEnt = 0;
        
        switch (zombieClass) {
            
            case ZC_HUNTER: {
                // skeeting mechanic is completely disabled for AI,
                // so we have to replicate it.
                
                iHunterSkeetDamage[victim] += RoundToFloor(damage);
                
                // have we skeeted it?
                if (bIsPouncing[victim] && iHunterSkeetDamage[victim] >= GetConVarInt(hCvarPounceInterrupt))
                {
                    bIsPouncing[victim] = false; 
                    iHunterSkeetDamage[victim] = 0;
                    
                    // this should be a skeet
                    damage = float(GetClientHealth(victim));
                    return Plugin_Changed;
                }
            }
            
            case ZC_CHARGER: {
                // all damage gets divided by 3 while AI is charging,
                // so all we have to do is multiply by 3.
                
                abilityEnt = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
                new bool:isCharging = false;
                if (abilityEnt > 0) {
                    isCharging = (GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0) ? true : false;
                }
                
                if (isCharging)
                {
                    damage = (damage * 3) + 1;
                    return Plugin_Changed;
                }
            }
            
        }
    }
    
    // AI doing damage
    if (GetClientTeam(attacker) == TEAM_INFECTED && IsFakeClient(attacker))
    {
        // check if AI is stumbling, set to 0.0
        
        if (GetEntPropFloat(attacker, Prop_Send, "m_staggerDist") > 0.0)
        {
            damage = 0.0;
            return Plugin_Changed;
        }
    }
    
    return Plugin_Continue;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    // clear SI tracking stats
    for (new i=1; i <= MaxClients; i++)
    {
        iHunterSkeetDamage[i] = 0;
        bIsPouncing[i] = false;
    }
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userId"));
    
    if (!IsClientAndInGame(victim)) { return; }
    
    bIsPouncing[victim] = false;
}

public Event_PlayerShoved(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userId"));
    
    if (!IsClientAndInGame(victim)) { return; }
    
    bIsPouncing[victim] = false;
}


// hunters pouncing / tracking
public Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
    // track hunters pouncing
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new String:abilityName[64];
    
    if (!IsClientAndInGame(client) || GetClientTeam(client) != TEAM_INFECTED) { return; }
    
    GetEventString(event, "ability", abilityName, sizeof(abilityName));
    
    if (!bIsPouncing[client] && strcmp(abilityName, "ability_lunge", false) == 0)
    {
        // Hunter pounce
        bIsPouncing[client] = true;
        iHunterSkeetDamage[client] = 0;                                     // use this to track skeet-damage
        
        CreateTimer(POUNCE_TIMER, Timer_GroundTouch, client, TIMER_REPEAT); // check every TIMER whether the pounce has ended
                                                                            // If the hunter lands on another player's head, they're technically grounded.
                                                                            // Instead of using isGrounded, this uses the bIsPouncing[] array with less precise timer
    }
}

public Action: Timer_GroundTouch(Handle:timer, any:client)
{
    if (IsClientAndInGame(client) && (IsGrounded(client)) || !IsPlayerAlive(client))
    {
        // Reached the ground or died in mid-air
        bIsPouncing[client] = false;
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public bool:IsGrounded(client)
{
    return (GetEntProp(client,Prop_Data,"m_fFlags") & FL_ONGROUND) > 0;
}

bool:IsClientAndInGame(index)
{
    if (index > 0 && index < MaxClients)
    {
        return IsClientInGame(index);
    }
    return false;
}





