/**
 *  L4D2 Godframe Color
 * 
 *  Simple plugin that makes survivors appear red while they are
 *  godframed (vanilla timings).
 *  Note: don't use in combination with GFC (use its in-built glows
 *        instead).
 */

#pragma semicolon 1

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

#define GODTIME_SMOKER      2.0
#define GODTIME_HUNTER      2.0
#define GODTIME_JOCKEY      2.0
#define GODTIME_CHARGER     2.0

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new     Float:  g_fGodFramesEnd[MAXPLAYERS+1];

public Plugin:myinfo =
{
    name = "L4D2 Godframes Color (Default timings)",
    author = "Tabun",
    version = "0.1.2",
    description = "Simple coloring of godframed survivors."
};

public OnPluginStart ()
{
    HookEvent("tongue_grab",        Event_PostSurvivorGrabSmoker);
    HookEvent("tongue_release",     Event_PostSurvivorReleaseSmoker);
    HookEvent("pounce_end",         Event_PostSurvivorReleaseHunter);
    HookEvent("jockey_ride_end",    Event_PostSurvivorReleaseJockey);
    HookEvent("charger_pummel_end", Event_PostSurvivorReleaseCharger);
}

public OnMapStart()
{
    for ( new i = 1; i <= MaxClients; i++ )
    {
        g_fGodFramesEnd[i] = 0.0;
        
        if ( IS_VALID_SURVIVOR(i) )
        {
            ResetGlow(i);
        }
    }
}

public Event_PostSurvivorGrabSmoker ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(event,"victim") );
    UpdateSurvivorGodFrames( victim, GODTIME_SMOKER );
}

public Event_PostSurvivorReleaseSmoker ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(event,"victim") );
    UpdateSurvivorGodFrames( victim, GODTIME_SMOKER );
}

public Event_PostSurvivorReleaseHunter ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(event,"victim") );
    UpdateSurvivorGodFrames( victim, GODTIME_HUNTER );
}

public Event_PostSurvivorReleaseJockey ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(event,"victim") );
    UpdateSurvivorGodFrames( victim, GODTIME_JOCKEY );
}

public Event_PostSurvivorReleaseCharger ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(event,"victim") );
    UpdateSurvivorGodFrames( victim, GODTIME_CHARGER );
}

stock UpdateSurvivorGodFrames ( client, Float: fGodTime )
{
    if ( !IS_VALID_CLIENT(client) ) { return; }
    
    g_fGodFramesEnd[client] = GetGameTime() + fGodTime - 0.1;   // safeguard margin 0.1
    
    SetGodframedGlow(client);
    CreateTimer( fGodTime, Timer_ResetGlow, client );
}

public Action:Timer_ResetGlow ( Handle:timer, any:client )
{
    ResetGlow(client);
}

stock ResetGlow ( client )
{
    if ( !IS_VALID_SURVIVOR(client) && ( !IS_VALID_INFECTED(client) || !IsPlayerAlive(client) ) ) { return; }
    
    // only reset glow if not extended
    if ( g_fGodFramesEnd[client] == 0.0 || GetGameTime() - g_fGodFramesEnd[client] > 0 )
    {
        // remove transparency
        SetEntityRenderMode( client, RenderMode:0 );
        SetEntityRenderColor( client, 255,255,255,255 );
    }
    else
    {
        // re-check after a second, to avoid eternal glows
        CreateTimer( 1.0, Timer_ResetGlow, client );
    }
}

stock SetGodframedGlow ( client )
{
    if ( !IS_SURVIVOR_ALIVE(client) ) { return; }
    
    // make player transparent while godframed
    SetEntityRenderMode( client, RenderMode:3 );
    SetEntityRenderColor( client, 255,0,0,200 );
}
