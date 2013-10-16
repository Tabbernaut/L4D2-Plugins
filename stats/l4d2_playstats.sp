#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
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

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8
#define ZC_NOTINFECTED          9
#define ZC_TOTAL                7

#define CONBUFSIZE              (1 << 10)       // 1k
#define CONBUFSIZELARGE         (1 << 14)       // 16k
#define CHARTHRESHOLD           160             // detecting unicode stuff

#define MAXTRACKED              64
#define MAXROUNDS               48              // ridiculously high, but just in case players do a marathon or something

#define MAXNAME                 64
#define MAXCHARACTERS           4
#define MAXMAP                  32
#define MAXGAME                 24

#define STATS_RESET_DELAY       5.0
#define ROUNDEND_DELAY          3.0
#define ROUNDEND_DELAY_SCAV     2.0

#define WP_MELEE                19
#define WP_PISTOL               1
#define WP_PISTOL_MAGNUM        32
#define WP_SMG                  2
#define WP_SMG_SILENCED         7
#define WP_HUNTING_RIFLE        6
#define WP_SNIPER_MILITARY      10
#define WP_PUMPSHOTGUN          3
#define WP_SHOTGUN_CHROME       8
#define WP_AUTOSHOTGUN          4
#define WP_SHOTGUN_SPAS         11
#define WP_RIFLE                5
#define WP_RIFLE_DESERT         9
#define WP_RIFLE_AK47           26
#define WP_MOLOTOV              13
#define WP_PIPE_BOMB            14
#define WP_VOMITJAR             25
#define WP_SMG_MP5              33
#define WP_RIFLE_SG552          34
#define WP_SNIPER_AWP           35
#define WP_SNIPER_SCOUT         36
#define WP_FIRST_AID_KIT        12
#define WP_PAIN_PILLS           15
#define WP_ADRENALINE           23
#define WP_MACHINEGUN           45

#define HITGROUP_HEAD           1

#define DMG_GENERIC             0               // generic damage was done
#define DMG_CRUSH               (1 << 0)        // crushed by falling or moving object. 
#define DMG_BULLET              (1 << 1)        // shot
#define DMG_SLASH               (1 << 2)        // cut, clawed, stabbed
#define DMG_BURN                (1 << 3)        // heat burned
#define DMG_BLAST               (1 << 6)        // explosive blast damage
#define DMG_CLUB                (1 << 7)        // crowbar, punch, headbutt
#define DMG_BUCKSHOT            (1 << 29)       // not quite a bullet. Little, rounder, different. 

#define FIRST_NON_BOT           4               // first index that doesn't belong to a survivor bot

#define TOTAL_FFGIVEN           0
#define TOTAL_FFTAKEN           1
#define FFTYPE_TOTAL            0
#define FFTYPE_PELLET           1
#define FFTYPE_BULLET           2
#define FFTYPE_SNIPER           3
#define FFTYPE_MELEE            4
#define FFTYPE_FIRE             5
#define FFTYPE_INCAP            6
#define FFTYPE_OTHER            7
#define FFTYPE_SELF             8
#define FFTYPE_MAX              9

#define SORT_SI                 0
#define SORT_CI                 1
#define SORT_FF                 2
#define MAXSORTS                3

#define LTEAM_A                 0
#define LTEAM_B                 1

#define BREV_SI                 (1 << 0)        // flags for MVP chat print appearance
#define BREV_CI                 (1 << 1)
#define BREV_FF                 (1 << 2)
#define BREV_RANK               (1 << 3)        // note: 16 reserved/removed
#define BREV_PERCENT            (1 << 5)
#define BREV_ABSOLUTE           (1 << 6)

#define AUTO_MVPCHAT_ROUND      (1 << 0)        // flags for what to print automatically at round end
#define AUTO_MVPCHAT_ALL        (1 << 1)
#define AUTO_MVPCON_ROUND       (1 << 2)
#define AUTO_MVPCON_ALL         (1 << 3)
#define AUTO_MVPCON_TANK        (1 << 4)
#define AUTO_FFCON_ROUND        (1 << 5)
#define AUTO_FFCON_ALL          (1 << 6)
#define AUTO_SKILLCON_ROUND     (1 << 7)
#define AUTO_SKILLCON_ALL       (1 << 8)
#define AUTO_ACCCON_ROUND       (1 << 9)
#define AUTO_ACCCON_ALL         (1 << 10)
#define AUTO_ACCCON_MORE_ROUND  (1 << 11)
#define AUTO_ACCCON_MORE_ALL    (1 << 12)
#define AUTO_FUNFACT_ROUND      (1 << 13)
#define AUTO_FUNFACT_ALL        (1 << 14)


/* new const String: g_cHitgroups[][] =
{
    "<generic>",
    "head",
    "chest",
    "stomach",
    "arm (l)",
    "arm (r)",
    "leg (l)",
    "leg (r)",
    "?",
    "?",
    "back"
};
*/

// types of statistic table(sets)
enum _:strStatType
{
    typGeneral,
    typMVP,
    typFF,
    typSkill,
    typAcc,
    typInf
};

// information for entire game
enum _:strGameData
{
            gmFailed,       // survivors lost the mission * times
            gmStartTime     // GetTime() value when starting
};

// information per round
enum _:strRoundData
{
            rndRestarts,     // how many times retried?
            rndPillsUsed,
            rndKitsUsed,
            rndDefibsUsed,
            rndCommon,
            rndSIKilled,
            rndWitchKilled,
            rndTankKilled,
            rndIncaps,
            rndDeaths,
            rndStartTime,   // GetTime() value when starting    
            rndEndTime      // GetTime() value when done
};
#define MAXRNDSTATS                 12

// information per player
enum _:strPlayerData
{
            plyShotsShotgun,        // 0 pellets
            plyShotsSmg,            // all bullets from smg/rifle
            plyShotsSniper,         // all bullets from snipers
            plyShotsPistol,         // all bullets from pistol/magnum
            plyHitsShotgun,
            plyHitsSmg,
            plyHitsSniper,
            plyHitsPistol,
            plyHeadshotsSmg,        // headshots for everything but on tank
            plyHeadshotsSniper,
            plyHeadshotsPistol,     // 10
            plyHeadshotsSISmg,      // headshots for SI only
            plyHeadshotsSISniper,
            plyHeadshotsSIPistol,
            plyHitsSIShotgun,       // all hits on special infected (not tank)
            plyHitsSISmg,
            plyHitsSISniper,
            plyHitsSIPistol,
            plyHitsTankShotgun,     // all hits on tank
            plyHitsTankSmg,         // useful for getting real headshot count (leave tank out of it)
            plyHitsTankSniper,      // 20
            plyHitsTankPistol,
            plyCommon,
            plyCommonTankUp,
            plySIKilled,
            plySIKilledTankUp,
            plySIDamage,
            plySIDamageTankUp,
            plyIncaps,
            plyDied,
            plySkeets,              // 30 skeets, full
            plySkeetsHurt,
            plySkeetsMelee,
            plyLevels,              // charger levels, full
            plyLevelsHurt,
            plyPops,                // boomer pops (pre puke)
            plyCrowns,
            plyCrownsHurt,          // non-full crowns 
            plyShoves,              // count every shove
            plyDeadStops,
            plyTongueCuts,          // 40 only real cuts
            plySelfClears,
            plyFallDamage,
            plyDmgTaken,
            plyFFGiven,
            plyFFTaken,
            plyFFHits,              // total amount of shotgun blasts / bullets / etc
            plyTankDamage,          // survivor damage to tank
            plyWitchDamage,
            plyMeleesOnTank,
            plyRockSkeets,          // 50
            plyRockEats,
            plyFFGivenPellet,
            plyFFGivenBullet,
            plyFFGivenSniper,
            plyFFGivenMelee,
            plyFFGivenFire,
            plyFFGivenIncap,
            plyFFGivenOther,
            plyFFGivenSelf,
            plyFFTakenPellet,       // 60
            plyFFTakenBullet,
            plyFFTakenSniper,
            plyFFTakenMelee,
            plyFFTakenFire,
            plyFFTakenIncap,
            plyFFTakenOther,
            plyFFGivenTotal,
            plyFFTakenTotal,
            plyHunterDPs,
            plyJockeyDPs            // 70
            
};
#define MAXPLYSTATS                 71

// trie values: weapon type (per accuracy-class)
enum strWeaponType
{
    WPTYPE_NONE,
    WPTYPE_SHOTGUN,
    WPTYPE_SMG,
    WPTYPE_SNIPER,
    WPTYPE_PISTOL
};

// trie values: OnEntityCreated classname
enum strOEC
{
    OEC_INFECTED
};

new     bool:   g_bLateLoad             = false;
new     bool:   g_bReadyUpAvailable     = false;
new     bool:   g_bSkillDetectLoaded    = false;

new     bool:   g_bModeCampaign         = false;
new     bool:   g_bModeScavenge         = false;

new     Handle: g_hCvarDebug            = INVALID_HANDLE;
new     Handle: g_hCvarMVPBrevityFlags  = INVALID_HANDLE;
new     Handle: g_hCvarAutoPrintVs      = INVALID_HANDLE;
new     Handle: g_hCvarAutoPrintCoop    = INVALID_HANDLE;


new     bool:   g_bGameStarted          = false;
new     bool:   g_bInRound              = false;
new     bool:   g_bTeamChanged          = false;                                        // to only do a teamcheck if a check is not already pending
new     bool:   g_bTankInGame           = false;
new     bool:   g_bPlayersLeftStart     = false;
new     bool:   g_bSecondHalf           = false;                                        // second roundhalf in a versus round
new             g_iRound                = 0;
new             g_iCurTeam              = LTEAM_A;                                      // current logical team
new             g_iTeamSize             = 4;

new             g_iPlayerIndexSorted    [MAXSORTS][MAXTRACKED];                         // used to create a sorted list
new             g_iPlayerCurrentTeam    [MAXTRACKED]                = {-1,...};         // which team is the player NOW on 0 = A, 1 = B, -1 = no team

new             g_strGameData           [strGameData];
new             g_strRoundData          [MAXROUNDS][2][strRoundData];                   // rounddata per game round, per team
new             g_strPlayerData         [MAXTRACKED][strPlayerData];
new             g_strRoundPlayerData    [MAXTRACKED][strPlayerData];

new             g_iFFDamageTotal;
new             g_iFFRoundDamageTotal;

new             g_iMVPSIDamageTotal     [2];                                            // damage totals for each team
new             g_iMVPCommonTotal       [2];                                            // common kill totals for each team
new             g_iMVPSIKilledTotal     [2];                                            // kill totals for each team
new             g_iMVPRoundSIDamageTotal[2];                                            // damage totals for each team, this round
new             g_iMVPRoundCommonTotal  [2];                                            // common kill totals for each team, this round
new             g_iMVPRoundSIKilledTotal[2];                                            // kill totals for each team, this round

new     Handle: g_hTriePlayers                                      = INVALID_HANDLE;   // trie for getting player index
new     Handle: g_hTrieWeapons                                      = INVALID_HANDLE;   // trie for getting weapon type (from classname)
new     Handle: g_hTrieEntityCreated                                = INVALID_HANDLE;   // trie for getting classname of entity created

new     String: g_sPlayerName           [MAXTRACKED][MAXNAME];
new     String: g_sMapName              [MAXROUNDS][MAXMAP];
new             g_iPlayers                                          = 0;

new     String: g_sConsoleBufGen        [CONBUFSIZELARGE]           = "";
new     String: g_sConsoleBufMVP        [CONBUFSIZELARGE]           = "";
new     String: g_sConsoleBufAcc        [CONBUFSIZELARGE]           = "";
new     String: g_sConsoleBufFFGiven    [CONBUFSIZELARGE]           = "";
new     String: g_sConsoleBufFFTaken    [CONBUFSIZELARGE]           = "";
new     String: g_sTmpString            [MAXNAME];


public Plugin: myinfo =
{
    name = "Player Statistics",
    author = "Tabun",
    description = "Tracks statistics, even when clients disconnect. MVP, Skills, Accuracy, etc.",
    version = "0.9.9",
    url = "https://github.com/Tabbernaut/L4D2-Plugins"
};


/*

    todo
    ----
        - automatic reports
            - add client-side override
        
        - skill
            - clears / average clear time

        - make infected skills table
                dps (hunter / jockey),
                dc's,
                damage done (to HB/DB)

        - hide 0 and 0.0% values from tables

        - count time active (live round, per team) [show in mvp?]

        - write CSV files per round -- db-ready
        
        - make confogl loading not cause round 1 to count...
            - if there were no stats, or the round was never started,
                survivors never left, or time was too short, reset it
            - listen to !forcematch / !match command and map restart after?
        
        - better 'team' checks, include players who were on the team
            - even if they switched after or went spec
            - rule: include everyone that was in the survivor team while the round was live
                    how to keep track?
        
        
        - hall of fame print, with only
            - most skeets (if any)
            - most levels (if any)
            - etc
        - if something special has triggered, show a single line with a 'fun fact':
            - skeet count > x
            - level count > x
            - crown count > x
            - ff > x % & absolute value
            - dp > absolute damage/height
            - jock dp > abs. height
        
        - fix: ff still will never display, even when using 'game'
        
        - timing for automatic print should be sooner: use door close (in versus)
        
        - mvp order is for game, not round.. fix
        
        - cut prints in chunks, paste the buffer per X lines
        
    details:
    --------
        - add lines in big tables so they're easier to read (every 4 rows)
        - make ### / ### => ### /####
        - move m2s/ds's to the far right of skills table
        
        
        
    ideas
    -----
    - instead of hits/shots, display average multiplier for shotgun pellets
        (can just do that per hitgroup, if we use what we know about the SI)
*/


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

// crox readyup usage
public OnAllPluginsLoaded()
{
    g_bReadyUpAvailable = LibraryExists("readyup");
    g_bSkillDetectLoaded = LibraryExists("skill_detect");
}
public OnLibraryRemoved(const String:name[])
{
    if ( StrEqual(name, "readyup") ) { g_bReadyUpAvailable = false; }
    if ( StrEqual(name, "skill_detect") ) { g_bSkillDetectLoaded = false; }
}
public OnLibraryAdded(const String:name[])
{
    if ( StrEqual(name, "readyup") ) { g_bReadyUpAvailable = true; }
    if ( StrEqual(name, "skill_detect") ) { g_bSkillDetectLoaded = true; }
}


