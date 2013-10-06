#pragma semicolon 1

#include <sourcemod>
//#include <sdktools>
//#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

#define CONBUFSIZE              1024
#define CONBUFSIZELARGE         4096
#define CHARTHRESHOLD           160         // detecting unicode stuff

#define DELAY_PRINT             3.0         // before survior mvp tables
#define DELAY_PRINT_SCAV        1.5

#define MAXTRACKED              128
#define MAXNAME                 64
#define MAXCHARACTERS           4
#define MAXGAME                 24

#define TYPE_TOTAL              0
#define TYPE_PELLET             1
#define TYPE_BULLET             2
#define TYPE_SNIPER             3
#define TYPE_MELEE              4
#define TYPE_FIRE               5
#define TYPE_INCAPPED           6
#define TYPE_OTHER              7
#define MAXTYPES                8

#define TYPE_SELF               8               // only for printing

#define FIRST_NON_BOT           4               // first index that doesn't belong to a survivor bot

#define TOTAL_GIVEN             0
#define TOTAL_TAKEN             1

#define WORLD_FALL              0
#define WORLD_OTHER             1

// damage type
#define DMG_GENERIC             0               // generic damage was done
#define DMG_CRUSH               (1 << 0)        // crushed by falling or moving object. 
#define DMG_BULLET              (1 << 1)        // shot
#define DMG_SLASH               (1 << 2)        // cut, clawed, stabbed
#define DMG_BURN                (1 << 3)        // heat burned
#define DMG_BLAST               (1 << 6)        // explosive blast damage
#define DMG_CLUB                (1 << 7)        // crowbar, punch, headbutt
#define DMG_BUCKSHOT            (1 << 29)       // not quite a bullet. Little, rounder, different. 


new     bool:           g_bLateLoad                                         = false;
new     bool:           g_bInRound                                          = false;
new     String:         g_sGameMode         [MAXGAME];
new     bool:           g_bCampaignMode                                     = false;

new     Handle:         g_hCvarAutoReport                                   = INVALID_HANDLE;

new     Handle:         g_hTriePlayers                                      = INVALID_HANDLE;       // trie for getting player index

new     String:         g_sConsoleBufGiven [CONBUFSIZELARGE]                = "";
new     String:         g_sConsoleBufTaken [CONBUFSIZELARGE]                = "";

new                     g_iDamageTotal  [MAXTRACKED][2];                                            // damage totals: 0 = given, 1 = taken
new                     g_iDamageWorld  [MAXTRACKED][2];                                            // damage taken from the world
new                     g_iDamage       [MAXTRACKED][MAXTRACKED][MAXTYPES];                         // damage done player-to-player, per type
new     String:         g_sPlayerName   [MAXTRACKED][MAXNAME];
new                     g_iPlayers                                          = 0;

new     String:         g_sTmpString    [MAXNAME];                                                  // why is this a global? kinda silly, but the global can be used for printing
                                                                                                    // after the stripUnicode() method is called.. oh well.

/*
    To Do
    -----
    
    - make it report, for a given player, to whom they did FF -- player-to-player reports
*/

public Plugin: myinfo =
{
    name = "Friendly-Fire Report",
    author = "Tabun",
    description = "Tracks and console-reports friendly fire damage",
    version = "0.9.9",
    url = "https://github.com/Tabbernaut/L4D2-Plugins"
};

public APLRes: AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax )
{
    g_bLateLoad = late;
    return APLRes_Success;
}


