#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define MAX_VARLENGTH           64
#define MAX_VALUELENGTH         128
#define MAX_SETVARS             64

#define DEBUG                   false


/*

    Simply reads and applies a bunch of cvar settings
    so it can be done dependent on this plugin being
    loaded, instead of cluttering up server.cfg
    
 */

new const String: g_sKeyValues[]        = "../../cfg/server_vanilla_cvars.txt";
//new const String: g_sCvarKeyNormal[]    = "normal_cvar";
new const String: g_sCvarKeySM[]        = "sm_cvar";


new     Handle:         g_hKvOrig                                           = INVALID_HANDLE;       // kv to store original values in
new     bool:           g_bFirstMapStartDone                                = false;                // so we can store the defaults at the right time


public Plugin:myinfo = {
    name        = "L4D(2) default vanilla server cvars loader.",
    author      = "Tabun",
    version     = "0.0.3",
    description = "Loads cvars for vanilla, so they don't have to be in server.cfg."
};


public OnPluginStart()
{
    // prepare KV for saving old states
    g_hKvOrig = CreateKeyValues("VanillaCvars_Orig");     // store original values
}

public OnPluginEnd()
{
    ResetServerPrefs();
    if (g_hKvOrig != INVALID_HANDLE) { CloseHandle(g_hKvOrig); }
}

public OnMapStart()
{
    if (!g_bFirstMapStartDone)
    {
        g_bFirstMapStartDone = true;
        GetThisServerPrefs();
    }
}


public GetThisServerPrefs()
{
    new iNumChanged = 0;                                // how many cvars were changed for this map
    
    // reopen original keyvalues for clean slate:
    if (g_hKvOrig != INVALID_HANDLE) { CloseHandle(g_hKvOrig); }
    g_hKvOrig = CreateKeyValues("VanillaCvars_Orig");       // store original values for this map
    
    
    // build path to keyvalues file
    new String:usePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, usePath, sizeof(usePath), g_sKeyValues);
    
    if (!FileExists(usePath)) {
        #if DEBUG
        PrintToServer("[vcv] file does not exist! (%s)", usePath);
        #endif
        return 0;
    }
    
    #if DEBUG
    PrintToServer("[vcv] trying keyvalue read (from [%s])...", usePath);
    #endif
    
    new Handle: hKv = CreateKeyValues("DefaultCVars");
    FileToKeyValues(hKv, usePath);
    
    if (hKv == INVALID_HANDLE) {
        #if DEBUG
        PrintToServer("[vcv] couldn't read file.");
        #endif
        return 0;
    }
    
    // read keyvalues (only sm_cvar bit now)
    if (!KvJumpToKey(hKv, g_sCvarKeySM))
    {
        // no special settings for this map
        CloseHandle(hKv);
        #if DEBUG
        PrintToServer("[vcv] couldn't find sm_cvar key (%s)", g_sCvarKeySM);
        #endif
        return 0;
    }
    
    // find all cvar keys and save the original values
    // then execute the change
    new String:tmpKey[MAX_VARLENGTH];
    new String:tmpValueNew[MAX_VALUELENGTH];
    new String:tmpValueOld[MAX_VALUELENGTH];
    new Handle: hConVar = INVALID_HANDLE;
    //new iConVarFlags = 0;
    
    
    if (KvGotoFirstSubKey(hKv, false))                              // false to get values
    {
        do
        {
            // read key stuff
            KvGetSectionName(hKv, tmpKey, sizeof(tmpKey));              // the subkey is a key-value pair, so get this to get the 'convar'
            #if DEBUG
            PrintToServer("[vcv] kv key found: [%s], reading value...", tmpKey);
            #endif
            
            // is it a convar?
            hConVar = FindConVar(tmpKey);
            
            if (hConVar != INVALID_HANDLE) {
                // get type..
                //iConVarFlags = GetConVarFlags(hConVar);
                
                // types?
                //      FCVAR_CHEAT
                
                KvGetString(hKv, NULL_STRING, tmpValueNew, sizeof(tmpValueNew), "[:none:]");
                #if DEBUG
                PrintToServer("[vcv] kv value read: [%s] => [%s])", tmpKey, tmpValueNew);
                #endif
                
                // read, save and set value
                if (!StrEqual(tmpValueNew,"[:none:]")) {
                    GetConVarString(hConVar, tmpValueOld, sizeof(tmpValueOld));
                    PrintToServer("[vcv] cvar value changed: [%s] => [%s] (saved old: [%s]))", tmpKey, tmpValueNew, tmpValueOld);
                    
                    if (!StrEqual(tmpValueNew,tmpValueOld)) {
                        // different, save the old
                        iNumChanged++;
                        KvSetString(g_hKvOrig, tmpKey, tmpValueOld);
                        
                        // cheat flags change
                        new saveFlags = GetConVarFlags(hConVar);
                        new tmpFlags = saveFlags;
                        tmpFlags &= ~FCVAR_CHEAT;
                        tmpFlags &= ~FCVAR_SPONLY;
                        SetConVarFlags(hConVar, tmpFlags);
                        
                        // apply the new
                        SetConVarString(hConVar, tmpValueNew);
                        
                        // reset flags
                        SetConVarFlags(hConVar, saveFlags);
                        
                    }
                }
            } else {
                #if DEBUG
                PrintToServer("[vcv] convar doesn't exist: [%s], not changing it.", tmpKey);
                #endif
            }
        } while (KvGotoNextKey(hKv, false));
    } 
    
    KvSetString(g_hKvOrig, "__EOF__", "1");             // a test-safeguard
    
    CloseHandle(hKv);
    return iNumChanged;
}