public OnPluginStart()
{
    // events    
    HookEvent("round_start",                Event_RoundStart,               EventHookMode_PostNoCopy);
    HookEvent("scavenge_round_start",       Event_RoundStart,               EventHookMode_PostNoCopy);
    HookEvent("round_end",                  Event_RoundEnd,                 EventHookMode_PostNoCopy);
    
    HookEvent("mission_lost",               Event_MissionLostCampaign,      EventHookMode_Post);
    HookEvent("map_transition",             Event_MapTransition,            EventHookMode_PostNoCopy);
    HookEvent("finale_win",                 Event_FinaleWin,                EventHookMode_PostNoCopy);
    
    HookEvent("player_team",                Event_PlayerTeam,               EventHookMode_Post);
    HookEvent("player_spawn",               Event_PlayerSpawn,              EventHookMode_Post);
    HookEvent("player_hurt",                Event_PlayerHurt,               EventHookMode_Post);
    HookEvent("player_death",               Event_PlayerDeath,              EventHookMode_Post);
    HookEvent("player_incapacitated",       Event_PlayerIncapped,           EventHookMode_Post);
    HookEvent("player_falldamage",          Event_PlayerFallDamage,         EventHookMode_Post);
    
    HookEvent("weapon_fire",                Event_WeaponFire,               EventHookMode_Post);
    HookEvent("infected_hurt",              Event_InfectedHurt,             EventHookMode_Post);
    HookEvent("witch_killed",               Event_WitchKilled,              EventHookMode_Post);
    HookEvent("heal_success",               Event_HealSuccess,              EventHookMode_Post);
    HookEvent("defibrillator_used",         Event_DefibUsed,                EventHookMode_Post);
    HookEvent("pills_used",                 Event_PillsUsed,                EventHookMode_Post);
    HookEvent("adrenaline_used",            Event_AdrenUsed,                EventHookMode_Post);
    
    //HookEvent("player_left_checkpoint",     Event_ExitedSaferoom,           EventHookMode_Post);
    //HookEvent("player_entered_checkpoint",  Event_EnteredSaferoom,          EventHookMode_Post);
    //HookEvent("door_close",                 Event_DoorClose,                EventHookMode_PostNoCopy );
    //HookEvent("finale_vehicle_leaving",     Event_FinaleVehicleLeaving,     EventHookMode_PostNoCopy );
    
    
    // cvars
    g_hCvarDebug = CreateConVar( "cstat_debug", "2", "Debug mode", FCVAR_PLUGIN, true, -1.0, false);
    g_hCvarMVPBrevityFlags = CreateConVar( "sm_survivor_mvp_brevity", "4", "Flags for setting brevity of MVP chat report (hide 1:SI, 2:CI, 4:FF, 8:rank, 32:perc, 64:abs).", FCVAR_PLUGIN, true, 0.0);
    g_hCvarAutoPrintVs = CreateConVar(   "sm_stats_autoprint_vs_round",    "133", "Flags for automatic print [versus round] (show 1,4:MVP-chat, 4,8,16:MVP-console, 32,64:FF, 128,256:special, 512,1024,2048,4096:accuracy).", FCVAR_PLUGIN, true, 0.0);
    //  default = 1 (mvpchat) + 4 (mvpcon-round) + 128 (special round) = 133
    g_hCvarAutoPrintCoop = CreateConVar( "sm_stats_autoprint_coop_round", "1289", "Flags for automatic print [campaign round] (show 1,4:MVP-chat, 4,8,16:MVP-console, 32,64:FF, 128,256:special, 512,1024,2048,4096:accuracy).", FCVAR_PLUGIN, true, 0.0);
    //  default = 1 (mvpchat) + 8 (mvpcon-all) + 256 (special all) + 1024 (acc all) = 1289
    
    g_iTeamSize = 4;
    
    
    // commands:
    RegConsoleCmd( "sm_stats",      Cmd_StatsDisplayGeneral,    "Prints stats for survivors" );
    RegConsoleCmd( "sm_mvp",        Cmd_StatsDisplayGeneral,    "Prints MVP stats for survivors" );
    RegConsoleCmd( "sm_skill",      Cmd_StatsDisplayGeneral,    "Prints special skills stats for survivors" );
    RegConsoleCmd( "sm_ff",         Cmd_StatsDisplayGeneral,    "Prints friendly fire stats stats" );
    RegConsoleCmd( "sm_acc",        Cmd_StatsDisplayGeneral,    "Prints accuracy stats for survivors" );
    
    RegAdminCmd( "statsreset",      Cmd_StatsReset, ADMFLAG_CHANGEMAP, "Resets the statistics. Admins only." );
    
    RegConsoleCmd( "say",           Cmd_Say );
    RegConsoleCmd( "say_team",      Cmd_Say );
    
    // tries
    InitTries();
    
    if ( g_bLateLoad )
    {
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) && !IsFakeClient(i) )
            {
                // store each player with a first check
                GetPlayerIndexForClient( i );
                //SDKHook(i, SDKHook_TraceAttack, TraceAttack);
            }
        }
        
        UpdatePlayerCurrentTeam();
        
        // just assume this
        g_bInRound = true;
        g_bPlayersLeftStart = true;
    }
}

public OnConfigsExecuted()
{
    g_iTeamSize = GetConVarInt( FindConVar("survivor_limit") );
}

// find a player
public OnClientPostAdminCheck( client )
{
    GetPlayerIndexForClient( client );
    //SDKHook(client, SDKHook_TraceAttack, TraceAttack);
}


public OnMapStart()
{
    GetCurrentMap( g_sMapName[g_iRound], MAXMAP );
    //PrintDebug( 2, "MapStart (round %i): %s ", g_iRound, g_sMapName[g_iRound] );
    
    g_bSecondHalf = false;
    
    CheckGameMode();
}

public OnMapEnd()
{
    //PrintDebug(2, "MapEnd (round %i)", g_iRound);
    g_bInRound = false;
    g_iRound++;
}

public Event_MissionLostCampaign (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    g_bPlayersLeftStart = false;
    
    g_strGameData[gmFailed]++;
    g_strRoundData[g_iRound][g_iCurTeam][rndRestarts]++;
}

public Event_RoundStart (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    if ( !g_bInRound ) { g_bInRound = true; }
    
    // easier to handle: store current survivor team
    g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
    
    // reset stats for this round
    CreateTimer( STATS_RESET_DELAY, Timer_ResetStats, 1, TIMER_FLAG_NO_MAPCHANGE );
}

public Event_RoundEnd (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // called on versus round end
    // and mission failed coop
    
    AutomaticRoundEndPrint( false );
    
    g_bInRound = false;
    g_bSecondHalf = true;
}

/*
public Event_ExitedSaferoom (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // campaign (ignore in versus)
    //PrintDebug(0, "Event: Exited Saferoom / Checkpoint");
}
public Event_EnteredSaferoom (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // campaign (ignore in versus)
    //PrintDebug(0, "Event: Entered Saferoom / Checkpoint");
}
*/

public Event_MapTransition (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // campaign (ignore in versus)
    if ( g_bModeCampaign ) {
        AutomaticRoundEndPrint(false);  // no delay for this one
    }
}
public Event_FinaleWin (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // campaign (ignore in versus)
    if ( g_bModeCampaign ) {
        AutomaticRoundEndPrint(false);
    }
    //AutomaticGameEndPrint();
}

public OnRoundIsLive()
{
    // only called if readyup is available
    RoundReallyStarting();
}

public Action: L4D_OnFirstSurvivorLeftSafeArea( client )
{
    // if no readyup, use this as the starting event
    if ( !g_bReadyUpAvailable )
    {
        RoundReallyStarting();
    }
}

stock RoundReallyStarting()
{
    g_bPlayersLeftStart = true;
        
    if ( !g_bGameStarted )
    {
        g_bGameStarted = true;
        g_strGameData[gmStartTime] = GetTime();
    }
    
    if ( g_strRoundData[g_iRound][g_iCurTeam][rndRestarts] == 0 )
    {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] = GetTime();
    }
    
    // make sure the teams are still what we think they are
    UpdatePlayerCurrentTeam();
}

/*
    Commands
    --------
*/

public Action: Cmd_Say ( client, args )
{
    // catch and hide !<command>s
    if (!client) { return Plugin_Continue; }
    
    decl String:sMessage[MAX_NAME_LENGTH];
    GetCmdArg(1, sMessage, sizeof(sMessage));
    
    if (    StrEqual(sMessage, "!mvp")   ||
            StrEqual(sMessage, "!ff")    ||
            StrEqual(sMessage, "!stats")
    ) {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action: Cmd_StatsDisplayGeneral ( client, args )
{
    // determine main type
    new iType = typGeneral;
    
    new String: sArg[24];
    GetCmdArg( 0, sArg, sizeof(sArg) );
    
    // determine main type (the command typed)
    PrintToChatAll("test: %s", sArg);
    
    if ( StrEqual(sArg, "stats", false) ) { iType = typMVP; }
    else if ( StrEqual(sArg, "mvp", false) ) { iType = typMVP; }
    else if ( StrEqual(sArg, "ff", false) ) { iType = typFF; }
    else if ( StrEqual(sArg, "skill", false) || StrEqual(sArg, "special", false) || StrEqual(sArg, "s", false) ) { iType = typSkill; }
    else if ( StrEqual(sArg, "acc", false) || StrEqual(sArg, "accuracy", false) || StrEqual(sArg, "ac", false) ) { iType = typAcc; }
    else if ( StrEqual(sArg, "inf", false) || StrEqual(sArg, "i", false) ) { iType = typAcc; }
    
    new bool:bSetRound, bool:bRound = true;
    new bool:bSetGame,  bool:bGame = false;
    new bool:bSetAll,   bool:bAll = false;
    new bool:bSetTeam,  bool:bTeam = true;
    new bool:bTank = false;
    new bool:bMore = false;
    new iStart = 1;
    
    
    if ( args )
    {
        GetCmdArg( 1, sArg, sizeof(sArg) );
        
        // find type selection (always 1)
        if ( StrEqual(sArg, "help", false) || StrEqual(sArg, "?", false) )
        {
            // show help
            if ( IS_VALID_INGAME(client) ) {
                PrintToChat( client, "\x01Use: /stats [<type>] [\x05round\x01/\x05game\x01/\x05team\x01/\x05all\x01]" );
                PrintToChat( client, "\x01 or: /stats [<type>] [\x05r\x01/\x05g\x01/\x05t\x01/\x05a\x01]" );
                PrintToChat( client, "\x01 where <type> is '\x04mvp\x01', '\x04skill\x01', '\x04ff\x01', '\x04acc\x01' or '\x04inf\x01'. (for more, see console)" );
            }
            
            decl String:bufBasic[CONBUFSIZELARGE];
            Format(bufBasic, CONBUFSIZELARGE,    "|------------------------------------------------------------------------------|\n");
            Format(bufBasic, CONBUFSIZELARGE,  "%s| /stats command help      in chat:    '/stats <type> [argument [argument]]'   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|                          in console: 'sm_stats <type> [arguments...]'        |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s| stat type:   'general':  general statistics about the game, as in campaign   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|              'mvp'    :  SI damage, common kills    (extra argument: 'tank') |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|              'skill'  :  skeets, levels, crowns, tongue cuts, etc            |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|              'ff'     :  friendly fire damage (per type of weapon)           |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|              'acc'    :  accuracy details           (extra argument: 'more') |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|", bufBasic);
            if ( IS_VALID_INGAME(client) ) { PrintToConsole( client, bufBasic); } else { PrintToServer( bufBasic); }
            Format(bufBasic, CONBUFSIZELARGE,    "| examples:                                                                    |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats skill round all' => shows skeets etc for all players, this round   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats ff team game'    => shows friendly fire for your team, this round  |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats acc'             => shows accuracy stats (your team, this round)   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats mvp tank'        => shows survivor action while tank is/was up     |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|", bufBasic);
            if ( IS_VALID_INGAME(client) ) { PrintToConsole( client, bufBasic); } else { PrintToServer( bufBasic); }
            return Plugin_Handled;
        }
        else if ( StrEqual(sArg, "mvp", false) ) { iType = typMVP; }
        else if ( StrEqual(sArg, "ff", false) ) { iType = typFF; }
        else if ( StrEqual(sArg, "skill", false) || StrEqual(sArg, "special", false) || StrEqual(sArg, "s", false) ) { iType = typSkill; }
        else if ( StrEqual(sArg, "acc", false) || StrEqual(sArg, "accuracy", false) || StrEqual(sArg, "ac", false) ) { iType = typAcc; }
        else if ( StrEqual(sArg, "inf", false) || StrEqual(sArg, "i", false) ) { iType = typAcc; }
        else if ( StrEqual(sArg, "general", false) || StrEqual(sArg, "gen", false) ) { iType = typGeneral; iStart++; }
        
        // if not general, we know the first was a different type indicator
        if ( iType != typGeneral ) { iStart++; }
        
        // check each other argument and see what we find
        for ( new i = iStart; i <= args; i++ )
        {
            GetCmdArg( i, sArg, sizeof(sArg) );
            
            if ( StrEqual(sArg, "round", false)     || StrEqual(sArg, "r", false) ) {
                bSetRound = true; bRound = true;
            }
            else if ( StrEqual(sArg, "game", false) || StrEqual(sArg, "g", false) ) {
                bSetGame = true; bGame = true;
            }
            else if ( StrEqual(sArg, "all", false)  || StrEqual(sArg, "a", false) ) {
                bSetAll = true; bAll = true;
            }
            else if ( StrEqual(sArg, "team", false) || StrEqual(sArg, "t", false) ) {
                bSetTeam = true; bTeam = true;
            }
            else if ( StrEqual(sArg, "more", false) || StrEqual(sArg, "m", false) ) {
                bMore = true;
            }
            else if ( StrEqual(sArg, "tank", false) ) {
                bTank = true;
            }
            else {
                if ( IS_VALID_INGAME(client) ) {
                    PrintToChat( client, "Stats command: unknown argument: '%s'. Type '/stats help' for possible arguments.", sArg );
                } else {
                    PrintToServer( "Stats command: unknown argument: '%s'. Type '/stats help' for possible arguments.", sArg );
                }
            }
        }
    }
    
    switch ( iType )
    {
        case typGeneral:
        {
            // game by default, unless overridden by 'round'
            DisplayStats( client, ( bSetRound && bRound ) ? true : false, ( bSetAll && bAll ) ? false : true );
        }
        
        case typMVP:
        {
            // by default: only for round
            DisplayStatsMVP( client, bTank, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true );
            // only show chat for non-tank table
            if ( !bTank ) {
                DisplayStatsMVPChat( client, ( bSetGame && bGame ) ? false : true );
            }
        }
        
        case typFF:
        {
            // by default: only for round
            DisplayStatsFriendlyFire( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true );
        }
        
        case typSkill:
        {
            // by default: only for round
            DisplayStatsSpecial( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true );
        }
        
        case typAcc:
        {
            // by default: only for round
            DisplayStatsAccuracy( client, bMore, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true );
        }
        
        case typInf:
        {
            // To do
            PrintToChat( client, "Work in progress. Not done yet." );
        }
    }
    
    return Plugin_Handled;
}

public Action: Cmd_StatsReset ( client, args )
{
    ResetStats();
    PrintToChatAll( "Player statistics reset." );
    return Plugin_Handled;
}

/*
    Tracking
    --------
*/
public Action: Event_PlayerTeam ( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
    //new client = GetClientOfUserId( GetEventInt(hEvent, "userid") );
    //if ( !IS_VALID_INGAME(client) ) { return Plugin_Continue; }
    //new newTeam = GetEventInt(hEvent, "team");
    //new oldTeam = GetEventInt(hEvent, "oldteam");
    
    if ( !g_bTeamChanged )
    {
        g_bTeamChanged = true;
        CreateTimer( 0.5, Timer_TeamChanged, _, TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action: Timer_TeamChanged (Handle:timer)
{
    g_bTeamChanged = false;
    UpdatePlayerCurrentTeam();
}

public Action: Event_PlayerHurt ( Handle:event, const String:name[], bool:dontBroadcast )
{
    if ( !g_bPlayersLeftStart ) { return Plugin_Continue; }
    
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    
    new damage = GetEventInt(event, "dmg_health");
    new attIndex, vicIndex;
    new team;
    
    // only record survivor-to-survivor damage done by humans
    if ( IS_VALID_SURVIVOR(attacker) && IS_VALID_INFECTED(victim) )
    {
        if ( damage < 1 ) { return Plugin_Continue; }
        
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return Plugin_Continue; }
        
        team = GetCurrentTeamSurvivor();
        new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        
        if ( zClass >= ZC_SMOKER && zClass <= ZC_CHARGER )
        {
            if ( g_bTankInGame )
            {
                g_strPlayerData[attIndex][plySIDamageTankUp] += damage;
                g_strRoundPlayerData[attIndex][plySIDamageTankUp] += damage;
            }
            
            g_strPlayerData[attIndex][plySIDamage] += damage;
            g_strRoundPlayerData[attIndex][plySIDamage] += damage;
            g_iMVPSIDamageTotal[team] += damage;
            g_iMVPRoundSIDamageTotal[team] += damage;
        }
        else if ( zClass == ZC_TANK && damage != 5000) // For some reason the last attacker does 5k damage?
        {
            new type = GetEventInt(event, "type");
            
            if ( type & DMG_CLUB || type & DMG_SLASH )
            {
                g_strPlayerData[attIndex][plyMeleesOnTank]++;
                g_strRoundPlayerData[attIndex][plyMeleesOnTank]++;
            }
            
            g_strPlayerData[attIndex][plyTankDamage] += damage;
            g_strRoundPlayerData[attIndex][plyTankDamage] += damage;
        }
    }
    else if ( IS_VALID_SURVIVOR(victim) && IS_VALID_SURVIVOR(attacker) && !IsFakeClient(attacker) )
    {
        // friendly fire
        
        new type = GetEventInt(event, "type");
        if ( damage < 1 ) { return Plugin_Continue; }
        
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return Plugin_Continue; }
        
        if ( attacker == victim )
        {
            vicIndex = attIndex;
        }
        else
        {
            vicIndex = GetPlayerIndexForClient( victim );
            if ( vicIndex == -1 ) { return Plugin_Continue; }
        }
        
        // record amounts
        g_iFFDamageTotal += damage;
        g_iFFRoundDamageTotal += damage;
        
        g_strPlayerData[attIndex][plyFFGivenTotal] += damage;
        g_strRoundPlayerData[attIndex][plyFFGivenTotal] += damage;
        g_strPlayerData[vicIndex][plyFFTakenTotal] += damage;
        g_strRoundPlayerData[vicIndex][plyFFTakenTotal] += damage;
        
        if ( attIndex == vicIndex ) {
            // damage to self
        }
        else if ( IsPlayerIncapacitated(victim) )
        {
            // don't count incapped damage for 'ffgiven' / 'fftaken'
            
            g_strPlayerData[attIndex][plyFFGivenIncap] += damage;
            g_strRoundPlayerData[attIndex][plyFFGivenIncap] += damage;
            g_strPlayerData[vicIndex][plyFFTakenIncap] += damage;
            g_strRoundPlayerData[vicIndex][plyFFTakenIncap] += damage;
        }
        else
        {
            g_strPlayerData[attIndex][plyFFGiven] += damage;           // only count non-incapped for this
            g_strRoundPlayerData[attIndex][plyFFGiven] += damage;
            if ( attIndex != vicIndex ) {
                g_strPlayerData[vicIndex][plyFFTaken] += damage;
                g_strRoundPlayerData[vicIndex][plyFFTaken] += damage;
            }
            
            // which type to save it to?
            if ( type & DMG_BURN )
            {
                g_strPlayerData[attIndex][plyFFGivenFire] += damage;
                g_strRoundPlayerData[attIndex][plyFFGivenFire] += damage;
                g_strPlayerData[vicIndex][plyFFTakenFire] += damage;
                g_strRoundPlayerData[vicIndex][plyFFTakenFire] += damage;
            }
            else if ( type & DMG_BUCKSHOT )
            {
                g_strPlayerData[attIndex][plyFFGivenPellet] += damage;
                g_strRoundPlayerData[attIndex][plyFFGivenPellet] += damage;
                g_strPlayerData[vicIndex][plyFFTakenPellet] += damage;
                g_strRoundPlayerData[vicIndex][plyFFTakenPellet] += damage;
            }
            else if ( type & DMG_CLUB || type & DMG_SLASH )
            {
                g_strPlayerData[attIndex][plyFFGivenMelee] += damage;
                g_strRoundPlayerData[attIndex][plyFFGivenMelee] += damage;
                g_strPlayerData[vicIndex][plyFFTakenMelee] += damage;
                g_strRoundPlayerData[vicIndex][plyFFTakenMelee] += damage;
            }
            else if ( type & DMG_BULLET )
            {
                g_strPlayerData[attIndex][plyFFGivenBullet] += damage;
                g_strRoundPlayerData[attIndex][plyFFGivenBullet] += damage;
                g_strPlayerData[vicIndex][plyFFTakenBullet] += damage;
                g_strRoundPlayerData[vicIndex][plyFFTakenBullet] += damage;
            }
            else
            {
                g_strPlayerData[attIndex][plyFFGivenOther] += damage;
                g_strRoundPlayerData[attIndex][plyFFGivenOther] += damage;
                g_strPlayerData[vicIndex][plyFFTakenOther] += damage;
                g_strRoundPlayerData[vicIndex][plyFFTakenOther] += damage;
            }
        }
        
    }
    else if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) )
    {
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return Plugin_Continue; }
        
        g_strPlayerData[vicIndex][plyDmgTaken] += damage;           // only count non-incapped for this
        g_strRoundPlayerData[vicIndex][plyDmgTaken] += damage;
    }
    
    return Plugin_Continue;
}

