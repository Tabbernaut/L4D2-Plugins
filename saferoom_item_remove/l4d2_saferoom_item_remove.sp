#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_saferoom_detect>


#define SAFEROOM_END    1
#define SAFEROOM_START  2


public Plugin:myinfo = 
{
    name = "Saferoom Item Remover",
    author = "Tabun",
    description = "Removes any saferoom item (start or end).",
    version = "0.0.2",
    url = ""
}


new     Handle:         g_hCvarEnabled                                      = INVALID_HANDLE;
new     Handle:         g_hCvarSaferoom                                     = INVALID_HANDLE;
new     Handle:         g_hTrieItems                                        = INVALID_HANDLE;


enum eTrieItemKillable
{
    ITEM_KILLABLE
}


public OnPluginStart()
{
    g_hCvarEnabled = CreateConVar(      "sm_safeitemkill_enable",       "1",    "Whether end saferoom items should be removed.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hCvarSaferoom = CreateConVar(     "sm_safeitemkill_saferooms",    "1",    "Add flags: 1 = end saferoom, 2 = start saferoom (3 = kill items from both).", FCVAR_PLUGIN, true, 0.0, false);
    
    PrepareTrie();
}

public OnRoundStart()
{
    if (GetConVarBool(g_hCvarEnabled))
    {
        RemoveEndSaferoomItems();
    }
}


RemoveEndSaferoomItems()
{
    // check for any items in the end saferoom, and remove them
    
    new String:classname[128];
    new eTrieItemKillable: checkItem;
    
    new entityCount = GetEntityCount();
    new iCount = 0;
    
    for (new i=1; i < entityCount; i++)
    {
        if (!IsValidEntity(i)) { continue; }
        
        // check item type
        GetEdictClassname(i, classname, sizeof(classname));
        if (GetTrieValue(g_hTrieItems, classname, checkItem))
        {
            if (GetConVarInt(g_hCvarSaferoom) & SAFEROOM_END && SAFEDETECT_IsEntityInEndSaferoom(i))
            {
                // kill the item
                AcceptEntityInput(i, "Kill");
                iCount++;
                continue;
            }
            
            if (GetConVarInt(g_hCvarSaferoom) & SAFEROOM_START && SAFEDETECT_IsEntityInStartSaferoom(i))
            {
                // kill the item
                AcceptEntityInput(i, "Kill");
                iCount++;
                continue;
            }
        }
    }
    
    LogMessage("[safeitemkill] Removed %i saferoom item(s).", iCount);
}


PrepareTrie()
{
    g_hTrieItems = CreateTrie();
    SetTrieValue(g_hTrieItems, "weapon_spawn",                         ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_item_spawn",                    ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_ammo_spawn",                    ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_melee_spawn",                   ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_pistol_spawn",                  ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_pistol_magnum_spawn",           ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_smg_spawn",                     ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_smg_silenced_spawn",            ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_pumpshotgun_spawn",             ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_shotgun_chrome_spawn",          ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_hunting_rifle_spawn",           ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_sniper_military_spawn",         ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_rifle_spawn",                   ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_rifle_ak47_spawn",              ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_rifle_desert_spawn",            ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_autoshotgun_spawn",             ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_shotgun_spas_spawn",            ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_rifle_m60_spawn",               ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_grenade_launcher_spawn",        ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_chainsaw_spawn",                ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_first_aid_kit_spawn",           ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_defibrillator_spawn",           ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_pain_pills_spawn",              ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_adrenaline_spawn",              ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_pipe_bomb_spawn",               ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_molotov_spawn",                 ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_vomitjar_spawn",                ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_gascan_spawn",                  ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "upgrade_spawn",                        ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "upgrade_laser_sight",                  ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_upgradepack_explosive_spawn",   ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "weapon_upgradepack_incendiary_spawn",  ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "upgrade_ammo_incendiary",              ITEM_KILLABLE);
    SetTrieValue(g_hTrieItems, "upgrade_ammo_explosive",               ITEM_KILLABLE);
    //SetTrieValue(g_hTrieItems, "prop_fuel_barrel",                     ITEM_KILLABLE);
    //SetTrieValue(g_hTrieItems, "prop_physics",                         ITEM_KILLABLE);
}