public ResetServerPrefs()
{
    KvRewind(g_hKvOrig);
    
    #if DEBUG
    PrintToServer("[vcv] attempting to reset values, if any...");
    #endif
    
    // find all cvar keys and reset to original values
    new String: tmpKey[64];
    new String: tmpValueOld[512];
    new Handle: hConVar = INVALID_HANDLE;
    
    if (KvGotoFirstSubKey(g_hKvOrig, false))                              // false to get values
    {
        do
        {
            // read key stuff
            KvGetSectionName(g_hKvOrig, tmpKey, sizeof(tmpKey));      // the subkey is a key-value pair, so get this to get the 'convar'
            
            if (StrEqual(tmpKey, "__EOF__")) { 
                #if DEBUG
                PrintToServer("[vcv] kv original settings, all read. (EOF).");
                #endif
                break;
            }
            else
            {
            
                #if DEBUG
                PrintToServer("[vcv] kv original saved setting found: [%s], reading value...", tmpKey);
                #endif
                
                // is it a convar?
                hConVar = FindConVar(tmpKey);
                
                if (hConVar != INVALID_HANDLE) {
                    
                    KvGetString(g_hKvOrig, NULL_STRING, tmpValueOld, sizeof(tmpValueOld), "[:none:]");
                    #if DEBUG
                    PrintToServer("[vcv] kv saved value read: [%s] => [%s])", tmpKey, tmpValueOld);
                    #endif
                    
                    // read, save and set value
                    if (!StrEqual(tmpValueOld,"[:none:]")) {
                        
                        // cheat flags change
                        new saveFlags = GetConVarFlags(hConVar);
                        new tmpFlags = saveFlags;
                        tmpFlags &= ~FCVAR_CHEAT;
                        tmpFlags &= ~FCVAR_SPONLY;
                        SetConVarFlags(hConVar, tmpFlags);
                        
                        // reset the old
                        SetConVarString(hConVar, tmpValueOld);
                        
                        // reset flags
                        SetConVarFlags(hConVar, saveFlags);
                        
                        PrintToServer("[vcv] cvar value reset to original: [%s] => [%s])", tmpKey, tmpValueOld);
                    }
                } else {
                    #if DEBUG
                    PrintToServer("[vcv] convar doesn't exist: [%s], not resetting it.", tmpKey);
                    #endif
                }
            }
            
        } while (KvGotoNextKey(g_hKvOrig, false));
    }
}