public Action: Event_InfectedHurt ( Handle:event, const String:name[], bool:dontBroadcast )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    // catch damage done to witch
    new entity = GetEventInt(event, "entityid");
    
    if ( IsWitch(entity) )
    {
        new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
        if ( !IS_VALID_SURVIVOR(attacker) ) { return; }
        new attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return; }
        
        new damage = GetEventInt(event, "amount");
        
        g_strPlayerData[attIndex][plyWitchDamage] += damage;
        g_strRoundPlayerData[attIndex][plyWitchDamage] += damage;
    }
}
public Action: Event_PlayerFallDamage ( Handle:event, const String:name[], bool:dontBroadcast )
{
    if ( !g_bPlayersLeftStart ) { return Plugin_Continue; }
    
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    if ( !IS_VALID_SURVIVOR(victim) ) { return Plugin_Continue; }
    
    new damage = GetEventInt(event, "damage");
    new index = GetPlayerIndexForClient( victim );
    if ( index == -1 ) { return Plugin_Continue; }
    
    g_strRoundPlayerData[index][plyFallDamage] += damage;
    g_strPlayerData[index][plyFallDamage] += damage;
    
    return Plugin_Continue;
}

public Action: Event_WitchKilled ( Handle:event, const String:name[], bool:dontBroadcast )
{
    g_strRoundData[g_iRound][g_iCurTeam][rndWitchKilled]++;
}

public Action: Event_PlayerDeath ( Handle:event, const String:name[], bool:dontBroadcast )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new index, attacker, team;
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        // survivor died
        
        g_strRoundData[g_iRound][g_iCurTeam][rndDeaths]++;
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        g_strRoundPlayerData[index][plyDied]++;
        g_strPlayerData[index][plyDied]++;
    }
    else if ( IS_VALID_INFECTED(client) )
    {
        // special infected died (check for tank)
        
        if ( GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK )
        {
            // check if it really died
            CreateTimer( 0.1, Timer_CheckTankDeath, client );
        }
        else
        {
            team = GetCurrentTeamSurvivor();
            
            g_strRoundData[g_iRound][g_iCurTeam][rndSIKilled]++;
            //g_iMVPCommonTotal[team]++;
            //g_iMVPRoundCommonTotal[team]++;
            
            attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
            
            if ( IS_VALID_SURVIVOR(attacker) )
            {
                index = GetPlayerIndexForClient( attacker );
                if ( index == -1 ) { return; }
                
                g_strRoundPlayerData[index][plySIKilled]++;
                g_strPlayerData[index][plySIKilled]++;
                g_iMVPSIKilledTotal[team]++;
                g_iMVPRoundSIKilledTotal[team]++;
                
                if ( g_bTankInGame )
                { 
                    g_strRoundPlayerData[index][plySIKilledTankUp]++;
                    g_strPlayerData[index][plySIKilledTankUp]++;
                }
            }
        }
    }
    else if ( !client )
    {
        // common infected died (check for witch)
        
        new common = GetEventInt(event, "entityid");
        attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
        
        if ( !IsWitch(common) )
        {
            team = GetCurrentTeamSurvivor();
            
            g_strRoundData[g_iRound][g_iCurTeam][rndCommon]++;
            g_iMVPCommonTotal[team]++;
            g_iMVPRoundCommonTotal[team]++;
            
            if ( IS_VALID_SURVIVOR(attacker) )
            {
                index = GetPlayerIndexForClient( attacker );
                if ( index == -1 ) { return; }
                
                g_strRoundPlayerData[index][plyCommon]++;
                g_strPlayerData[index][plyCommon]++;
                
                if ( g_bTankInGame ) {
                    g_strRoundPlayerData[index][plyCommonTankUp]++;
                    g_strPlayerData[index][plyCommonTankUp]++;
                }
            }
        }
    }
}
public Action: Timer_CheckTankDeath ( Handle:hTimer, any:client_oldTank )
{
    if ( !IsTankInGame() )
    {
        // tank died
        g_strRoundData[g_iRound][g_iCurTeam][rndTankKilled]++;
        g_bTankInGame = false;
    }
}
public Action: Event_TankSpawned( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
    //new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    g_bTankInGame = true;
}

public Action: Event_PlayerIncapped (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        g_strRoundData[g_iRound][g_iCurTeam][rndIncaps]++;
        
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        g_strRoundPlayerData[index][plyIncaps]++;
        g_strPlayerData[index][plyIncaps]++;
    }
}


public Action: Event_DefibUsed (Handle:event, const String:name[], bool:dontBroadcast)
{
    g_strRoundData[g_iRound][g_iCurTeam][rndDefibsUsed]++;
}
public Action: Event_HealSuccess (Handle:event, const String:name[], bool:dontBroadcast)
{
    g_strRoundData[g_iRound][g_iCurTeam][rndKitsUsed]++;
}
public Action: Event_PillsUsed (Handle:event, const String:name[], bool:dontBroadcast)
{
    g_strRoundData[g_iRound][g_iCurTeam][rndPillsUsed]++;
}
public Action: Event_AdrenUsed (Handle:event, const String:name[], bool:dontBroadcast)
{
    g_strRoundData[g_iRound][g_iCurTeam][rndPillsUsed]++;
}

// keep track of shots fired
public Action: Event_WeaponFire (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    if ( !IS_VALID_SURVIVOR(client) || !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    new weaponId = GetEventInt(event, "weaponid");
    
    if ( weaponId == WP_PISTOL || weaponId == WP_PISTOL_MAGNUM )
    {
        g_strRoundPlayerData[index][plyShotsPistol]++;
        g_strPlayerData[index][plyShotsPistol]++;
    }
    else if (   weaponId == WP_SMG || weaponId == WP_SMG_SILENCED || weaponId == WP_SMG_MP5 ||
                weaponId == WP_RIFLE || weaponId == WP_RIFLE_DESERT || weaponId == WP_RIFLE_AK47 || weaponId == WP_RIFLE_SG552
    ) {
        g_strRoundPlayerData[index][plyShotsSmg]++;
        g_strPlayerData[index][plyShotsSmg]++;
    }
    else if (   weaponId == WP_PUMPSHOTGUN || weaponId == WP_SHOTGUN_CHROME ||
                weaponId == WP_AUTOSHOTGUN || weaponId == WP_SHOTGUN_SPAS
    ) {
        // get pellets
        new count = GetEventInt(event, "count");
        g_strRoundPlayerData[index][plyShotsShotgun] += count;
        g_strPlayerData[index][plyShotsShotgun] += count;
    }
    else if (   weaponId == WP_HUNTING_RIFLE || weaponId == WP_SNIPER_MILITARY  ||
                weaponId == WP_SNIPER_AWP || weaponId == WP_SNIPER_SCOUT
    ) {
        g_strRoundPlayerData[index][plyShotsSniper]++;
        g_strPlayerData[index][plyShotsSniper]++;
    }
    else if (weaponId == WP_MELEE)
    {
        //g_strPlayerData[index][plyShotsPistol]++;
    }
    
    // ignore otherwise
}



// special / tank gets hit
public Action: TraceAttack_Special (victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if ( !g_bPlayersLeftStart ) { return; }
    if ( !IS_VALID_SURVIVOR(attacker) || !IsValidEdict(inflictor) ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    new weaponType = WPTYPE_NONE;
    
    // get weapon type
    if ( damagetype & DMG_BUCKSHOT )
    {
        weaponType = WPTYPE_SHOTGUN;
    }
    else if ( damagetype & DMG_BULLET )
    {
        decl String:weaponname[48];
        GetClientWeapon(attacker, weaponname, sizeof(weaponname));
        weaponType = GetWeaponTypeForClassname(weaponname);
    }
    else {
        // not handling anything else
        return;
    }
    
    
    //PrintToChatAll("special hit: weptype %i hit: %i", weaponType, hitgroup );
    
    // count hits
    switch ( weaponType )
    {
        case WPTYPE_SHOTGUN: {  g_strPlayerData[index][plyHitsShotgun]++; g_strPlayerData[index][plyHitsSIShotgun]++;   g_strRoundPlayerData[index][plyHitsShotgun]++; g_strRoundPlayerData[index][plyHitsSIShotgun]++; }
        case WPTYPE_SMG: {      g_strPlayerData[index][plyHitsSmg]++;     g_strPlayerData[index][plyHitsSISmg]++;       g_strRoundPlayerData[index][plyHitsSmg]++;     g_strRoundPlayerData[index][plyHitsSISmg]++; }
        case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHitsSniper]++;  g_strPlayerData[index][plyHitsSISniper]++;    g_strRoundPlayerData[index][plyHitsSniper]++;  g_strRoundPlayerData[index][plyHitsSISniper]++; }
        case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHitsPistol]++;  g_strPlayerData[index][plyHitsSIPistol]++;    g_strRoundPlayerData[index][plyHitsPistol]++;  g_strRoundPlayerData[index][plyHitsSIPistol]++; }
    }
    
    // headshots on anything but tank, separately store hits for tank
    if ( GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_TANK )
    {
        switch ( weaponType )
        {
            case WPTYPE_SHOTGUN: {  g_strPlayerData[index][plyHitsTankShotgun]++;   g_strRoundPlayerData[index][plyHitsTankShotgun]++; }
            case WPTYPE_SMG: {      g_strPlayerData[index][plyHitsTankSmg]++;       g_strRoundPlayerData[index][plyHitsTankSmg]++; }
            case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHitsTankSniper]++;    g_strRoundPlayerData[index][plyHitsTankSniper]++; }
            case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHitsTankPistol]++;    g_strRoundPlayerData[index][plyHitsTankPistol]++; }
        }
    }
    
    // headshots (only bullet-based)
    if ( damagetype & DMG_BULLET && hitgroup == HITGROUP_HEAD && GetEntProp(victim, Prop_Send, "m_zombieClass") != ZC_TANK )
    {
        switch ( weaponType )
        {
            case WPTYPE_SMG: {      g_strPlayerData[index][plyHeadshotsSmg]++;    g_strPlayerData[index][plyHeadshotsSISmg]++;      g_strRoundPlayerData[index][plyHeadshotsSmg]++;    g_strRoundPlayerData[index][plyHeadshotsSISmg]++; }
            case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHeadshotsSniper]++; g_strPlayerData[index][plyHeadshotsSISniper]++;   g_strRoundPlayerData[index][plyHeadshotsSniper]++; g_strRoundPlayerData[index][plyHeadshotsSISniper]++; }
            case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHeadshotsPistol]++; g_strPlayerData[index][plyHeadshotsSIPistol]++;   g_strRoundPlayerData[index][plyHeadshotsPistol]++; g_strRoundPlayerData[index][plyHeadshotsSIPistol]++; }
        }
    }
}

