#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_VALID_NON_CLIENT(%1) (%1 > MaxClients && IsValidEdict(%1) && IsValidEntity(%1))

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

#define FRIENDLY_FIRE           0.4
#define COMMON_DAMAGE_FACTOR    2
#define SI_DAMAGE_FACTOR        1.5
//#define TANK_HEALTH_FACTOR      1.25

new Handle: g_hCvarEnabled;
new Handle: g_hCvarFriendlyFire;
new Handle: g_hCvarSurvivorGlows;

new bool:   g_bIsEnabled = false;
new bool:   g_bLateLoad;
new Float:  g_fOriginalFriendlyFire;
new bool:   g_bOriginalSurvivorGlows;

public Plugin: myinfo =
{
    name = "Coop Difficulty Bumper",
    author = "Tabun",
    description = "Make things a bit more difficult in coop",
    version = "0.0.1",
    url = "https://github.com/Tabbernaut/L4D2-Plugins"
};

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart()
{
    g_hCvarEnabled = CreateConVar("difficulty_bump_enabled", "1", "Whether the difficulty bump is enabled", FCVAR_NONE, true, 0.0);

    g_hCvarSurvivorGlows = FindConVar("sv_disable_glow_survivors");
    g_hCvarFriendlyFire  = FindConVar("survivor_friendly_fire_factor_expert");

    HookConVarChange(g_hCvarEnabled, ConVarChange_Enabled);

    if (! g_bLateLoad) {
        return;
    }

    for (new i = 1; i <= MaxClients; i++) {
        if (IS_VALID_INGAME(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public OnPluginEnd()
{
    ResetEverything();
}

public OnMapStart()
{
    if (GetConVarBool(g_hCvarEnabled)) {
        MakeItHarder();
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public ConVarChange_Enabled(Handle:cvar, const String:oldValue[], const String:newValue[])
{
    if (StringToInt(newValue) == 1) {
        MakeItHarder();
    } else {
        ResetEverything();
    }
}

MakeItHarder()
{
    if (g_bIsEnabled) {
        return;
    }

    PrintToServer("[difbump] Made it a bit harder");

    g_bIsEnabled = true;

    g_bOriginalSurvivorGlows = GetConVarBool(g_hCvarSurvivorGlows);
    SetConVarBool(g_hCvarSurvivorGlows, true);

    g_fOriginalFriendlyFire = GetConVarFloat(g_hCvarFriendlyFire);
    SetConVarFloat(g_hCvarFriendlyFire, FRIENDLY_FIRE);
}

ResetEverything()
{
    if (! g_bIsEnabled) {
        return;
    }

    PrintToServer("[difbump] Made it a bit easier again (reset)");

    g_bIsEnabled = false;

    SetConVarBool(g_hCvarSurvivorGlows, g_bOriginalSurvivorGlows);
    SetConVarFloat(g_hCvarFriendlyFire, g_fOriginalFriendlyFire);
}


public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
    if (
        ! g_bIsEnabled
        || ! IS_SURVIVOR_ALIVE(victim)
        || inflictor <= 0
        || ! IsValidEdict(inflictor)
    ) {
        return Plugin_Continue;
    }

    if (IsValidCommon(inflictor)) {
        damage = COMMON_DAMAGE_FACTOR * damage;
        return Plugin_Changed;
    }

    if (IsValidSI(inflictor)) {
        damage = SI_DAMAGE_FACTOR * damage;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

bool: IsValidCommon(client)
{
    if (! IS_VALID_NON_CLIENT(client)) {
        return false;
    }

    decl String:sClassname[32];
    GetEdictClassname(client, sClassname, sizeof(sClassname));

    return StrEqual(sClassname, "infected");
}

bool: IsValidSI(client)
{
    if (! IS_VALID_NON_CLIENT(client)) {
        return false;
    }

    new iClass = GetEntProp(client, Prop_Send, "m_zombieClass");

    return iClass >= ZC_SMOKER && iClass < ZC_WITCH;
}