public OnPluginStart()
{
    decl String: sSteamId[32];
    
    HookEvent( "door_close",                Event_DoorClose,            EventHookMode_PostNoCopy );
    HookEvent( "finale_vehicle_leaving",    Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy );
    HookEvent( "round_start",               Event_RoundStart,           EventHookMode_PostNoCopy );
    HookEvent( "scavenge_round_start",      Event_ScavRoundStart,       EventHookMode_PostNoCopy );
    HookEvent( "round_end",                 Event_RoundEnd,             EventHookMode_PostNoCopy );
    HookEvent( "player_hurt",               Event_PlayerHurt,           EventHookMode_Post );
    HookEvent( "player_falldamage",         Event_PlayerFallDamage,     EventHookMode_Post );
    
    g_hCvarAutoReport = CreateConVar( "sm_ffreport_auto", "1", "Enable display of FF in console at end of round", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    
    RegConsoleCmd( "sm_ff", Cmd_FriendlyFireDisplay, "Prints the current FF stats for survivors" );
    
    g_hTriePlayers = CreateTrie();
    
    // create 4 slots for bots
    SetTrieValue( g_hTriePlayers, "BOT_0", 0 );
    SetTrieValue( g_hTriePlayers, "BOT_1", 1 );
    SetTrieValue( g_hTriePlayers, "BOT_2", 2 );
    SetTrieValue( g_hTriePlayers, "BOT_3", 3 );
    g_sPlayerName[0] = "BOT [Nick/Bill]";
    g_sPlayerName[1] = "BOT [Rochelle/Zoey]";
    g_sPlayerName[2] = "BOT [Coach/Francis]";
    g_sPlayerName[3] = "BOT [Ellis/Louis]";
    g_iPlayers += 4;
    
    if ( g_bLateLoad )
    {
        new index = -1;
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) && !IsFakeClient(i) )
            {
                GetClientAuthString( i, sSteamId, sizeof(sSteamId) );
                
                index = GetPlayerIndexForSteamId( sSteamId );
                
                if ( index == -1 )
                {
                    SetTrieValue( g_hTriePlayers, sSteamId, g_iPlayers );
                    GetClientName( i, g_sPlayerName[g_iPlayers], MAXNAME );
                    //PrintToChatAll("client: %i %N %s", i, i, g_sPlayerName[g_iPlayers] );
                    g_iPlayers++;
                
                    if ( g_iPlayers >= MAXTRACKED ) { g_iPlayers = MAXTRACKED - 1; }    // safeguard
                }
            }
        }
    }
}

public OnClientPostAdminCheck( client )
{
    decl String: sSteamId[32];
    
    GetClientAuthString( client, sSteamId, sizeof(sSteamId) );
    
    new index = GetPlayerIndexForSteamId( sSteamId );
    
    // get a new index for this player?
    if ( index == -1 )
    {
        SetTrieValue( g_hTriePlayers, sSteamId, g_iPlayers );
        GetClientName( client, g_sPlayerName[g_iPlayers], MAXNAME );
        //PrintToChatAll("client: %i %N %s", client, client, g_sPlayerName[g_iPlayers] );
        g_iPlayers++;
        
        if ( g_iPlayers >= MAXTRACKED ) { g_iPlayers = MAXTRACKED - 1; }    // safeguard
    }
}

public OnMapStart()
{
    GetConVarString( FindConVar("mp_gamemode"), g_sGameMode, MAXGAME );
    
    if (    StrEqual(g_sGameMode, "coop", false) ||
            StrEqual(g_sGameMode, "mutation4", false) ||         // hard eight
            StrEqual(g_sGameMode, "mutation14", false) ||        // gib fest
            StrEqual(g_sGameMode, "mutation20", false)           // healing gnome
    ) {
        g_bCampaignMode = true;
    }
}

public OnMapEnd()
{
    g_bInRound = false;
}

public Event_RoundStart (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( !g_bInRound )
    {
        g_bInRound = true;
    }
    
    // clean slate
    for ( new i = 0; i < g_iPlayers; i++ )
    {
        g_iDamageTotal[i][TOTAL_GIVEN] = 0;
        g_iDamageTotal[i][TOTAL_TAKEN] = 0;
        g_iDamageWorld[i][WORLD_FALL] = 0;
        g_iDamageWorld[i][WORLD_OTHER] = 0;
        
        for ( new j = 0; j < g_iPlayers; j++ )
        {
            for ( new k = 0; k < MAXTYPES; k++ )
            {
                g_iDamage[i][j][k] = 0;
            }
        }
    }
}