// common infected / witch gets hit
public Action: TraceAttack_Infected (victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if ( !g_bPlayersLeftStart ) { return; }
    if ( !IS_VALID_SURVIVOR(attacker) || !IsValidEdict(inflictor) ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    new weaponType = WPTYPE_NONE;
    
    // get weapon type
    if ( damagetype & DMG_BUCKSHOT )
    {
        weaponType = WPTYPE_SHOTGUN;
    }
    else if ( damagetype & DMG_BULLET )
    {
        decl String:weaponname[48];
        GetClientWeapon(attacker, weaponname, sizeof(weaponname));
        weaponType = GetWeaponTypeForClassname(weaponname);
    }
    else {
        // not handling anything else
        return;
    }
    
    //PrintToChatAll("common hit: weptype %i hit: %10s", weaponType, g_cHitgroups[hitgroup]);
    
    // count hits
    switch ( weaponType )
    {
        case WPTYPE_SHOTGUN: {  g_strPlayerData[index][plyHitsShotgun]++;   g_strRoundPlayerData[index][plyHitsShotgun]++;}
        case WPTYPE_SMG: {      g_strPlayerData[index][plyHitsSmg]++;       g_strRoundPlayerData[index][plyHitsSmg]++; }
        case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHitsSniper]++;    g_strRoundPlayerData[index][plyHitsSniper]++; }
        case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHitsPistol]++;    g_strRoundPlayerData[index][plyHitsPistol]++; }
    }
    
    // headshots (only bullet-based)
    if ( damagetype & DMG_BULLET && hitgroup == HITGROUP_HEAD )
    {
        switch ( weaponType )
        {
            case WPTYPE_SMG: {      g_strPlayerData[index][plyHeadshotsSmg]++;      g_strRoundPlayerData[index][plyHeadshotsSmg]++; }
            case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHeadshotsSniper]++;   g_strRoundPlayerData[index][plyHeadshotsSniper]++; }
            case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHeadshotsPistol]++;   g_strRoundPlayerData[index][plyHeadshotsPistol]++; }
        }
    }
}


// hooks for tracking attacks on SI/Tank
public Action: Event_PlayerSpawn (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId( GetEventInt(hEvent, "userid") );
    if ( !IS_VALID_INFECTED(client) ) { return; }

    SDKHook(client, SDKHook_TraceAttack, TraceAttack_Special);
}


// hooks for tracking attacks on common/witch
public OnEntityCreated ( entity, const String:classname[] )
{
    if ( entity < 1 || !IsValidEntity(entity) || !IsValidEdict(entity) ) { return; }
    
    // track infected / witches, so damage on them counts as hits
    
    new strOEC: classnameOEC;
    if (!GetTrieValue(g_hTrieEntityCreated, classname, classnameOEC)) { return; }
    
    switch ( classnameOEC )
    {
        case OEC_INFECTED:
        {
            SDKHook(entity, SDKHook_TraceAttack, TraceAttack_Infected);
        }
    }
}




/*
    Skill Detect forwards
    ---------------------
*/

// m2 & deadstop
public OnSpecialShoved ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyShoves]++;
    g_strRoundPlayerData[index][plyShoves]++;
}
public OnHunterDeadstop ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyDeadStops]++;
    g_strRoundPlayerData[index][plyDeadStops]++;
}

// skeets
public OnSkeet ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeets]++;
    g_strRoundPlayerData[index][plySkeets]++;
}
public OnSkeetHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeetsHurt]++;
    g_strRoundPlayerData[index][plySkeetsHurt]++;
}
public OnSkeetMelee ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeetsMelee]++;
    g_strRoundPlayerData[index][plySkeetsMelee]++;
}
/* public OnSkeetMeleeHurt ( attacker, victim, damage )
{
    //new index = GetPlayerIndexForClient( attacker );
    //if ( index == -1 ) { return; }
    //g_strPlayerData[index][plySkeetsHurt]++;
    //g_strRoundPlayerData[index][plySkeetsHurt]++;
}
*/
public OnSkeetSniper ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeets]++;
    g_strRoundPlayerData[index][plySkeets]++;
}
public OnSkeetSniperHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeetsHurt]++;
    g_strRoundPlayerData[index][plySkeetsHurt]++;
}

// pops
public OnBoomerPop ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyPops]++;
    g_strRoundPlayerData[index][plyPops]++;
}

// levels
public OnChargerLevel ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyLevels]++;
    g_strRoundPlayerData[index][plyLevels]++;
}
public OnChargerLevelHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyLevelsHurt]++;
    g_strRoundPlayerData[index][plyLevelsHurt]++;
}

// smoker clears
public OnTongueCut ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyTongueCuts]++;
    g_strRoundPlayerData[index][plyTongueCuts]++;
}
public OnSmokerSelfClear ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySelfClears]++;
    g_strRoundPlayerData[index][plySelfClears]++;
}

// crowns
public OnWitchCrown ( attacker, damage )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyCrowns]++;
    g_strRoundPlayerData[index][plyCrowns]++;
}
public OnWitchDrawCrown ( attacker, damage, chipdamage )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyCrownsHurt]++;
    g_strRoundPlayerData[index][plyCrownsHurt]++;
}
// tank rock
public OnTankRockEaten ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( victim );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyRockEats]++;
    g_strRoundPlayerData[index][plyRockEats]++;
}

public OnTankRockSkeeted ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyRockSkeets]++;
    g_strRoundPlayerData[index][plyRockSkeets]++;
}
// highpounces
public OnHunterHighPounce ( attacker, victim, Float:damage, Float:height )
{
}
public OnJockeyHighPounce ( attacker, victim, Float:height )
{
}

/*
    Stats cleanup
    -------------
*/
public Action: Timer_ResetStats (Handle:timer, any:roundOnly)
{
    // reset stats (for current team)
    ResetStats( bool:(roundOnly), g_iCurTeam );
}

stock ResetStats( bool:bCurrentRoundOnly = false, iTeam = LTEAM_A )
{
    new i, j, k;
    
    if ( !bCurrentRoundOnly )
    {
        // just so nobody gets robbed of seeing stats, print to all
        DisplayStats( );
        
        // clear game
        g_bGameStarted = false;
        g_strGameData[gmFailed] = 0;
        
        g_iMVPSIDamageTotal[0] = 0;
        g_iMVPSIDamageTotal[1] = 0;
        g_iMVPCommonTotal[0] = 0;
        g_iMVPCommonTotal[1] = 0;
        
        // clear rounds
        for ( i = 0; i < MAXROUNDS; i++ )
        {
            g_sMapName[i] = "";
            for ( j = 0; j < 2; j++ )
            {
                for ( k = 0; k < MAXRNDSTATS; k++ )
                {
                    g_strRoundData[i][j][k] = 0;
                }
            }
        }
        
        // clear players
        for ( i = 0; i < MAXTRACKED; i++ )
        {
            for ( j = 0; j < MAXPLYSTATS; j++ )
            {
                g_strPlayerData[i][j] = 0;
            }
        }
        
        g_iRound = 0;
    }
    else
    {
        g_strRoundData[g_iRound][iTeam][rndPillsUsed] = 0;
        g_strRoundData[g_iRound][iTeam][rndKitsUsed] = 0;
        g_strRoundData[g_iRound][iTeam][rndDefibsUsed] = 0;
        g_strRoundData[g_iRound][iTeam][rndSIKilled] = 0;
        g_strRoundData[g_iRound][iTeam][rndCommon] = 0;
        g_strRoundData[g_iRound][iTeam][rndTankKilled] = 0;
        g_strRoundData[g_iRound][iTeam][rndWitchKilled] = 0;
        g_strRoundData[g_iRound][iTeam][rndIncaps] = 0;
        g_strRoundData[g_iRound][iTeam][rndDeaths] = 0;
    }
    
    // other round data
    g_iMVPRoundSIDamageTotal[0] = 0;
    g_iMVPRoundSIDamageTotal[1] = 0;
    g_iMVPRoundCommonTotal[0] = 0;
    g_iMVPRoundCommonTotal[1] = 0;
    
    // round data for players
    for ( i = 0; i < MAXTRACKED; i++ )
    {
        for ( j = 0; j < MAXPLYSTATS; j++ )
        {
            g_strRoundPlayerData[i][j] = 0;
        }
    }
    
    // ff data
    g_iFFDamageTotal = 0;
    g_iFFRoundDamageTotal = 0;
}

stock UpdatePlayerCurrentTeam()
{
    new i, client, index;
    new team = GetCurrentTeamSurvivor();
    
    // reset all
    for ( i = 0; i < MAXTRACKED; i++ )
    {
        g_iPlayerCurrentTeam[i] = -1;
    }
    
    // find all survivors
    // find all infected
    
    for ( client = 1; client <= MaxClients; client++ )
    {
        if ( !IS_VALID_INGAME(client) ) { continue; }
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { continue; }
        
        if ( IS_VALID_SURVIVOR(client) ) {
            g_iPlayerCurrentTeam[index] = team;
        }
        else if ( IS_VALID_INFECTED(client) ) {
            g_iPlayerCurrentTeam[index] = (team) ? 0 : 1;
        }
    }
}

/*
    Display
    -------
*/

