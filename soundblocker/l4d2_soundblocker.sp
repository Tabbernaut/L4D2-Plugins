#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))

new const String: g_csBlockSounds[][] = {
    "seearmored",
    "seeclowns",
    "seehazmat",
    "seemudmen"
};

public Plugin: myinfo =
{
    name = "Soundblocker",
    author = "Tabun",
    description = "Block some annoying sounds we don't need",
    version = "0.0.1",
    url = "https://github.com/Tabbernaut/L4D2-Plugins"
};



public OnPluginStart()
{
    AddNormalSoundHook(Event_SoundPlayed);
}

public Action: Event_SoundPlayed(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    if (! IS_SURVIVOR_ALIVE(entity)) {
        return Plugin_Continue;
    }

    for (new i=0; i < sizeof(g_csBlockSounds); i++) {
        if (StrContains(sample, g_csBlockSounds[i], false) != -1) {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}