public Event_RoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
    // display table
    if ( StrEqual(g_sGameMode, "scavenge", false) )
    {
        if ( g_bInRound )
        {
            if ( GetConVarBool( g_hCvarAutoReport ) )
            {
                CreateTimer( DELAY_PRINT_SCAV, Timer_FriendlyFireDisplay );
            }
            g_bInRound = false;
        }
    }
    else
    {
        // versus or other
        if ( g_bInRound )
        {
            // only show / log stuff when the round is done "the first time", and cvar is set
            if ( GetConVarBool( g_hCvarAutoReport ) )
            {
                CreateTimer( DELAY_PRINT, Timer_FriendlyFireDisplay );
            }
            g_bInRound = false;
        }
    }
}

// scavenge
public Event_ScavRoundStart (Handle:event, const String:name[], bool:dontBroadcast)
{
    Event_RoundStart(INVALID_HANDLE, "", true);
}

// for campaign mode
public Event_FinaleVehicleLeaving (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( g_bCampaignMode )
    {
        CreateTimer( DELAY_PRINT, Timer_FriendlyFireDisplay );
    }
}

public Event_DoorClose (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( g_bCampaignMode && GetEventBool(event, "checkpoint") )
    {
        CreateTimer( DELAY_PRINT, Timer_FriendlyFireDisplay );
    }
}


// tracking
// --------

public Action: Event_PlayerHurt ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    
    // only record survivor-to-survivor damage done by humans
    if ( !IS_VALID_SURVIVOR(victim) ) { return Plugin_Continue; }
    
    new damage = GetEventInt(event, "dmg_health");
    new type = GetEventInt(event, "type");
    
    // only record actual damage done
    if ( damage < 1 ) { return Plugin_Continue; }
    
    decl String: sSteamId[32];
    new attIndex, vicIndex;
    
    // world did the damage?
    /*
    if ( attacker == 0 )
    {
        new attackEnt = GetEventInt(event, "attackerentid");
        decl String:classname[32];
        GetEdictClassname( attackEnt, classname, sizeof(classname) );
        PrintToChatAll("ent: %i %s", attackEnt, classname );
        
        if ( IsFakeClient( victim ) )
        {
            Format( sSteamId, sizeof( sSteamId ), "BOT_%i", GetPlayerCharacter( victim ) );
        }
        else
        {
            GetClientAuthString( victim, sSteamId, sizeof(sSteamId) );
        }
        vicIndex = GetPlayerIndexForSteamId( sSteamId );
        
        g_iDamageWorld[vicIndex][WORLD_OTHER] += damage;
        
        return Plugin_Continue;
    }
    */
    
    // otherwise, only deal with survivor-survivor human damage
    if ( !IS_VALID_SURVIVOR(attacker) || IsFakeClient(attacker) ) { return Plugin_Continue; }
    
    // this is okay, because attacker can never be a bot
    GetClientAuthString( attacker, sSteamId, sizeof(sSteamId) );
    attIndex = GetPlayerIndexForSteamId( sSteamId );
    
    if ( attacker == victim )
    {
        vicIndex = attIndex;
    }
    else
    {
        if ( IsFakeClient( victim ) )
        {
            Format( sSteamId, sizeof( sSteamId ), "BOT_%i", GetPlayerCharacter( victim ) );
        }
        else
        {
            GetClientAuthString( victim, sSteamId, sizeof(sSteamId) );
        }
        vicIndex = GetPlayerIndexForSteamId( sSteamId );
    }
    
    // record amounts
    g_iDamageTotal[attIndex][TOTAL_GIVEN] += damage;
    g_iDamageTotal[vicIndex][TOTAL_TAKEN] += damage;
    g_iDamage[attIndex][vicIndex][TYPE_TOTAL] += damage;
    
    
    if ( IsPlayerIncapacitated(victim) )
    {
        g_iDamage[attIndex][vicIndex][TYPE_INCAPPED] += damage;
    }
    else
    {
        // which type to save it to?
        if ( type & DMG_BURN )
        {
            g_iDamage[attIndex][vicIndex][TYPE_FIRE] += damage;
        }
        else if ( type & DMG_BUCKSHOT )
        {
            g_iDamage[attIndex][vicIndex][TYPE_PELLET] += damage;
        }
        else if ( type & DMG_CLUB || type & DMG_SLASH )
        {
            g_iDamage[attIndex][vicIndex][TYPE_MELEE] += damage;
        }
        else if ( type & DMG_BULLET )
        {
            g_iDamage[attIndex][vicIndex][TYPE_BULLET] += damage;
        }
        else
        {
            g_iDamage[attIndex][vicIndex][TYPE_OTHER] += damage;
        }
    }

    return Plugin_Continue;
}