// display general stats -- if round set, only for that round no.
stock DisplayStats( client = -1, bool:bRound = false, round = -1 )
{
    if ( round != -1 ) { round--; }
    
    decl String:bufBasicHeader[CONBUFSIZE];
    //decl String:bufBasic[CONBUFSIZELARGE];
    decl String: strTmp[24];
    decl String: strTmpA[40];
    //decl String: strTmpB[32];
    new iCount, i, j;
    
    if ( round == -1 )
    {
        // display all rounds / game summary
        
        // game info
        if ( g_bGameStarted )
        {
            new tmpInt = GetTime() - g_strGameData[gmStartTime];
            strTmp = "";
            
            if ( tmpInt > 3600 ) {
                new tmpHr = RoundToFloor( float(tmpInt) / 3600.0 );
                Format( strTmp, sizeof(strTmp), "%ih", tmpHr );
                tmpInt -= (tmpHr * 3600);
            }
            if ( tmpInt > 60 ) {
                if ( strlen( strTmp ) ) {  Format( strTmp, sizeof(strTmp), "%s ", strTmp ); }
                new tmpMin = RoundToFloor( float(tmpInt) / 60.0 );
                Format( strTmp, sizeof(strTmp), "%im", tmpMin );
                tmpInt -= (tmpMin * 60);
            }
            if ( tmpInt ) {
                if ( strlen( strTmp ) ) { Format( strTmp, sizeof(strTmp), "%s ", strTmp ); }
                Format( strTmp, sizeof(strTmp), "%s%is", strTmp, tmpInt );
            }
        }
        else {
            Format( strTmp, sizeof(strTmp), "(not started)" );
        }
        iCount = 0;
        while (strlen(strTmp) < 20 && iCount < 1000) { iCount++; Format(strTmp, sizeof(strTmp), " %s", strTmp); }
        
        
        // kill stats
        new tmpSpecial, tmpCommon, tmpWitches, tmpTanks, tmpIncap, tmpDeath;
        
        for ( i = 0; i <= g_iRound; i++ )
        {
            tmpSpecial += g_strRoundData[i][g_iCurTeam][rndSIKilled];
            tmpCommon += g_strRoundData[i][g_iCurTeam][rndCommon];
            tmpWitches += g_strRoundData[i][g_iCurTeam][rndWitchKilled];
            tmpTanks += g_strRoundData[i][g_iCurTeam][rndTankKilled];
            tmpIncap += g_strRoundData[i][g_iCurTeam][rndIncaps];
            tmpDeath += g_strRoundData[i][g_iCurTeam][rndDeaths];
        }
        
        Format(bufBasicHeader, CONBUFSIZE, "\n");
        Format(bufBasicHeader, CONBUFSIZE, "%s| General Stats                                    |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Time spent:          |      %20s |\n", bufBasicHeader, strTmp);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Rounds / Railed      |             %5i / %5i |\n", bufBasicHeader, g_iRound, g_strGameData[gmFailed]);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|                      | Kills:    %5i  specials |\n", bufBasicHeader, tmpSpecial );
        Format(bufBasicHeader, CONBUFSIZE, "%s|                      |           %5i  commons  |\n", bufBasicHeader, tmpCommon );
        Format(bufBasicHeader, CONBUFSIZE, "%s| Deaths:        %5i |           %5i  witches  |\n", bufBasicHeader, tmpDeath, tmpWitches );
        Format(bufBasicHeader, CONBUFSIZE, "%s| Incaps:        %5i |           %5i  tanks    |\n", bufBasicHeader, tmpIncap, tmpTanks );
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
        
        if ( !client )
        {
            for ( i = 1; i <= MaxClients; i++ )
            {
                if ( IS_VALID_INGAME( i ) )
                {
                    PrintToConsole(i, bufBasicHeader);
                    //PrintToConsole(i, bufBasic);
                }
            }
        }
        else
        {
            if ( IS_VALID_INGAME( client ) )
            {
                PrintToConsole(client, bufBasicHeader);
                //PrintToConsole(client, bufBasic);
            }
        }
        
        // round data
        for ( i = 0; i <= g_iRound; i++ )
        {
            // game info
            if ( g_strRoundData[i][g_iCurTeam][rndStartTime] )
            {
                new tmpInt = 0;
                if ( g_strRoundData[i][g_iCurTeam][rndEndTime] ) {
                    tmpInt = g_strRoundData[i][g_iCurTeam][rndEndTime];
                } else {
                    tmpInt = GetTime() - g_strRoundData[i][g_iCurTeam][rndStartTime];
                }
                strTmp = "";
                
                if ( tmpInt > 3600 ) {
                    new tmpHr = RoundToFloor( float(tmpInt) / 3600.0 );
                    Format( strTmp, sizeof(strTmp), "%ih", tmpHr );
                    tmpInt -= (tmpHr * 3600);
                }
                if ( tmpInt > 60 ) {
                    if ( strlen( strTmp ) ) {  Format( strTmp, sizeof(strTmp), "%s ", strTmp ); }
                    new tmpMin = RoundToFloor( float(tmpInt) / 60.0 );
                    Format( strTmp, sizeof(strTmp), "%im", tmpMin );
                    tmpInt -= (tmpMin * 60);
                }
                if ( tmpInt ) {
                    if ( strlen( strTmp ) ) { Format( strTmp, sizeof(strTmp), "%s ", strTmp ); }
                    Format( strTmp, sizeof(strTmp), "%s%is", strTmp, tmpInt );
                }
            }
            else {
                Format( strTmp, sizeof(strTmp), "(not started yet)" );
            }
            iCount = 0;
            while (strlen(strTmp) < 17 && iCount < 1000) { iCount++; Format(strTmp, sizeof(strTmp), " %s", strTmp); }
            
            strcopy(strTmpA, sizeof(strTmpA), g_sMapName[i]);
            iCount = 0;
            while (strlen(strTmpA) < 32 && iCount < 1000) { iCount++; Format(strTmpA, sizeof(strTmpA), " %s", strTmpA); }
            
            Format(bufBasicHeader, CONBUFSIZE, "|--------------------------------------------------|\n");
            Format(bufBasicHeader, CONBUFSIZE, "%s| Round %3i.:     %32s |\n", bufBasicHeader, (i + 1), strTmpA );
            Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
            Format(bufBasicHeader, CONBUFSIZE, "%s| Time spent, attemps: | %17s / %5s |\n", bufBasicHeader, strTmp,
                    g_strRoundData[i][g_iCurTeam][rndRestarts]
                );
            Format(bufBasicHeader, CONBUFSIZE, "%s| Kills SI, CI, Witch: |     %5i / %5i / %5i |\n", bufBasicHeader,
                    g_strRoundData[i][g_iCurTeam][rndSIKilled],
                    g_strRoundData[i][g_iCurTeam][rndCommon],
                    g_strRoundData[i][g_iCurTeam][rndWitchKilled]
                );
            Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|", bufBasicHeader);
            
            if ( !client )
            {
                for ( j = 1; j <= MaxClients; j++ )
                {
                    if ( IS_VALID_INGAME( j ) )
                    {
                        PrintToConsole(j, bufBasicHeader);
                        //PrintToConsole(j, bufBasic);
                    }
                }
            }
            else
            {
                if ( IS_VALID_INGAME( client ) )
                {
                    PrintToConsole(client, bufBasicHeader);
                    //PrintToConsole(client, bufBasic);
                }
            }
        }
    }
    else if ( round > g_iRound )
    {
        // too high
        if ( IsClientAndInGame( client ) )
        {
            PrintToChat( client, "<round> must be a number between 1 and %i", g_iRound + 1 );
        }
    }
    else
    {
        // display round stats
        i = round;
        
        if ( g_strRoundData[i][g_iCurTeam][rndStartTime] )
        {
            new tmpInt = 0;
            if ( g_strRoundData[i][g_iCurTeam][rndEndTime] ) {
                tmpInt = g_strRoundData[i][g_iCurTeam][rndEndTime];
            } else {
                tmpInt = GetTime() - g_strRoundData[i][g_iCurTeam][rndStartTime];
            }
            strTmp = "";
            
            if ( tmpInt > 3600 ) {
                new tmpHr = RoundToFloor( float(tmpInt) / 3600.0 );
                Format( strTmp, sizeof(strTmp), "%ih", tmpHr );
                tmpInt -= (tmpHr * 3600);
            }
            if ( tmpInt > 60 ) {
                if ( strlen( strTmp ) ) {  Format( strTmp, sizeof(strTmp), "%s ", strTmp ); }
                new tmpMin = RoundToFloor( float(tmpInt) / 60.0 );
                Format( strTmp, sizeof(strTmp), "%im", tmpMin );
                tmpInt -= (tmpMin * 60);
            }
            if ( tmpInt ) {
                if ( strlen( strTmp ) ) { Format( strTmp, sizeof(strTmp), "%s ", strTmp ); }
                Format( strTmp, sizeof(strTmp), "%s%is", strTmp, tmpInt );
            }
        }
        else {
            Format( strTmp, sizeof(strTmp), "(not started yet)" );
        }
        iCount = 0;
        while (strlen(strTmp) < 15 && iCount < 1000) { iCount++; Format(strTmp, sizeof(strTmp), " %s", strTmp); }
        
        strcopy(strTmpA, sizeof(strTmpA), g_sMapName[i]);
        iCount = 0;
        while (strlen(strTmpA) < 32 && iCount < 1000) { iCount++; Format(strTmpA, sizeof(strTmpA), " %s", strTmpA); }
        
        Format(bufBasicHeader, CONBUFSIZE, "|--------------------------------------------------|\n");
        Format(bufBasicHeader, CONBUFSIZE, "%s| Round %3i.:     %32s |\n", bufBasicHeader, (i + 1), strTmpA );
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Time spent, attemps: | %15s / %5s |\n", bufBasicHeader,
                strTmp,
                g_strRoundData[i][g_iCurTeam][rndRestarts]
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s| Kills SI, CI, Witch: |     %5i / %5i / %5i |\n", bufBasicHeader,
                g_strRoundData[i][g_iCurTeam][rndSIKilled],
                g_strRoundData[i][g_iCurTeam][rndCommon],
                g_strRoundData[i][g_iCurTeam][rndWitchKilled]
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|", bufBasicHeader);
        
        if ( !client )
        {
            for ( j = 1; j <= MaxClients; j++ )
            {
                if ( IS_VALID_INGAME( j ) )
                {
                    PrintToConsole(j, bufBasicHeader);
                    //PrintToConsole(j, bufBasic);
                }
            }
        }
        else
        {
            if ( IS_VALID_INGAME( client ) )
            {
                PrintToConsole(client, bufBasicHeader);
                //PrintToConsole(client, bufBasic);
            }
        }
    }
}

// display mvp stats
stock DisplayStatsMVPChat( client, bool:bRound = true )
{
    // make sure the MVP stats itself is called first, so the players are already sorted
    
    decl String:printBuffer[1024];
    decl String:tmpBuffer[512];
    new String:strLines[8][192];
    new i, x;
    
    printBuffer = GetMVPChatString();
    PrintToServer("\x01%s", printBuffer);

    // PrintToChatAll has a max length. Split it in to individual lines to output separately
    new intPieces = ExplodeString( printBuffer, "\n", strLines, sizeof(strLines), sizeof(strLines[]) );
    if ( client > 0 ) {
        for ( i = 0; i < intPieces; i++ )
        {
            PrintToChat(client, "\x01%s", strLines[i]);
        }
    }
    else {
        for ( i = 0; i < intPieces; i++ )
        {
            PrintToChatAll("\x01%s", strLines[i]);
        }
    }
    
    
    new iBrevityFlags = GetConVarInt(g_hCvarMVPBrevityFlags);
    new team = GetCurrentTeamSurvivor();
    
    // find index for this client
    new index = -1;
    new found = -1;
    
    
    // also find the three non-mvp survivors and tell them they sucked
    // tell them they sucked with SI
    if (    ( bRound && g_iMVPRoundSIDamageTotal[team] > 0 || !bRound && g_iMVPSIDamageTotal[team] > 0 ) &&
            !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_SI)
    ) {
        
        // skip 0, since that is the MVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ )
        {
            index = g_iPlayerIndexSorted[SORT_SI][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MAXPLAYERS; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            
            if ( found == -1 ) { continue; }

            if ( IS_VALID_CLIENT(found) && !IsFakeClient(found) )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg,\x05 %d \x01kills)",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            (bRound) ? g_strRoundPlayerData[index][plySIKilled] : g_strPlayerData[index][plySIKilled]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - SI: #\x03%d \x01(dmg \x04%.0f%%\x01, kills \x04%.0f%%\x01)",
                            (i+1),
                            (bRound) ? ((float(g_strRoundPlayerData[index][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100),
                            (bRound) ? ((float(g_strRoundPlayerData[index][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100)
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg [\x04%.0f%%\x01],\x05 %d \x01kills [\x04%.0f%%\x01])",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            (bRound) ? ((float(g_strRoundPlayerData[index][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100),
                            (bRound) ? g_strRoundPlayerData[index][plySIKilled] : g_strPlayerData[index][plySIKilled],
                            (bRound) ? ((float(g_strRoundPlayerData[index][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100)
                        );
                }
                PrintToChat( found, "\x01%s", tmpBuffer );
            }
        }
    }

    // tell them they sucked with Common
    if (    ( bRound && g_iMVPRoundCommonTotal[team] > 0 || !bRound && g_iMVPCommonTotal[team] > 0 ) &&
            !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_CI)
    ) {
        
        // skip 0, since that is the MVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ )
        {
            index = g_iPlayerIndexSorted[SORT_CI][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MAXPLAYERS; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            
            if ( found == -1 ) { continue; }

            if ( ( !IS_VALID_CLIENT(client) || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills)",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][plyCommon] : g_strPlayerData[index][plyCommon]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - CI: #\x03%d \x01(kills \x04%.0f%%\x01)",
                            (i+1),
                            (bRound) ? ((float(g_strRoundPlayerData[index][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strPlayerData[index][plyCommon]) / float(g_iMVPCommonTotal[team])) * 100)
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills [\x04%.0f%%\x01])",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][plyCommon] : g_strPlayerData[index][plyCommon],
                            (bRound) ? ((float(g_strRoundPlayerData[index][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strPlayerData[index][plyCommon]) / float(g_iMVPCommonTotal[team])) * 100)
                        );
                }
                PrintToChat( found, "\x01%s", tmpBuffer );
            }
        }
    }
    
    // tell them they were better with FF
    if (    !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_FF) )
    {
        // skip 0, since that is the LVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ )
        {
            index = g_iPlayerIndexSorted[SORT_FF][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MAXPLAYERS; x++ )
            {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            
            if ( found == -1 ) { continue; }

            if ( bRound && !g_strRoundPlayerData[index][plyFFGiven] || !bRound && !g_strPlayerData[index][plyFFGiven] ) { continue; }
            
            if ( ( !IS_VALID_CLIENT(client) || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) )
            {
                Format(tmpBuffer, sizeof(tmpBuffer), "[LVP] Your rank - FF: #\x03%d \x01(\x05%d \x01dmg)",
                        (i+1),
                        (bRound) ? g_strRoundPlayerData[index][plyFFGiven] : g_strPlayerData[index][plyFFGiven]
                    );

                PrintToChat( found, "\x01%s", tmpBuffer );
            }
        }
    }
}

String: GetMVPChatString( bool:bRound = true )
{
    decl String: printBuffer[1024];
    decl String: tmpBuffer[512];
    
    printBuffer = "";
    
    // SI damage already sorted, sort CI and FF too
    //SortPlayersMVP( round, SORT_SI );
    SortPlayersMVP( bRound, SORT_CI );
    SortPlayersMVP( bRound, SORT_FF );
    
    
    new mvp_SI = g_iPlayerIndexSorted[SORT_SI][0];
    new mvp_Common = g_iPlayerIndexSorted[SORT_CI][0];
    new mvp_FF = g_iPlayerIndexSorted[SORT_FF][0];
    
    // in here for now.. handle team / team player stuff later?
    new team = GetCurrentTeamSurvivor();
    
    new iBrevityFlags = GetConVarInt(g_hCvarMVPBrevityFlags);
    
    // if null data, set them to -1
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_SI][plySIDamage]   || !bRound && !g_strPlayerData[mvp_SI][plySIDamage] )   { mvp_SI = -1; }
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_Common][plyCommon] || !bRound && !g_strPlayerData[mvp_Common][plyCommon] ) { mvp_Common = -1; }
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_FF][plyFFGiven]    || !bRound && !g_strPlayerData[mvp_FF][plyFFGiven] )    { mvp_FF = -1; }
    
    // report
    if ( mvp_SI == -1 && mvp_Common == -1 && !(iBrevityFlags & BREV_SI && iBrevityFlags & BREV_CI) )
    {
        Format(tmpBuffer, sizeof(tmpBuffer), "MVP: (not enough action yet)\n");
        StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
    }
    else
    {
        if ( !(iBrevityFlags & BREV_SI) )
        {
            if ( mvp_SI > -1 )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] SI:\x03 %s \x01(\x05%d \x01dmg,\x05 %d \x01kills)\n", 
                            g_sPlayerName[mvp_SI],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][plySIDamage] : g_strPlayerData[mvp_SI][plySIDamage],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][plySIKilled] : g_strPlayerData[mvp_SI][plySIKilled]
                        );
                } else if ( iBrevityFlags & BREV_ABSOLUTE ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] SI:\x03 %s \x01(dmg \x04%2.0f%%\x01, kills \x04%.0f%%\x01)\n",
                            g_sPlayerName[mvp_SI],
                            (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100),
                            (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100)
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] SI:\x03 %s \x01(\x05%d \x01dmg[\x04%.0f%%\x01],\x05 %d \x01kills [\x04%.0f%%\x01])\n",
                            g_sPlayerName[mvp_SI],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][plySIDamage] : g_strPlayerData[mvp_SI][plySIDamage],
                            (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100),
                            (bRound) ? g_strRoundPlayerData[mvp_SI][plySIKilled] : g_strPlayerData[mvp_SI][plySIKilled],
                            (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100)
                        );
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
            else
            {
                StrCat(printBuffer, sizeof(printBuffer), "[MVP] SI: \x03(nobody)\x01\n");
            }
        }
        
        if ( !(iBrevityFlags & BREV_CI) )
        {
            if ( mvp_Common > -1 )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] CI:\x03 %s \x01(\x05%d \x01common)\n",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? g_strRoundPlayerData[mvp_Common][plyCommon] : g_strPlayerData[mvp_Common][plyCommon]
                        );
                } else if ( iBrevityFlags & BREV_ABSOLUTE ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] CI:\x03 %s \x01(\x04%.0f%%\x01)\n",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? ((float(g_strRoundPlayerData[mvp_Common][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strRoundPlayerData[mvp_Common][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100)
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP] CI:\x03 %s \x01(\x05%d \x01common [\x04%.0f%%\x01])\n",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? g_strRoundPlayerData[mvp_Common][plyCommon] : g_strPlayerData[mvp_Common][plyCommon],
                            (bRound) ? ((float(g_strRoundPlayerData[mvp_Common][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strRoundPlayerData[mvp_Common][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100)
                        );
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
        }
    }
    
    // FF
    if ( !(iBrevityFlags & BREV_FF) )
    {
        if ( mvp_FF == -1 )
        {
            Format(tmpBuffer, sizeof(tmpBuffer), "LVP - FF: no friendly fire at all!\n");
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
        else
        {
            Format(tmpBuffer, sizeof(tmpBuffer), "[LVP] FF:\x03 %s \x01(\x05%d \x01dmg)\n",
                        g_sPlayerName[mvp_FF],
                        (bRound) ? g_strRoundPlayerData[mvp_FF][plyFFGiven] : g_strPlayerData[mvp_FF][plyFFGiven]
                    );
            
            /*
                only absolute for now
            if (iBrevityFlags & BREV_PERCENT) {
                
            }
            else if (iBrevityFlags & BREV_ABSOLUTE) {
                Format(tmpBuffer, sizeof(tmpBuffer), "[LVP] FF:\x03 %s \x01(\x04%.0f%%\x01)\n",
                        mvp_FF_name,
                        (round) ? ((float(g_strRoundPlayerData[mvp_FF][plyFFGiven]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strRoundPlayerData[mvp_FF][plyFFGiven]) / float(g_iMVPRoundCommonTotal[team])) * 100)
                    );
            } else {
                Format(tmpBuffer, sizeof(tmpBuffer), "[LVP] FF:\x03 %s \x01(\x05%d \x01dmg [\x04%.0f%%\x01])\n",
                        mvp_FF_name,
                        (round) ? g_strRoundPlayerData[mvp_FF][plyFFGiven] : g_strPlayerData[mvp_FF][plyFFGiven],
                        (float(iDidFF[mvp_FF]) / float(iTotalFF)) * 100
                    );
            }
            */
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
    }
    
    return printBuffer;
}

stock DisplayStatsMVP( client, bool:bTank = false, bool:bRound = true, bool:bTeam = true )
{
    // get sorted players list
    SortPlayersMVP( bRound );
    
    new bool: bTankUp = bool:( !g_bModeCampaign && IsTankInGame() && g_bInRound );
    
    // prepare buffer(s) for printing
    if ( !bTank || !bTankUp )
    {
        BuildConsoleBufferMVP( bTank, bRound, bTeam );
    }
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String:bufBasic[CONBUFSIZELARGE];
    
    if ( bTank )
    {
        if ( bTankUp ) {
            Format(bufBasicHeader, CONBUFSIZE, "\n");
            Format(bufBasicHeader, CONBUFSIZE, "%s| Survivor MVP Stats -- Tank Fight (not showing table, tank is still up...)    |", bufBasicHeader);
            Format(bufBasic, CONBUFSIZELARGE,    "|------------------------------------------------------------------------------|\n");
        }
        else {        
            Format(bufBasicHeader, CONBUFSIZE, "\n");
            Format(bufBasicHeader, CONBUFSIZE, "%s| Survivor MVP Stats -- Tank Fight -- %10s -- %11s                |\n",
                    bufBasicHeader,
                    ( bRound ) ? "This Round" : "All Rounds",
                    ( bTeam ) ? "This Team  " : "All Players"
                );
            Format(bufBasicHeader, CONBUFSIZE, "%s|------------------------------------------------------------------------------|\n", bufBasicHeader);
            Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | SI during tank | CI d. tank | Melees | Rock skeet/eat |\n", bufBasicHeader);
            Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|----------------|------------|--------|----------------|", bufBasicHeader);
            Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufMVP);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|\n", bufBasic);
        }
    }
    else
    {
        Format(bufBasicHeader, CONBUFSIZE, "\n");
        
        Format(bufBasicHeader, CONBUFSIZE, "%s| Survivor MVP Stats -- %10s -- %11s                                                 |\n",
                bufBasicHeader,
                ( bRound ) ? "This Round" : "All Rounds",
                ( bTeam ) ? "This Team  " : "All Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|-------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Specials   kills/dmg  | Commons         | Tank   | Witch  | FF    | Rcvd |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|-----------------------|-----------------|--------|--------|-------|------|", bufBasicHeader);
        Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufMVP);
        Format(bufBasic, CONBUFSIZELARGE,  "%s|-------------------------------------------------------------------------------------------------|\n", bufBasic);
    }
    
    
    if ( client == -1 ) {
        // print to all
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IS_VALID_INGAME( i ) )
            {
                PrintToConsole(i, bufBasicHeader);
                PrintToConsole(i, bufBasic);
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        PrintToServer(bufBasic);
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        PrintToConsole(client, bufBasic);
    }
}

