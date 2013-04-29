#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <l4d2lib>

#define SR_DEBUG_MODE       0               // outputs some coordinate data

#define DETMODE_LIB         0               // use l4d2lib functions
#define DETMODE_EXACT       1               // use exact list (coordinate-in-box)

#define SR_RADIUS           200.0           // the radius used from saferoom-coordinate fr. l4d2lib

#define STRMAX_MAPNAME      64


/*

    To Do
    =========
        - make player checks for starting saferooms simply use simple netprop check.
        - maybe: make two-box check for weird saferooms:
            - c10m3/c10m4 church
            - c11m1 greenhouse
        
        - switch to a neat keyvalues / database type setup
            - or try to get it integrated with l4d2lib?
            
        - add custom campaigns (popular ones)
            Dead Before Dawn (DC)
            Haunted Forest
            Detour Ahead
            Warcelona
            Carried Off
            I Hate Mountains
        
    Changelog
    =========
    
        0.0.2
            - All official maps done (even Cold Stream).
            
        0.0.1
            - Added ugly maptable and maps for all standard L4D2 campaigns (L4D1 still to do)
        
*/

public Plugin:myinfo = 
{
    name = "Precise saferoom detection (ugly version)",
    author = "Tabun",
    description = "Allows checks whether a coordinate/entity/player is in start or end saferoom.",
    version = "0.0.1",
    url = ""
}


new     Handle:         g_hTrieMapsN                                        = INVALID_HANDLE;       // trie for recognizing maps for saferoom locations (internal list, ugly version)
new                     g_iMode                                             = DETMODE_LIB;          // detection mode for this map (LIB = l4d2lib 'vague radius' mode)
new     String:         g_sMapname[STRMAX_MAPNAME];
new     mapsName:       g_eMapCode;                                                                 // code for the map, if DETMODE_EXACT is on

new     bool:           g_bHasStart;                                                                // if DETMODE_EXACT, whether start saferoom is known
new     Float:          g_fStartLocA[3];                                                            // coordinates of 1 corner of the start saferoom box
new     Float:          g_fStartLocB[3];                                                            // and its opposite corner
new     Float:          g_fStartRotate;                                                             // rotated saferoom by this many degrees (for easy in-box coordinate checking)

new     bool:           g_bHasEnd;
new     Float:          g_fEndLocA[3];
new     Float:          g_fEndLocB[3];
new     Float:          g_fEndRotate;


enum mapsName                   // for recognizing which (official) map we're on
{
    MAPSN_C1M1, MAPSN_C1M2, MAPSN_C1M3, MAPSN_C1M4,
    MAPSN_C2M1, MAPSN_C2M2, MAPSN_C2M3, MAPSN_C2M4, MAPSN_C2M5,
    MAPSN_C3M1, MAPSN_C3M2, MAPSN_C3M3, MAPSN_C3M4,
    MAPSN_C4M1, MAPSN_C4M2, MAPSN_C4M3, MAPSN_C4M4, MAPSN_C4M5,
    MAPSN_C5M1, MAPSN_C5M2, MAPSN_C5M3, MAPSN_C5M4, MAPSN_C5M5,
    MAPSN_C6M1, MAPSN_C6M2, MAPSN_C6M3,
    MAPSN_C7M1, MAPSN_C7M2, MAPSN_C7M3,
    MAPSN_C8M1, MAPSN_C8M2, MAPSN_C8M3, MAPSN_C8M4, MAPSN_C8M5,
    MAPSN_C9M1, MAPSN_C9M2,
    MAPSN_C10M1, MAPSN_C10M2, MAPSN_C10M3, MAPSN_C10M4, MAPSN_C10M5,
    MAPSN_C11M1, MAPSN_C11M2, MAPSN_C11M3, MAPSN_C11M4, MAPSN_C11M5,
    MAPSN_C12M1, MAPSN_C12M2, MAPSN_C12M3, MAPSN_C12M4, MAPSN_C12M5,
    MAPSN_C13M1, MAPSN_C13M2, MAPSN_C13M3, MAPSN_C13M4
}



// Natives
// -------
 
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("SAFEDETECT_IsEntityInStartSaferoom", Native_IsEntityInStartSaferoom);
    CreateNative("SAFEDETECT_IsPlayerInStartSaferoom", Native_IsPlayerInStartSaferoom);
    CreateNative("SAFEDETECT_IsEntityInEndSaferoom", Native_IsEntityInEndSaferoom);
    CreateNative("SAFEDETECT_IsPlayerInEndSaferoom", Native_IsPlayerInEndSaferoom);    
    return APLRes_Success;
}

public Native_IsEntityInStartSaferoom(Handle:plugin, numParams)
{
    new entity = GetNativeCell(1);
    return _: IsEntityInStartSaferoom(entity);
}
public Native_IsEntityInEndSaferoom(Handle:plugin, numParams)
{
    new entity = GetNativeCell(1);
    return _: IsEntityInEndSaferoom(entity);
}

public Native_IsPlayerInStartSaferoom(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    return _: IsPlayerInStartSaferoom(client);
}
public Native_IsPlayerInEndSaferoom(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    return _: IsPlayerInEndSaferoom(client);
}



// Init
// ----

public OnPluginStart()
{
    // fill a huge trie with maps that we have data for
    
    PrepareTrie();
}


public OnMapStart()
{
    // get and store map data for this round
    
    GetCurrentMap(g_sMapname, sizeof(g_sMapname));
    
    if ( GetTrieValue(g_hTrieMapsN, g_sMapname, g_eMapCode) )
    {
        g_iMode = DETMODE_EXACT;
        SetSafeRoomData();
    }
    else
    {
        g_iMode = DETMODE_LIB;
    }
}

// Checks
// ------