public Action: Event_PlayerFallDamage ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    //new causer = GetClientOfUserId( GetEventInt(event, "causer") );

    if ( !IS_VALID_SURVIVOR(victim) ) { return Plugin_Continue; }
    
    new damage = GetEventInt(event, "damage");
    
    decl String: sSteamId[32];
    new vicIndex;
    
    if ( IsFakeClient( victim ) )
    {
        Format( sSteamId, sizeof( sSteamId ), "BOT_%i", GetPlayerCharacter( victim ) );
    }
    else
    {
        GetClientAuthString( victim, sSteamId, sizeof(sSteamId) );
    }
    vicIndex = GetPlayerIndexForSteamId( sSteamId );
    
    g_iDamageWorld[vicIndex][WORLD_FALL] += damage;    
    
    return Plugin_Continue;
}


// printing
// --------

public Action:Timer_FriendlyFireDisplay ( Handle:timer )
{
    // print to all
    FriendlyFireDisplay( 0 );
}

public FriendlyFireDisplay( client )
{
    // prepare buffer(s) for printing
    BuildConsoleBuffer();
    
    // friendly fire -- given
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String:bufBasic[CONBUFSIZELARGE];
    
    Format(bufBasicHeader, CONBUFSIZE, "\n");
    Format(bufBasicHeader, CONBUFSIZE, "%s| FF GIVEN               Friendly Fire Statistics  --  Offenders                                       |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | On Incap | Other  || to Self |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
    Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufGiven);
    Format(bufBasic, CONBUFSIZELARGE,  "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasic);

    if ( !client )
    {
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IS_VALID_INGAME( i ) )
            {
                PrintToConsole(i, bufBasicHeader);
                PrintToConsole(i, bufBasic);
            }
        }
    }
    else 
    {
        if ( IS_VALID_INGAME( client ) )
        {
            PrintToConsole(client, bufBasicHeader);
            PrintToConsole(client, bufBasic);
        }
    }
    
    // friendly fire -- taken
    Format(bufBasicHeader, CONBUFSIZE, "\n");
    Format(bufBasicHeader, CONBUFSIZE, "%s| FF RECEIVED            Friendly Fire Statistics  --  Victims                                         |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | Incapped | Other  || Fall    |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
    Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufTaken);
    Format(bufBasic, CONBUFSIZELARGE,  "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasic);
    
    if ( !client )
    {
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IS_VALID_INGAME( i ) )
            {
                PrintToConsole(i, bufBasicHeader);
                PrintToConsole(i, bufBasic);
            }
        }
    }
    else 
    {
        if ( IS_VALID_INGAME( client ) )
        {
            PrintToConsole(client, bufBasicHeader);
            PrintToConsole(client, bufBasic);
        }
    }
}