// display player accuracy stats: details => tank/si/etc
stock DisplayStatsAccuracy( client, bool:bDetails = false, bool:bRound = false, bool:bTeam = true, bool:bSorted = true )
{
    // sorting
    if ( !bSorted )
    {
        SortPlayersMVP( bRound, SORT_SI );
    }
    
    // prepare buffer(s) for printing
    BuildConsoleBufferAccuracy( bDetails, bRound, bTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String:bufBasic[CONBUFSIZELARGE];
    
    if ( bDetails )
    {
        Format(bufBasicHeader, CONBUFSIZE, "\n");
        Format(bufBasicHeader, CONBUFSIZE, "%s| Accuracy -- Details -- %10s -- %11s                 hits on SI;  headshots on SI;  hits on tank |\n",
                bufBasicHeader,
                ( bRound ) ? "This Round" : "All Rounds",
                ( bTeam ) ? "This Team  " : "All Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Shotgun             | SMG / Rifle         | Sniper              | Pistol              |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------|---------------------|---------------------|---------------------|", bufBasicHeader);
        Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufAcc);
        Format(bufBasic, CONBUFSIZELARGE,  "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasic);
    }
    else
    {
        Format(bufBasicHeader, CONBUFSIZE, "\n");
        Format(bufBasicHeader, CONBUFSIZE, "%s| Accuracy Stats -- %10s -- %11s            hits (pellets/bullets);  acc %;  headshots % (of hits)  |\n",
                bufBasicHeader,
                ( bRound ) ? "This Round" : "All Rounds",
                ( bTeam ) ? "This Team  " : "All Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Shotgun buckshot    | SMG / Rifle  acc hs | Sniper       acc hs | Pistol       acc hs |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------|---------------------|---------------------|---------------------|", bufBasicHeader);
        Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufAcc);
        Format(bufBasic, CONBUFSIZELARGE,  "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasic);
    }
    
    if ( client == -1 ) {
        // print to all
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IS_VALID_INGAME( i ) )
            {
                PrintToConsole(i, bufBasicHeader);
                PrintToConsole(i, bufBasic);
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        PrintToServer(bufBasic);
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        PrintToConsole(client, bufBasic);
    }
}

// display special skill stats
stock DisplayStatsSpecial( client, bool:bRound = false, bool:bTeam = true, bool:bSorted = false )
{
    // sorting
    if ( !bSorted )
    {
        SortPlayersMVP( bRound, SORT_SI );
    }
    
    // prepare buffer(s) for printing
    BuildConsoleBufferSpecial( bRound, bTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String:bufBasic[CONBUFSIZELARGE];
    
    Format(bufBasicHeader, CONBUFSIZE, "\n");
    
    Format(bufBasicHeader, CONBUFSIZE, "%s| Special -- %10s -- %11s       skts(full/hurt/melee); lvl(full/hurt); crwn(full/draw) |\n",\
            bufBasicHeader,
            ( bRound ) ? "This Round" : "All Rounds",
            ( bTeam ) ? "This Team  " : "All Players"
        );
    if ( !g_bSkillDetectLoaded ) {
        Format(bufBasicHeader, CONBUFSIZE, "%s| ( skill_detect library not loaded: most of these stats won't be tracked )                         |\n", bufBasicHeader);
    }
    //                                                             #### / ### / ###   ### / ###    ### / ###   ### / ###   ####   #### / ####
    Format(bufBasicHeader, CONBUFSIZE, "%s|---------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Skeets  fl/ht/ml | DSs / M2s  | Levels    | Crowns    | Pops | Cuts / Self |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|------------------|------------|-----------|-----------|------|-------------|", bufBasicHeader);
    Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufGen);
    Format(bufBasic, CONBUFSIZELARGE,  "%s|---------------------------------------------------------------------------------------------------|\n", bufBasic);
    
    if ( client == -1 ) {
        // print to all
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IS_VALID_INGAME( i ) )
            {
                PrintToConsole(i, bufBasicHeader);
                PrintToConsole(i, bufBasic);
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        PrintToServer(bufBasic);
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        PrintToConsole(client, bufBasic);
    }
}

// display tables of survivor friendly fire given/taken
stock DisplayStatsFriendlyFire ( client, bool:bRound = true, bool:bTeam = true, bool:bSorted = false )
{
    // sorting
    if ( !bSorted )
    {
        SortPlayersMVP( true, SORT_FF );
    }
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String:bufBasic[CONBUFSIZELARGE];
    
    // only show tables if there is FF damage
    new bool:bNoStatsToShow = (bRound && !g_iFFRoundDamageTotal || !bRound && !g_iFFDamageTotal);
    
    if ( bNoStatsToShow )
    {
        Format(bufBasicHeader, CONBUFSIZE, "\n");
        Format(bufBasic, CONBUFSIZELARGE,  "FF: No Friendly Fire done, not showing table.");
    }
    else
    {
    
        // prepare buffer(s) for printing
        BuildConsoleBufferFriendlyFire( bRound );
        
        
        // friendly fire -- given
        Format(bufBasicHeader, CONBUFSIZE, "\n");
        Format(bufBasicHeader, CONBUFSIZE, "%s| Friendly Fire -- Given / Offenders -- %10s -- %11s                                      |\n",
                bufBasicHeader,
                ( bRound ) ? "This Round" : "All Rounds",
                ( bTeam ) ? "This Team  " : "All Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | On Incap | Other  || to Self |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
        Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufFFGiven);
        Format(bufBasic, CONBUFSIZELARGE,  "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasic);
    }

    if ( client == -1 ) {
        // print to all
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IS_VALID_INGAME( i ) )
            {
                PrintToConsole(i, bufBasicHeader);
                PrintToConsole(i, bufBasic);
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        PrintToServer(bufBasic);
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        PrintToConsole(client, bufBasic);
    }
    
    if ( bNoStatsToShow )
    {
        return;
    }
    
    // friendly fire -- taken
    Format(bufBasicHeader, CONBUFSIZE, "\n");
    Format(bufBasicHeader, CONBUFSIZE, "%s| Friendly Fire -- Received / Victims -- %10s -- %11s                                     |\n",
                bufBasicHeader,
                ( bRound ) ? "This Round" : "All Rounds",
                ( bTeam ) ? "This Team  " : "All Players"
            );
    Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | Incapped | Other  || Fall    |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
    Format(bufBasic, CONBUFSIZELARGE,  "%s", g_sConsoleBufFFTaken);
    Format(bufBasic, CONBUFSIZELARGE,  "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasic);
    
    if ( client == -1 ) {
        // print to all
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IS_VALID_INGAME( i ) )
            {
                PrintToConsole(i, bufBasicHeader);
                PrintToConsole(i, bufBasic);
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        PrintToServer(bufBasic);
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        PrintToConsole(client, bufBasic);
    }
}

stock BuildConsoleBufferSpecial ( bool:bRound = false, bool:bTeam = true, bool:bSorted = false )
{
    g_sConsoleBufGen = "";
    new const s_len = 24;
    new String: strTmp[6][s_len];
    new i, x;
    
    // Special skill stats
    for ( x = 0; x < g_iPlayers; x++ )
    {
        i = g_iPlayerIndexSorted[SORT_SI][x];
        
        // also skip bots for this list
        if ( i < FIRST_NON_BOT ) { continue; }
        
        // skeets:
        if (    bRound && (g_strRoundPlayerData[i][plySkeets] || g_strRoundPlayerData[i][plySkeetsHurt] || g_strRoundPlayerData[i][plySkeetsMelee]) ||
                !bRound && (g_strPlayerData[i][plySkeets] || g_strPlayerData[i][plySkeetsHurt] || g_strPlayerData[i][plySkeetsMelee])
        ) {
            Format( strTmp[0], s_len, "%4d / %3d / %3d",
                    ( (bRound) ? g_strRoundPlayerData[i][plySkeets] : g_strPlayerData[i][plySkeets] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plySkeetsHurt] : g_strPlayerData[i][plySkeetsHurt] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plySkeetsMelee] : g_strPlayerData[i][plySkeetsMelee] )
                );
        } else {
            Format( strTmp[0], s_len, "                " );
        }
        
        // deadstops & m2s
        if (    bRound && (g_strRoundPlayerData[i][plyShoves] || g_strRoundPlayerData[i][plyDeadStops]) ||
                !bRound && (g_strPlayerData[i][plyShoves] || g_strPlayerData[i][plyDeadStops])
        ) {
            Format( strTmp[1], s_len, "%4d / %3d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyDeadStops] : g_strPlayerData[i][plyDeadStops] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plyShoves] : g_strPlayerData[i][plyShoves] )
                );
        } else {
            Format( strTmp[1], s_len, "          " );
        }
        
        // levels
        if (    bRound && (g_strRoundPlayerData[i][plyLevels] || g_strRoundPlayerData[i][plyLevelsHurt]) ||
                !bRound && (g_strPlayerData[i][plyLevels] || g_strPlayerData[i][plyLevelsHurt])
        ) {
            Format( strTmp[2], s_len, "%3d / %3d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyLevels] : g_strPlayerData[i][plyLevels] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plyLevelsHurt] : g_strPlayerData[i][plyLevelsHurt] )
                );
        } else {
            Format( strTmp[2], s_len, "         " );
        }
        
        // crowns
        if (    bRound && (g_strRoundPlayerData[i][plyCrowns] || g_strRoundPlayerData[i][plyCrownsHurt]) ||
                !bRound && (g_strPlayerData[i][plyCrowns] || g_strPlayerData[i][plyCrownsHurt])
        ) {
            Format( strTmp[3], s_len, "%3d / %3d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyCrowns] : g_strPlayerData[i][plyCrowns] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plyCrownsHurt] : g_strPlayerData[i][plyCrownsHurt] )
                );
        } else {
            Format( strTmp[3], s_len, "         " );
        }
        
        // pops
        if (    bRound && g_strRoundPlayerData[i][plyPops] || !bRound && g_strPlayerData[i][plyPops] ) {
            Format( strTmp[4], s_len, "%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyPops] : g_strPlayerData[i][plyPops] )
                );
        } else {
            Format( strTmp[4], s_len, "    " );
        }
        
        // cuts
        if (    bRound && (g_strRoundPlayerData[i][plyTongueCuts] || g_strRoundPlayerData[i][plySelfClears] ) ||
                !bRound && (g_strPlayerData[i][plyTongueCuts] || g_strPlayerData[i][plySelfClears] ) ) {
            Format( strTmp[5], s_len, "%4d / %4d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyTongueCuts] : g_strPlayerData[i][plyTongueCuts] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plySelfClears] : g_strPlayerData[i][plySelfClears] )
                );
        } else {
            Format( strTmp[5], s_len, "           " );
        }
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[i] );
        
        // Format the basic stats
        Format(g_sConsoleBufGen, CONBUFSIZE,
                "%s| %20s | %16s | %10s | %9s | %9s | %4s | %11s |\n",
                g_sConsoleBufGen,
                g_sTmpString,
                strTmp[0], strTmp[1], strTmp[2],
                strTmp[3], strTmp[4], strTmp[5]
            );
    }
}