public IsEntityInStartSaferoom(entity)
{
    if (!IsValidEntity(entity)) { return false; }
    
    // get entity location
    new Float: location[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
    
    return IsPointInStartSaferoom(location);
}

public IsEntityInEndSaferoom(entity)
{
    if (!IsValidEntity(entity)) { return false; }
    
    // get entity location
    new Float: location[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
    
    return IsPointInEndSaferoom(location);
}


public IsPlayerInStartSaferoom(client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) { return false; }
    
    // get client location
    new Float: locationA[3];
    new Float: locationB[3];
    
    // try both abs & eye
    GetClientAbsOrigin(client, locationA);
    GetClientEyePosition(client, locationB);
    
    return bool: (IsPointInStartSaferoom(locationA) || IsPointInStartSaferoom(locationB));
}

public IsPlayerInEndSaferoom(client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) { return false; }
    
    // get client location
    new Float: locationA[3];
    new Float: locationB[3];
    
    // try both abs & eye
    GetClientAbsOrigin(client, locationA);
    GetClientEyePosition(client, locationB);
    
    return bool: (IsPointInEndSaferoom(locationA) || IsPointInEndSaferoom(locationB));
}


IsPointInStartSaferoom(Float:location[3], entity=-1)
{
    if (g_iMode == DETMODE_EXACT)
    {
        if (!g_bHasStart) { return false; }
        
        // rotate point if necessary
        if (g_fStartRotate)
        {
            RotatePoint(g_fStartLocA, location[0], location[1], g_fStartRotate);
        }
        
        // check if the point is inside the box (end or start)
        new Float: xMin, Float: xMax;
        new Float: yMin, Float: yMax;
        new Float: zMin, Float: zMax;
        
        if (g_fStartLocA[0] < g_fStartLocB[0]) { xMin = g_fStartLocA[0]; xMax = g_fStartLocB[0]; } else { xMin = g_fStartLocB[0]; xMax = g_fStartLocA[0]; }
        if (g_fStartLocA[1] < g_fStartLocB[1]) { yMin = g_fStartLocA[1]; yMax = g_fStartLocB[1]; } else { yMin = g_fStartLocB[1]; yMax = g_fStartLocA[1]; }
        if (g_fStartLocA[2] < g_fStartLocB[2]) { zMin = g_fStartLocA[2]; zMax = g_fStartLocB[2]; } else { zMin = g_fStartLocB[2]; zMax = g_fStartLocA[2]; }
        
        PrintDebug("dimensions checked: %f - %f (%f) -- %f - %f (%f) -- %f - %f (%f)", xMin, xMax, location[0], yMin, yMax, location[1], zMin, zMax, location[2]);
        
        return bool: (      location[0] >= xMin && location[0] <= xMax
                        &&  location[1] >= yMin && location[1] <= yMax
                        &&  location[2] >= zMin && location[2] <= zMax  );
    }
    else
    {
        // trust l4d2lib report
        
        if (entity == -1)
        {
            // can't relay simple entity check
        
            new Float:saferoom[3];
            L4D2_GetMapStartOrigin(saferoom);
            
            return bool: (GetVectorDistance(location, saferoom) <= SR_RADIUS);
        }
        else
        {
            // simple relay
            return bool: (L4D2_IsEntityInSaferoom(entity) && Saferoom_Start);
        }
    }
    
}

IsPointInEndSaferoom(Float:location[3], entity = -1)
{
    if (g_iMode == DETMODE_EXACT)
    {
        if (!g_bHasEnd) { return false; }
        
        // rotate point if necessary
        if (g_fEndRotate)
        {
            RotatePoint(g_fEndLocA, location[0], location[1], g_fEndRotate);
        }
        
        
        // check if the point is inside the box (end or start)
        new Float: xMin, Float: xMax;
        new Float: yMin, Float: yMax;
        new Float: zMin, Float: zMax;
        
        if (g_fEndLocA[0] < g_fEndLocB[0]) { xMin = g_fEndLocA[0]; xMax = g_fEndLocB[0]; } else { xMin = g_fEndLocB[0]; xMax = g_fEndLocA[0]; }
        if (g_fEndLocA[1] < g_fEndLocB[1]) { yMin = g_fEndLocA[1]; yMax = g_fEndLocB[1]; } else { yMin = g_fEndLocB[1]; yMax = g_fEndLocA[1]; }
        if (g_fEndLocA[2] < g_fEndLocB[2]) { zMin = g_fEndLocA[2]; zMax = g_fEndLocB[2]; } else { zMin = g_fEndLocB[2]; zMax = g_fEndLocA[2]; }
        
        PrintDebug("dimensions checked: %f - %f (%f) -- %f - %f (%f) -- %f - %f (%f)", xMin, xMax, location[0], yMin, yMax, location[1], zMin, zMax, location[2]);
        
        return bool: (      location[0] >= xMin && location[0] <= xMax
                        &&  location[1] >= yMin && location[1] <= yMax
                        &&  location[2] >= zMin && location[2] <= zMax  );
    }
    else
    {
        // trust l4d2lib report
        
        if (entity == -1)
        {
            // can't relay simple entity check
        
            new Float:saferoom[3];
            L4D2_GetMapEndOrigin(saferoom);
            
            return bool: (GetVectorDistance(location, saferoom) <= SR_RADIUS);
        }
        else
        {
            // simple relay
            return bool: (L4D2_IsEntityInSaferoom(entity) && Saferoom_End);
        }
    }
}




// Ugly maptable
// --------------