public BuildConsoleBuffer ()
{
    g_sConsoleBufGiven = "";
    g_sConsoleBufTaken = "";
    
    new const s_len = 15;
    
    decl String:strPrint[MAXTYPES+1][s_len];    // types + type_self
    new dmgCount[MAXTYPES];
    new dmgSelf, dmgWorld;
    
    /*
        Sorting is not really important, but might consider it later
    */
    
    
    // GIVEN
    for (new i = 0; i <= g_iPlayers; i++)
    {
        // skip any row where total of given and taken is 0
        if ( !g_iDamageTotal[i][TOTAL_GIVEN] && !g_iDamageTotal[i][TOTAL_TAKEN] ) { continue; }
        
        // also skip bots for this list
        if ( i < FIRST_NON_BOT ) { continue; }
        
        dmgSelf = 0;
        for ( new z = 0; z < MAXTYPES; z++ )
        {
            dmgCount[z] = 0;
        }
        
        for ( new j = 0; j <= g_iPlayers; j++ )
        {
            dmgCount[TYPE_TOTAL] += g_iDamage[i][j][TYPE_TOTAL];
            
            if ( i == j )
            {
                // self (no further differentiation)
                dmgSelf += g_iDamage[i][j][TYPE_TOTAL];
            }
            else
            {
                dmgCount[TYPE_PELLET] +=    g_iDamage[i][j][TYPE_PELLET];
                dmgCount[TYPE_BULLET] +=    g_iDamage[i][j][TYPE_BULLET];
                dmgCount[TYPE_MELEE] +=     g_iDamage[i][j][TYPE_MELEE];
                dmgCount[TYPE_FIRE] +=      g_iDamage[i][j][TYPE_FIRE];
                dmgCount[TYPE_INCAPPED] +=  g_iDamage[i][j][TYPE_INCAPPED];
                dmgCount[TYPE_OTHER] +=     g_iDamage[i][j][TYPE_OTHER];
            }
        }
        
        // prepare print
        if ( dmgCount[TYPE_TOTAL] ) {
            Format( strPrint[TYPE_TOTAL],       s_len, "%7d",   dmgCount[TYPE_TOTAL] );
        } else {
            Format( strPrint[TYPE_TOTAL],       s_len, "       " );
        }
        if ( dmgCount[TYPE_PELLET] ) {
            Format(strPrint[TYPE_PELLET],       s_len, "%7d",   dmgCount[TYPE_PELLET] );
        } else {
            Format( strPrint[TYPE_PELLET],      s_len, "       " );
        }
        if ( dmgCount[TYPE_BULLET] ) {
            Format(strPrint[TYPE_BULLET],       s_len, "%7d",   dmgCount[TYPE_BULLET]);
        } else {
            Format( strPrint[TYPE_BULLET],      s_len, "       " );
        }
        if ( dmgCount[TYPE_MELEE] ) {
            Format(strPrint[TYPE_MELEE],        s_len, "%6d",   dmgCount[TYPE_MELEE]);
        } else {
            Format( strPrint[TYPE_MELEE],       s_len, "      " );
        }
        if ( dmgCount[TYPE_FIRE] ) {
            Format(strPrint[TYPE_FIRE],         s_len, "%6d",   dmgCount[TYPE_FIRE]);
        } else {
            Format( strPrint[TYPE_FIRE],        s_len, "      " );
        }
        if ( dmgCount[TYPE_INCAPPED] ) {
            Format(strPrint[TYPE_INCAPPED],     s_len, "%8d",   dmgCount[TYPE_INCAPPED]);
        } else {
            Format( strPrint[TYPE_INCAPPED],    s_len, "        " );
        }
        if ( dmgCount[TYPE_OTHER] ) {
            Format(strPrint[TYPE_OTHER],        s_len, "%6d",   dmgCount[TYPE_OTHER]);
        } else {
            Format( strPrint[TYPE_OTHER],       s_len, "      " );
        }        
        if ( dmgSelf ) {
            Format(strPrint[TYPE_SELF],         s_len, "%7d",   dmgSelf);
        } else {
            Format( strPrint[TYPE_SELF],        s_len, "       " );
        }
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[i] );
        
        // Format the basic stats
        Format(g_sConsoleBufGiven, CONBUFSIZE,
            "%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |\n",
            g_sConsoleBufGiven,
            g_sTmpString,
            strPrint[TYPE_TOTAL],
            strPrint[TYPE_PELLET], strPrint[TYPE_BULLET], strPrint[TYPE_MELEE],
            strPrint[TYPE_FIRE], strPrint[TYPE_INCAPPED], strPrint[TYPE_OTHER],
            strPrint[TYPE_SELF]
        );
    }
    
    // TAKEN
    for (new j = 0; j <= g_iPlayers; j++)
    {
        // skip any row where total of given and taken is 0
        if ( !g_iDamageTotal[j][TOTAL_GIVEN] && !g_iDamageTotal[j][TOTAL_TAKEN] ) { continue; }
        
        dmgWorld = g_iDamageWorld[j][WORLD_FALL];
        for ( new z = 0; z < MAXTYPES; z++ )
        {
            dmgCount[z] = 0;
        }
        
        for ( new i = 0; i <= g_iPlayers; i++ )
        {
            dmgCount[TYPE_TOTAL] += g_iDamage[i][j][TYPE_TOTAL];
            
            if ( i != j )
            {
                dmgCount[TYPE_PELLET] +=    g_iDamage[i][j][TYPE_PELLET];
                dmgCount[TYPE_BULLET] +=    g_iDamage[i][j][TYPE_BULLET];
                dmgCount[TYPE_MELEE] +=     g_iDamage[i][j][TYPE_MELEE];
                dmgCount[TYPE_FIRE] +=      g_iDamage[i][j][TYPE_FIRE];
                dmgCount[TYPE_INCAPPED] +=  g_iDamage[i][j][TYPE_INCAPPED];
                dmgCount[TYPE_OTHER] +=     g_iDamage[i][j][TYPE_OTHER];
            }
        }
        
        // prepare print
        if ( dmgCount[TYPE_TOTAL] ) {
            Format( strPrint[TYPE_TOTAL],       s_len, "%7d",   dmgCount[TYPE_TOTAL] );
        } else {
            Format( strPrint[TYPE_TOTAL],       s_len, "       " );
        }
        if ( dmgCount[TYPE_PELLET] ) {
            Format(strPrint[TYPE_PELLET],       s_len, "%7d",   dmgCount[TYPE_PELLET] );
        } else {
            Format( strPrint[TYPE_PELLET],      s_len, "       " );
        }
        if ( dmgCount[TYPE_BULLET] ) {
            Format(strPrint[TYPE_BULLET],       s_len, "%7d",   dmgCount[TYPE_BULLET]);
        } else {
            Format( strPrint[TYPE_BULLET],      s_len, "       " );
        }
        if ( dmgCount[TYPE_MELEE] ) {
            Format(strPrint[TYPE_MELEE],        s_len, "%6d",   dmgCount[TYPE_MELEE]);
        } else {
            Format( strPrint[TYPE_MELEE],       s_len, "      " );
        }
        if ( dmgCount[TYPE_FIRE] ) {
            Format(strPrint[TYPE_FIRE],         s_len, "%6d",   dmgCount[TYPE_FIRE]);
        } else {
            Format( strPrint[TYPE_FIRE],        s_len, "      " );
        }
        if ( dmgCount[TYPE_INCAPPED] ) {
            Format(strPrint[TYPE_INCAPPED],     s_len, "%8d",   dmgCount[TYPE_INCAPPED]);
        } else {
            Format( strPrint[TYPE_INCAPPED],    s_len, "        " );
        }
        if ( dmgCount[TYPE_OTHER] ) {
            Format(strPrint[TYPE_OTHER],        s_len, "%6d",   dmgCount[TYPE_OTHER]);
        } else {
            Format( strPrint[TYPE_OTHER],       s_len, "      " );
        }
        if ( dmgWorld ) {
            Format(strPrint[TYPE_SELF],         s_len, "%7d",   dmgWorld);
        } else {
            Format( strPrint[TYPE_SELF],        s_len, "       " );
        }
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[j] );
        
        // Format the basic stats
        Format(g_sConsoleBufTaken, CONBUFSIZE,
            "%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |\n",
            g_sConsoleBufTaken,
            g_sTmpString,
            strPrint[TYPE_TOTAL],
            strPrint[TYPE_PELLET], strPrint[TYPE_BULLET], strPrint[TYPE_MELEE],
            strPrint[TYPE_FIRE], strPrint[TYPE_INCAPPED], strPrint[TYPE_OTHER],
            strPrint[TYPE_SELF]
        );
    }
}