stock BuildConsoleBufferAccuracy ( bool:details = false, bool:bRound = false, bool:bTeam = true )
{
    g_sConsoleBufAcc = "";
    new const s_len = 24;
    new String: strTmp[5][s_len], String: strTmpA[s_len], String: strTmpB[s_len];
    new i;
    
    /*
        Sorting is not really important, but might consider it later
    */
    
    // 1234567890123456789
    // ##### /##### ###.#%
    //   ##### ##### #####     details
    
    if ( details )
    {
        // Accuracy - details
        for ( i = 0; i < g_iPlayers; i++ )
        {
            // also skip bots for this list
            if ( i < FIRST_NON_BOT ) { continue; }
            
            // shotgun:
            if ( bRound && g_strRoundPlayerData[i][plyHitsShotgun] || !bRound && g_strPlayerData[i][plyHitsShotgun] ) {
                Format( strTmp[0], s_len, "  %5d       %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsSIShotgun] : g_strPlayerData[i][plyHitsSIShotgun] ),
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsTankShotgun] : g_strPlayerData[i][plyHitsTankShotgun] )
                    );
            } else {
                Format( strTmp[0], s_len, "                   " );
            }
            
            // smg:
            if ( bRound && g_strRoundPlayerData[i][plyHitsSmg] || !bRound && g_strPlayerData[i][plyHitsSmg] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHeadshotsSISmg] ) / float( g_strRoundPlayerData[i][plyHitsSISmg] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISmg] ) / float( g_strPlayerData[i][plyHitsSISmg] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[1], s_len, " %5d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsSISmg] : g_strPlayerData[i][plyHitsSISmg] ),
                        strTmpA,
                        ( (bRound) ?  g_strRoundPlayerData[i][plyHitsTankSmg] : g_strPlayerData[i][plyHitsTankSmg] )
                    );
            } else {
                Format( strTmp[1], s_len, "                   " );
            }
            
            // sniper:
            if ( bRound && g_strRoundPlayerData[i][plyHitsSniper] || !bRound && g_strPlayerData[i][plyHitsSniper] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHeadshotsSISniper] ) / float( g_strRoundPlayerData[i][plyHitsSISniper] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISniper] ) / float( g_strPlayerData[i][plyHitsSISniper] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[2], s_len, " %5d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsSISniper] : g_strPlayerData[i][plyHitsSISniper] ),
                        strTmpA,
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsTankSniper] : g_strPlayerData[i][plyHitsTankSniper] )
                    );
            } else {
                Format( strTmp[2], s_len, "                   " );
            }
            
            // pistols:
            if ( bRound && g_strRoundPlayerData[i][plyHitsPistol] || !bRound && g_strPlayerData[i][plyHitsPistol] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHeadshotsSIPistol] ) / float( g_strRoundPlayerData[i][plyHitsSIPistol] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSIPistol] ) / float( g_strPlayerData[i][plyHitsSIPistol] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[3], s_len, " %5d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsSIPistol] : g_strPlayerData[i][plyHitsSIPistol] ),
                        strTmpA,
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsTankPistol] : g_strPlayerData[i][plyHitsTankPistol] )
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format(g_sConsoleBufAcc, CONBUFSIZE,
                    "%s| %20s | %19s | %19s | %19s | %19s |\n",
                    g_sConsoleBufAcc,
                    g_sTmpString,
                    strTmp[0],
                    strTmp[1],
                    strTmp[2],
                    strTmp[3]
                );
        }
    }
    else
    {
        // Accuracy - normal
        for ( i = 0; i < g_iPlayers; i++ )
        {
            // also skip bots for this list
            if ( i < FIRST_NON_BOT ) { continue; }
            
            // shotgun:
            if ( bRound && g_strRoundPlayerData[i][plyShotsShotgun] || !bRound && g_strPlayerData[i][plyShotsShotgun] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHitsShotgun] ) / float( g_strRoundPlayerData[i][plyShotsShotgun] ) * 100.0);
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsShotgun] ) / float( g_strPlayerData[i][plyShotsShotgun] ) * 100.0);
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[0], s_len, "%5d /%5d %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsShotgun] : g_strPlayerData[i][plyHitsShotgun] ),
                        ( (bRound) ? g_strRoundPlayerData[i][plyShotsShotgun] : g_strPlayerData[i][plyShotsShotgun] ),
                        strTmpA
                    );
            } else {
                Format( strTmp[0], s_len, "                   " );
            }
            
            // smg:
            if ( bRound && g_strRoundPlayerData[i][plyShotsSmg] || !bRound && g_strPlayerData[i][plyShotsSmg] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHitsSmg] ) / float( g_strRoundPlayerData[i][plyShotsSmg] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSmg] ) / float( g_strPlayerData[i][plyShotsSmg] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) {
                    Format( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHeadshotsSmg] ) / float( g_strRoundPlayerData[i][plyHitsSmg] - g_strRoundPlayerData[i][plyHitsTankSmg] ) * 100.0 );
                } else {
                    Format( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSmg] ) / float( g_strPlayerData[i][plyHitsSmg] - g_strPlayerData[i][plyHitsTankSmg] ) * 100.0 );
                }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[1], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsSmg] : g_strPlayerData[i][plyHitsSmg] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[1], s_len, "                   " );
            }
            
            // sniper:
            if ( bRound && g_strRoundPlayerData[i][plyShotsSniper] || !bRound && g_strPlayerData[i][plyShotsSniper] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHitsSniper] ) / float( g_strRoundPlayerData[i][plyShotsSniper] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSniper] ) / float( g_strPlayerData[i][plyShotsSniper] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) {
                    Format( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHeadshotsSniper] ) / float( g_strRoundPlayerData[i][plyHitsSniper] - g_strRoundPlayerData[i][plyHitsTankSniper] ) * 100.0 );
                } else {
                    Format( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSniper] ) / float( g_strPlayerData[i][plyHitsSniper] - g_strPlayerData[i][plyHitsTankSniper] ) * 100.0 );
                }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[2], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsSniper] : g_strPlayerData[i][plyHitsSniper] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[2], s_len, "                   " );
            }
            
            // pistols:
            if ( bRound && g_strRoundPlayerData[i][plyShotsPistol] || !bRound && g_strPlayerData[i][plyShotsPistol] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHitsPistol] ) / float( g_strRoundPlayerData[i][plyShotsPistol] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsPistol] ) / float( g_strPlayerData[i][plyShotsPistol] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) {
                    Format( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyHeadshotsPistol] ) / float( g_strRoundPlayerData[i][plyHitsPistol] - g_strRoundPlayerData[i][plyHitsTankPistol] ) * 100.0 );
                } else {
                    Format( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsPistol] ) / float( g_strPlayerData[i][plyHitsPistol] - g_strPlayerData[i][plyHitsTankPistol] ) * 100.0 );
                }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[3], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][plyHitsPistol] : g_strPlayerData[i][plyHitsPistol] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format(g_sConsoleBufAcc, CONBUFSIZE,
                    "%s| %20s | %19s | %19s | %19s | %19s |\n",
                    g_sConsoleBufAcc,
                    g_sTmpString,
                    strTmp[0],
                    strTmp[1],
                    strTmp[2],
                    strTmp[3]
                );
        }
    }
}


stock BuildConsoleBufferMVP ( bool:tank = false, bool:bRound = true, bool:bTeam = true )
{
    g_sConsoleBufMVP = "";
    new const s_len = 24;
    new String: strTmp[6][s_len], String: strTmpA[s_len];
    new i, x;
    
    // current logical survivor team?
    new team = GetCurrentTeamSurvivor();
    
    if ( tank )
    {
        // MVP - tank related
        
        for ( x = 0; x < g_iPlayers; x++ )
        {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            //if ( i < FIRST_NON_BOT ) { continue; }
            
            // only show survivors...
            if ( g_iPlayerCurrentTeam[i] != team ) { continue; }
            
            // si damage
            Format( strTmp[0], s_len, "%5d  %7d",
                    ( (bRound) ? g_strRoundPlayerData[i][plySIKilledTankUp] : g_strPlayerData[i][plySIKilledTankUp] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plySIDamageTankUp] : g_strPlayerData[i][plySIDamageTankUp] ),
                    strTmpA
                );
            
            // commons
            Format( strTmp[1], s_len, "   %7d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyCommonTankUp] : g_strPlayerData[i][plyCommonTankUp] )
                );
            
            // melee on tank
            Format( strTmp[2], s_len, "%6d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyMeleesOnTank] : g_strPlayerData[i][plyMeleesOnTank] )
                );
            
            // rock skeets / eats       ----- / -----
            Format( strTmp[3], s_len, " %5d / %5d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyRockSkeets] : g_strPlayerData[i][plyRockSkeets] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plyRockEats] : g_strPlayerData[i][plyRockEats] )
                );

            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format(g_sConsoleBufMVP, CONBUFSIZE,
                    "%s| %20s | %14s | %10s | %6s | %14s |\n",
                    g_sConsoleBufMVP,
                    g_sTmpString,
                    strTmp[0],
                    strTmp[1],
                    strTmp[2],
                    strTmp[3]
                );
        }
    }
    else
    {
        // MVP normal
        new bool: bTank = bool:( !g_bModeCampaign && IsTankInGame() && g_bInRound );
        
        for ( x = 0; x < g_iPlayers; x++ )
        {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            //if ( i < FIRST_NON_BOT ) { continue; }
            
            // only show survivors...
            if ( g_iPlayerCurrentTeam[i] != team ) { continue; }
            
            // si damage
            if ( bRound ) { Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plySIDamage] ) / float( g_iMVPRoundSIDamageTotal[team] ) * 100.0);
            } else {        Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plySIDamage] ) / float( g_iMVPSIDamageTotal[team] ) * 100.0); }
            while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
            Format( strTmp[0], s_len, "%4d  %7d  %5s%%%%",
                    ( (bRound) ? g_strRoundPlayerData[i][plySIKilled] : g_strPlayerData[i][plySIKilled] ),
                    ( (bRound) ? g_strRoundPlayerData[i][plySIDamage] : g_strPlayerData[i][plySIDamage] ),
                    strTmpA
                );
            
            
            // commons
            if ( bRound ) { Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][plyCommon] ) / float( g_iMVPRoundCommonTotal[team] ) * 100.0);
            } else {        Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyCommon] ) / float( g_iMVPCommonTotal[team] ) * 100.0); }
            while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
            Format( strTmp[1], s_len, "%7d  %5s%%%%",
                    ( (bRound) ? g_strRoundPlayerData[i][plyCommon] : g_strPlayerData[i][plyCommon] ),
                    strTmpA
                );
            
            // tank
            if ( bTank ) {
                // hide 
                Format( strTmp[2], s_len, "%s", "hidden" );
            } else {
                Format( strTmp[2], s_len, "%6d",
                        ( (bRound) ? g_strRoundPlayerData[i][plyTankDamage] : g_strPlayerData[i][plyTankDamage] )
                    );
            }
            
            // witch
            Format( strTmp[3], s_len, "%6d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyWitchDamage] : g_strPlayerData[i][plyWitchDamage] )
                );
            
            // ff
            Format( strTmp[4], s_len, "%5d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyFFGiven] : g_strPlayerData[i][plyFFGiven] )
                );
            
            // damage received
            Format( strTmp[5], s_len, "%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][plyDmgTaken] : g_strPlayerData[i][plyDmgTaken] )
                );
            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format(g_sConsoleBufMVP, CONBUFSIZE,
                    "%s| %20s | %21s | %15s | %6s | %6s | %5s | %4s |\n",
                    g_sConsoleBufMVP,
                    g_sTmpString,
                    strTmp[0],
                    strTmp[1],
                    strTmp[2],
                    strTmp[3],
                    strTmp[4],
                    strTmp[5]
                );
        }
    }
}