stock SetSafeRoomData()
{
    // clean start
    g_bHasStart = true;
    g_bHasEnd = true;
    g_fStartLocA[0] = 0.0; g_fStartLocA[1] = 0.0; g_fStartLocA[2] = 0.0;
    g_fStartLocB[0] = 0.0; g_fStartLocB[1] = 0.0; g_fStartLocB[2] = 0.0;
    g_fEndLocA[0] = 0.0; g_fEndLocA[1] = 0.0; g_fEndLocA[2] = 0.0;
    g_fEndLocB[0] = 0.0; g_fEndLocB[1] = 0.0; g_fEndLocB[2] = 0.0;
    g_fStartRotate = 0.0;
    g_fEndRotate = 0.0;
    
    // get from ugly table
    switch (g_eMapCode)
    {
		case MAPSN_C1M1: {
			g_fStartLocA[0] = 396.43; g_fStartLocA[1] = 6220.43; g_fStartLocA[2] = 2825.83;
			g_fStartLocB[0] = 785.11; g_fStartLocB[1] = 5377.41; g_fStartLocB[2] = 3116.32;
			g_fEndLocA[0] = 1842.31; g_fEndLocA[1] = 4649.12; g_fEndLocA[2] = 1162.56;
			g_fEndLocB[0] = 2295.29; g_fEndLocB[1] = 4264.04; g_fEndLocB[2] = 1385.94;
		}
		case MAPSN_C1M2: {
			g_fStartLocA[0] = 2207.97; g_fStartLocA[1] = 5326.77; g_fStartLocA[2] = 410.56;
			g_fStartLocB[0] = 2591.66; g_fStartLocB[1] = 4936.33; g_fStartLocB[2] = 624.01;
			g_fEndLocA[0] = -7753.16; g_fEndLocA[1] = -4825.43; g_fEndLocA[2] = 708.03;
			g_fEndLocB[0] = -7197.54; g_fEndLocB[1] = -4577.97; g_fEndLocB[2] = 321.33;
		}
		case MAPSN_C1M3: {
			g_fStartLocA[0] = 6337.67; g_fStartLocA[1] = -1225.78; g_fStartLocA[2] = 329.74;
			g_fStartLocB[0] = 7023.04; g_fStartLocB[1] = -1523.81; g_fStartLocB[2] = 7.82;
			g_fEndLocA[0] = -2260.07; g_fEndLocA[1] = -4514.49; g_fEndLocA[2] = 504.92;
			g_fEndLocB[0] = -1824.19; g_fEndLocB[1] = -4791.52; g_fEndLocB[2] = 799.61;
		}
		case MAPSN_C1M4: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -2242.36; g_fStartLocA[1] = -4762.73; g_fStartLocA[2] = 518.7;
			g_fStartLocB[0] = -1539.17; g_fStartLocB[1] = -4487.89; g_fStartLocB[2] = 761.38;
		}
		case MAPSN_C2M1: {
			g_fStartLocA[0] = 9843.47; g_fStartLocA[1] = 8601.59; g_fStartLocA[2] = -588.3;
			g_fStartLocB[0] = 11195.10; g_fStartLocB[1] = 7074.39; g_fStartLocB[2] = -104.31;
			g_fEndLocA[0] = -974.59; g_fEndLocA[1] = -2366.09; g_fEndLocA[2] = -1103.45;
			g_fEndLocB[0] = -786.03; g_fEndLocB[1] = -2810.12; g_fEndLocB[2] = -938.01;
		}
		case MAPSN_C2M2: {
			g_fStartLocA[0] = 1548.78; g_fStartLocA[1] = 3027.10; g_fStartLocA[2] = -13.62;
			g_fStartLocB[0] = 1745.98; g_fStartLocB[1] = 2565.51; g_fStartLocB[2] = 144.52;
			g_fEndLocA[0] = -5175.20; g_fEndLocA[1] = -5638.28; g_fEndLocA[2] = 170.33;
			g_fEndLocB[0] = -4325.67; g_fEndLocB[1] = -5344.59; g_fEndLocB[2] = -72.89;
		}
		case MAPSN_C2M3: {
			g_fStartLocA[0] = 3855.61; g_fStartLocA[1] = 1912.54; g_fStartLocA[2] = 161.21;
			g_fStartLocB[0] = 4609.10; g_fStartLocB[1] = 2167.82; g_fStartLocB[2] = -107.15;
			g_fEndLocA[0] = -5560.42; g_fEndLocA[1] = 1288.18; g_fEndLocA[2] = 177.33;
			g_fEndLocB[0] = -4990.63; g_fEndLocB[1] = 2000.53; g_fEndLocB[2] = -17.02;
		}
		case MAPSN_C2M4: {
			g_fStartLocA[0] = 2853.62; g_fStartLocA[1] = 3235.78; g_fStartLocA[2] = -12.74;
			g_fStartLocB[0] = 3386.73; g_fStartLocB[1] = 3932.50; g_fStartLocB[2] = -203.55;
			g_fEndLocA[0] = -1188.92; g_fEndLocA[1] = 2085.07; g_fEndLocA[2] = -87.38;
			g_fEndLocB[0] = -543.20; g_fEndLocB[1] = 2160.72; g_fEndLocB[2] = -277.14;
			g_fEndRotate = 45.0;
		}
		case MAPSN_C2M5: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -1139.90; g_fStartLocA[1] = 2088.84; g_fStartLocA[2] = -276.01;
			g_fStartLocB[0] = -529.57; g_fStartLocB[1] = 2151.35; g_fStartLocB[2] = -30.98;
		}
		case MAPSN_C3M1: {
			g_fStartLocA[0] = -12625.47; g_fStartLocA[1] = 10206.99; g_fStartLocA[2] = 223.98;
			g_fStartLocB[0] = -12468.62; g_fStartLocB[1] = 10716.47; g_fStartLocB[2] = 359.80;
			g_fEndLocA[0] = -2769.28; g_fEndLocA[1] = 173.17; g_fEndLocA[2] = 212.01;
			g_fEndLocB[0] = -2567.17; g_fEndLocB[1] = 701.89; g_fEndLocB[2] = 16.38;
			g_fStartRotate = -60.0;
		}
		case MAPSN_C3M2: {
			g_fStartLocA[0] = -8278.86; g_fStartLocA[1] = 7260.80; g_fStartLocA[2] = 151.21;
			g_fStartLocB[0] = -8038.69; g_fStartLocB[1] = 7814.96; g_fStartLocB[2] = -17.69;
			g_fEndLocA[0] = 7305.83; g_fEndLocA[1] = -1102.44; g_fEndLocA[2] = 277.41;
			g_fEndLocB[0] = 7723.75; g_fEndLocB[1] = -777.77; g_fEndLocB[2] = 122.04;
		}
		case MAPSN_C3M3: {
			g_fStartLocA[0] = -6008.88; g_fStartLocA[1] = 1983.75; g_fStartLocA[2] = 286.62;
			g_fStartLocB[0] = -5574.81; g_fStartLocB[1] = 2287.05; g_fStartLocB[2] = 114.66;
			g_fEndLocA[0] = 4899.29; g_fEndLocA[1] = -3892.83; g_fEndLocA[2] = 337.6;
			g_fEndLocB[0] = 5230.81; g_fEndLocB[1] = -3650.34; g_fEndLocB[2] = 486.68;
		}
		case MAPSN_C3M4: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -5207.73; g_fStartLocA[1] = -1779.06; g_fStartLocA[2] = -125.65;
			g_fStartLocB[0] = -4879.46; g_fStartLocB[1] = -1545.58; g_fStartLocB[2] = 32.29;
		}
		case MAPSN_C4M1: {
			g_fStartLocA[0] = -7093.14; g_fStartLocA[1] = 6688.61; g_fStartLocA[2] = 453.86;
			g_fStartLocB[0] = -6354.96; g_fStartLocB[1] = 8051.25; g_fStartLocB[2] = 65.87;
			g_fEndLocA[0] = 3734.55; g_fEndLocA[1] = -1860.02; g_fEndLocA[2] = 394.79;
			g_fEndLocB[0] = 4237.81; g_fEndLocB[1] = -1428.38; g_fEndLocB[2] = 85.6;
		}
		case MAPSN_C4M2: {
			g_fStartLocA[0] = 3470.72; g_fStartLocA[1] = -1551.12; g_fStartLocA[2] = 366.75;
			g_fStartLocB[0] = 3974.07; g_fStartLocB[1] = -1978.05; g_fStartLocB[2] = 91.53;
			g_fEndLocA[0] = -1911.52; g_fEndLocA[1] = -13837.81; g_fEndLocA[2] = 256.72;
			g_fEndLocB[0] = -1670.73; g_fEndLocB[1] = -13582.69; g_fEndLocB[2] = 114.47;
		}
		case MAPSN_C4M3: {
			g_fStartLocA[0] = -1911.52; g_fStartLocA[1] = -13837.81; g_fStartLocA[2] = 256.72;
			g_fStartLocB[0] = -1670.73; g_fStartLocB[1] = -13582.69; g_fStartLocB[2] = 114.47;
			g_fEndLocA[0] = 3470.72; g_fEndLocA[1] = -1551.12; g_fEndLocA[2] = 366.75;
			g_fEndLocB[0] = 3974.07; g_fEndLocB[1] = -1978.05; g_fEndLocB[2] = 91.53;
		}
		case MAPSN_C4M4: {
			g_fStartLocA[0] = 3734.55; g_fStartLocA[1] = -1860.02; g_fStartLocA[2] = 394.79;
			g_fStartLocB[0] = 4237.81; g_fStartLocB[1] = -1428.38; g_fStartLocB[2] = 85.6;
			g_fEndLocA[0] = -3684.23; g_fEndLocA[1] = 7746.72; g_fEndLocA[2] = 284.03;
			g_fEndLocB[0] = -2856.12; g_fEndLocB[1] = 8150.86; g_fEndLocB[2] = 106.16;
		}
		case MAPSN_C4M5: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -3684.23; g_fStartLocA[1] = 7746.72; g_fStartLocA[2] = 284.00;
			g_fStartLocB[0] = -2848.77; g_fStartLocB[1] = 8161.33; g_fStartLocB[2] = 107.3;
		}
		case MAPSN_C5M1: {
			g_fStartLocA[0] = 668.80; g_fStartLocA[1] = 821.66; g_fStartLocA[2] = -204.64;
			g_fStartLocB[0] = 910.43; g_fStartLocB[1] = 239.99; g_fStartLocB[2] = -498.97;
			g_fEndLocA[0] = -4654.84; g_fEndLocA[1] = -1427.35; g_fEndLocA[2] = -160.94;
			g_fEndLocB[0] = -3761.66; g_fEndLocB[1] = -1172.97; g_fEndLocB[2] = -367.08;
		}
		case MAPSN_C5M2: {
			g_fStartLocA[0] = -4668.72; g_fStartLocA[1] = -1442.49; g_fStartLocA[2] = -181.21;
			g_fStartLocB[0] = -3743.52; g_fStartLocB[1] = -1104.72; g_fStartLocB[2] = -391.38;
			g_fEndLocA[0] = -9940.22; g_fEndLocA[1] = -8243.56; g_fEndLocA[2] = -72.79;
			g_fEndLocB[0] = -9552.56; g_fEndLocB[1] = -7713.49; g_fEndLocB[2] = -280.65;
		}
		case MAPSN_C5M3: {
			g_fStartLocA[0] = 6214.29; g_fStartLocA[1] = 8162.44; g_fStartLocA[2] = -23.79;
			g_fStartLocB[0] = 6592.18; g_fStartLocB[1] = 8686.59; g_fStartLocB[2] = 191.41;
			g_fEndLocA[0] = 7055.61; g_fEndLocA[1] = -9720.56; g_fEndLocA[2] = 269.07;
			g_fEndLocB[0] = 7590.59; g_fEndLocB[1] = -9480.47; g_fEndLocB[2] = 92.7;
		}
		case MAPSN_C5M4: {
			g_fStartLocA[0] = -3476.94; g_fStartLocA[1] = 4753.31; g_fStartLocA[2] = 53.53;
			g_fStartLocB[0] = -2941.91; g_fStartLocB[1] = 4980.77; g_fStartLocB[2] = 287.54;
			g_fEndLocA[0] = 1294.23; g_fEndLocA[1] = -3354.43; g_fEndLocA[2] = 48.83;
			g_fEndLocB[0] = 1672.85; g_fEndLocB[1] = -3752.36; g_fEndLocB[2] = 943.85;
		}
		case MAPSN_C5M5: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -12214.43; g_fStartLocA[1] = 5623.77; g_fStartLocA[2] = 96.39;
			g_fStartLocB[0] = -11858.14; g_fStartLocB[1] = 6010.33; g_fStartLocB[2] = 717.25;
		}
		case MAPSN_C6M1: {
			g_fStartLocA[0] = 733.62; g_fStartLocA[1] = 4701.33; g_fStartLocA[2] = 365.43;
			g_fStartLocB[0] = 1143.86; g_fStartLocB[1] = 3576.57; g_fStartLocB[2] = 80.19;
			g_fEndLocA[0] = -4307.58; g_fEndLocA[1] = 1237.83; g_fEndLocA[2] = 868.49;
			g_fEndLocB[0] = -3932.47; g_fEndLocB[1] = 1504.18; g_fEndLocB[2] = 712.03;
		}
		case MAPSN_C6M2: {
			g_fStartLocA[0] = 2890.05; g_fStartLocA[1] = -1349.82; g_fStartLocA[2] = -152.44;
			g_fStartLocB[0] = 3273.04; g_fStartLocB[1] = -1100.77; g_fStartLocB[2] = -340.26;
			g_fEndLocA[0] = 11121.52; g_fEndLocA[1] = 4869.86; g_fEndLocA[2] = -647.87;
			g_fEndLocB[0] = 11445.19; g_fEndLocB[1] = 5275.42; g_fEndLocB[2] = -365.59;
		}
		case MAPSN_C6M3: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -2561.14; g_fStartLocA[1] = -666.93; g_fStartLocA[2] = -282.85;
			g_fStartLocB[0] = -2212.61; g_fStartLocB[1] = -241.20; g_fStartLocB[2] = -13.94;
		}
		case MAPSN_C7M1: {
			g_fStartLocA[0] = 13240.04; g_fStartLocA[1] = 2039.30; g_fStartLocA[2] = -197.85;
			g_fStartLocB[0] = 14060.28; g_fStartLocB[1] = 3036.96; g_fStartLocB[2] = 322.46;
			g_fEndLocA[0] = 1727.15; g_fEndLocA[1] = 2564.84; g_fEndLocA[2] = 333.11;
			g_fEndLocB[0] = 2031.11; g_fEndLocB[1] = 2268.89; g_fEndLocB[2] = 120.73;
		}
		case MAPSN_C7M2: {
			g_fStartLocA[0] = 10569.66; g_fStartLocA[1] = 2318.17; g_fStartLocA[2] = 159.82;
			g_fStartLocB[0] = 10955.52; g_fStartLocB[1] = 2625.89; g_fStartLocB[2] = 326.90;
			g_fEndLocA[0] = -11332.87; g_fEndLocA[1] = 3283.46; g_fEndLocA[2] = 362.12;
			g_fEndLocB[0] = -10879.71; g_fEndLocB[1] = 2933.70; g_fEndLocB[2] = 144.64;
		}
		case MAPSN_C7M3: {
			g_bHasEnd = false;
			g_fStartLocA[0] = 944.14; g_fStartLocA[1] = 3079.41; g_fStartLocA[2] = 152.74;
			g_fStartLocB[0] = 1394.07; g_fStartLocB[1] = 3414.69; g_fStartLocB[2] = 392.88;
		}
		case MAPSN_C9M1: {
			g_fStartLocA[0] = -10353.97; g_fStartLocA[1] = -8265.59; g_fStartLocA[2] = 494.69;
			g_fStartLocB[0] = -9489.91; g_fStartLocB[1] = -8950.13; g_fStartLocB[2] = -39.34;
			g_fEndLocA[0] = 100.92; g_fEndLocA[1] = -1538.67; g_fEndLocA[2] = -218.59;
			g_fEndLocB[0] = 439.21; g_fEndLocB[1] = -1169.42; g_fEndLocB[2] = -33.40;
		}
		case MAPSN_C9M2: {
			g_bHasEnd = false;
			g_fStartLocA[0] = 109.02; g_fStartLocA[1] = -1478.15; g_fStartLocA[2] = -217.48;
			g_fStartLocB[0] = 435.16; g_fStartLocB[1] = -1087.94; g_fStartLocB[2] = -44.24;
		}
		case MAPSN_C10M1: {
			g_fStartLocA[0] = -13039.56; g_fStartLocA[1] = -14584.41; g_fStartLocA[2] = 541.57;
			g_fStartLocB[0] = -11178.48; g_fStartLocB[1] = -14879.90; g_fStartLocB[2] = -271.81;
			g_fEndLocA[0] = -11197.13; g_fEndLocA[1] = -4786.38; g_fEndLocA[2] = 547.65;
			g_fEndLocB[0] = -10641.26; g_fEndLocB[1] = -5127.08; g_fEndLocB[2] = 257.46;
		}
		case MAPSN_C10M2: {
			g_fStartLocA[0] = -11492.66; g_fStartLocA[1] = -8834.38; g_fStartLocA[2] = -237.97;
			g_fStartLocB[0] = -10928.58; g_fStartLocB[1] = -9167.82; g_fStartLocB[2] = -626.73;
			g_fEndLocA[0] = -8670.57; g_fEndLocA[1] = -5607.66; g_fEndLocA[2] = 84.11;
			g_fEndLocB[0] = -8202.08; g_fEndLocB[1] = -5492.25; g_fEndLocB[2] = -41.82;
		}
		case MAPSN_C10M3: {
			g_fStartLocA[0] = -8670.14; g_fStartLocA[1] = -5612.17; g_fStartLocA[2] = 90.70;
			g_fStartLocB[0] = -8155.81; g_fStartLocB[1] = -5456.26; g_fStartLocB[2] = -59.46;
			g_fEndLocA[0] = -2649.76; g_fEndLocA[1] = -137.11; g_fEndLocA[2] = 561.04;
			g_fEndLocB[0] = -2361.98; g_fEndLocB[1] = 43.32; g_fEndLocB[2] = 138.61;
		}
		case MAPSN_C10M4: {
			g_fStartLocA[0] = -3278.34; g_fStartLocA[1] = 289.16; g_fStartLocA[2] = 525.74;
			g_fStartLocB[0] = -2878.58; g_fStartLocB[1] = -144.66; g_fStartLocB[2] = 92.53;
			g_fEndLocA[0] = 1096.01; g_fEndLocA[1] = -5192.07; g_fEndLocA[2] = -75.01;
			g_fEndLocB[0] = 1540.37; g_fEndLocB[1] = -5511.87; g_fEndLocB[2] = 120.13;
		}
		case MAPSN_C10M5: {
			g_bHasEnd = false;
			g_fStartLocA[0] = 1775.66; g_fStartLocA[1] = 4881.23; g_fStartLocA[2] = 102.15;
			g_fStartLocB[0] = 2240.58; g_fStartLocB[1] = 4511.82; g_fStartLocB[2] = -85.56;
		}
		case MAPSN_C11M1: {
			g_fStartLocA[0] = 6386.81; g_fStartLocA[1] = -188.34; g_fStartLocA[2] = 632.03;
			g_fStartLocB[0] = 7007.50; g_fStartLocB[1] = -920.59; g_fStartLocB[2] = 1095.44;
			g_fEndLocA[0] = 4991.43; g_fEndLocA[1] = 2533.24; g_fEndLocA[2] = 24.82;
			g_fEndLocB[0] = 5478.24; g_fEndLocB[1] = 2919.94; g_fEndLocB[2] = 275.62;
		}
		case MAPSN_C11M2: {
			g_fStartLocA[0] = 4913.78; g_fStartLocA[1] = 2508.82; g_fStartLocA[2] = 263.47;
			g_fStartLocB[0] = 5452.98; g_fStartLocB[1] = 2897.34; g_fStartLocB[2] = 4.56;
			g_fEndLocA[0] = 7780.49; g_fEndLocA[1] = 5953.86; g_fEndLocA[2] = -11.58;
			g_fEndLocB[0] = 8137.91; g_fEndLocB[1] = 6358.82; g_fEndLocB[2] = 290.82;
		}
		case MAPSN_C11M3: {
			g_fStartLocA[0] = -5570.25; g_fStartLocA[1] = -3333.13; g_fStartLocA[2] = 284.38;
			g_fStartLocB[0] = -5208.61; g_fStartLocB[1] = -2860.08; g_fStartLocB[2] = -8.72;
			g_fEndLocA[0] = -523.94; g_fEndLocA[1] = 3420.62; g_fEndLocA[2] = 239.95;
			g_fEndLocB[0] = -301.20; g_fEndLocB[1] = 3735.97; g_fEndLocB[2] = 517.65;
		}
		case MAPSN_C11M4: {
			g_fStartLocA[0] = -558.28; g_fStartLocA[1] = 3714.01; g_fStartLocA[2] = 520.29;
			g_fStartLocB[0] = -305.83; g_fStartLocB[1] = 3409.08; g_fStartLocB[2] = 265.57;
			g_fEndLocA[0] = 3176.09; g_fEndLocA[1] = 4714.54; g_fEndLocA[2] = 379.75;
			g_fEndLocB[0] = 3612.72; g_fEndLocB[1] = 4394.95; g_fEndLocB[2] = 86.89;
		}
		case MAPSN_C11M5: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -6830.40; g_fStartLocA[1] = 12189.08; g_fStartLocA[2] = 323.62;
			g_fStartLocB[0] = -6394.75; g_fStartLocB[1] = 11902.46; g_fStartLocB[2] = 135.24;
			g_fStartRotate = -10.0;
		}
		case MAPSN_C12M1: {
			g_fStartLocA[0] = -9027.93; g_fStartLocA[1] = -15762.54; g_fStartLocA[2] = 935.88;
			g_fStartLocB[0] = -7402.46; g_fStartLocB[1] = -14735.30; g_fStartLocB[2] = 240.22;
			g_fEndLocA[0] = -6734.21; g_fEndLocA[1] = -6969.61; g_fEndLocA[2] = 334.11;
			g_fEndLocB[0] = -6328.27; g_fEndLocB[1] = -6575.63; g_fEndLocB[2] = 530.19;
		}
		case MAPSN_C12M2: {
			g_fStartLocA[0] = -6710.24; g_fStartLocA[1] = -6975.58; g_fStartLocA[2] = 488.28;
			g_fStartLocB[0] = -6329.88; g_fStartLocB[1] = -6619.08; g_fStartLocB[2] = 336.02;
			g_fEndLocA[0] = -1103.62; g_fEndLocA[1] = -10241.63; g_fEndLocA[2] = -89.94;
			g_fEndLocB[0] = -774.54; g_fEndLocB[1] = -10509.94; g_fEndLocB[2] = 205.28;
		}
		case MAPSN_C12M3: {
			g_fStartLocA[0] = -1152.52; g_fStartLocA[1] = -10246.47; g_fStartLocA[2] = 220.74;
			g_fStartLocB[0] = -761.71; g_fStartLocB[1] = -10511.19; g_fStartLocB[2] = -84.61;
			g_fEndLocA[0] = 7541.00; g_fEndLocA[1] = -11476.40; g_fEndLocA[2] = 408.49;
			g_fEndLocB[0] = 7865.33; g_fEndLocB[1] = -11247.60; g_fEndLocB[2] = 611.48;
		}
		case MAPSN_C12M4: {
			g_fStartLocA[0] = 7529.09; g_fStartLocA[1] = -11487.74; g_fStartLocA[2] = 613.50;
			g_fStartLocB[0] = 7869.49; g_fStartLocB[1] = -11250.56; g_fStartLocB[2] = 424.21;
			g_fEndLocA[0] = 10432.52; g_fEndLocA[1] = -636.86; g_fEndLocA[2] = -40.64;
			g_fEndLocB[0] = 10470.55; g_fEndLocB[1] = -153.58; g_fEndLocB[2] = 92.62;
			g_fEndRotate = -10.0;
		}
		case MAPSN_C12M5: {
			g_bHasEnd = false;
			g_fStartLocA[0] = 10432.52; g_fStartLocA[1] = -636.86; g_fStartLocA[2] = -40.64;
			g_fStartLocB[0] = 10470.55; g_fStartLocB[1] = -153.58; g_fStartLocB[2] = 92.62;
			g_fStartRotate = -10.0;
		}
		case MAPSN_C13M1: {
			g_fStartLocA[0] = -3305.98; g_fStartLocA[1] = -330.80; g_fStartLocA[2] = 376.77;
			g_fStartLocB[0] = -2782.98; g_fStartLocB[1] = -1173.65; g_fStartLocB[2] = 49.21;
			g_fEndLocA[0] = 848.57; g_fEndLocA[1] = -1287.31; g_fEndLocA[2] = 539.70;
			g_fEndLocB[0] = 1327.06; g_fEndLocB[1] = -650.63; g_fEndLocB[2] = 298.14;
		}
		case MAPSN_C13M2: {
			g_fStartLocA[0] = 8356.25; g_fStartLocA[1] = 6976.13; g_fStartLocA[2] = 476.88;
			g_fStartLocB[0] = 8910.00; g_fStartLocB[1] = 7797.59; g_fStartLocB[2] = 726.00;
			g_fEndLocA[0] = 150.41; g_fEndLocA[1] = 8645.47; g_fEndLocA[2] = -436.5;
			g_fEndLocB[0] = 522.73; g_fEndLocB[1] = 8984.41; g_fEndLocB[2] = -206.50;
		}
		case MAPSN_C13M3: {
			g_fStartLocA[0] = -4562.74; g_fStartLocA[1] = -5372.95; g_fStartLocA[2] = 339.86;
			g_fStartLocB[0] = -4169.81; g_fStartLocB[1] = -4943.63; g_fStartLocB[2] = 67.12;
			g_fEndLocA[0] = 5830.62; g_fEndLocA[1] = -6551.95; g_fEndLocA[2] = 539.20;
			g_fEndLocB[0] = 6335.01; g_fEndLocB[1] = -6055.55; g_fEndLocB[2] = 363.56;
		}
		case MAPSN_C13M4: {
			g_bHasEnd = false;
			g_fStartLocA[0] = -3631.93; g_fStartLocA[1] = -9377.93; g_fStartLocA[2] = 318.42;
			g_fStartLocB[0] = -3134.19; g_fStartLocB[1] = -8887.80; g_fStartLocB[2] = 513.99;
		}
    }
    
    // rotate if necessary (don't forget to rotate points later!)
    if (g_fStartRotate != 0.0)
    {
        RotatePoint(g_fStartLocA, g_fStartLocB[0], g_fStartLocB[1], g_fStartRotate);
    }
    if (g_fEndRotate != 0.0)
    {
        RotatePoint(g_fEndLocA, g_fEndLocB[0], g_fEndLocB[1], g_fEndRotate);
    }
    
}