public Action: Cmd_FriendlyFireDisplay ( client, args )
{
    FriendlyFireDisplay( client );
}


// support
// -------

stock bool:IsPlayerIncapacitated(client) { return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated", 1); }


stock GetPlayerIndexForSteamId ( const String:steamId[] )
{
    new pIndex;
    
    if ( GetTrieValue( g_hTriePlayers, steamId, pIndex ) ) {
        return pIndex;
    }
    
    return -1;
}

stock GetPlayerCharacter ( client )
{
    new tmpChr = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    
    // use models when incorrect character returned
    if ( tmpChr < 0 || tmpChr >= MAXCHARACTERS )
    {
        decl String:model[256];
        GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
        
        if (StrContains(model, "gambler") != -1) {          tmpChr = 0; }
        else if (StrContains(model, "coach") != -1) {       tmpChr = 2; }
        else if (StrContains(model, "mechanic") != -1) {    tmpChr = 3; }
        else if (StrContains(model, "producer") != -1) {    tmpChr = 1; }
        else if (StrContains(model, "namvet") != -1) {      tmpChr = 0; }
        else if (StrContains(model, "teengirl") != -1) {    tmpChr = 1; }
        else if (StrContains(model, "biker") != -1) {       tmpChr = 3; }
        else if (StrContains(model, "manager") != -1) {     tmpChr = 2; }
        else {                                              tmpChr = 0; }
    }
    
    return tmpChr;
}

public stripUnicode ( String:testString[MAXNAME] )
{
    new const maxlength = MAX_NAME_LENGTH;
    //strcopy(testString, maxlength, sTmpString);
    g_sTmpString = testString;
    
    new uni=0;
    new currentChar;
    new tmpCharLength = 0;
    //new iReplace[MAX_NAME_LENGTH];      // replace these chars
    
    for (new i=0; i < maxlength - 3 && g_sTmpString[i] != 0; i++)
    {
        // estimate current character value
        if ((g_sTmpString[i]&0x80) == 0) // single byte character?
        {
            currentChar=g_sTmpString[i]; tmpCharLength = 0;
        } else if (((g_sTmpString[i]&0xE0) == 0xC0) && ((g_sTmpString[i+1]&0xC0) == 0x80)) // two byte character?
        {
            currentChar=(g_sTmpString[i++] & 0x1f); currentChar=currentChar<<6;
            currentChar+=(g_sTmpString[i] & 0x3f); 
            tmpCharLength = 1;
        } else if (((g_sTmpString[i]&0xF0) == 0xE0) && ((g_sTmpString[i+1]&0xC0) == 0x80) && ((g_sTmpString[i+2]&0xC0) == 0x80)) // three byte character?
        {
            currentChar=(g_sTmpString[i++] & 0x0f); currentChar=currentChar<<6;
            currentChar+=(g_sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(g_sTmpString[i] & 0x3f);
            tmpCharLength = 2;
        } else if (((g_sTmpString[i]&0xF8) == 0xF0) && ((g_sTmpString[i+1]&0xC0) == 0x80) && ((g_sTmpString[i+2]&0xC0) == 0x80) && ((g_sTmpString[i+3]&0xC0) == 0x80)) // four byte character?
        {
            currentChar=(g_sTmpString[i++] & 0x07); currentChar=currentChar<<6;
            currentChar+=(g_sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(g_sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(g_sTmpString[i] & 0x3f);
            tmpCharLength = 3;
        } else 
        {
            currentChar=CHARTHRESHOLD + 1; // reaching this may be caused by bug in sourcemod or some kind of bug using by the user - for unicode users I do assume last ...
            tmpCharLength = 0;
        }
        
        // decide if character is allowed
        if (currentChar > CHARTHRESHOLD)
        {
            uni++;
            // replace this character // 95 = _, 32 = space
            for (new j=tmpCharLength; j >= 0; j--) {
                g_sTmpString[i - j] = 95; 
            }
        }
    }
}


/*
enum _:WeaponId
{
    WEPID_NONE,                 // 0
    WEPID_PISTOL,               // 1
    WEPID_SMG,                  // 2
    WEPID_PUMPSHOTGUN,          // 3
    WEPID_AUTOSHOTGUN,          // 4
    WEPID_RIFLE,                // 5
    WEPID_HUNTING_RIFLE,        // 6
    WEPID_SMG_SILENCED,         // 7
    WEPID_SHOTGUN_CHROME,       // 8
    WEPID_RIFLE_DESERT,         // 9
    WEPID_SNIPER_MILITARY,      // 10
    WEPID_SHOTGUN_SPAS,         // 11
    WEPID_FIRST_AID_KIT,        // 12
    WEPID_MOLOTOV,              // 13
    WEPID_PIPE_BOMB,            // 14
    WEPID_PAIN_PILLS,           // 15
    WEPID_GASCAN,               // 16
    WEPID_PROPANE_TANK,         // 17
    WEPID_OXYGEN_TANK,          // 18
    WEPID_MELEE,                // 19
    WEPID_CHAINSAW,             // 20    
    WEPID_GRENADE_LAUNCHER,     // 21
    WEPID_AMMO_PACK,            // 22
    WEPID_ADRENALINE,           // 23
    WEPID_DEFIBRILLATOR,        // 24
    WEPID_VOMITJAR,             // 25 
    WEPID_RIFLE_AK47,           // 26
    WEPID_GNOME_CHOMPSKI,       // 27
    WEPID_COLA_BOTTLES,         // 28
    WEPID_FIREWORKS_BOX,        // 29
    WEPID_INCENDIARY_AMMO,      // 30
    WEPID_FRAG_AMMO,        // 31
    WEPID_PISTOL_MAGNUM,    // 32
    WEPID_SMG_MP5,             // 33
    WEPID_RIFLE_SG552,         // 34
    WEPID_SNIPER_AWP,         // 35
    WEPID_SNIPER_SCOUT,     // 36
    WEPID_RIFLE_M60,        // 37
    WEPID_TANK_CLAW,        // 38
    WEPID_HUNTER_CLAW,        // 39
    WEPID_CHARGER_CLAW,        // 40
    WEPID_BOOMER_CLAW,        // 41
    WEPID_SMOKER_CLAW,        // 42
    WEPID_SPITTER_CLAW,        // 43
    WEPID_JOCKEY_CLAW,        // 44
    WEPID_MACHINEGUN,        // 45
    WEPID_FATAL_VOMIT,        // 46
    WEPID_EXPLODING_SPLAT,    // 47
    WEPID_LUNGE_POUNCE,        // 48
    WEPID_LOUNGE,            // 49
    WEPID_FULLPULL,            // 50
    WEPID_CHOKE,            // 51
    WEPID_THROWING_ROCK,    // 52
    WEPID_TURBO_PHYSICS,    // 53 what is this
    WEPID_AMMO,                // 54
    WEPID_UPGRADE_ITEM        // 55
};
*/