stock BuildConsoleBufferFriendlyFire ( bool:bRound = true, bool:bTeam = true )
{
    g_sConsoleBufFFGiven = "";
    g_sConsoleBufFFTaken = "";
    
    new const s_len = 15;
    decl String:strPrint[FFTYPE_MAX][s_len];
    new i, j, x;
    
    
    // GIVEN
    for ( x = 0; x < g_iPlayers; x++ )
    {
        i = g_iPlayerIndexSorted[SORT_FF][x];
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[i][plyFFGivenTotal] && !g_strRoundPlayerData[i][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[i][plyFFGivenTotal] && !g_strPlayerData[i][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // also skip bots for this list
        if ( i < FIRST_NON_BOT ) { continue; }
        
        // prepare print
        if ( !bRound && g_strPlayerData[i][plyFFGivenTotal] || bRound && g_strRoundPlayerData[i][plyFFGivenTotal] ) {
            Format(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (bRound) ? g_strPlayerData[i][plyFFGivenTotal] : g_strRoundPlayerData[i][plyFFGivenTotal] );
        } else {                            Format(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenPellet] || bRound && g_strRoundPlayerData[i][plyFFGivenPellet] ) {
            Format(strPrint[FFTYPE_PELLET],     s_len, "%7d", (bRound) ? g_strPlayerData[i][plyFFGivenPellet] : g_strRoundPlayerData[i][plyFFGivenPellet] );
        } else {                            Format(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenBullet] || bRound && g_strRoundPlayerData[i][plyFFGivenBullet] ) {
            Format(strPrint[FFTYPE_BULLET],     s_len, "%7d", (bRound) ? g_strPlayerData[i][plyFFGivenBullet] : g_strRoundPlayerData[i][plyFFGivenBullet] );
        } else {                            Format(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenMelee] || bRound && g_strRoundPlayerData[i][plyFFGivenMelee] ) {
            Format(strPrint[FFTYPE_MELEE],      s_len, "%6d", (bRound) ? g_strPlayerData[i][plyFFGivenMelee] : g_strRoundPlayerData[i][plyFFGivenMelee] );
        } else {                            Format(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenFire] || bRound && g_strRoundPlayerData[i][plyFFGivenFire] ) {
            Format(strPrint[FFTYPE_FIRE],       s_len, "%6d", (bRound) ? g_strPlayerData[i][plyFFGivenFire] : g_strRoundPlayerData[i][plyFFGivenFire] );
        } else {                            Format(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenIncap] || bRound && g_strRoundPlayerData[i][plyFFGivenIncap] ) {
            Format(strPrint[FFTYPE_INCAP],      s_len, "%8d", (bRound) ? g_strPlayerData[i][plyFFGivenIncap] : g_strRoundPlayerData[i][plyFFGivenIncap] );
        } else {                            Format(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenOther] || bRound && g_strRoundPlayerData[i][plyFFGivenOther] ) {
            Format(strPrint[FFTYPE_OTHER],      s_len, "%6d", (bRound) ? g_strPlayerData[i][plyFFGivenOther] : g_strRoundPlayerData[i][plyFFGivenOther] );
        } else {                            Format(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenSelf] || bRound && g_strRoundPlayerData[i][plyFFGivenSelf] ) {
            Format(strPrint[FFTYPE_SELF],       s_len, "%7d", (bRound) ? g_strPlayerData[i][plyFFGivenSelf] : g_strRoundPlayerData[i][plyFFGivenSelf] );
        } else {                            Format(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[i] );
        
        // Format the basic stats
        Format(g_sConsoleBufFFGiven, CONBUFSIZE,
                "%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |\n",
                g_sConsoleBufFFGiven,
                g_sTmpString,
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE],   strPrint[FFTYPE_INCAP],  strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF]
            );
    }
    
    // TAKEN
    for ( x = 0; x < g_iPlayers; x++ )
    {
        j = g_iPlayerIndexSorted[SORT_FF][x];
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[j][plyFFGivenTotal] && !g_strRoundPlayerData[j][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[j][plyFFGivenTotal] && !g_strPlayerData[j][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // prepare print
        if ( !bRound && g_strPlayerData[j][plyFFTakenTotal] || bRound && g_strRoundPlayerData[j][plyFFTakenTotal] ) {
            Format(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (bRound) ? g_strPlayerData[j][plyFFTakenTotal] : g_strRoundPlayerData[j][plyFFTakenTotal] );
        } else {                            Format(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenPellet] || !bRound && g_strRoundPlayerData[j][plyFFTakenPellet] ) {
            Format(strPrint[FFTYPE_PELLET],     s_len, "%7d", (bRound) ? g_strPlayerData[j][plyFFTakenPellet] : g_strRoundPlayerData[j][plyFFTakenPellet] );
        } else {                            Format(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenBullet] || bRound && g_strRoundPlayerData[j][plyFFTakenBullet] ) {
            Format(strPrint[FFTYPE_BULLET],     s_len, "%7d", (bRound) ? g_strPlayerData[j][plyFFTakenBullet] : g_strRoundPlayerData[j][plyFFTakenBullet] );
        } else {                            Format(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenMelee] || bRound && g_strRoundPlayerData[j][plyFFTakenMelee] ) {
            Format(strPrint[FFTYPE_MELEE],      s_len, "%6d", (bRound) ? g_strPlayerData[j][plyFFTakenMelee] : g_strRoundPlayerData[j][plyFFTakenMelee] );
        } else {                            Format(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenFire] || bRound && g_strRoundPlayerData[j][plyFFTakenFire] ) {
            Format(strPrint[FFTYPE_FIRE],       s_len, "%6d", (bRound) ? g_strPlayerData[j][plyFFTakenFire] : g_strRoundPlayerData[j][plyFFTakenFire] );
        } else {                            Format(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenIncap] || bRound && g_strRoundPlayerData[j][plyFFTakenIncap] ) {
            Format(strPrint[FFTYPE_INCAP],      s_len, "%8d", (bRound) ? g_strPlayerData[j][plyFFTakenIncap] : g_strRoundPlayerData[j][plyFFTakenIncap] );
        } else {                            Format(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenOther] || bRound && g_strRoundPlayerData[j][plyFFTakenOther] ) {
            Format(strPrint[FFTYPE_OTHER],      s_len, "%6d", (bRound) ? g_strPlayerData[j][plyFFTakenOther] : g_strRoundPlayerData[j][plyFFTakenOther] );
        } else {                            Format(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[j][plyFallDamage] || bRound && g_strRoundPlayerData[j][plyFallDamage] ) {
            Format(strPrint[FFTYPE_SELF],       s_len, "%7d", (bRound) ? g_strRoundPlayerData[j][plyFallDamage] : g_strPlayerData[j][plyFallDamage] );
        } else {                            Format(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[j] );
        
        // Format the basic stats
        Format(g_sConsoleBufFFTaken, CONBUFSIZE,
                "%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |\n",
                g_sConsoleBufFFTaken,
                g_sTmpString,
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE],   strPrint[FFTYPE_INCAP],  strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF]
            );
    }
}

stock SortPlayersMVP( bool:round = true, sortCol = SORT_SI )
{
    new iStored = 0;
    new i, j;
    new bool: found, highest;
    
    if ( sortCol < SORT_SI || sortCol > SORT_FF ) { return; }
    
    while ( iStored < g_iPlayers )
    {
        highest = -1;
        
        for ( i = 0; i < g_iPlayers; i++ )
        {
            // if we already sorted the index, skip it
            found = false;
            for ( j = 0; j < iStored; j++ )
            {
                if ( g_iPlayerIndexSorted[sortCol][j] == i ) { found = true; }
            }
            if ( found ) { continue; }
            
            // if the index is the (next) highest, take it
            switch ( sortCol )
            {
                case SORT_SI:
                {
                    if ( round ) {
                        if ( highest == -1 || g_strRoundPlayerData[i][plySIDamage] > g_strRoundPlayerData[highest][plySIDamage] ) {
                            highest = i;
                        }
                    } else {
                        if ( highest == -1 || g_strPlayerData[i][plySIDamage] > g_strPlayerData[highest][plySIDamage] ) {
                            highest = i;
                        }
                    }
                }
                case SORT_CI:
                {
                    if ( round ) {
                        if ( highest == -1 || g_strRoundPlayerData[i][plyCommon] > g_strRoundPlayerData[highest][plyCommon] ) {
                            highest = i;
                        }
                    } else {
                        if ( highest == -1 || g_strPlayerData[i][plyCommon] > g_strPlayerData[highest][plyCommon] ) {
                            highest = i;
                        }
                    }
                }
                case SORT_FF:
                {
                    if ( round ) {
                        if ( highest == -1 || g_strRoundPlayerData[i][plyFFGiven] > g_strRoundPlayerData[highest][plyFFGiven] ) {
                            highest = i;
                        }
                    } else {
                        if ( highest == -1 || g_strPlayerData[i][plyFFGiven] > g_strPlayerData[highest][plyFFGiven] ) {
                            highest = i;
                        }
                    }
                }
            }
        }
    
        g_iPlayerIndexSorted[sortCol][iStored] = highest;
        iStored++;
    }
}

/*
    Automatic display
    -----------------
*/
stock AutomaticRoundEndPrint( bool:doDelay = true )
{
    new Float:fDelay = ROUNDEND_DELAY;
    if ( g_bModeScavenge ) { fDelay = ROUNDEND_DELAY_SCAV; }
    
    if ( doDelay ) {
        CreateTimer( fDelay, Timer_AutomaticRoundEndPrint, _, TIMER_FLAG_NO_MAPCHANGE );
    }
    else {
        Timer_AutomaticRoundEndPrint(INVALID_HANDLE);
    }
}

public Action: Timer_AutomaticRoundEndPrint ( Handle:timer )
{
    // what should we display?
    
    // check cvar flags
    // mvp print?
    // current round stats only .. which tables?
    
    new iFlags = GetConVarInt( ( g_bModeCampaign ) ? g_hCvarAutoPrintCoop : g_hCvarAutoPrintVs );
    
    new bool: bSorted = (iFlags & AUTO_MVPCON_ROUND) || (iFlags & AUTO_MVPCON_ALL) || (iFlags & AUTO_MVPCON_TANK);
    new bool: bSortedForGame = false;
    
    // mvp
    if ( iFlags & AUTO_MVPCON_ROUND ) {
        DisplayStatsMVP(-1, false, true);
    }
    if ( iFlags & AUTO_MVPCON_ALL ) {
        DisplayStatsMVP(-1, false, false);
        bSortedForGame = true;
    }
    if ( iFlags & AUTO_MVPCON_TANK ) {
        DisplayStatsMVP(-1, true);
    }
    
    if ( iFlags & AUTO_MVPCHAT_ROUND ) {
        if ( !bSorted || bSortedForGame ) {
            // not sorted yet, sort for SI [round]
            SortPlayersMVP( true, SORT_SI );
            bSorted = true;
        }
        DisplayStatsMVPChat(-1, true);
    }
    
    if ( iFlags & AUTO_MVPCHAT_ALL ) {
        if ( !bSorted || !bSortedForGame ) {
            // not sorted yet, sort for SI
            bSortedForGame = true;
            SortPlayersMVP( false, SORT_SI );
            bSorted = true;
        }
        DisplayStatsMVPChat(-1, false);
    }
    
    // special / skill
    if ( iFlags & AUTO_SKILLCON_ROUND ) {
        DisplayStatsSpecial(-1, true, false);
    }
    if ( iFlags & AUTO_SKILLCON_ALL ) {
        DisplayStatsSpecial(-1, false, false);
    }
    
    // ff
    if ( iFlags & AUTO_FFCON_ROUND ) {
        DisplayStatsFriendlyFire(-1, true, (bSorted && !bSortedForGame) );
    }
    if ( iFlags & AUTO_FFCON_ALL ) {
        DisplayStatsFriendlyFire(-1, false, (bSorted && bSortedForGame) );
    }
    
    // accuracy
    if ( iFlags & AUTO_ACCCON_ROUND ) {
        DisplayStatsAccuracy(-1, false, true, (bSorted && !bSortedForGame) );
    }
    if ( iFlags & AUTO_ACCCON_ALL ) {
        DisplayStatsAccuracy(-1, false, false, (bSorted && bSortedForGame) );
    }
    if ( iFlags & AUTO_ACCCON_MORE_ROUND ) {
        DisplayStatsAccuracy(-1, true, true, (bSorted && !bSortedForGame) );
    }
    if ( iFlags & AUTO_ACCCON_MORE_ALL ) {
        DisplayStatsAccuracy(-1, true, false, (bSorted && bSortedForGame) );
    }
    
    // to do:
    // - inf
    // - fun fact
    
}


/*  
    Support
    -------
*/
stock GetCurrentTeamSurvivor()
{
    return GameRules_GetProp("m_bAreTeamsFlipped");
}

stock GetWeaponTypeForId ( weaponId )
{
    if ( weaponId == WP_PISTOL || weaponId == WP_PISTOL_MAGNUM )
    {
        return WPTYPE_PISTOL;
    }
    else if (   weaponId == WP_SMG || weaponId == WP_SMG_SILENCED || weaponId == WP_SMG_MP5 ||
                weaponId == WP_RIFLE || weaponId == WP_RIFLE_DESERT || weaponId == WP_RIFLE_AK47 || weaponId == WP_RIFLE_SG552
    ) {
        return WPTYPE_SMG;
    }
    else if (   weaponId == WP_PUMPSHOTGUN || weaponId == WP_SHOTGUN_CHROME ||
                weaponId == WP_AUTOSHOTGUN || weaponId == WP_SHOTGUN_SPAS
    ) {
        return WPTYPE_SHOTGUN;
    }
    else if (   weaponId == WP_HUNTING_RIFLE || weaponId == WP_SNIPER_MILITARY  ||
                weaponId == WP_SNIPER_AWP || weaponId == WP_SNIPER_SCOUT
    ) {
        return WPTYPE_SNIPER;
    }
    
    return 0;
}

stock GetWeaponTypeForClassname ( const String:classname[] )
{
    new strWeaponType: weaponType;
    
    if ( !GetTrieValue(g_hTrieWeapons, classname, weaponType) ) {
        return WPTYPE_NONE;
    }
    
    return weaponType;
}

stock GetPlayerIndexForClient ( client )
{
    if ( !IsClientAndInGame(client) ) { return -1; }
    
    decl String: sSteamId[32];
    
    // fake clients:
    if ( IsFakeClient(client) )
    {
        Format( sSteamId, sizeof( sSteamId ), "BOT_%i", GetPlayerCharacter(client) );
    }
    else
    {
        GetClientAuthString( client, sSteamId, sizeof(sSteamId) );
    }
    
    return GetPlayerIndexForSteamId( sSteamId, client );
}

stock GetPlayerIndexForSteamId ( const String:steamId[], client=-1 )
{
    new pIndex = -1;
    
    if ( !GetTrieValue( g_hTriePlayers, steamId, pIndex ) )
    {
        // add it
        pIndex = g_iPlayers;
        SetTrieValue( g_hTriePlayers, steamId, pIndex );
        
        // store name
        if ( client != -1 ) {
            GetClientName( client, g_sPlayerName[pIndex], MAXNAME );
        }
        
        //PrintToChatAll("client: %i %N %s", client, client, g_sPlayerName[g_iPlayers] );
        
        g_iPlayers++;
        
        // safeguard
        if ( g_iPlayers >= MAXTRACKED ) {
            g_iPlayers = FIRST_NON_BOT;
        }
    }
    
    return pIndex;
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


stock bool: IsClientAndInGame (index)
{
    if (index > 0 && index <= MaxClients)
    {
        return IsClientInGame(index);
    }
    return false;
}
stock bool: IsWitch ( iEntity )
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "witch");
    }
    return false;
}

stock bool: IsTankInGame()
{
    for ( new client = 1; client <= MaxClients; client++ )
    {
        if ( IS_VALID_INFECTED(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK)
        {
            return true;
        }
    }
    return false;
}
stock bool: IsPlayerIncapacitated ( client )
{
    return bool: GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
}

/*
    Tries
    -----
*/

stock InitTries()
{
    // player index
    g_hTriePlayers = CreateTrie();
    
    // create 4 slots for bots
    SetTrieValue( g_hTriePlayers, "BOT_0", 0 );
    SetTrieValue( g_hTriePlayers, "BOT_1", 1 );
    SetTrieValue( g_hTriePlayers, "BOT_2", 2 );
    SetTrieValue( g_hTriePlayers, "BOT_3", 3 );
    g_sPlayerName[0] = "BOT [Nick/Bill]";
    g_sPlayerName[1] = "BOT [Rochelle/Zoey]";
    g_sPlayerName[2] = "BOT [Coach/Louis]";
    g_sPlayerName[3] = "BOT [Ellis/Francis]";
    g_iPlayers += FIRST_NON_BOT;
    
    // weapon recognition
    g_hTrieWeapons = CreateTrie();
    SetTrieValue(g_hTrieWeapons, "weapon_pistol",              WPTYPE_PISTOL);
    SetTrieValue(g_hTrieWeapons, "weapon_pistol_magnum",       WPTYPE_PISTOL);
    SetTrieValue(g_hTrieWeapons, "weapon_pumpshotgun",         WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_shotgun_chrome",      WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_autoshotgun",         WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_shotgun_spas",        WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_hunting_rifle",       WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_sniper_military",     WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_sniper_awp",          WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_sniper_scout",        WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_smg",                 WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_smg_silenced",        WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle",               WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_desert",        WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_ak47",          WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_smg_mp5",             WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_sg552",         WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_m60",           WPTYPE_SMG);
    //SetTrieValue(g_hTrieWeapons, "weapon_melee",               WPTYPE_NONE);
    //SetTrieValue(g_hTrieWeapons, "weapon_chainsaw",            WPTYPE_NONE);
    //SetTrieValue(g_hTrieWeapons, "weapon_grenade_launcher",    WP_NONE);
    
    g_hTrieEntityCreated = CreateTrie();
    SetTrieValue(g_hTrieEntityCreated, "infected",              OEC_INFECTED);
}
/*
    General functions
    -----------------
*/
stock CheckGameMode()
{
    // check gamemode for 'coop'
    new String:tmpStr[24];
    GetConVarString( FindConVar("mp_gamemode"), tmpStr, sizeof(tmpStr) );
    
    if (    StrEqual(tmpStr, "coop", false)         ||
            StrEqual(tmpStr, "mutation4", false)    ||      // hard eight
            StrEqual(tmpStr, "mutation14", false)   ||      // gib fest
            StrEqual(tmpStr, "mutation20", false)   ||      // healing gnome
            StrEqual(tmpStr, "mutationrandomcoop", false)   // healing gnome
    ) {
        g_bModeCampaign = true;
        g_bModeScavenge = false;
    }
    else if ( StrEqual(tmpStr, "scavenge", false) )
    {
        g_bModeCampaign = false;
        g_bModeScavenge = true;
    }
    else {
        g_bModeCampaign = false;
        g_bModeScavenge = false;
    }
}

stock stripUnicode ( String:testString[MAXNAME], maxLength = 20 )
{
    if ( maxLength < 1 ) { maxLength = MAX_NAME_LENGTH; }
    
    //strcopy(testString, maxLength, sTmpString);
    g_sTmpString = testString;
    
    new uni=0;
    new currentChar;
    new tmpCharLength = 0;
    //new iReplace[MAX_NAME_LENGTH];      // replace these chars
    
    for ( new i = 0; i < maxLength - 3 && g_sTmpString[i] != 0; i++ )
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
    
    if ( strlen(g_sTmpString) > maxLength )
    {
        g_sTmpString[maxLength] = 0;
    }
}

stock PrintDebug( debugLevel, const String:Message[], any:... )
{
    if (debugLevel <= GetConVarInt(g_hCvarDebug))
    {
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 3);
        LogMessage(DebugBuff);
        //PrintToServer(DebugBuff);
        //PrintToChatAll(DebugBuff);
    }
}

