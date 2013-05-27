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

#define SKEET_POUNCING_AI        (0x01)
#define DEBUFF_CHARGING_AI        (0x02)
#define BLOCK_STUMBLE_SCRATCH    (0x04)
#define ALL_FEATURES            (SKEET_POUNCING_AI | DEBUFF_CHARGING_AI | BLOCK_STUMBLE_SCRATCH)

// CVars
new     bool:           bLateLoad                                               = false;

new        Handle:            hCvarEnabled                                            = INVALID_HANDLE;
new                        fEnabled                                                = ALL_FEATURES;            // enables individual features of the plugin
new     Handle:         hCvarPounceInterrupt                                    = INVALID_HANDLE;
new                        iPounceInterrupt                                        = 150;                    // caches pounce interrupt cvar's value

new                     iHunterSkeetDamage[MAXPLAYERS+1]                         = { 0, ... };           // how much damage done in a single hunter leap so far
new     bool:           bIsPouncing[MAXPLAYERS+1]                                 = { false, ... };       // whether hunter player is currently pouncing/lunging


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
        
        1.0.5
            - (dcx2) Added enable cvar
            - (dcx2) Cached pounce interrupt cvar
            - (dcx2) fixed charger debuff calculation (for 1pt error)
            
        1.0.4 
            - Used dcx2's much better IN_ATTACK2 method of blocking stumble-scratching.
            
        1.0.3
            - Added stumble-negation inflictor check so only SI scratches are affected.
        
        1.0.2
            - Fixed incorrect bracketing that caused error spam. (Re-fixed because drunk)
        
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
    author = "Tabun, dcx2",
    description = "Makes AI SI take (and do) damage like human SI.",
    version = "1.0.5",
    url = "https://github.com/Tabbernaut/L4D2-Plugins/tree/master/ai_damagefix"
}

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}


public OnPluginStart()
{
    // cvars
       hCvarEnabled = CreateConVar("l4d2_aidmgfix_enable",         "7",     "Bit flag: Enables plugin features (add together): 1=Skeet pouncing AI, 2=Debuff charging AI, 4=Block stumble scratches, 7=all, 0=off", FCVAR_PLUGIN|FCVAR_NOTIFY);
    hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");

    HookConVarChange(hCvarEnabled, OnAIDamageFixEnableChanged);
    HookConVarChange(hCvarPounceInterrupt, OnPounceInterruptChanged);

    fEnabled = GetConVarInt(hCvarEnabled);
    iPounceInterrupt =  GetConVarInt(hCvarPounceInterrupt);

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


public OnAIDamageFixEnableChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
    fEnabled = StringToInt(newVal);
}

public OnPounceInterruptChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
    iPounceInterrupt = StringToInt(newVal);
}


public OnClientPostAdminCheck(client)
{
    // hook bots spawning
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    if (!fEnabled || !IsClientAndInGame(victim) || !IsClientAndInGame(attacker) || damage == 0.0) { return Plugin_Continue; }
    
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
                
                if (!(fEnabled & SKEET_POUNCING_AI)) { return Plugin_Continue; }
                
                iHunterSkeetDamage[victim] += RoundToFloor(damage);
                
                // have we skeeted it?
                if (bIsPouncing[victim] && iHunterSkeetDamage[victim] >= iPounceInterrupt)
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
                
                if (!(fEnabled & DEBUFF_CHARGING_AI)) { return Plugin_Continue; }
                
                abilityEnt = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
                new bool:isCharging = false;
                if (abilityEnt > 0) {
                    isCharging = (GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0) ? true : false;
                }
                
                if (isCharging)
                {
                    damage = (damage - FloatFraction(damage) + 1.0) * 3.0;            // Engine does Floor(damage) / 3 - 1
                    return Plugin_Changed;
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client, &buttons)
{
    // If the AI Infected is staggering, block melee so they can't scratch
    if ((fEnabled & BLOCK_STUMBLE_SCRATCH) && IsClientAndInGame(client) && GetClientTeam(client) == TEAM_INFECTED && IsFakeClient(client) && GetEntPropFloat(client, Prop_Send, "m_staggerDist") > 0.0)
    {
        buttons &= ~IN_ATTACK2;
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
    if (IsClientAndInGame(client) && (IsGrounded(client) || !IsPlayerAlive(client)))
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