stock PrepareTrie()
{
    g_hTrieMapsN = CreateTrie();
    SetTrieValue(g_hTrieMapsN, "c1m1_hotel",                    MAPSN_C1M1);
    SetTrieValue(g_hTrieMapsN, "c1m2_streets",                  MAPSN_C1M2);
    SetTrieValue(g_hTrieMapsN, "c1m3_mall",                     MAPSN_C1M3);
    SetTrieValue(g_hTrieMapsN, "c1m4_atrium",                   MAPSN_C1M4);
    SetTrieValue(g_hTrieMapsN, "c2m1_highway",                  MAPSN_C2M1);
    SetTrieValue(g_hTrieMapsN, "c2m2_fairgrounds",              MAPSN_C2M2);
    SetTrieValue(g_hTrieMapsN, "c2m3_coaster",                  MAPSN_C2M3);
    SetTrieValue(g_hTrieMapsN, "c2m4_barns",                    MAPSN_C2M4);
    SetTrieValue(g_hTrieMapsN, "c2m5_concert",                  MAPSN_C2M5);
    SetTrieValue(g_hTrieMapsN, "c3m1_plankcountry",             MAPSN_C3M1);
    SetTrieValue(g_hTrieMapsN, "c3m2_swamp",                    MAPSN_C3M2);
    SetTrieValue(g_hTrieMapsN, "c3m3_shantytown",               MAPSN_C3M3);
    SetTrieValue(g_hTrieMapsN, "c3m4_plantation",               MAPSN_C3M4);
    SetTrieValue(g_hTrieMapsN, "c4m1_milltown_a",               MAPSN_C4M1);
    SetTrieValue(g_hTrieMapsN, "c4m2_sugarmill_a",              MAPSN_C4M2);
    SetTrieValue(g_hTrieMapsN, "c4m3_sugarmill_b",              MAPSN_C4M3);
    SetTrieValue(g_hTrieMapsN, "c4m4_milltown_b",               MAPSN_C4M4);
    SetTrieValue(g_hTrieMapsN, "c4m5_milltown_escape",          MAPSN_C4M5);
    SetTrieValue(g_hTrieMapsN, "c5m1_waterfront",               MAPSN_C5M1);
    SetTrieValue(g_hTrieMapsN, "c5m2_park",                     MAPSN_C5M2);
    SetTrieValue(g_hTrieMapsN, "c5m3_cemetery",                 MAPSN_C5M3);
    SetTrieValue(g_hTrieMapsN, "c5m4_quarter",                  MAPSN_C5M4);
    SetTrieValue(g_hTrieMapsN, "c5m5_bridge",                   MAPSN_C5M5);
    SetTrieValue(g_hTrieMapsN, "c6m1_riverbank",                MAPSN_C6M1);
    SetTrieValue(g_hTrieMapsN, "c6m2_bedlam",                   MAPSN_C6M2);
    SetTrieValue(g_hTrieMapsN, "c6m3_port",                     MAPSN_C6M3);
    SetTrieValue(g_hTrieMapsN, "c7m1_docks",                    MAPSN_C7M1);
    SetTrieValue(g_hTrieMapsN, "c7m2_barge",                    MAPSN_C7M2);
    SetTrieValue(g_hTrieMapsN, "c7m3_port",                     MAPSN_C7M3);
    SetTrieValue(g_hTrieMapsN, "c8m1_apartment",                MAPSN_C8M1);
    SetTrieValue(g_hTrieMapsN, "c8m2_subway",                   MAPSN_C8M2);
    SetTrieValue(g_hTrieMapsN, "c8m3_sewers",                   MAPSN_C8M3);
    SetTrieValue(g_hTrieMapsN, "c8m4_interior",                 MAPSN_C8M4);
    SetTrieValue(g_hTrieMapsN, "c8m5_rooftop",                  MAPSN_C8M5);
    SetTrieValue(g_hTrieMapsN, "c9m1_alleys",                   MAPSN_C9M1);
    SetTrieValue(g_hTrieMapsN, "c9m2_lots",                     MAPSN_C9M2);
    SetTrieValue(g_hTrieMapsN, "c10m1_caves",                   MAPSN_C10M1);
    SetTrieValue(g_hTrieMapsN, "c10m2_drainage",                MAPSN_C10M2);
    SetTrieValue(g_hTrieMapsN, "c10m3_ranchhouse",              MAPSN_C10M3);
    SetTrieValue(g_hTrieMapsN, "c10m4_mainstreet",              MAPSN_C10M4);
    SetTrieValue(g_hTrieMapsN, "c10m5_houseboat",               MAPSN_C10M5);
    SetTrieValue(g_hTrieMapsN, "c11m1_greenhouse",              MAPSN_C11M1);
    SetTrieValue(g_hTrieMapsN, "c11m2_offices",                 MAPSN_C11M2);
    SetTrieValue(g_hTrieMapsN, "c11m3_garage",                  MAPSN_C11M3);
    SetTrieValue(g_hTrieMapsN, "c11m4_terminal",                MAPSN_C11M4);
    SetTrieValue(g_hTrieMapsN, "c11m5_runway",                  MAPSN_C11M5);
    SetTrieValue(g_hTrieMapsN, "c12m1_hilltop",                 MAPSN_C12M1);
    SetTrieValue(g_hTrieMapsN, "c12m2_traintunnel",             MAPSN_C12M2);
    SetTrieValue(g_hTrieMapsN, "c12m3_bridge",                  MAPSN_C12M3);
    SetTrieValue(g_hTrieMapsN, "c12m4_barn",                    MAPSN_C12M4);
    SetTrieValue(g_hTrieMapsN, "c12m5_cornfield",               MAPSN_C12M5);
    SetTrieValue(g_hTrieMapsN, "c13m1_alpinecreek",             MAPSN_C13M1);
    SetTrieValue(g_hTrieMapsN, "c13m2_southpinestream",         MAPSN_C13M2);
    SetTrieValue(g_hTrieMapsN, "c13m3_memorialbridge",          MAPSN_C13M3);
    SetTrieValue(g_hTrieMapsN, "c13m4_cutthroatcreek",          MAPSN_C13M4);
    SetTrieValue(g_hTrieMapsN, "c5m1_darkwaterfront",           MAPSN_C5M1);    // same locations as normal version
    SetTrieValue(g_hTrieMapsN, "c5m2_darkpark",                 MAPSN_C5M1);
    SetTrieValue(g_hTrieMapsN, "c5m3_darkcemetery",             MAPSN_C5M3);
    SetTrieValue(g_hTrieMapsN, "c5m4_darkquarter",              MAPSN_C5M4);
    SetTrieValue(g_hTrieMapsN, "c5m5_darkbridge",               MAPSN_C5M5);
}



// Support functions
// -----------------

// rotate a point (x,y) over an angle, with ref. to an origin (x,y plane only)
stock RotatePoint(Float:origin[3], &Float:pointX, &Float:pointY, Float:angle)
{
    // translate angle to radians:
    new Float: newPoint[2];
    angle = angle / 57.2957795130823;
    
    newPoint[0] = (Cosine(angle) * (pointX - origin[0])) - (Sine(angle) * (pointY - origin[1]))   + origin[0];
    newPoint[1] = (Sine(angle) * (pointX - origin[0]))   + (Cosine(angle) * (pointY - origin[1])) + origin[1];
    
    pointX = newPoint[0];
    pointY = newPoint[1];
    
    return;
}

public PrintDebug(const String:Message[], any:...)
{
    #if SR_DEBUG_MODE
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
        //PrintToServer(DebugBuff);
        //PrintToChatAll(DebugBuff);
    #endif
}