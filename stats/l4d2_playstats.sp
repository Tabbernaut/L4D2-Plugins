#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>
#include <l4d2_direct>
#include <clientprefs>
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
#define CONBUFSIZELARGE         (1 << 12)       // 4k
#define MAXCHUNKS               10              // how many chunks of 4k max
#define CHARTHRESHOLD           160             // detecting unicode stuff
#define MAXLINESPERCHUNK        4               // how many lines in a chunk
#define DIVIDERINTERVAL         4               // add divider line every X lines

#define MAXTRACKED              64
#define MAXROUNDS               48              // ridiculously high, but just in case players do a marathon or something
#define MAXSHOWROUNDS           10              // how many rounds to show in the general stats table, max

#define MAXNAME                 64
#define MAXNAME_TABLE           20              // name size max in console tables
#define MAXCHARACTERS           4
#define MAXMAP                  32
#define MAXGAME                 24

#define STATS_RESET_DELAY       5.0
#define ROUNDSTART_DELAY        3.0
#define ROUNDEND_SCORE_DELAY    1.0
#define ROUNDEND_DELAY          3.0
#define ROUNDEND_DELAY_SCAV     2.0
#define PRINT_REPEAT_DELAY      15              // how many seconds to wait before re-doing automatic round end prints (opening/closing end door, etc)

#define MIN_TEAM_PRESENT_TIME   30              // how many seconds a player with 0-stats has to have been on a team to be listed as part of that team

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
#define LTEAM_CURRENT           2

#define BREV_SI                 (1 << 0)        // flags for MVP chat print appearance
#define BREV_CI                 (1 << 1)
#define BREV_FF                 (1 << 2)
#define BREV_RANK               (1 << 3)        // note: 16 reserved/removed
#define BREV_PERCENT            (1 << 5)
#define BREV_ABSOLUTE           (1 << 6)

#define AUTO_MVPCHAT_ROUND      (1 << 0)        // flags for what to print automatically at round end
#define AUTO_MVPCHAT_GAME       (1 << 1)
#define AUTO_MVPCON_ROUND       (1 << 2)
#define AUTO_MVPCON_GAME        (1 << 3)
#define AUTO_MVPCON_TANK        (1 << 4)        // 16
#define AUTO_FFCON_ROUND        (1 << 5)
#define AUTO_FFCON_GAME         (1 << 6)
#define AUTO_SKILLCON_ROUND     (1 << 7)        // 128
#define AUTO_SKILLCON_GAME      (1 << 8)
#define AUTO_ACCCON_ROUND       (1 << 9)
#define AUTO_ACCCON_GAME        (1 << 10)       // 1024
#define AUTO_ACCCON_MORE_ROUND  (1 << 11)
#define AUTO_ACCCON_MORE_GAME   (1 << 12)
#define AUTO_FUNFACT_ROUND      (1 << 13)
#define AUTO_FUNFACT_GAME       (1 << 14)       // 16384
#define AUTO_MVPCON_MORE_ROUND  (1 << 15)
#define AUTO_MVPCON_MORE_GAME   (1 << 16)

// fun fact
#define FFACT_MAX_WEIGHT        10
#define FFACT_TYPE_CROWN        1
#define FFACT_TYPE_DRAWCROWN    2
#define FFACT_TYPE_SKEETS       3
#define FFACT_TYPE_MELEESKEETS  4
#define FFACT_TYPE_HUNTERDP     5
#define FFACT_TYPE_JOCKEYDP     6
#define FFACT_TYPE_M2           7
#define FFACT_TYPE_MELEETANK    8
#define FFACT_TYPE_CUT          9
#define FFACT_TYPE_POP          10
#define FFACT_TYPE_DEADSTOP     11
#define FFACT_TYPE_LEVELS       12
#define FFACT_MAXTYPES          12

#define FFACT_MIN_CROWN         1
#define FFACT_MAX_CROWN         10
#define FFACT_MIN_DRAWCROWN     1
#define FFACT_MAX_DRAWCROWN     10
#define FFACT_MIN_SKEET         2
#define FFACT_MAX_SKEET         20
#define FFACT_MIN_MELEESKEET    1
#define FFACT_MAX_MELEESKEET    10
#define FFACT_MIN_HUNTERDP      2
#define FFACT_MAX_HUNTERDP      10
#define FFACT_MIN_JOCKEYDP      2
#define FFACT_MAX_JOCKEYDP      10
#define FFACT_MIN_M2            15
#define FFACT_MAX_M2            50
#define FFACT_MIN_MELEETANK     4
#define FFACT_MAX_MELEETANK     10
#define FFACT_MIN_CUT           4
#define FFACT_MAX_CUT           10
#define FFACT_MIN_POP           4
#define FFACT_MAX_POP           10
#define FFACT_MIN_DEADSTOP      7
#define FFACT_MAX_DEADSTOP      20
#define FFACT_MIN_LEVEL         3
#define FFACT_MAX_LEVEL         10


// writing
#define DIR_OUTPUT              "logs/"
#define MAX_QUERY_SIZE          8192
#define FILETABLEFLAGS          33460           // AUTO_ flags for what to print to a file automatically

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
    typInf,
    typFact
};

// information for entire game
enum _:strGameData
{
            gmFailed,               // survivors lost the mission * times
            gmStartTime             // GetTime() value when starting
};

// information per round
enum _:strRoundData
{
            rndRestarts,            // how many times retried?
            rndPillsUsed,
            rndKitsUsed,
            rndDefibsUsed,
            rndCommon,
            rndSIKilled,
            rndSIDamage,
            rndSISpawned,
            rndWitchKilled,
            rndTankKilled,
            rndIncaps,              // 10
            rndDeaths,
            rndFFDamageTotal,
            rndStartTime,           // GetTime() value when starting    
            rndEndTime,             // GetTime() value when done
            rndStartTimePause,
            rndStopTimePause,
            rndStartTimeTank,
            rndStopTimeTank
};
#define MAXRNDSTATS                 18

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
            plyJockeyDPs,           // 70
            plyTimeStartPresent,    //      time present (on the team)
            plyTimeStopPresent,     //      if stoptime is 0, then it's NOW, ongoing
            plyTimeStartAlive,
            plyTimeStopAlive,
            plyTimeStartUpright,    //      time not capped
            plyTimeStopUpright
};
#define MAXPLYSTATS                 76

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
    OEC_INFECTED,
    OEC_WITCH
};

new     bool:   g_bLateLoad             = false;
new     bool:   g_bFirstLoadDone        = false;                                        // true after first onMapStart
new     bool:   g_bLoadSkipDone         = false;                                        // true after skipping the _resetnextmap for stats
new     bool:   g_bReadyUpAvailable     = false;
new     bool:   g_bPauseAvailable       = false;
new     bool:   g_bSkillDetectLoaded    = false;
new     bool:   g_bCMTActive            = false;

new     bool:   g_bModeCampaign         = false;
new     bool:   g_bModeScavenge         = false;

new     Handle: g_hCookiePrint          = INVALID_HANDLE;
new             g_iCookieValue          [MAXPLAYERS+1];                                 // if a cookie is set for a client, this is its value

new     Handle: g_hCvarDebug            = INVALID_HANDLE;
new     Handle: g_hCvarMVPBrevityFlags  = INVALID_HANDLE;
new     Handle: g_hCvarAutoPrintVs      = INVALID_HANDLE;
new     Handle: g_hCvarAutoPrintCoop    = INVALID_HANDLE;
new     Handle: g_hCvarShowBots         = INVALID_HANDLE;
new     Handle: g_hCvarDetailPercent    = INVALID_HANDLE;
new     Handle: g_hCvarWriteStats       = INVALID_HANDLE;
new     Handle: g_hCvarSkipMap          = INVALID_HANDLE;

new     bool:   g_bGameStarted          = false;
new     bool:   g_bInRound              = false;
new     bool:   g_bTeamChanged          = false;                                        // to only do a teamcheck if a check is not already pending
new     bool:   g_bTankInGame           = false;
new     bool:   g_bPlayersLeftStart     = false;
new     bool:   g_bSecondHalf           = false;                                        // second roundhalf in a versus round
new     bool:   g_bFailedPrevious       = false;                                        // whether the previous attempt was a failed campaign mode round
new             g_iRound                = 0;
new             g_iCurTeam              = LTEAM_A;                                      // current logical team
new             g_iTeamSize             = 4;
new             g_iLastRoundEndPrint    = 0;                                            // when the last automatic print was shown
new             g_iSurvived             [2];                                            // just for stats: how many survivors that round (0 = wipe)

new     bool:   g_bPaused               = false;                                        // whether paused with pause.smx
new             g_iPauseStart           = 0;                                            // time the current pause started

new             g_iScores               [2];                                            // scores for both teams, as currently known
new             g_iOldScores            [2];                                            // scores for both teams, as in previous round

new             g_iPlayerIndexSorted    [MAXSORTS][MAXTRACKED];                         // used to create a sorted list
new             g_iPlayerSortedUseTeam  [MAXSORTS][MAXTRACKED];                         // after sorting: which team to use as the survivor team for player
new             g_iPlayerRoundTeam      [3][MAXTRACKED];                                // which team is the player 0 = A, 1 = B, -1 = no team; [2] = current survivor round; [0]/[1] = team A / B (anyone who was ever on it)

new             g_strGameData           [strGameData];
new             g_strAllRoundData       [2][strRoundData];                              // rounddata for ALL rounds, per team
new             g_strRoundData          [MAXROUNDS][2][strRoundData];                   // rounddata per game round, per team
new             g_strPlayerData         [MAXTRACKED][strPlayerData];
new             g_strRoundPlayerData    [MAXTRACKED][2][strPlayerData];                 // player data per team

new     Handle: g_hTriePlayers                                      = INVALID_HANDLE;   // trie for getting player index
new     Handle: g_hTrieWeapons                                      = INVALID_HANDLE;   // trie for getting weapon type (from classname)
new     Handle: g_hTrieEntityCreated                                = INVALID_HANDLE;   // trie for getting classname of entity created

new     String: g_sPlayerName           [MAXTRACKED][MAXNAME];
new     String: g_sPlayerNameSafe       [MAXTRACKED][MAXNAME];                          // version of name without unicode characters
new     String: g_sPlayerId             [MAXTRACKED][32];                               // steam id
new     String: g_sMapName              [MAXROUNDS][MAXMAP];
new     String: g_sConfigName           [MAXMAP];
new             g_iPlayers                                          = 0;

new     String: g_sConsoleBuf           [MAXCHUNKS][CONBUFSIZELARGE];
new             g_iConsoleBufChunks                                 = 0;

new     String: g_sStatsFile            [MAXNAME];                                      // name for the statsfile we should write to
new     Handle: g_hStatsFile;                                                           // handle for a statsfile that we write tables to


public Plugin: myinfo =
{
    name = "Player Statistics",
    author = "Tabun",
    description = "Tracks statistics, even when clients disconnect. MVP, Skills, Accuracy, etc.",
    version = "0.9.10",
    url = "https://github.com/Tabbernaut/L4D2-Plugins"
};


/*
    todo
    ----

        fixes:
        ------
        - game data doesn't show (even when it should, after a round is done)
        - pause time is incorrect, sometimes?

        - accuracy still shaky..
            - 174% with pistols..
            - 103% with sniper..
                check weaponfire event.. if it doesn't fire always (or sometimes has 'count' too) there is a prob
                maybe it's got to do with tank-spawning + passing? 
        
        - there might be some problem with printing large tables
            at round-end .. test some more (garbage text appears?)
            - it's not the size.. got something to do with the timing?
            - or delays between prints? (<= prolly)
            
        - filewrite
            - get reliable max flowdist per survivor -- how?
            
        build:
        ------
        - skill
            - clears / instaclears / average clear time?

        - make infected skills table
                dps (hunter),
                damage done (to upright survivors),
                commons killed,
                dc's, assists, ?
        
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
    g_bPauseAvailable = LibraryExists("pause");
    g_bSkillDetectLoaded = LibraryExists("skill_detect");
}
public OnLibraryRemoved(const String:name[])
{
    if ( StrEqual(name, "readyup") ) { g_bReadyUpAvailable = false; }
    if ( StrEqual(name, "pause") ) { g_bPauseAvailable = false; }
    if ( StrEqual(name, "skill_detect") ) { g_bSkillDetectLoaded = false; }
}
public OnLibraryAdded(const String:name[])
{
    if ( StrEqual(name, "readyup") ) { g_bReadyUpAvailable = true; }
    if ( StrEqual(name, "pause") ) { g_bPauseAvailable = true; }
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
    HookEvent("survivor_rescued",           Event_SurvivorRescue,           EventHookMode_Post);
    
    HookEvent("player_team",                Event_PlayerTeam,               EventHookMode_Post);
    HookEvent("player_spawn",               Event_PlayerSpawn,              EventHookMode_Post);
    HookEvent("player_hurt",                Event_PlayerHurt,               EventHookMode_Post);
    HookEvent("player_death",               Event_PlayerDeath,              EventHookMode_Post);
    HookEvent("player_incapacitated",       Event_PlayerIncapped,           EventHookMode_Post);
    HookEvent("player_ledge_grab",          Event_PlayerLedged,             EventHookMode_Post);
    HookEvent("player_ledge_release",       Event_PlayerLedgeRelease,       EventHookMode_Post);
    
    HookEvent("revive_success",             Event_PlayerRevived,            EventHookMode_Post);
    HookEvent("player_falldamage",          Event_PlayerFallDamage,         EventHookMode_Post);
    
    HookEvent("tank_spawn",                 Event_TankSpawned,              EventHookMode_Post);
    HookEvent("weapon_fire",                Event_WeaponFire,               EventHookMode_Post);
    HookEvent("infected_hurt",              Event_InfectedHurt,             EventHookMode_Post);
    HookEvent("witch_killed",               Event_WitchKilled,              EventHookMode_Post);
    HookEvent("heal_success",               Event_HealSuccess,              EventHookMode_Post);
    HookEvent("defibrillator_used",         Event_DefibUsed,                EventHookMode_Post);
    HookEvent("pills_used",                 Event_PillsUsed,                EventHookMode_Post);
    HookEvent("adrenaline_used",            Event_AdrenUsed,                EventHookMode_Post);
    
    
    // cvars
    g_hCvarDebug = CreateConVar(
            "sm_stats_debug",
            "0",
            "Debug mode",
            FCVAR_PLUGIN, true, 0.0, false
        );
    g_hCvarMVPBrevityFlags = CreateConVar(
            "sm_survivor_mvp_brevity",
            "4",
            "Flags for setting brevity of MVP chat report (hide 1:SI, 2:CI, 4:FF, 8:rank, 32:perc, 64:abs).",
            FCVAR_PLUGIN, true, 0.0, false
        );
    g_hCvarAutoPrintVs = CreateConVar(
            "sm_stats_autoprint_vs_round",
            "8325",                                     // default = 1 (mvpchat) + 4 (mvpcon-round) + 128 (special round) = 133 + (funfact round) 8192 = 8325
            "Flags for automatic print [versus round] (show 1,4:MVP-chat, 4,8,16:MVP-console, 32,64:FF, 128,256:special, 512,1024,2048,4096:accuracy).",
            FCVAR_PLUGIN, true, 0.0, false
        );
    g_hCvarAutoPrintCoop = CreateConVar(
            "sm_stats_autoprint_coop_round",
            "1289",                                     // default = 1 (mvpchat) + 8 (mvpcon-all) + 256 (special all) + 1024 (acc all) = 1289
            "Flags for automatic print [campaign round] (show 1,4:MVP-chat, 4,8,16:MVP-console, 32,64:FF, 128,256:special, 512,1024,2048,4096:accuracy).",
            FCVAR_PLUGIN, true, 0.0, false
        );
    g_hCvarShowBots = CreateConVar(
            "sm_stats_showbots",
            "1",
            "Show bots in all tables (0 = show them in MVP and FF tables only)",
            FCVAR_PLUGIN, true, 0.0, false
        );
    g_hCvarDetailPercent = CreateConVar(
            "sm_stats_percentdecimal",
            "0",
            "Show the first decimal for (most) MVP percent in console tables.",
            FCVAR_PLUGIN, true, 0.0, false
        );
    g_hCvarWriteStats = CreateConVar(
            "sm_stats_writestats",
            "0",
            "Whether to store stats in logs/ dir (1 = write csv; 2 = write csv & pretty tables). Versus only.",
            FCVAR_PLUGIN, true, 0.0, false
        );
    g_hCvarSkipMap = CreateConVar(
            "sm_stats_resetnextmap",
            "0",
            "First round is ignored (for use with confogl/matchvotes - this will be automatically unset after a new map is loaded).",
            FCVAR_PLUGIN, true, 0.0, false
        );
    
    g_iTeamSize = 4;
    
    
    // commands:
    RegConsoleCmd( "sm_stats",      Cmd_StatsDisplayGeneral,    "Prints stats for survivors" );
    RegConsoleCmd( "sm_mvp",        Cmd_StatsDisplayGeneral,    "Prints MVP stats for survivors" );
    RegConsoleCmd( "sm_skill",      Cmd_StatsDisplayGeneral,    "Prints special skills stats for survivors" );
    RegConsoleCmd( "sm_ff",         Cmd_StatsDisplayGeneral,    "Prints friendly fire stats stats" );
    RegConsoleCmd( "sm_acc",        Cmd_StatsDisplayGeneral,    "Prints accuracy stats for survivors" );
    
    RegConsoleCmd( "sm_stats_auto", Cmd_Cookie_SetPrintFlags,   "Sets client-side preference for automatic stats-print at end of round" );
    
    RegAdminCmd(   "statsreset",    Cmd_StatsReset, ADMFLAG_CHANGEMAP, "Resets the statistics. Admins only." );
    
    RegConsoleCmd( "say",           Cmd_Say );
    RegConsoleCmd( "say_team",      Cmd_Say );
    
    // cookie
    g_hCookiePrint = RegClientCookie( "sm_stats_autoprintflags", "Stats Auto Print Flags", CookieAccess_Public );
    
    // tries
    InitTries();
    
    // prepare team array
    ClearPlayerTeam();
    
    if ( g_bLateLoad )
    {
        new i, index;
        new time = GetTime();
        
        for ( i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) && !IsFakeClient(i) )
            {
                // store each player with a first check
                index = GetPlayerIndexForClient( i );
                
                // set start time to now
                g_strRoundPlayerData[index][0][plyTimeStartPresent] = time;
                g_strRoundPlayerData[index][0][plyTimeStartAlive] = time;
                g_strRoundPlayerData[index][0][plyTimeStartUpright] = time;
                g_strRoundPlayerData[index][1][plyTimeStartPresent] = time;
                g_strRoundPlayerData[index][1][plyTimeStartAlive] = time;
                g_strRoundPlayerData[index][1][plyTimeStartUpright] = time;
            }
        }
        
        // set time for bots aswell
        for ( i = 0; i < FIRST_NON_BOT; i++ )
        {
            g_strRoundPlayerData[i][0][plyTimeStartPresent] = time;
            g_strRoundPlayerData[i][0][plyTimeStartAlive] = time;
            g_strRoundPlayerData[i][0][plyTimeStartUpright] = time;
            g_strRoundPlayerData[i][1][plyTimeStartPresent] = time;
            g_strRoundPlayerData[i][1][plyTimeStartAlive] = time;
            g_strRoundPlayerData[i][1][plyTimeStartUpright] = time;
        }
        
        // just assume this
        g_bInRound = true;
        g_bPlayersLeftStart = true;
        
        g_strGameData[gmStartTime] = GetTime();
        g_strRoundData[0][0][rndStartTime] = GetTime();
        g_strRoundData[0][1][rndStartTime] = GetTime();
        
        // team
        g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
        UpdatePlayerCurrentTeam();
    }
}

public OnConfigsExecuted()
{
    g_iTeamSize = GetConVarInt( FindConVar("survivor_limit") );
    
    // currently loaded config?
    g_sConfigName = "";
    
    new Handle: tmpHandle = FindConVar("l4d_ready_cfg_name");
    if ( tmpHandle != INVALID_HANDLE )
    {
        GetConVarString( tmpHandle, g_sConfigName, MAXMAP );
    }
}

// find a player
public OnClientPostAdminCheck( client )
{
    GetPlayerIndexForClient( client );
}

public OnClientDisconnect( client )
{
    g_iCookieValue[client] = 0;
    
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    // only note time for survivor team players
    if ( g_iPlayerRoundTeam[LTEAM_CURRENT][index] != g_iCurTeam ) { return; }
    
    // store time they left
    new time = GetTime();
    
    // if paused, substract time so far from player's time in game
    if ( g_bPaused ) {
        time = g_iPauseStart;
    }
    
    g_strPlayerData[index][plyTimeStopPresent] = time;
    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] = time;
    if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time; }
    if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time; }
}

public OnMapStart()
{
    GetCurrentMap( g_sMapName[g_iRound], MAXMAP );
    //PrintDebug( 2, "MapStart (round %i): %s ", g_iRound, g_sMapName[g_iRound] );
    
    g_bSecondHalf = false;
    
    CheckGameMode();
    
    if ( !g_bLoadSkipDone && GetConVarBool(g_hCvarSkipMap) )
    {
        // reset stats and unset cvar
        PrintDebug( 2, "OnMapStart: Resetting all stats (resetnextmap setting)...s " );
        ResetStats( false, -1 );
        
        // this might not work (server might be resetting the resetnextmap var every time
        //  so also using the bool to make sure it only happens once
        SetConVarInt(g_hCvarSkipMap, 0);
        g_bLoadSkipDone = true;
    }
    else if ( g_bFirstLoadDone )
    {
        // reset stats for previous round
        PrintDebug( 2, "OnMapStart: Reset stats for round (Timer_ResetStats)" );
        CreateTimer( STATS_RESET_DELAY, Timer_ResetStats, 1, TIMER_FLAG_NO_MAPCHANGE );
    }
    
    g_bFirstLoadDone = true;
    
    if ( !g_bModeCampaign )
    {
        g_iOldScores[LTEAM_A] = g_iScores[LTEAM_A];
        g_iOldScores[LTEAM_B] = g_iScores[LTEAM_B];
    }
}

public OnMapEnd()
{
    //PrintDebug(2, "MapEnd (round %i)", g_iRound);
    g_bInRound = false;
    g_iRound++;
    
    // if this was a finale, (and CMT is not loaded), end of game
    if ( !g_bCMTActive && !g_bModeCampaign && L4D_IsMissionFinalMap() )
    {
        HandleGameEnd();
    }
}

public Event_MissionLostCampaign (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    //PrintDebug( 2, "Event: MissionLost (times %i)", g_strGameData[gmFailed] + 1);
    g_strGameData[gmFailed]++;
    g_strRoundData[g_iRound][g_iCurTeam][rndRestarts]++;
    
    HandleRoundEnd( true );
}

public Event_RoundStart (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    HandleRoundStart();
    CreateTimer( ROUNDSTART_DELAY, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE );
}
stock HandleRoundStart( bool:bLeftStart = false )
{
    //PrintDebug( 1, "HandleRoundStart (leftstart: %i): inround: %i", bLeftStart, g_bInRound);
    
    if ( g_bInRound ) { return; }
    
    g_bInRound = true;
    
    g_bPlayersLeftStart = bLeftStart;
    g_bTankInGame = false;
    g_bPaused = false;
    
    if ( bLeftStart )
    {
        g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
        ClearPlayerTeam( g_iCurTeam );
    }
}

// delayed, so we can trust GetCurrentTeamSurvivor()
public Action: Timer_RoundStart ( Handle:timer )
{
    // easier to handle: store current survivor team
    g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
    
    // clear team for stats
    ClearPlayerTeam( g_iCurTeam );
    
    //PrintDebug( 2, "Event_RoundStart (roundhalf: %i: survivor team: %i (cur survivor: %i))", (g_bSecondHalf) ? 1 : 0, g_iCurTeam, GetCurrentTeamSurvivor() );
}

public Event_RoundEnd (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // called on versus round end
    // and mission failed coop
    HandleRoundEnd();
}

// do something when round ends (including for campaign mode)
stock HandleRoundEnd ( bool: bFailed = false )
{
    PrintDebug( 1, "HandleRoundEnd (failed: %i): inround: %i, current round: %i", bFailed, g_bInRound, g_iRound);
    
    // only do once
    if ( !g_bInRound ) { return; }
    
    // count survivors
    g_iSurvived[g_iCurTeam] = GetUprightSurvivors();
    
    // note end of tankfight
    if ( g_bTankInGame ) {
        HandleTankTimeEnd();
    }
    
    // set all 0 times to present
    SetRoundEndTimes();
    
    g_bInRound = false;
    
    if ( !g_bModeCampaign || !bFailed )
    {
        // write stats for this roundhalf to file
        // do before addition, because these are round stats
        if ( GetConVarBool(g_hCvarWriteStats) )
        {
            if ( g_bSecondHalf )  {
                CreateTimer( ROUNDEND_SCORE_DELAY, Timer_WriteStats, g_iCurTeam );
            } else {
                WriteStatsToFile( g_iCurTeam, false );
            }
        }
        
        // only add stuff to total time if the round isn't ongoing
        HandleRoundAddition();
        
        if ( g_iLastRoundEndPrint == 0 || GetTime() - g_iLastRoundEndPrint > PRINT_REPEAT_DELAY )
        {
            // false == no delay
            AutomaticRoundEndPrint( false );
        }
    }
    
    // if no-one is on the server anymore, reset the stats (keep it clean when no real game is going on) [safeguard]
    if ( (g_bModeCampaign || g_bSecondHalf) && !AreClientsConnected() )
    {
        PrintDebug( 2, "HandleRoundEnd: Reset stats for entire game (no players on server)..." );
        ResetStats( false, -1 );
    }
    
    if ( !g_bModeCampaign )
    {
        g_bSecondHalf = true;
    }
    else
    {
        g_bFailedPrevious = bFailed;
    }
    
    g_bPlayersLeftStart = false;
}
// fix all 0-endtime values 
stock SetRoundEndTimes()
{
    new i, j;
    new time = GetTime();
    
    // start-stop times (always pairs)  <, not <=, because per 2!
    for ( i = rndStartTime; i < MAXRNDSTATS; i += 2 )
    {
        // set end
        if ( g_strRoundData[g_iRound][g_iCurTeam][i] && !g_strRoundData[g_iRound][g_iCurTeam][i+1] ) { g_strRoundData[g_iRound][g_iCurTeam][i+1] = time; }
    }
    
    // player data
    for ( j = 0; j < MAXTRACKED; j++ )
    {
        // start-stop times (always pairs)  <, not <=, because per 2!
        for ( i = plyTimeStartPresent; i < MAXPLYSTATS; i += 2 )
        {
            if ( g_strRoundPlayerData[j][g_iCurTeam][i] && !g_strRoundPlayerData[j][g_iCurTeam][i+1] ) { g_strRoundPlayerData[j][g_iCurTeam][i+1] = time; }
        }
    }
}

// add stuff from this round to the game/allround data arrays
stock HandleRoundAddition()
{
    new i, j;
    
    PrintDebug( 1, "Handling round addition for round %i, roundhalf %i (team %s).", g_iRound, g_bSecondHalf, (g_iCurTeam == LTEAM_A) ? "A" : "B" );
    
    // also sets end time to NOW for any 'ongoing' times for round/player
    
    // round data
    for ( i = 0; i < rndStartTime; i++ )
    {
        g_strAllRoundData[g_iCurTeam][i] += g_strRoundData[g_iRound][g_iCurTeam][i];
    }
    // start-stop times (always pairs)  <, not <=, because per 2!
    for ( i = rndStartTime; i < MAXRNDSTATS; i += 2 )
    {
        // set end
        g_strAllRoundData[g_iCurTeam][i+1] += g_strRoundData[g_iRound][g_iCurTeam][i+1] - g_strRoundData[g_iRound][g_iCurTeam][i];
    }
    
    // player data
    for ( j = 0; j < MAXTRACKED; j++ )
    {
        for ( i = 0; i < plyTimeStartPresent; i++ )
        {
            g_strPlayerData[j][i] += g_strRoundPlayerData[j][g_iCurTeam][i];
        }
        // start-stop times (always pairs)  <, not <=, because per 2!
        for ( i = plyTimeStartPresent; i < MAXPLYSTATS; i += 2 )
        {
            g_strPlayerData[j][i+1] += g_strRoundPlayerData[j][g_iCurTeam][i+1] - g_strRoundPlayerData[j][g_iCurTeam][i];
        }
    }
}

public Event_MapTransition (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // campaign (ignore in versus)
    if ( g_bModeCampaign )
    {
        HandleRoundEnd();
    }
}
public Event_FinaleWin (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // campaign (ignore in versus)
    if ( g_bModeCampaign )
    {
        HandleRoundEnd();
        // finale needn't be the end of the game with custom map transitions
        if ( !g_bCMTActive ) {
            HandleGameEnd();
        }
    }
    //AutomaticGameEndPrint();
}

// do something when game/campaign ends (including for campaign mode)
stock HandleGameEnd()
{
    // do automatic game end printing?
    
    // reset all stats
    ResetStats( false, -1 );
}
public OnRoundIsLive()
{
    // only called if readyup is available
    RoundReallyStarting();
}

public Action: L4D_OnFirstSurvivorLeftSafeArea( client )
{
    // just as a safeguard (for campaign mode / failed rounds?)
    HandleRoundStart( true );
    
    // if no readyup, use this as the starting event
    if ( !g_bReadyUpAvailable )
    {
        RoundReallyStarting();
    }
}

stock RoundReallyStarting()
{
    g_bPlayersLeftStart = true;
    new time = GetTime();
    
    if ( !g_bGameStarted )
    {
        g_bGameStarted = true;
        g_strGameData[gmStartTime] = time;
        // set start survivor time -- and tell this if we should take a round-failed-restart into account
        SetStartSurvivorTime( true, g_bFailedPrevious );
    }
    
    if ( g_bFailedPrevious && g_strRoundData[g_iRound][g_iCurTeam][rndEndTime] )
    {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] = time - ( g_strRoundData[g_iRound][g_iCurTeam][rndEndTime] - g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] );
        g_strRoundData[g_iRound][g_iCurTeam][rndEndTime] = 0;
        g_bFailedPrevious = false;
    }
    else
    {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] = time;
    }
    // the conditional below would allow full round times including fails.. not doing that now
    //if ( !g_bModeCampaign || g_strRoundData[g_iRound][g_iCurTeam][rndRestarts] == 0 ) { }
    
    //PrintDebug( 2, "RoundReallyStarting (round %i: roundhalf: %i: survivor team: %i)", g_iRound, (g_bSecondHalf) ? 1 : 0, g_iCurTeam );
    
    // make sure the teams are still what we think they are
    UpdatePlayerCurrentTeam();
    SetStartSurvivorTime();
}

public OnPause()
{
    if ( g_bPaused ) { return; }
    g_bPaused = true;
    
    new time = GetTime();
    
    g_iPauseStart = time;
    
    PrintDebug( 1, "Pause (start time: %i -- stored time: %i -- round start time: %i).", g_iPauseStart, g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause], g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] );
}

public OnUnpause()
{
    g_bPaused = false;
    
    new time = GetTime();
    new pauseTime = time - g_iPauseStart;
    new client, index;
    
    // adjust remembered pause time
    if ( g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause] && g_strRoundData[g_iRound][g_iCurTeam][rndStopTimePause] ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause] = time - (g_strRoundData[g_iRound][g_iCurTeam][rndStopTimePause] - g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause]) - g_iPauseStart;
    } else {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause] = time - g_iPauseStart;
    }
    g_strRoundData[g_iRound][g_iCurTeam][rndStopTimePause] = time;
    
    // when unpausing, substract the pause duration from round time -- can assume that round isn't over yet
    g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] += pauseTime;
    
    // same for tank, if it's up
    if ( g_bTankInGame ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] += pauseTime;
    }
    
    // for each player in the current survivor team: substract too
    for ( client = 1; client <= MaxClients; client++ )
    {
        if ( !IS_VALID_INGAME(client) || !IS_VALID_SURVIVOR(client) ) { continue; }
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { continue; }
        
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] )  {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] += pauseTime;
        }
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] )  {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] += pauseTime;
        }
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] )  {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += pauseTime;
        }
    }
    
    PrintDebug( 1, "Pause End (end time: %i -- pause duration: %i -- round start time: %i).", GetTime(), pauseTime, g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] );
    
    g_iPauseStart = 0;
}

public Action: L4D_OnSetCampaignScores ( &scoreA, &scoreB )
{
    PrintDebug( 2, "OnSetCampaignScores: A: %i -- B: %i (secondround: %i)", scoreA, scoreB, g_bSecondHalf );
    
    g_iScores[LTEAM_A] = scoreA;
    g_iScores[LTEAM_B] = scoreB;
    
    return Plugin_Continue;
}
/*
    Commands
    --------
*/

public Action: Cmd_Say ( client, args )
{
    // catch and hide !<command>s
    if (!client) { return Plugin_Continue; }
    
    decl String:sMessage[MAXNAME];
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
    if ( StrEqual(sArg, "sm_mvp", false) ) {        iType = typMVP; }
    else if ( StrEqual(sArg, "sm_ff", false) ) {    iType = typFF; }
    else if ( StrEqual(sArg, "sm_skill", false) ) { iType = typSkill; }
    else if ( StrEqual(sArg, "sm_acc", false) ) {   iType = typAcc; }
    else if ( StrEqual(sArg, "sm_inf", false) ) {   iType = typInf; }
    
    new bool:bSetRound, bool:bRound = true;
    new bool:bSetGame,  bool:bGame = false;
    new bool:bSetAll,   bool:bAll = false;
    new bool:bOther = false;
    new bool:bTank = false;
    new bool:bMore = false;
    new bool:bMy = false;
    new iStart = 1;
    
    new otherTeam = (g_iCurTeam) ? 0 : 1;
    
    if ( args )
    {
        GetCmdArg( 1, sArg, sizeof(sArg) );
        
        // find type selection (always 1)
        if ( StrEqual(sArg, "help", false) || StrEqual(sArg, "?", false) )
        {
            // show help
            if ( IS_VALID_INGAME(client) ) {
                PrintToChat( client, "\x01Use: /stats [<type>] [\x05round\x01/\x05game\x01/\x05team\x01/\x05all\x01/\x05other\x01]" );
                PrintToChat( client, "\x01 or: /stats [<type>] [\x05r\x01/\x05g\x01/\x05t\x01/\x05a\x01/\x05o\x01]" );
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
            Format(bufBasic, CONBUFSIZELARGE,  "%s|              'inf'    :  special infected stats (dp's, damage done etc)      |", bufBasic);
            if ( IS_VALID_INGAME(client) ) { PrintToConsole( client, bufBasic); } else { PrintToServer( bufBasic); }
            
            Format(bufBasic, CONBUFSIZELARGE,    "|------------------------------------------------------------------------------|\n");
            Format(bufBasic, CONBUFSIZELARGE,  "%s| arguments:                                                                   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'round' ('r') / 'game' ('g') : for this round; or for entire game so far   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'team' ('t') / 'all' ('a')   : current survivor team only; or all players  |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'other' ('o') / 'my'         : team that is now infected; or your team NMW |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'tank'          [ MVP only ] : show stats for tank fight                   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'more'    [ ACC & MVP only ] : show more stats ( MVP time / SI/tank hits ) |", bufBasic);
            if ( IS_VALID_INGAME(client) ) { PrintToConsole( client, bufBasic); } else { PrintToServer( bufBasic); }
            
            Format(bufBasic, CONBUFSIZELARGE,    "|------------------------------------------------------------------------------|\n");
            Format(bufBasic, CONBUFSIZELARGE,  "%s| examples:                                                                    |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats skill round all' => shows skeets etc for all players, this round   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats ff team game'    => shows active team's friendly fire, this round  |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats acc my'          => shows accuracy stats (your team, this round)   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats mvp tank'        => shows survivor action while tank is/was up     |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|", bufBasic);
            if ( IS_VALID_INGAME(client) ) { PrintToConsole( client, bufBasic); } else { PrintToServer( bufBasic); }
            return Plugin_Handled;
        }
        else if ( StrEqual(sArg, "mvp", false) ) { iType = typMVP; iStart++; }
        else if ( StrEqual(sArg, "ff", false) ) { iType = typFF; iStart++; }
        else if ( StrEqual(sArg, "skill", false) || StrEqual(sArg, "special", false) || StrEqual(sArg, "s", false) ) { iType = typSkill; iStart++; }
        else if ( StrEqual(sArg, "acc", false) || StrEqual(sArg, "accuracy", false) || StrEqual(sArg, "ac", false) ) { iType = typAcc; iStart++; }
        else if ( StrEqual(sArg, "inf", false) || StrEqual(sArg, "i", false) ) { iType = typAcc; iStart++; }
        else if ( StrEqual(sArg, "fact", false) || StrEqual(sArg, "fun", false) ) { iType = typFact; iStart++; }
        else if ( StrEqual(sArg, "general", false) || StrEqual(sArg, "gen", false) ) { iType = typGeneral; iStart++; }
        
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
                if ( bSetAll ) { bSetAll = true; bAll = false; }
            }
            else if ( StrEqual(sArg, "other", false) || StrEqual(sArg, "o", false) || StrEqual(sArg, "otherteam", false) ) {
                bOther = true;
            }
            else if ( StrEqual(sArg, "more", false) || StrEqual(sArg, "m", false) ) {
                bMore = true;
            }
            else if ( StrEqual(sArg, "tank", false) ) {
                bTank = true;
            }
            else if ( StrEqual(sArg, "my", false) ) {
                bMy = true;
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
    
    new iTeam = (bOther) ? otherTeam : -1;
    
    // what is 'my' team?
    if ( bMy ) {
        new index = GetPlayerIndexForClient( client );
        new curteam = -1;
        if ( index != -1 ) {
            curteam = g_iPlayerRoundTeam[LTEAM_CURRENT][index];
            if ( curteam != -1 ) {
                bSetAll = true;
                bAll = false;
                iTeam = curteam;
            } else {
                // fall back to default
                iTeam = -1;
            }
        }
    }
    
    
    
    switch ( iType )
    {
        case typGeneral:
        {
            // game by default, unless overridden by 'round'
            //  the first -1 == round number (may think about allowing a number input here later)
            DisplayStats( client, ( bSetRound && bRound ) ? true : false, -1, ( bSetAll && bAll ) ? false : true, iTeam );
        }
        
        case typMVP:
        {
            // by default: only for round
            DisplayStatsMVP( client, bTank, bMore, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, iTeam );
            // only show chat for non-tank table
            if ( !bTank && !bMore ) {
                DisplayStatsMVPChat( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, iTeam );
            }
        }
        
        case typFF:
        {
            // by default: only for round
            DisplayStatsFriendlyFire( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, false, iTeam );
        }
        
        case typSkill:
        {
            // by default: only for round
            DisplayStatsSpecial( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, false, iTeam );
        }
        
        case typAcc:
        {
            // by default: only for round
            DisplayStatsAccuracy( client, bMore, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, false, iTeam );
        }
        
        case typInf:
        {
            // To do
            PrintToChat( client, "Work in progress. Not done yet." );
        }
        
        case typFact:
        {
            DisplayStatsFunFactChat( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, iTeam );
        }
    }
    
    return Plugin_Handled;
}

public Action: Cmd_StatsReset ( client, args )
{
    ResetStats( false, -1 );
    PrintToChatAll( "Player statistics reset." );
    return Plugin_Handled;
}


/*
    Cookies and clientprefs
    -----------------------
*/
public Action: Cmd_Cookie_SetPrintFlags ( client, args )
{
    if ( args )
    {
        decl String: sArg[24];
        GetCmdArg( 1, sArg, sizeof(sArg) );
        new iFlags = StringToInt( sArg );
        
        if ( StrEqual(sArg, "?", false) || StrEqual(sArg, "help", false) ) 
        {
            PrintToChat( client, "\x01Use: \x04/stats_auto <flags>\x01. Flags is an integer that is the sum of all printouts to be displayed at round-end." );
            PrintToChat( client, "\x01Set flags to 0 to use server autoprint default; set to -1 to not display anything at all." );
            PrintToChat( client, "\x01See: \x05https://github.com/Tabbernaut/L4D2-Plugins/blob/master/stats/README.md\x01 for a list of flags." );
            return Plugin_Handled;
        }
        else if ( StrEqual(sArg, "test", false) || StrEqual(sArg, "preview", false) )
        {
            if ( g_iCookieValue[client] < 1 )
            {
                PrintToChat( client, "\x01Stats Preview: No flags set. First set flags with \x04/stats_auto <flags>\x01. Type \x04/stats_auto help\x01 for more info." );
                return Plugin_Handled;
            }
            AutomaticPrintPerClient( g_iCookieValue[client], client );
        }
        else if ( iFlags >= -1 )
        {
            if ( iFlags == -1 ) {
                PrintToChat( client, "\x01Stats Pref.: \x04no round end prints at all\x01." );
            }
            else if ( iFlags == 0 ) {
                PrintToChat( client, "\x01Stats Pref.: \x04server default\x01." );
            }
            else {
                new String: tmpStr[64];
                
                if ( iFlags & AUTO_MVPCHAT_ROUND ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "mvp/chat(round)" );
                }
                if ( iFlags & AUTO_MVPCHAT_GAME ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "mvp/chat(game)" );
                }
                if ( iFlags & AUTO_MVPCON_ROUND ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "mvp(round)" );
                }
                if ( iFlags & AUTO_MVPCON_GAME ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "mvp(game)" );
                }
                if ( iFlags & AUTO_MVPCON_MORE_ROUND ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "mvp/more(round)" );
                }
                if ( iFlags & AUTO_MVPCON_MORE_GAME ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "mvp/more(game)" );
                }
                if ( iFlags & AUTO_MVPCON_TANK ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "mvp/tankfight" );
                }
                if ( iFlags & AUTO_SKILLCON_ROUND ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "skill/special(round)" );
                }
                if ( iFlags & AUTO_SKILLCON_GAME ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "skill/special(game)" );
                }
                if ( iFlags & AUTO_FFCON_ROUND ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "ff(round)" );
                }
                if ( iFlags & AUTO_FFCON_GAME ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "ff(game)" );
                }
                if ( iFlags & AUTO_ACCCON_ROUND ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "accuracy(round)" );
                }
                if ( iFlags & AUTO_ACCCON_GAME ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "accuracy(game)" );
                }
                if ( iFlags & AUTO_ACCCON_MORE_ROUND ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "acc/more(round)" );
                }
                if ( iFlags & AUTO_ACCCON_MORE_GAME ) {
                    Format( tmpStr, sizeof(tmpStr), "%s%s%s", tmpStr, (strlen(tmpStr)) ? ", " : "", "acc/more(game)" );
                }
                
                PrintToChat( client, "\x01Stats Pref.: Flags set for: \x04%s\x01.", tmpStr );
                PrintToChat( client, "\x01Use \x04/stats_auto test\x01 to get a report preview.");
            }
            
            g_iCookieValue[client] = iFlags;
            
            if ( AreClientCookiesCached(client) )
            {
                decl String:sCookieValue[16];
                IntToString(iFlags, sCookieValue, sizeof(sCookieValue));
                SetClientCookie( client, g_hCookiePrint, sCookieValue );
            }
            else {
                PrintToChat( client, "Stats Pref.: Error: cookie not cached yet (try again in a bit)." );
            }    
        }
        else
        {
            PrintToChat( client, "Stats Pref.: invalid value: '%s'. Type '/stats_auto help' for more info.", sArg );
        }
    }
    else
    {
        PrintToChat( client, "\x01Use: \x04/stats_auto <flags>\x01. Type \x04/stats_auto help\x01 for more info." );
    }
    
    return Plugin_Handled;
}

public OnClientCookiesCached ( client )
{
    decl String:sCookieValue[16];
    GetClientCookie( client, g_hCookiePrint, sCookieValue, sizeof(sCookieValue) );
    g_iCookieValue[client] = StringToInt( sCookieValue );
}

/*
    Forwards from custom_map_transitions
*/
// called when the first map is about to be loaded
public OnCMTStart( rounds, const String:mapname[] )
{
    // reset stats
    g_bCMTActive = true;
    PrintDebug(2, "CMT start. Rounds: %i. First map: %s", rounds, mapname);
    
    // reset all stats
    ResetStats( false, -1 );
}

// called after the last round has ended
public OnCMTEnd()
{
    g_bCMTActive = false;
    PrintDebug(2, "CMT end.");
    
    HandleGameEnd();
}

/*
    Team / Bot tracking
    -------------------
*/
public Action: Event_PlayerTeam ( Handle:event, const String:name[], bool:dontBroadcast )
{
    if ( !g_bTeamChanged )
    {
        new newTeam = GetEventInt(event, "team");
        new oldTeam = GetEventInt(event, "oldteam");
        
        // only do checks for players moving from or to survivor team
        if ( newTeam != TEAM_SURVIVOR && oldTeam != TEAM_SURVIVOR ) { return; }
        
        g_bTeamChanged = true;
        CreateTimer( 0.5, Timer_TeamChanged, _, TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action: Timer_TeamChanged (Handle:timer)
{
    g_bTeamChanged = false;
    UpdatePlayerCurrentTeam();
}

/*
    Tracking
    --------
*/
public Action: Event_PlayerHurt ( Handle:event, const String:name[], bool:dontBroadcast )
{
    if ( !g_bPlayersLeftStart ) { return Plugin_Continue; }
    
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    
    new damage = GetEventInt(event, "dmg_health");
    new attIndex, vicIndex;
    
    // survivor to infected
    if ( IS_VALID_SURVIVOR(attacker) && IS_VALID_INFECTED(victim) )
    {
        if ( damage < 1 ) { return Plugin_Continue; }
        
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return Plugin_Continue; }
        
        new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        
        if ( zClass >= ZC_SMOKER && zClass <= ZC_CHARGER )
        {
            if ( g_bTankInGame )
            {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plySIDamageTankUp] += damage;
            }
            
            g_strRoundData[g_iRound][g_iCurTeam][rndSIDamage] += damage;
            g_strRoundPlayerData[attIndex][g_iCurTeam][plySIDamage] += damage;
        }
        else if ( zClass == ZC_TANK && damage != 5000) // For some reason the last attacker does 5k damage?
        {
            new type = GetEventInt(event, "type");
            
            if ( type & DMG_CLUB || type & DMG_SLASH )
            {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyMeleesOnTank]++;
            }
            
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyTankDamage] += damage;
        }
    }
    // survivor to survivor
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
        g_strRoundData[g_iRound][g_iCurTeam][rndFFDamageTotal] += damage;
        
        g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenTotal] += damage;
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenTotal] += damage;
        
        if ( attIndex == vicIndex ) {
            // damage to self
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenSelf] += damage;
        }
        else if ( IsPlayerIncapacitated(victim) )
        {
            // don't count incapped damage for 'ffgiven' / 'fftaken'
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenIncap] += damage;
            g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenIncap] += damage;
        }
        else
        {
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGiven] += damage;
            if ( attIndex != vicIndex ) {
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTaken] += damage;
            }
            
            // which type to save it to?
            if ( type & DMG_BURN )
            {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenFire] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenFire] += damage;
            }
            else if ( type & DMG_BUCKSHOT )
            {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenPellet] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenPellet] += damage;
            }
            else if ( type & DMG_CLUB || type & DMG_SLASH )
            {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenMelee] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenMelee] += damage;
            }
            else if ( type & DMG_BULLET )
            {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenBullet] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenBullet] += damage;
            }
            else
            {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenOther] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenOther] += damage;
            }
        }
        
    }
    // infected to survivor
    else if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) )
    {
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return Plugin_Continue; }
        
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyDmgTaken] += damage;
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
        
        g_strRoundPlayerData[attIndex][g_iCurTeam][plyWitchDamage] += damage;
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
    
    g_strRoundPlayerData[index][g_iCurTeam][plyFallDamage] += damage;
    
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
    new index, attacker;
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        // survivor died
        
        g_strRoundData[g_iRound][g_iCurTeam][rndDeaths]++;
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        g_strRoundPlayerData[index][g_iCurTeam][plyDied]++;
        
        // store time they died
        new time = GetTime();
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time;
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time; }
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
            
            attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
            
            if ( IS_VALID_SURVIVOR(attacker) )
            {
                index = GetPlayerIndexForClient( attacker );
                if ( index == -1 ) { return; }
                
                g_strRoundData[g_iRound][g_iCurTeam][rndSIKilled]++;
                g_strRoundPlayerData[index][g_iCurTeam][plySIKilled]++;
                
                if ( g_bTankInGame )
                { 
                    g_strRoundPlayerData[index][g_iCurTeam][plySIKilledTankUp]++;
                }
            }
        }
    }
    else if ( !client )
    {
        // common infected died (check for witch)
        
        new common = GetEventInt(event, "entityid");
        attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
        
        if ( IS_VALID_SURVIVOR(attacker) && !IsWitch(common) )
        {
            
            index = GetPlayerIndexForClient( attacker );
            if ( index == -1 ) { return; }
            
            g_strRoundData[g_iRound][g_iCurTeam][rndCommon]++;
            g_strRoundPlayerData[index][g_iCurTeam][plyCommon]++;
            
            if ( g_bTankInGame ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyCommonTankUp]++;
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
        
        // handle tank time up
        if ( g_bInRound )
        {
            HandleTankTimeEnd();
        }
    }
}

stock HandleTankTimeEnd()
{
    g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] = GetTime();
}

public Action: Event_TankSpawned( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
    //new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    g_bTankInGame = true;
    new time = GetTime();
    
    if ( !g_bInRound ) { return; }
    
    // note time
    if ( !g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] = time;
    }
    else if ( g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] = time - (g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] - g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank]);
        g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] = 0;
    }
    // else, keep starttime, it's two+ tanks at the same time...
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
        
        g_strRoundPlayerData[index][g_iCurTeam][plyIncaps]++;
        
        // store time they incapped (if they weren't already)
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = GetTime(); }
    }
}

public Action: Event_PlayerRevived (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "subject") );
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        if ( !IsPlayerIncapacitatedAtAll(client) && IsPlayerAlive(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += GetTime() - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
        }
    }
}

// rescue closets in coop
public Action: Event_SurvivorRescue (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId( GetEventInt(event, "victim") );
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    // if they were dead, they're alive now! magic.
    new time = GetTime();
    if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] )  {
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive];
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = 0;
    }
    if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] )  {
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
    }
}

// ledgegrabs
public Action: Event_PlayerLedged (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        // store time they incapped (if they weren't already)
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = GetTime(); }
    }
}

public Action: Event_PlayerLedgeRelease (Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        if ( !IsPlayerIncapacitatedAtAll(client) && IsPlayerAlive(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += GetTime() - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
        }
    }
}

// items used
public Action: Event_DefibUsed (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId( GetEventInt(event, "subject") );
    
    g_strRoundData[g_iRound][g_iCurTeam][rndDefibsUsed]++;
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        new time = GetTime();
        if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] )  {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = 0;
        }
        if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] )  {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
        }
    }
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
    if ( !IS_VALID_SURVIVOR(client) || IsPlayerIncapacitated(client) ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    new weaponId = GetEventInt(event, "weaponid");
    
    if ( weaponId == WP_PISTOL || weaponId == WP_PISTOL_MAGNUM )
    {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsPistol]++;
    }
    else if (   weaponId == WP_SMG || weaponId == WP_SMG_SILENCED || weaponId == WP_SMG_MP5 ||
                weaponId == WP_RIFLE || weaponId == WP_RIFLE_DESERT || weaponId == WP_RIFLE_AK47 || weaponId == WP_RIFLE_SG552
    ) {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsSmg]++;
    }
    else if (   weaponId == WP_PUMPSHOTGUN || weaponId == WP_SHOTGUN_CHROME ||
                weaponId == WP_AUTOSHOTGUN || weaponId == WP_SHOTGUN_SPAS
    ) {
        // get pellets
        new count = GetEventInt(event, "count");
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsShotgun] += count;
    }
    else if (   weaponId == WP_HUNTING_RIFLE || weaponId == WP_SNIPER_MILITARY  ||
                weaponId == WP_SNIPER_AWP || weaponId == WP_SNIPER_SCOUT
    ) {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsSniper]++;
    }
    /* else if (weaponId == WP_MELEE)
    {
        //g_strRoundPlayerData[index][g_iCurTeam][plyShotsMelee]++;
    } */
    
    // ignore otherwise
}



// special / tank gets hit
public Action: TraceAttack_Special (victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if ( !g_bPlayersLeftStart ) { return; }
    if ( !IS_VALID_SURVIVOR(attacker) || !IsValidEdict(inflictor) || IsPlayerIncapacitated(attacker) ) { return; }
    
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
        case WPTYPE_SHOTGUN: {  g_strRoundPlayerData[index][g_iCurTeam][plyHitsShotgun]++; g_strRoundPlayerData[index][g_iCurTeam][plyHitsSIShotgun]++; }
        case WPTYPE_SMG: {      g_strRoundPlayerData[index][g_iCurTeam][plyHitsSmg]++;     g_strRoundPlayerData[index][g_iCurTeam][plyHitsSISmg]++; }
        case WPTYPE_SNIPER: {   g_strRoundPlayerData[index][g_iCurTeam][plyHitsSniper]++;  g_strRoundPlayerData[index][g_iCurTeam][plyHitsSISniper]++; }
        case WPTYPE_PISTOL: {   g_strRoundPlayerData[index][g_iCurTeam][plyHitsPistol]++;  g_strRoundPlayerData[index][g_iCurTeam][plyHitsSIPistol]++; }
    }
    
    // headshots on anything but tank, separately store hits for tank
    if ( GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_TANK )
    {
        switch ( weaponType )
        {
            case WPTYPE_SHOTGUN: {  g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankShotgun]++; }
            case WPTYPE_SMG: {      g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankSmg]++; }
            case WPTYPE_SNIPER: {   g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankSniper]++; }
            case WPTYPE_PISTOL: {   g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankPistol]++; }
        }
    }
    
    // headshots (only bullet-based)
    if ( damagetype & DMG_BULLET && hitgroup == HITGROUP_HEAD && GetEntProp(victim, Prop_Send, "m_zombieClass") != ZC_TANK )
    {
        switch ( weaponType )
        {
            case WPTYPE_SMG: {      g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSmg]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSISmg]++; }
            case WPTYPE_SNIPER: {   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSniper]++; g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSISniper]++; }
            case WPTYPE_PISTOL: {   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsPistol]++; g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSIPistol]++; }
        }
    }
}

// common infected / witch gets hit
public Action: TraceAttack_Infected (victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if ( !g_bPlayersLeftStart ) { return; }
    if ( !IS_VALID_SURVIVOR(attacker) || !IsValidEdict(inflictor) || IsPlayerIncapacitated(attacker) ) { return; }
    
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
        case WPTYPE_SHOTGUN: {  g_strRoundPlayerData[index][g_iCurTeam][plyHitsShotgun]++;}
        case WPTYPE_SMG: {      g_strRoundPlayerData[index][g_iCurTeam][plyHitsSmg]++; }
        case WPTYPE_SNIPER: {   g_strRoundPlayerData[index][g_iCurTeam][plyHitsSniper]++; }
        case WPTYPE_PISTOL: {   g_strRoundPlayerData[index][g_iCurTeam][plyHitsPistol]++; }
    }
    
    // headshots (only bullet-based)
    if ( damagetype & DMG_BULLET && hitgroup == HITGROUP_HEAD )
    {
        switch ( weaponType )
        {
            case WPTYPE_SMG: {      g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSmg]++; }
            case WPTYPE_SNIPER: {   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSniper]++; }
            case WPTYPE_PISTOL: {   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsPistol]++; }
        }
    }
}


// hooks for tracking attacks on SI/Tank
public Action: Event_PlayerSpawn (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId( GetEventInt(hEvent, "userid") );
    if ( !IS_VALID_INFECTED(client) ) { return; }

    SDKHook(client, SDKHook_TraceAttack, TraceAttack_Special);
    
    g_strRoundData[g_iRound][g_iCurTeam][rndSISpawned]++;
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
    
    g_strRoundPlayerData[index][g_iCurTeam][plyShoves]++;
}
public OnHunterDeadstop ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyDeadStops]++;
}

// skeets
public OnSkeet ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetGL ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}
public OnSkeetMelee ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsMelee]++;
}
public OnSkeetMeleeHurt ( attacker, victim, damage )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}

public OnSkeetSniper ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetSniperHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}

// pops
public OnBoomerPop ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyPops]++;
}

// levels
public OnChargerLevel ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyLevels]++;
}
public OnChargerLevelHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyLevelsHurt]++;
}

// smoker clears
public OnTongueCut ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyTongueCuts]++;
}
public OnSmokerSelfClear ( attacker, victim, withShove )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySelfClears]++;
}

// crowns
public OnWitchCrown ( attacker, damage )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyCrowns]++;
}
public OnWitchDrawCrown ( attacker, damage, chipdamage )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyCrownsHurt]++;
}
// tank rock
public OnTankRockEaten ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( victim );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyRockEats]++;
}

public OnTankRockSkeeted ( attacker, victim )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyRockSkeets]++;
}
// highpounces
public OnHunterHighPounce ( attacker, victim, Float:damage, Float:height )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyHunterDPs]++;
}
public OnJockeyHighPounce ( attacker, victim, Float:height )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyJockeyDPs]++;
}

/*
    Stats cleanup
    -------------
*/
// stats reset (called on map start, clears both roundhalves)
public Action: Timer_ResetStats (Handle:timer, any:roundOnly)
{
    // reset stats (for current team)
    ResetStats( bool:(roundOnly) );
}

// team -1 = clear both; failedround = campaign mode only
stock ResetStats ( bool:bCurrentRoundOnly = false, iTeam = -1, bool: bFailedRound = false )
{
    new i, j, k;
    
    PrintDebug( 1, "Resetting stats [round %i]. (for: %s; for team: %i)", g_iRound, (bCurrentRoundOnly) ? "this round" : "the game", iTeam );
    
    // if we're cleaning the entire GAME ('round' refers to two roundhalves here)
    if ( !bCurrentRoundOnly )
    {
        // just so nobody gets robbed of seeing stats, print to all
        DisplayStats( );
        
        // clear game
        g_iRound = 0;
        g_bGameStarted = false;
        g_strGameData[gmFailed] = 0;
        
        // clear rounds
        for ( i = 0; i < MAXROUNDS; i++ ) {
            g_sMapName[i] = "";
            for ( j = 0; j < 2; j++ ) {
                for ( k = 0; k <= MAXRNDSTATS; k++ ) {
                    g_strRoundData[i][j][k] = 0;
                }
            }
        }
        for ( j = 0; j < 2; j++ ) {
            for ( k = 0; k <= MAXRNDSTATS; k++ ) {
                g_strAllRoundData[j][k] = 0;
            }
        }
        
        // clear players
        for ( i = 0; i < MAXTRACKED; i++ ) {
            for ( j = 0; j <= MAXPLYSTATS; j++ ) {
                g_strPlayerData[i][j] = 0;
            }
        }
        
        for ( j = 0; j < 2; j++ ) {
            g_iScores[j] = 0;
            g_iOldScores[j] = 0;
        }
    }
    else
    {
        if ( iTeam == -1 ) {
            for ( k = 0; k <= MAXRNDSTATS; k++ ) {
                if ( bFailedRound && k == rndRestarts ) { continue; }
                g_strRoundData[g_iRound][LTEAM_A][k] = 0;
                g_strRoundData[g_iRound][LTEAM_B][k] = 0;
            }
        }
        else {
            for ( k = 0; k <= MAXRNDSTATS; k++ ) {
                if ( bFailedRound && k == rndRestarts ) { continue; }
                g_strRoundData[g_iRound][iTeam][k] = 0;
            }
        }
    }
    
    // other round data
    if ( iTeam == -1 )  // both
    {
        // round data for players
        for ( i = 0; i < MAXTRACKED; i++ ) {
            for ( j = 0; j < 2; j++ ) {
                for ( k = 0; k <= MAXPLYSTATS; k++ ) {
                    g_strRoundPlayerData[i][j][k] = 0;
                }
            }
        }
    }
    else
    {
        // round data for players
        for ( i = 0; i < MAXTRACKED; i++ ) {
            for ( k = 0; k <= MAXPLYSTATS; k++ ) {
                g_strRoundPlayerData[i][iTeam][k] = 0;
            }
        }
    }
}

stock UpdatePlayerCurrentTeam()
{
    new client, index;
    new time = GetTime();
    
    new bool: botPresent[4];
    
    // if paused, add the full pause time so far,
    // so that it will get substracted neatly when the
    // game unpauses
    
    // reset
    ClearPlayerTeam( LTEAM_CURRENT );
    
    // find all survivors
    // find all infected
    
    for ( client = 1; client <= MaxClients; client++ )
    {
        if ( !IS_VALID_INGAME(client) ) { continue; }
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { continue; }
        
        if ( IS_VALID_SURVIVOR(client) )
        {
            g_iPlayerRoundTeam[LTEAM_CURRENT][index] = g_iCurTeam;

            if ( !g_bPlayersLeftStart ) { continue; }
            
            // check bots
            if ( index < FIRST_NON_BOT ) { botPresent[index] = true; }
            
            // for tracking which players ever were in the team (only useful if they were in the team when round was live)
            g_iPlayerRoundTeam[g_iCurTeam][index] = g_iCurTeam;
            
            // if player wasn't present, update presence (shift start forward)
            
            if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] = time - ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] );
            } else if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] = time;
            }
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] = 0;
            if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] -= time - g_iPauseStart; }
            
            // if player wasn't alive and is now, update -- if never joined and dead, start = stop
            if ( IsPlayerAlive(client) ) {
                if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] ) {
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] = time - ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] );
                } else if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] ) {
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] = time;
                }
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = 0;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] -= time - g_iPauseStart; }
            }
            else if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] = time;
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time;
            }
            
            
            // if player wasn't upright and is now, update -- if never joined and incapped, start = stop
            if ( !IsPlayerIncapacitatedAtAll(client) && IsPlayerAlive(client) ) {
                if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] = time - ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] );
                } else if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] = time;
                }
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] -= time - g_iPauseStart; }
            }
            else  if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] = time;
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time;
            }
        }
        else
        {
            if ( IS_VALID_INFECTED(client) ) {
                g_iPlayerRoundTeam[LTEAM_CURRENT][index] = (g_iCurTeam) ? 0 : 1;
            }
            
            // if the player moved here from the other team, stop his presence time
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] = time;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] -= time - g_iPauseStart; }
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] -= time - g_iPauseStart; }
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] -= time - g_iPauseStart; }
            }
        }
    }
    
    /*
        bots don't work as normal -- they just disappear
        check which bots are here, and consider the other
        bots to have moved instead
    
    */
    if ( g_bPlayersLeftStart )
    {
        for ( index = 0; index < FIRST_NON_BOT; index++ )
        {
            if ( botPresent[index] ) { continue; }
            
            // if the bot was removed from survivors:
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] = time;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] -= time - g_iPauseStart; }
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] -= time - g_iPauseStart; }
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time;
                if ( g_bPaused ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] -= time - g_iPauseStart; }
            }
        }
    }
}

stock ClearPlayerTeam ( iTeam = -1 )
{
    new i, j;
    
    if ( iTeam == -1 )
    {
        // clear all
        for ( j = 0; j < 3; j++ ) {
            for ( i = 0; i < MAXTRACKED; i++ ) {
                g_iPlayerRoundTeam[j][i] = -1;
            }
        }
    }
    else {
        for ( i = 0; i < MAXTRACKED; i++ ) {
            g_iPlayerRoundTeam[iTeam][i] = -1;
        }
    }
}

stock SetStartSurvivorTime ( bool:bGame = false, bool:bRestart = false )
{
    new client, index;
    new time = GetTime();
    
    for ( client = 1; client <= MaxClients; client++ )
    {
        if ( !IS_VALID_INGAME(client) ) { continue; }
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { continue; }
        
        if ( IS_VALID_SURVIVOR(client) )
        {
            if ( bGame )
            {
                g_strPlayerData[index][plyTimeStartPresent] = time;
                g_strPlayerData[index][plyTimeStartAlive] = time;
                g_strPlayerData[index][plyTimeStartUpright] = time;
            }
            else
            {
                if ( bRestart )
                {
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] = time - ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] );
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] = time - ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] );
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] = time - ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] );
                }
                else {
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] = time;
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] = time;
                    g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] = time;
                }
            }
        }
    }
}
/*
    Display
    -------
*/
// display general stats -- if round set, only for that round no.
stock DisplayStats( client = -1, bool:bRound = false, round = -1, bool:bTeam = true, iTeam = -1 )
{
    if ( round != -1 ) { round--; }
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String: strTmp[24];
    decl String: strTmpA[24];
    new i, j;
    
    g_iConsoleBufChunks = 0;
    
    new team = g_iCurTeam;
    if ( iTeam != -1 ) { team = iTeam; }
    else if ( g_bSecondHalf && !g_bPlayersLeftStart ) { team = (team) ? 0 : 1; }
    
    // display all rounds / game summary
    
    // game info
    if ( g_bGameStarted )
    {
        FormatTimeAsDuration( strTmp, sizeof(strTmp), GetTime() - g_strGameData[gmStartTime] );
        LeftPadString( strTmp, sizeof(strTmp), 14 );
    }
    else {
        Format( strTmp, sizeof(strTmp), " (not started)" );
    }
    
    // spawn/kill ratio
    FormatPercentage( strTmpA, sizeof(strTmpA), g_strAllRoundData[team][rndSIKilled], g_strAllRoundData[team][rndSISpawned], false ); // never a decimal
    LeftPadString( strTmpA, sizeof(strTmpA), 4 );
    
    Format(bufBasicHeader, CONBUFSIZE, "\n");
    Format(bufBasicHeader, CONBUFSIZE, "%s| General Stats                                    |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Time: %14s | Rounds/Fails: %4i /%5i |\n", bufBasicHeader,
            strTmp,
            g_iRound,
            g_strGameData[gmFailed]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Kits/Pills:%3d /%4d | Kills:   %6i  specials |\n", bufBasicHeader,
            g_strAllRoundData[team][rndKitsUsed],
            g_strAllRoundData[team][rndPillsUsed],
            g_strAllRoundData[team][rndSIKilled]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s| SI kill rate:  %4s%s |          %6i  commons  |\n",
            bufBasicHeader,
            strTmpA,
            ( g_strAllRoundData[team][rndSISpawned] ) ? "%%" : " ",
            g_strAllRoundData[team][rndCommon] 
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s| Deaths:       %6i |          %6i  witches  |\n", bufBasicHeader,
            g_strAllRoundData[team][rndDeaths],
            g_strAllRoundData[team][rndWitchKilled]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s| Incaps:       %6i |          %6i  tanks    |\n", bufBasicHeader,
            g_strAllRoundData[team][rndIncaps],
            g_strAllRoundData[team][rndTankKilled]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 )
            {
                PrintToConsole(i, bufBasicHeader);
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        
    }
    
    // round header
    Format( bufBasicHeader,
            CONBUFSIZE,
                                           "\n| General data per game round -- %11s                                                        |\n",
            ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
        );
    
    //                                    | ###. ############### | ###h ##m ##s | ##### | ###### |  ##### |  ##### | #### |  ##### |   ###### |
    Format(bufBasicHeader, CONBUFSIZE, "%s|---------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Round                | Time         | SI    | Common | Deaths | Incaps | Kits | Pills  | Restarts |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|--------------|-------|--------|--------|--------|------|--------|----------|", bufBasicHeader);
    
    // round data
    BuildConsoleBufferGeneral( bTeam, iTeam );
    
    if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
    if ( g_iConsoleBufChunks > -1 ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                     "%s\n|---------------------------------------------------------------------------------------------------|",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    } else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                              |%s",
                bufBasicHeader,
                                       "\n|---------------------------------------------------------------------------------------------------|"
            );
    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 )
            {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

// display mvp stats
stock DisplayStatsMVPChat( client, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    // make sure the MVP stats itself is called first, so the players are already sorted
    
    decl String:printBuffer[1024];
    decl String:tmpBuffer[512];
    new String:strLines[8][192];
    new i, j, x;
    
    printBuffer = GetMVPChatString( bRound, bTeam, iTeam );
    
    if ( client == -1 ) {
        PrintToServer("\x01%s", printBuffer);
    }

    // PrintToChatAll has a max length. Split it in to individual lines to output separately
    new intPieces = ExplodeString( printBuffer, "\n", strLines, sizeof(strLines), sizeof(strLines[]) );
    if ( client > 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToChat(client, "\x01%s", strLines[i]);
        }
    }
    else if ( client == 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToServer("\x01%s", strLines[i]);
        }
    }
    else {
        for ( j = 1; j <= MaxClients; j++ ) {
            for ( i = 0; i < intPieces; i++ ) {
                if ( !IS_VALID_INGAME( j ) || g_iCookieValue[j] != 0 ) { continue; }
                PrintToChat( j, "\x01%s", strLines[i] );
            }
        }
    }
    
    new iBrevityFlags = GetConVarInt(g_hCvarMVPBrevityFlags);
    
    new team = g_iCurTeam;
    if ( iTeam != -1 ) { team = iTeam; }
    else if ( g_bSecondHalf && !g_bPlayersLeftStart ) { team = (team) ? 0 : 1; }
    
    // find index for this client
    new index = -1;
    new found = -1;
    new listNumber = 0;
    
    // also find the three non-mvp survivors and tell them they sucked
    // tell them they sucked with SI
    if (    ( bRound && g_strRoundData[g_iRound][team][rndSIDamage] > 0 || !bRound && g_strAllRoundData[team][rndSIDamage] > 0 ) &&
            !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_SI)
    ) {
        // skip 0, since that is the MVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ )
        {
            index = g_iPlayerIndexSorted[SORT_SI][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MaxClients; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            if ( found == -1 ) { continue; }
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }
            
            if ( listNumber && ( client == -1 || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) && g_iCookieValue[found] != -1 )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg,\x05 %d \x01kills)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            (bRound) ? g_strRoundPlayerData[index][team][plySIKilled] : g_strPlayerData[index][plySIKilled]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(dmg \x04%i%%\x01, kills \x04%i%%\x01)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[index][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[index][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[index][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) :
                                    ((float(g_strPlayerData[index][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg [\x04%i%%\x01],\x05 %d \x01kills [\x04%i%%\x01])",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[index][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[index][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIKilled] : g_strPlayerData[index][plySIKilled],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[index][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) : 
                                    ((float(g_strPlayerData[index][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                }
                PrintToChat( found, "\x01%s", tmpBuffer );
            }
            
            listNumber++;
        }
    }

    // tell them they sucked with Common
    listNumber = 0;
    if (    ( bRound && g_strRoundData[g_iRound][team][rndCommon] || !bRound && g_strAllRoundData[team][rndCommon] ) &&
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
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }
            
            if ( listNumber && ( client == -1 || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) && g_iCookieValue[found] != -1 )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plyCommon] : g_strPlayerData[index][plyCommon]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(kills \x04%i%%\x01)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[index][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[index][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills [\x04%i%%\x01])",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plyCommon] : g_strPlayerData[index][plyCommon],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[index][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[index][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
                        );
                }
                PrintToChat( found, "\x01%s", tmpBuffer );
            }
            
            listNumber++;
        }
    }
    
    // tell them they were better with FF
    listNumber = 0;
    if (    !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_FF) )
    {
        // skip 0, since that is the LVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ )
        {
            index = g_iPlayerIndexSorted[SORT_FF][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MaxClients; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            if ( found == -1 ) { continue; }
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }

            if ( bRound && !g_strRoundPlayerData[index][team][plyFFGiven] || !bRound && !g_strPlayerData[index][plyFFGiven] ) { continue; }
            
            if ( listNumber && ( client == -1 || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) && g_iCookieValue[found] != -1 )
            {
                Format(tmpBuffer, sizeof(tmpBuffer), "[LVP%s] Your rank - FF: #\x03%d \x01(\x05%d \x01dmg)",
                        (bRound) ? "" : " - Game",
                        (i+1),
                        (bRound) ? g_strRoundPlayerData[index][team][plyFFGiven] : g_strPlayerData[index][plyFFGiven]
                    );

                PrintToChat( found, "\x01%s", tmpBuffer );
            }
            
            listNumber++;
        }
    }
}

String: GetMVPChatString( bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    decl String: printBuffer[1024];
    decl String: tmpBuffer[512];
    
    printBuffer = "";
    
    // SI damage already sorted, sort CI and FF too
    SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    SortPlayersMVP( bRound, SORT_CI, bTeam, iTeam );
    SortPlayersMVP( bRound, SORT_FF, bTeam, iTeam );
    
    // use current survivor team -- or previous team in second half before starting
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // normally, topmost is the mvp
    new mvp_SI =        g_iPlayerIndexSorted[SORT_SI][0];
    new mvp_Common =    g_iPlayerIndexSorted[SORT_CI][0];
    new mvp_FF =        g_iPlayerIndexSorted[SORT_FF][0];
    
    // find first on the right team, if looking for 1 team and there is no team-specific sorting list
    if ( bTeam && !bRound ) {
        for ( new i = 0; i < MAXTRACKED; i++ ) {
            if ( g_iPlayerRoundTeam[team][i] == team ) {
                mvp_SI = i;
                mvp_Common = i;
                mvp_FF = i;
                break;
            }
        }
    }
    
    new iBrevityFlags = GetConVarInt(g_hCvarMVPBrevityFlags);
    
    // if null data, set them to -1
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_SI][team][plySIDamage]   || !bRound && !g_strPlayerData[mvp_SI][plySIDamage] )   { mvp_SI = -1; }
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_Common][team][plyCommon] || !bRound && !g_strPlayerData[mvp_Common][plyCommon] ) { mvp_Common = -1; }
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_FF][team][plyFFGiven]    || !bRound && !g_strPlayerData[mvp_FF][plyFFGiven] )    { mvp_FF = -1; }
    
    // report
    if ( mvp_SI == -1 && mvp_Common == -1 && !(iBrevityFlags & BREV_SI && iBrevityFlags & BREV_CI) )
    {
        Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s]: (not enough action yet)\n", (bRound) ? "" : " - Game" );
        StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
    }
    else
    {
        if ( !(iBrevityFlags & BREV_SI) )
        {
            if ( mvp_SI > -1 )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(\x05%d \x01dmg,\x05 %d \x01kills)\n", 
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIDamage] : g_strPlayerData[mvp_SI][plySIDamage],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIKilled] : g_strPlayerData[mvp_SI][plySIKilled]
                        );
                } else if ( iBrevityFlags & BREV_ABSOLUTE ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(dmg \x04%i%%\x01, kills \x04%i%%\x01)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(\x05%d \x01dmg[\x04%i%%\x01],\x05 %d \x01kills [\x04%i%%\x01])\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIDamage] : g_strPlayerData[mvp_SI][plySIDamage],
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIKilled] : g_strPlayerData[mvp_SI][plySIKilled],
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
            else
            {
                Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI: \x03(nobody)\x01\n", (bRound) ? "" : " - Game" );
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
        }
        
        if ( !(iBrevityFlags & BREV_CI) )
        {
            if ( mvp_Common > -1 )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x05%d \x01common)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? g_strRoundPlayerData[mvp_Common][team][plyCommon] : g_strPlayerData[mvp_Common][plyCommon]
                        );
                } else if ( iBrevityFlags & BREV_ABSOLUTE ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x04%i%%\x01)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[mvp_Common][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[mvp_Common][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x05%d \x01common [\x04%i%%\x01])\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? g_strRoundPlayerData[mvp_Common][team][plyCommon] : g_strPlayerData[mvp_Common][plyCommon],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[mvp_Common][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[mvp_Common][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
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
            Format(tmpBuffer, sizeof(tmpBuffer), "[LVP%s] FF: no friendly fire at all!\n",
                    (bRound) ? "" : " - Game"
                );
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
        else
        {
            Format(tmpBuffer, sizeof(tmpBuffer), "[LVP%s] FF:\x03 %s \x01(\x05%d \x01dmg)\n",
                        (bRound) ? "" : " - Game",
                        g_sPlayerName[mvp_FF],
                        (bRound) ? g_strRoundPlayerData[mvp_FF][team][plyFFGiven] : g_strPlayerData[mvp_FF][plyFFGiven]
                    );
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
    }
    
    return printBuffer;
}

stock DisplayStatsMVP( client, bool:bTank = false, bool:bMore = false, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    new i, j;
    new bool: bFooter = false;
    
    // get sorted players list
    SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    
    new bool: bTankUp = bool:( !g_bModeCampaign && IsTankInGame() && g_bInRound );
    
    // prepare buffer(s) for printing
    if ( !bTank || !bTankUp )
    {
        BuildConsoleBufferMVP( bTank, bMore, bRound, bTeam, iTeam );
    }
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String:bufBasicFooter[CONBUFSIZE];
    
    if ( bTank )
    {
        if ( bTankUp ) {
            Format(bufBasicHeader, CONBUFSIZE, "\n| Survivor MVP Stats -- Tank Fight (not showing table, tank is still up...)    |\n");
            Format(bufBasicHeader, CONBUFSIZE, "%s|------------------------------------------------------------------------------|",    bufBasicHeader);
            g_iConsoleBufChunks = -1;
        }
        else {        
            Format(bufBasicHeader, CONBUFSIZE, "\n| Survivor MVP Stats -- Tank Fight -- %10s -- %11s                |\n",
                    ( bRound ) ? "This Round" : "ALL Rounds",
                    ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
                );
            Format(bufBasicHeader, CONBUFSIZE, "%s|------------------------------------------------------------------------------|\n",  bufBasicHeader);
            Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | SI during tank | CI d. tank | Melees | Rock skeet/eat |\n",  bufBasicHeader);
            Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|----------------|------------|--------|----------------|",    bufBasicHeader);
            
            if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
            if ( g_iConsoleBufChunks > -1 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks],
                        CONBUFSIZELARGE,
                                             "%s\n|------------------------------------------------------------------------------|\n",
                        g_sConsoleBuf[g_iConsoleBufChunks]
                );
            } else {
                Format( bufBasicHeader,
                        CONBUFSIZE,
                                             "%s\n| (nothing to display)                                                         |%s",
                        bufBasicHeader,
                                               "\n|------------------------------------------------------------------------------|"
                );
            }
        }
    }
    else if ( bMore )
    {
        Format(bufBasicHeader, CONBUFSIZE, "\n| Survivor MVP Stats -- More Stats -- %10s -- %11s                         |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        //                                                             ###h ##m ##s
        Format(bufBasicHeader, CONBUFSIZE,    "%s|---------------------------------------------------------------------------------------|\n",  bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Time Present  %%%% of rnd | Alive  | Upright |                    |\n",  bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE,    "%s|----------------------|------------------------|--------|---------|--------------------|",    bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                            "%s\n|---------------------------------------------------------------------------------------|\n",
                    g_sConsoleBuf[g_iConsoleBufChunks]
            );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                            "%s\n| (nothing to display)                                                                  |%s",
                    bufBasicHeader,
                                              "\n|---------------------------------------------------------------------------------------|"
            );
        }
    }
    else
    {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                           "\n| Survivor MVP Stats -- %10s -- %11s                                                        |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------|\n",   bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Specials   kills/dmg  | Commons         | Tank   | Witch  | FF    | Rcvd | Time |\n",   bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|-----------------------|-----------------|--------|--------|-------|------|------|",     bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------------------------------------------------------------------------------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                   |%s",
                    bufBasicHeader,
                                           "\n|--------------------------------------------------------------------------------------------------------|"
                );
        }
        
        // print pause and tank time
        if ( g_iConsoleBufChunks > -1 )
        {
            new const s_len = 24;
            new String: strTmp[3][s_len];
            new fullTime, tankTime, pauseTime;
            
            fullTime = GetFullRoundTime( bRound, bTeam, team );
            tankTime = GetFullRoundTime( bRound, bTeam, team, true );
            pauseTime = GetFullRoundTime( bRound, bTeam, team, false, true );
            
            if ( fullTime )  {
                FormatTimeAsDuration( strTmp[0], s_len, fullTime, false  );
                RightPadString( strTmp[0], s_len, 13);
            } else {
                FormatEx( strTmp[0], s_len, "(not started)");
            }
            
            if ( tankTime )  {
                FormatTimeAsDuration( strTmp[1], s_len, tankTime, false  );
                RightPadString( strTmp[1], s_len, 13);
            } else {
                FormatEx( strTmp[1], s_len, "             ");
            }
            
            if ( g_bPauseAvailable ) {
                if ( pauseTime )  {
                    FormatTimeAsDuration( strTmp[2], s_len, pauseTime, false  );
                    RightPadString( strTmp[2], s_len, 13);
                } else {
                    FormatEx( strTmp[2], s_len, "             ");
                }
            } else {
                FormatEx( strTmp[2], s_len, "             ");
            }
            
            FormatEx( bufBasicFooter,
                    CONBUFSIZE,
                                            "| Round Duration:  %13s   %s  %13s   %s  %13s  |\n%s",
                    strTmp[0],
                    (tankTime) ? "Tank Fight Duration:" : "                    ",
                    strTmp[1],
                    (g_bPauseAvailable && pauseTime) ? "Pause Duration:" : "               ",
                    strTmp[2],
                                            "|--------------------------------------------------------------------------------------------------------|\n"
                );
            
            bFooter = true;
        }
    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            if ( bFooter ) {
                ReplaceString(bufBasicFooter, CONBUFSIZE, "%%", "%");
                WriteFileString( g_hStatsFile, bufBasicFooter, false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 )
            {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
                if ( bFooter ) {
                    PrintToConsole(i, bufBasicFooter);
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer(g_sConsoleBuf[j] );
        }
        if ( bFooter ) {
            PrintToServer(bufBasicFooter);
        }
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
        if ( bFooter ) {
            PrintToConsole(client, bufBasicFooter);
        }
    }
}

// show 1 (randomly selected, but at least relevant) fact about the game
stock DisplayStatsFunFactChat( client, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    decl String:printBuffer[1024];
    new String:strLines[8][192];
    new i, j;
    
    printBuffer = GetFunFactChatString( bRound, bTeam, iTeam );
    
    // only print if we got something
    if ( !strlen(printBuffer) ) { return; }
    
    if ( client == -1 ) {
        PrintToServer("\x01%s", printBuffer);
    }

    // PrintToChatAll has a max length. Split it in to individual lines to output separately
    new intPieces = ExplodeString( printBuffer, "\n", strLines, sizeof(strLines), sizeof(strLines[]) );
    
    if ( client > 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToChat(client, "\x01%s", strLines[i]);
        }
    }
    else if ( client == 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToServer("\x01%s", strLines[i]);
        }
    }
    else {
        for ( j = 1; j <= MaxClients; j++ ) {
            for ( i = 0; i < intPieces; i++ ) {
                if ( !IS_VALID_INGAME( j ) || g_iCookieValue[j] != 0 ) { continue; }
                PrintToChat( j, "\x01%s", strLines[i] );
            }
        }
    }
}

String: GetFunFactChatString( bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    decl String: printBuffer[1024];
    
    printBuffer = "";
    
    // use current survivor team -- or previous team in second half before starting
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    new i, j;
    new wTotal = 0;
    new wPicks[256];
    
    new wTypeHighPly[FFACT_MAXTYPES+1];
    new wTypeHighVal[FFACT_MAXTYPES+1];
    new wTypeHighTeam[FFACT_MAXTYPES+1];
    
    // for each type, check whether / and how weighted
    new wTmp = 0;
    new highest, value, property, minval, maxval;
    
    for ( i = 0; i <= FFACT_MAXTYPES; i++ )
    {
        wTmp = 0;
        wTypeHighPly[i] = -1;
        wTypeHighTeam[i] = team;
        
        switch (i)
        {
            case FFACT_TYPE_CROWN: {
                property = plyCrowns;
                minval = FFACT_MIN_CROWN;
                maxval = FFACT_MAX_CROWN;
            }
            case FFACT_TYPE_DRAWCROWN: {
                property = plyCrownsHurt;
                minval = FFACT_MIN_DRAWCROWN;
                maxval = FFACT_MAX_DRAWCROWN;
            }
            case FFACT_TYPE_SKEETS: {
                property = plySkeets;
                minval = FFACT_MIN_SKEET;
                maxval = FFACT_MAX_SKEET;
            }
            case FFACT_TYPE_MELEESKEETS: {
                property = plySkeetsMelee;
                minval = FFACT_MIN_MELEESKEET;
                maxval = FFACT_MAX_MELEESKEET;
            }
            case FFACT_TYPE_HUNTERDP: {
                property = plyHunterDPs;
                minval = FFACT_MIN_HUNTERDP;
                maxval = FFACT_MAX_HUNTERDP;
            }
            case FFACT_TYPE_JOCKEYDP: {
                property = plyJockeyDPs;
                minval = FFACT_MIN_JOCKEYDP;
                maxval = FFACT_MAX_JOCKEYDP;
            }
            case FFACT_TYPE_M2: {
                property = plyShoves;
                minval = FFACT_MIN_M2;
                maxval = FFACT_MAX_M2;
            }
            case FFACT_TYPE_MELEETANK: {
                property = plyMeleesOnTank;
                minval = FFACT_MIN_MELEETANK;
                maxval = FFACT_MAX_MELEETANK;
            }
            case FFACT_TYPE_CUT: {
                property = plyTongueCuts;
                minval = FFACT_MIN_CUT;
                maxval = FFACT_MAX_CUT;
            }
            case FFACT_TYPE_POP: {
                property = plyPops;
                minval = FFACT_MIN_POP;
                maxval = FFACT_MAX_POP;
            }
            case FFACT_TYPE_DEADSTOP: {
                property = plyDeadStops;
                minval = FFACT_MIN_DEADSTOP;
                maxval = FFACT_MAX_DEADSTOP;
            }
            case FFACT_TYPE_LEVELS: {
                property = plyLevels;
                minval = FFACT_MIN_LEVEL;
                maxval = FFACT_MAX_LEVEL;
            }
        }
        
        highest = GetPlayerWithHighestValue( property, bRound, bTeam, iTeam );
        if ( bRound && bTeam ) {
            value = g_strRoundPlayerData[highest][team][property];
        } else {
            if ( g_strRoundPlayerData[highest][LTEAM_A][property] > g_strRoundPlayerData[highest][LTEAM_B][property] ) {
                value = g_strRoundPlayerData[highest][LTEAM_A][property];
                wTypeHighTeam[i] = LTEAM_A;
            } else {
                value = g_strRoundPlayerData[highest][LTEAM_B][property];
                wTypeHighTeam[i] = LTEAM_B;
            }
        }
        
        if ( value > minval )
        {
            wTypeHighPly[i] = highest;
            wTypeHighVal[i] = value;
            // weight for this fact
            if ( value >= maxval ) {
                wTmp = FFACT_MAX_WEIGHT;
            } else {
                wTmp = RoundFloat(  float(value - minval) / float(maxval - minval) * float(FFACT_MAX_WEIGHT) ) + 1;
            }
        }
        
        if ( wTmp ) {
            for ( j = 0; j < wTmp; j++ ) { wPicks[wTotal+j] = i; }
            wTotal += wTmp;
        }
    }
    
    if ( !wTotal ) { return printBuffer; }
    
    // pick one, format it
    new wPick = GetRandomInt( 0, wTotal-1 );
    wPick = wPicks[wPick];
    
    switch (wPick)
    {
        case FFACT_TYPE_CROWN: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01crowned \x05%d \x01witches.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_DRAWCROWN: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01draw-crowned \x05%d \x01witches.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_SKEETS: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01skeeted \x05%d \x01hunters.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_MELEESKEETS: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01skeeted \x05%d \x01hunters with a melee weapon.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_HUNTERDP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01did \x05%d \x01highpounces with hunters.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_JOCKEYDP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01did \x05%d \x01highpounces with jockeys.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_M2: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01shoved \x05%d \x01special infected.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_MELEETANK: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01got \x05%d \x01melee swings on the tank.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_CUT: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01cut \x05%d \x01tongue cuts.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_POP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01popped \x05%d \x01boomers.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_DEADSTOP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01deadstopped \x05%d \x01hunters.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_LEVELS: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] This,\x04 %s \x01fully leveled \x05%d \x01chargers.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
    }
    
    return printBuffer;
}

// display player accuracy stats: details => tank/si/etc
stock DisplayStatsAccuracy( client, bool:bDetails = false, bool:bRound = false, bool:bTeam = true, bool:bSorted = true, iTeam = -1 )
{
    new i, j;
    
    // sorting
    if ( !bSorted )
    {
        SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    }
    
    // prepare buffer(s) for printing
    BuildConsoleBufferAccuracy( bDetails, bRound, bTeam, iTeam );
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
    if ( bDetails )
    {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                           "\n| Accuracy -- Details -- %10s -- %11s                 hits on SI;  headshots on SI;  hits on tank |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Shotgun             | SMG / Rifle         | Sniper              | Pistol              |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------|---------------------|---------------------|---------------------|", bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------------------------------------------------------------------------------------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                         |%s",
                    bufBasicHeader,
                                           "\n|--------------------------------------------------------------------------------------------------------------|"
                );
        }
    }
    else
    {
        Format(bufBasicHeader, CONBUFSIZE, "\n| Accuracy Stats -- %10s -- %11s       hits (pellets/bullets);  acc prc;  headshots prc (of hits) |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Shotgun buckshot    | SMG / Rifle  acc hs | Sniper       acc hs | Pistol       acc hs |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------|---------------------|---------------------|---------------------|", bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------------------------------------------------------------------------------------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                         |%s",
                    bufBasicHeader,
                                           "\n|--------------------------------------------------------------------------------------------------------------|"
                );
        }

    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 )
            {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

// display special skill stats
stock DisplayStatsSpecial( client, bool:bRound = true, bool:bTeam = true, bool:bSorted = false, iTeam = -1 )
{
    new i, j;
    
    // sorting
    if ( !bSorted )
    {
        SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    }
    
    // prepare buffer(s) for printing
    BuildConsoleBufferSpecial( bRound, bTeam, iTeam );
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
    Format( bufBasicHeader,
            CONBUFSIZE,
                                           "\n| Special -- %10s -- %11s       skts(full/hurt/melee); lvl(full/hurt); crwn(full/draw) |\n",
            ( bRound ) ? "This Round" : "ALL Rounds",
            ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
        );
    if ( !g_bSkillDetectLoaded ) {
        Format(bufBasicHeader, CONBUFSIZE, "%s| ( skill_detect library not loaded: most of these stats won't be tracked )                         |\n", bufBasicHeader);
    }
    //                                                             #### / ### / ###   ### / ###    ### / ###   ### / ###   ####   #### / ####
    Format(bufBasicHeader, CONBUFSIZE, "%s|---------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Skeets  fl/ht/ml | Levels    | Crowns    | Pops | Cuts / Self | DSs / M2s  |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|------------------|-----------|-----------|------|-------------|------------|", bufBasicHeader);
    
    if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
    if ( g_iConsoleBufChunks > -1 ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                     "%s\n|---------------------------------------------------------------------------------------------------|",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    } else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                              |%s",
                bufBasicHeader,
                                       "\n|---------------------------------------------------------------------------------------------------|"
            );
    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 )
            {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

// display tables of survivor friendly fire given/taken
stock DisplayStatsFriendlyFire ( client, bool:bRound = true, bool:bTeam = true, bool:bSorted = false, iTeam = -1 )
{
    new i, j;
    // iTeam: -1: current survivor team, 0/1: specific team
    
    // sorting
    if ( !bSorted )
    {
        SortPlayersMVP( true, SORT_FF, bTeam, iTeam );
    }
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
    // only show tables if there is FF damage
    new bool:bNoStatsToShow = true;
    if ( bRound ) {
        if ( bTeam ) {
            if ( g_strRoundData[g_iRound][team][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        } else {
            if ( g_strRoundData[g_iRound][LTEAM_A][rndFFDamageTotal] || g_strRoundData[g_iRound][LTEAM_B][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        }
    }
    else {
        if ( bTeam ) {
            if ( g_strAllRoundData[team][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        } else {
            if ( g_strAllRoundData[LTEAM_A][rndFFDamageTotal] || g_strAllRoundData[LTEAM_B][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        }
    }
    
    if ( bNoStatsToShow )
    {
        Format(bufBasicHeader, CONBUFSIZE, "\nFF: No Friendly Fire done, not showing table.");
        g_iConsoleBufChunks = -1;
    }
    else
    {
        // prepare buffer(s) for printing
        BuildConsoleBufferFriendlyFireGiven( bRound, bTeam, iTeam );
        
        // friendly fire -- given
        Format( bufBasicHeader,
                CONBUFSIZE,
                                           "\n| Friendly Fire -- Given / Offenders -- %10s -- %11s                                      |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | On Incap | Other  || to Self |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------||---------------------------------------------------------||---------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                 |%s",
                    bufBasicHeader,
                                           "\n|------------------------------------------------------------------------------------------------------|"
                );
        }
    }

    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 )
            {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
    
    if ( bNoStatsToShow ) { return; }
    BuildConsoleBufferFriendlyFireTaken( bRound, bTeam, iTeam );
    
    // friendly fire -- taken
    Format(     bufBasicHeader,
                CONBUFSIZE,
                                       "\n| Friendly Fire -- Received / Victims -- %10s -- %11s                                     |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
    Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | Incapped | Other  || Fall    |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
    
    if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
    if ( g_iConsoleBufChunks > -1 ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                     "%s\n|--------------------------------||---------------------------------------------------------||---------|\n",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    } else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                                 |%s",
                bufBasicHeader,
                                       "\n|------------------------------------------------------------------------------------------------------|"
            );
    }
    
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 )
            {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) )
    {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

stock BuildConsoleBufferGeneral ( bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[9][s_len];
    new i, line;
    new bool: bDivider = false;
    new String: strTmpMap[20];
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    new tmpRoundTime;
    new startRound = ( g_iRound > MAXSHOWROUNDS ) ? g_iRound - MAXSHOWROUNDS : 0;
    
    //                      | ###. ############### | ###h ##m ##s | ##### | ###### |  ##### |  ##### | #### | ##### |    ###### |
    
    // game rounds
    for ( i = startRound; i <= g_iRound; i++ )
    {
        // round header:
        strcopy( strTmpMap, sizeof(strTmpMap), g_sMapName[i] );
        RightPadString( strTmpMap, sizeof(strTmpMap), 15 );
        Format( strTmp[0], s_len, "%3d. %15s", i + 1, strTmpMap );
        
        // round time
        tmpRoundTime = 0;
        if ( g_strRoundData[i][team][rndStartTime] )
        {
            if ( i == g_iRound ) {
                tmpRoundTime = GetFullRoundTime( true, bTeam, team );
            } else {
                tmpRoundTime = g_strRoundData[i][team][rndEndTime] - g_strRoundData[i][team][rndStartTime];
            }
            
            FormatTimeAsDuration( strTmp[1], s_len, tmpRoundTime );
            LeftPadString( strTmp[1], s_len, 12 );
        }
        else {
            Format( strTmp[1], s_len, "            " );
        }
        
        // si
        if ( g_strRoundData[i][team][rndSIKilled] ) {
            Format( strTmp[2], s_len, "%5d", g_strRoundData[i][team][rndSIKilled] );
        } else {
            Format( strTmp[2], s_len, "     " );
        }
        
        // common
        if ( g_strRoundData[i][team][rndCommon] ) {
            Format( strTmp[3], s_len, "%6d", g_strRoundData[i][team][rndSIKilled] );
        } else {
            Format( strTmp[3], s_len, "      " );
        }
        
        // deaths
        if ( g_strRoundData[i][team][rndDeaths] ) {
            Format( strTmp[4], s_len, "%6d", g_strRoundData[i][team][rndDeaths] );
        } else {
            Format( strTmp[4], s_len, "      " );
        }
        
        // incaps
        if ( g_strRoundData[i][team][rndIncaps] ) {
            Format( strTmp[5], s_len, "%6d", g_strRoundData[i][team][rndIncaps] );
        } else {
            Format( strTmp[5], s_len, "      " );
        }
        
        // kits
        if ( g_strRoundData[i][team][rndKitsUsed] ) {
            Format( strTmp[6], s_len, "%4d", g_strRoundData[i][team][rndKitsUsed] );
        } else {
            Format( strTmp[6], s_len, "    " );
        }
        
        // pills
        if ( g_strRoundData[i][team][rndPillsUsed] ) {
            Format( strTmp[7], s_len, "%6d", g_strRoundData[i][team][rndPillsUsed] );
        } else {
            Format( strTmp[7], s_len, "      " );
        }
        
        // restarts
        if ( g_strRoundData[i][team][rndRestarts] ) {
            Format( strTmp[8], s_len, "%8d", g_strRoundData[i][team][rndRestarts] );
        } else {
            Format( strTmp[8], s_len, "        " );
        }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %12s | %5s | %6s | %6s | %6s | %4s | %6s | %8s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ------------ | ----- | ------ | ------ | ------ | ---- | ----- | --------- |\n" : "",
                strTmp[0], strTmp[1], strTmp[2],
                strTmp[3], strTmp[4], strTmp[5],
                strTmp[6], strTmp[7], strTmp[8]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock BuildConsoleBufferSpecial ( bool:bRound = false, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[6][s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // Special skill stats
    for ( x = 0; x < g_iPlayers; x++ )
    {
        i = g_iPlayerIndexSorted[SORT_SI][x];
        
        // also skip bots for this list
        if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( !bTeam && bRound ) {
            team = g_iPlayerSortedUseTeam[SORT_SI][i];
        }
        if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
        
        // skeets:
        if (    bRound && (g_strRoundPlayerData[i][team][plySkeets] || g_strRoundPlayerData[i][team][plySkeetsHurt] || g_strRoundPlayerData[i][team][plySkeetsMelee]) ||
                !bRound && (g_strPlayerData[i][plySkeets] || g_strPlayerData[i][plySkeetsHurt] || g_strPlayerData[i][plySkeetsMelee])
        ) {
            Format( strTmp[0], s_len, "%4d /%4d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySkeets] : g_strPlayerData[i][plySkeets] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySkeetsHurt] : g_strPlayerData[i][plySkeetsHurt] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySkeetsMelee] : g_strPlayerData[i][plySkeetsMelee] )
                );
        } else {
            Format( strTmp[0], s_len, "                " );
        }
        
        // levels
        if (    bRound && (g_strRoundPlayerData[i][team][plyLevels] || g_strRoundPlayerData[i][team][plyLevelsHurt]) ||
                !bRound && (g_strPlayerData[i][plyLevels] || g_strPlayerData[i][plyLevelsHurt])
        ) {
            Format( strTmp[1], s_len, "%3d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyLevels] : g_strPlayerData[i][plyLevels] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyLevelsHurt] : g_strPlayerData[i][plyLevelsHurt] )
                );
        } else {
            Format( strTmp[1], s_len, "         " );
        }
        
        // crowns
        if (    bRound && (g_strRoundPlayerData[i][team][plyCrowns] || g_strRoundPlayerData[i][team][plyCrownsHurt]) ||
                !bRound && (g_strPlayerData[i][plyCrowns] || g_strPlayerData[i][plyCrownsHurt])
        ) {
            Format( strTmp[2], s_len, "%3d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyCrowns] : g_strPlayerData[i][plyCrowns] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyCrownsHurt] : g_strPlayerData[i][plyCrownsHurt] )
                );
        } else {
            Format( strTmp[2], s_len, "         " );
        }
        
        // pops
        if ( bRound && g_strRoundPlayerData[i][team][plyPops] || !bRound && g_strPlayerData[i][plyPops] ) {
            Format( strTmp[3], s_len, "%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyPops] : g_strPlayerData[i][plyPops] )
                );
        } else {
            Format( strTmp[3], s_len, "    " );
        }
        
        // cuts
        if (    bRound && (g_strRoundPlayerData[i][team][plyTongueCuts] || g_strRoundPlayerData[i][team][plySelfClears] ) ||
                !bRound && (g_strPlayerData[i][plyTongueCuts] || g_strPlayerData[i][plySelfClears] ) ) {
            Format( strTmp[4], s_len, "%4d /%5d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyTongueCuts] : g_strPlayerData[i][plyTongueCuts] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySelfClears] : g_strPlayerData[i][plySelfClears] )
                );
        } else {
            Format( strTmp[4], s_len, "           " );
        }
        
        // deadstops & m2s
        if (    bRound && (g_strRoundPlayerData[i][team][plyShoves] || g_strRoundPlayerData[i][team][plyDeadStops]) ||
                !bRound && (g_strPlayerData[i][plyShoves] || g_strPlayerData[i][plyDeadStops])
        ) {
            Format( strTmp[5], s_len, "%4d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyDeadStops] : g_strPlayerData[i][plyDeadStops] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyShoves] : g_strPlayerData[i][plyShoves] )
                );
        } else {
            Format( strTmp[5], s_len, "          " );
        }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %16s | %9s | %9s | %4s | %11s | %10s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ---------------- | --------- | --------- | ---- | ----------- | ---------- |\n" : "",
                g_sPlayerNameSafe[i],
                strTmp[0], strTmp[1], strTmp[2],
                strTmp[3], strTmp[4], strTmp[5]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock BuildConsoleBufferAccuracy ( bool:details = false, bool:bRound = false, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[5][s_len], String: strTmpA[s_len], String: strTmpB[s_len];
    new i, line;
    new bool: bDivider = false;
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // 1234567890123456789
    // ##### /##### ###.#%
    //   ##### ##### #####     details
    
    if ( details )
    {
        // Accuracy - details
        for ( i = 0; i < g_iPlayers; i++ )
        {
            // also skip bots for this list
            if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // shotgun:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsShotgun] || !bRound && g_strPlayerData[i][plyHitsShotgun] ) {
                Format( strTmp[0], s_len, "%7d     %7d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSIShotgun] : g_strPlayerData[i][plyHitsSIShotgun] ),
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsTankShotgun] : g_strPlayerData[i][plyHitsTankShotgun] )
                    );
            } else {
                Format( strTmp[0], s_len, "                   " );
            }
            
            // smg:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsSmg] || !bRound && g_strPlayerData[i][plyHitsSmg] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSISmg] ) / float( g_strRoundPlayerData[i][team][plyHitsSISmg] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISmg] ) / float( g_strPlayerData[i][plyHitsSISmg] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[1], s_len, "%6d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSISmg] : g_strPlayerData[i][plyHitsSISmg] ),
                        strTmpA,
                        ( (bRound) ?  g_strRoundPlayerData[i][team][plyHitsTankSmg] : g_strPlayerData[i][plyHitsTankSmg] )
                    );
            } else {
                Format( strTmp[1], s_len, "                   " );
            }
            
            // sniper:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsSniper] || !bRound && g_strPlayerData[i][plyHitsSniper] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSISniper] ) / float( g_strRoundPlayerData[i][team][plyHitsSISniper] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISniper] ) / float( g_strPlayerData[i][plyHitsSISniper] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[2], s_len, "%6d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSISniper] : g_strPlayerData[i][plyHitsSISniper] ),
                        strTmpA,
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsTankSniper] : g_strPlayerData[i][plyHitsTankSniper] )
                    );
            } else {
                Format( strTmp[2], s_len, "                   " );
            }
            
            // pistols:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsPistol] || !bRound && g_strPlayerData[i][plyHitsPistol] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSIPistol] ) / float( g_strRoundPlayerData[i][team][plyHitsSIPistol] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSIPistol] ) / float( g_strPlayerData[i][plyHitsSIPistol] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[3], s_len, "%6d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSIPistol] : g_strPlayerData[i][plyHitsSIPistol] ),
                        strTmpA,
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsTankPistol] : g_strPlayerData[i][plyHitsTankPistol] )
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %19s | %19s | %19s | %19s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | ------------------- | ------------------- | ------------------- | ------------------- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
    else
    {
        // Accuracy - normal
        for ( i = 0; i < g_iPlayers; i++ )
        {
            // also skip bots for this list
            if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // shotgun:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsShotgun] || !bRound && g_strPlayerData[i][plyShotsShotgun] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsShotgun] ) / float( g_strRoundPlayerData[i][team][plyShotsShotgun] ) * 100.0);
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsShotgun] ) / float( g_strPlayerData[i][plyShotsShotgun] ) * 100.0); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[0], s_len, "%7d      %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsShotgun] : g_strPlayerData[i][plyHitsShotgun] ),
                        strTmpA
                    );
            } else {
                Format( strTmp[0], s_len, "                   " );
            }
            
            // smg:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsSmg] || !bRound && g_strPlayerData[i][plyShotsSmg] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsSmg] ) / float( g_strRoundPlayerData[i][team][plyShotsSmg] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSmg] ) / float( g_strPlayerData[i][plyShotsSmg] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) { FormatEx( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSmg] ) / float( g_strRoundPlayerData[i][team][plyHitsSmg] - g_strRoundPlayerData[i][team][plyHitsTankSmg] ) * 100.0 );
                } else {        FormatEx( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSmg] ) / float( g_strPlayerData[i][plyHitsSmg] - g_strPlayerData[i][plyHitsTankSmg] ) * 100.0 ); }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[1], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSmg] : g_strPlayerData[i][plyHitsSmg] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[1], s_len, "                   " );
            }
            
            // sniper:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsSniper] || !bRound && g_strPlayerData[i][plyShotsSniper] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsSniper] ) / float( g_strRoundPlayerData[i][team][plyShotsSniper] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSniper] ) / float( g_strPlayerData[i][plyShotsSniper] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) { FormatEx( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSniper] ) / float( g_strRoundPlayerData[i][team][plyHitsSniper] - g_strRoundPlayerData[i][team][plyHitsTankSniper] ) * 100.0 );
                } else {        FormatEx( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSniper] ) / float( g_strPlayerData[i][plyHitsSniper] - g_strPlayerData[i][plyHitsTankSniper] ) * 100.0 ); }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[2], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSniper] : g_strPlayerData[i][plyHitsSniper] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[2], s_len, "                   " );
            }
            
            // pistols:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsPistol] || !bRound && g_strPlayerData[i][plyShotsPistol] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsPistol] ) / float( g_strRoundPlayerData[i][team][plyShotsPistol] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsPistol] ) / float( g_strPlayerData[i][plyShotsPistol] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) { FormatEx( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsPistol] ) / float( g_strRoundPlayerData[i][team][plyHitsPistol] - g_strRoundPlayerData[i][team][plyHitsTankPistol] ) * 100.0 );
                } else {        FormatEx( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsPistol] ) / float( g_strPlayerData[i][plyHitsPistol] - g_strPlayerData[i][plyHitsTankPistol] ) * 100.0 ); }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[3], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsPistol] : g_strPlayerData[i][plyHitsPistol] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %19s | %19s | %19s | %19s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | ------------------- | ------------------- | ------------------- | ------------------- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
}

stock BuildConsoleBufferMVP ( bool:bTank = false, bool: bMore = false, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[7][s_len], String: strTmpA[s_len], String: strTmpB[s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    new time = GetTime();
    new fullTime, presTime, aliveTime, upTime;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // prepare time for comparison to full round
    if ( !bTank ) {
        fullTime = GetFullRoundTime( bRound, bTeam, team );
    }
    
    if ( bTank )
    {
        // MVP - tank related
        
        for ( x = 0; x < g_iPlayers; x++ )
        {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // si damage
            if ( bRound && g_strRoundPlayerData[i][team][plySIKilledTankUp] || !bRound && g_strPlayerData[i][plySIKilledTankUp] ) {
                FormatEx( strTmp[0], s_len, "%5d %8d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plySIKilledTankUp] : g_strPlayerData[i][plySIKilledTankUp] ),
                        ( (bRound) ? g_strRoundPlayerData[i][team][plySIDamageTankUp] : g_strPlayerData[i][plySIDamageTankUp] )
                    );
            } else { FormatEx( strTmp[0], s_len, "              " ); }
            
            // commons
            if ( bRound && g_strRoundPlayerData[i][team][plyCommonTankUp] || !bRound && g_strPlayerData[i][plyCommonTankUp] ) {
                FormatEx( strTmp[1], s_len, "  %8d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyCommonTankUp] : g_strPlayerData[i][plyCommonTankUp] )
                    );
            } else { FormatEx( strTmp[1], s_len, "          " ); }
            
            // melee on tank
            if ( bRound && g_strRoundPlayerData[i][team][plyMeleesOnTank] || !bRound && g_strPlayerData[i][plyMeleesOnTank] ) {
                FormatEx( strTmp[2], s_len, "%6d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyMeleesOnTank] : g_strPlayerData[i][plyMeleesOnTank] )
                    );
            } else { FormatEx( strTmp[2], s_len, "      " ); }
            
            // rock skeets / eats       ----- / -----
            if ( bRound && (g_strRoundPlayerData[i][team][plyRockSkeets] || g_strRoundPlayerData[i][team][plyRockEats]) ||
                !bRound && (g_strPlayerData[i][plyRockSkeets] || g_strPlayerData[i][plyRockEats])
            ) {
                FormatEx( strTmp[3], s_len, " %5d /%6d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyRockSkeets] : g_strPlayerData[i][plyRockSkeets] ),
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyRockEats] : g_strPlayerData[i][plyRockEats] )
                    );
            } else { FormatEx( strTmp[3], s_len, "              " ); }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %14s | %10s | %6s | %14s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | -------------- | ---------- | ------ | -------------- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
    else if ( bMore )
    {
        // MVP - more ( time / pinned )
        for ( x = 0; x < g_iPlayers; x++ )
        {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // time present
            if ( bRound ) {
                if ( g_strRoundPlayerData[i][team][plyTimeStartPresent] ) {
                    presTime = ( (g_strRoundPlayerData[i][team][plyTimeStopPresent]) ? g_strRoundPlayerData[i][team][plyTimeStopPresent] : time ) - g_strRoundPlayerData[i][team][plyTimeStartPresent];
                } else {
                    presTime = 0;
                }
            } else {
                if ( g_strPlayerData[i][plyTimeStartPresent] ) {
                    presTime = ( (g_strPlayerData[i][plyTimeStopPresent]) ? g_strPlayerData[i][plyTimeStopPresent] : time ) - g_strPlayerData[i][plyTimeStartPresent];
                } else {
                    presTime = 0;
                }
            }
            
            FormatPercentage( strTmpA, s_len, presTime, fullTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 7 );
            FormatEx( strTmpA, s_len, "%7s%s",
                    strTmpA,
                    ( presTime ) ? "%%" : " "
                );
            
            if ( fullTime && presTime )  {
                FormatTimeAsDuration( strTmpB, s_len, presTime );
                LeftPadString( strTmpB, s_len, 13 );
            } else {
                Format( strTmpB, s_len, "             ");
            }
            Format( strTmp[0], s_len, "%13s %8s", strTmpB, strTmpA );
            
            // time alive
            if ( bRound ) {
                if ( g_strRoundPlayerData[i][team][plyTimeStartAlive] ) {
                    aliveTime = ( (g_strRoundPlayerData[i][team][plyTimeStopAlive]) ? g_strRoundPlayerData[i][team][plyTimeStopAlive] : time ) - g_strRoundPlayerData[i][team][plyTimeStartAlive];
                } else {
                    aliveTime = 0;
                }
            } else {
                if ( g_strPlayerData[i][plyTimeStartAlive] ) {
                    aliveTime = ( (g_strPlayerData[i][plyTimeStopAlive]) ? g_strPlayerData[i][plyTimeStopAlive] : time ) - g_strPlayerData[i][plyTimeStartAlive];
                } else {
                    aliveTime = 0;
                }
            }
            
            FormatPercentage( strTmpA, s_len, aliveTime, presTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 5 );
            FormatEx( strTmp[1], s_len, "%5s%s",
                    strTmpA,
                    ( presTime ) ? "%%" : " "
                );
            
            // time upright
            if ( bRound ) {
                if ( g_strRoundPlayerData[i][team][plyTimeStartUpright] ) {
                    upTime = ( (g_strRoundPlayerData[i][team][plyTimeStopUpright]) ? g_strRoundPlayerData[i][team][plyTimeStopUpright] : time ) - g_strRoundPlayerData[i][team][plyTimeStartUpright];
                } else {
                    upTime = 0;
                }
            } else {
                if ( g_strPlayerData[i][plyTimeStartUpright] ) {
                    upTime = ( (g_strPlayerData[i][plyTimeStopUpright]) ? g_strPlayerData[i][plyTimeStopUpright] : time ) - g_strPlayerData[i][plyTimeStartUpright];
                } else {
                    upTime = 0;
                }
            }
            
            FormatPercentage( strTmpA, s_len, upTime, presTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 6 );
            FormatEx( strTmp[2], s_len, "%6s%s",
                    strTmpA,
                    ( presTime ) ? "%%" : " "
                );
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %22s | %6s | %7s |                    |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | ---------------------- | ------ | ------- |                    |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
    else
    {
        // MVP normal
        
        new bool: bPrcDecimal = GetConVarBool(g_hCvarDetailPercent);
        new bool: bTankUp = bool:( !g_bModeCampaign && (!bTeam || team == g_iCurTeam) && g_bInRound && IsTankInGame() );
        
        for ( x = 0; x < g_iPlayers; x++ )
        {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // si damage
            if ( bRound && g_strRoundPlayerData[i][team][plySIDamage] || !bRound && g_strPlayerData[i][plySIDamage] ) {
                FormatPercentage( strTmpA, s_len,
                        ( bRound ) ? g_strRoundPlayerData[i][team][plySIDamage] : g_strPlayerData[i][plySIDamage],
                        ( bRound ) ? g_strRoundData[g_iRound][team][rndSIDamage] : g_strAllRoundData[team][rndSIDamage],
                        bPrcDecimal
                    );
                LeftPadString( strTmpA, s_len, 5 );
                
                Format( strTmp[0], s_len, "%4d %8d  %5s%s",
                        (bRound) ? g_strRoundPlayerData[i][team][plySIKilled] : g_strPlayerData[i][plySIKilled],
                        (bRound) ? g_strRoundPlayerData[i][team][plySIDamage] : g_strPlayerData[i][plySIDamage],
                        strTmpA,
                        ( bRound && g_strRoundPlayerData[i][team][plySIDamage] || !bRound && g_strPlayerData[i][plySIDamage] ) ? "%%" : " "
                    );
            } else {
                FormatEx( strTmp[0], s_len, "                     " );
            }
            
            // commons
            if ( bRound && g_strRoundPlayerData[i][team][plyCommon] || !bRound && g_strPlayerData[i][plyCommon] ) {
                FormatPercentage( strTmpA, s_len,
                        ( bRound ) ? g_strRoundPlayerData[i][team][plyCommon] : g_strPlayerData[i][plyCommon],
                        ( bRound ) ? g_strRoundData[g_iRound][team][rndCommon] : g_strAllRoundData[team][rndCommon],
                        bPrcDecimal
                    );
                LeftPadString( strTmpA, s_len, 5 );
                
                FormatEx( strTmp[1], s_len, "%7d  %5s%s",
                        (bRound) ? g_strRoundPlayerData[i][team][plyCommon] : g_strPlayerData[i][plyCommon],
                        strTmpA,
                        ( bRound && g_strRoundPlayerData[i][team][plyCommon] || !bRound && g_strPlayerData[i][plyCommon] ) ? "%%" : " "
                    );
            } else {
                FormatEx( strTmp[1], s_len, "               " );
            }
            
            // tank
            if ( bTankUp ) {
                // hide 
                FormatEx( strTmp[2], s_len, "%s", "hidden" );
            } else {
                if ( bRound && g_strRoundPlayerData[i][team][plyTankDamage] || !bRound && g_strPlayerData[i][plyTankDamage] ) {
                    FormatEx( strTmp[2], s_len, "%6d",
                            (bRound) ? g_strRoundPlayerData[i][team][plyTankDamage] : g_strPlayerData[i][plyTankDamage]
                        );
                } else { FormatEx( strTmp[2], s_len, "      " ); }
            }
            
            // witch
            if ( bRound && g_strRoundPlayerData[i][team][plyWitchDamage] || !bRound && g_strPlayerData[i][plyWitchDamage] ) {
                FormatEx( strTmp[3], s_len, "%6d",
                        (bRound) ? g_strRoundPlayerData[i][team][plyWitchDamage] : g_strPlayerData[i][plyWitchDamage]
                    );
            } else { FormatEx( strTmp[3], s_len, "      " ); }
            
            // ff
            if ( bRound && g_strRoundPlayerData[i][team][plyFFGiven] || !bRound && g_strPlayerData[i][plyFFGiven] ) {
                FormatEx( strTmp[4], s_len, "%5d",
                        (bRound) ? g_strRoundPlayerData[i][team][plyFFGiven] : g_strPlayerData[i][plyFFGiven]
                    );
            } else { FormatEx( strTmp[4], s_len, "     " ); }
            
            // damage received
            if ( bRound && g_strRoundPlayerData[i][team][plyDmgTaken] || !bRound && g_strPlayerData[i][plyDmgTaken] ) {
                FormatEx( strTmp[5], s_len, "%4d",
                        (bRound) ? g_strRoundPlayerData[i][team][plyDmgTaken] : g_strPlayerData[i][plyDmgTaken]
                    );
            } else { FormatEx( strTmp[5], s_len, "    " ); }
            
            // time (%)
            if ( bRound ) {
                presTime = ( (g_strRoundPlayerData[i][team][plyTimeStopPresent]) ? g_strRoundPlayerData[i][team][plyTimeStopPresent] : time ) - g_strRoundPlayerData[i][team][plyTimeStartPresent];
            } else {
                presTime = ( (g_strPlayerData[i][plyTimeStopPresent]) ? g_strPlayerData[i][plyTimeStopPresent] : time ) - g_strPlayerData[i][plyTimeStartPresent];
            }
            FormatPercentage( strTmpA, s_len, presTime, fullTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 3 );
            FormatEx( strTmp[6], s_len, "%3s%s",
                    strTmpA,
                    ( presTime && fullTime ) ? "%%" : " "
                );
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            }
            else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %21s | %15s | %6s | %6s | %5s | %4s | %4s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | --------------------- | --------------- | ------ | ------ | ----- | ---- | ---- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2],
                    strTmp[3], strTmp[4], strTmp[5],
                    strTmp[6]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
}

stock BuildConsoleBufferFriendlyFireGiven ( bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 15;
    decl String:strPrint[FFTYPE_MAX][s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // GIVEN
    for ( x = 0; x < g_iPlayers; x++ )
    {
        i = g_iPlayerIndexSorted[SORT_FF][x];
        
        // also skip bots for this list?
        if ( i < FIRST_NON_BOT ) { continue; }  // never show bots here, they never do FF
        
        // only show survivors for the round in question
        if ( !bTeam && bRound ) {
            team = g_iPlayerSortedUseTeam[SORT_FF][i];
        }
        if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[i][team][plyFFGivenTotal] && !g_strRoundPlayerData[i][team][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[i][plyFFGivenTotal] && !g_strPlayerData[i][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // prepare print
        if ( !bRound && g_strPlayerData[i][plyFFGivenTotal] || bRound && g_strRoundPlayerData[i][team][plyFFGivenTotal] ) {
                    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenTotal] : g_strRoundPlayerData[i][team][plyFFGivenTotal] );
        } else {    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenPellet] || bRound && g_strRoundPlayerData[i][team][plyFFGivenPellet] ) {
                    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenPellet] : g_strRoundPlayerData[i][team][plyFFGivenPellet] );
        } else {    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenBullet] || bRound && g_strRoundPlayerData[i][team][plyFFGivenBullet] ) {
                    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenBullet] : g_strRoundPlayerData[i][team][plyFFGivenBullet] );
        } else {    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenMelee] || bRound && g_strRoundPlayerData[i][team][plyFFGivenMelee] ) {
                    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenMelee] : g_strRoundPlayerData[i][team][plyFFGivenMelee] );
        } else {    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenFire] || bRound && g_strRoundPlayerData[i][team][plyFFGivenFire] ) {
                    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenFire] : g_strRoundPlayerData[i][team][plyFFGivenFire] );
        } else {    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenIncap] || bRound && g_strRoundPlayerData[i][team][plyFFGivenIncap] ) {
                    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "%8d", (!bRound) ? g_strPlayerData[i][plyFFGivenIncap] : g_strRoundPlayerData[i][team][plyFFGivenIncap] );
        } else {    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenOther] || bRound && g_strRoundPlayerData[i][team][plyFFGivenOther] ) {
                    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenOther] : g_strRoundPlayerData[i][team][plyFFGivenOther] );
        } else {    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenSelf] || bRound && g_strRoundPlayerData[i][team][plyFFGivenSelf] ) {
                    FormatEx(strPrint[FFTYPE_SELF],       s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenSelf] : g_strRoundPlayerData[i][team][plyFFGivenSelf] );
        } else {    FormatEx(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ------- || ------- | ------- | ------ | ------ | -------- | ------ || ------- |\n" : "",
                g_sPlayerNameSafe[i],
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE], strPrint[FFTYPE_INCAP], strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock BuildConsoleBufferFriendlyFireTaken ( bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 15;
    decl String:strPrint[FFTYPE_MAX][s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // TAKEN
    for ( x = 0; x < g_iPlayers; x++ )
    {
        i = g_iPlayerIndexSorted[SORT_FF][x];
                
        // also skip bots for this list?
        //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( !bTeam && bRound ) {
            team = g_iPlayerSortedUseTeam[SORT_SI][i];
        }
        if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[i][team][plyFFGivenTotal] && !g_strRoundPlayerData[i][team][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[i][plyFFGivenTotal] && !g_strPlayerData[i][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // prepare print
        if ( !bRound && g_strPlayerData[i][plyFFTakenTotal] || bRound && g_strRoundPlayerData[i][team][plyFFTakenTotal] ) {
                    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFTakenTotal] : g_strRoundPlayerData[i][team][plyFFTakenTotal] );
        } else {    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenPellet] || !bRound && g_strRoundPlayerData[i][team][plyFFTakenPellet] ) {
                    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFTakenPellet] : g_strRoundPlayerData[i][team][plyFFTakenPellet] );
        } else {    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenBullet] || bRound && g_strRoundPlayerData[i][team][plyFFTakenBullet] ) {
                    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFTakenBullet] : g_strRoundPlayerData[i][team][plyFFTakenBullet] );
        } else {    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenMelee] || bRound && g_strRoundPlayerData[i][team][plyFFTakenMelee] ) {
                    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFTakenMelee] : g_strRoundPlayerData[i][team][plyFFTakenMelee] );
        } else {    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenFire] || bRound && g_strRoundPlayerData[i][team][plyFFTakenFire] ) {
                    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFTakenFire] : g_strRoundPlayerData[i][team][plyFFTakenFire] );
        } else {    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenIncap] || bRound && g_strRoundPlayerData[i][team][plyFFTakenIncap] ) {
                    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "%8d", (!bRound) ? g_strPlayerData[i][plyFFTakenIncap] : g_strRoundPlayerData[i][team][plyFFTakenIncap] );
        } else {    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenOther] || bRound && g_strRoundPlayerData[i][team][plyFFTakenOther] ) {
                    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFTakenOther] : g_strRoundPlayerData[i][team][plyFFTakenOther] );
        } else {    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFallDamage] || bRound && g_strRoundPlayerData[i][team][plyFallDamage] ) {
                    FormatEx(strPrint[FFTYPE_SELF],       s_len, "%7d", (!bRound) ? g_strRoundPlayerData[i][team][plyFallDamage] : g_strPlayerData[i][plyFallDamage] );
        } else {    FormatEx(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ------- || ------- | ------- | ------ | ------ | -------- | ------ || ------- |\n" : "",
                g_sPlayerNameSafe[i],
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE], strPrint[FFTYPE_INCAP], strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock SortPlayersMVP ( bool:bRound = true, sortCol = SORT_SI, bool:bTeam = true, iTeam = -1 )
{
    new iStored = 0;
    new i, j;
    new bool: found, highest, highTeam, pickTeam;
    
    if ( sortCol < SORT_SI || sortCol > SORT_FF ) { return; }
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1) : g_iCurTeam );
    
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
                    if ( bRound ) {
                        if ( bTeam ) {
                            if (    highest == -1 ||
                                    g_strRoundPlayerData[i][team][plySIDamage] > g_strRoundPlayerData[highest][team][plySIDamage] || 
                                    g_strRoundPlayerData[i][team][plySIDamage] == g_strRoundPlayerData[highest][team][plySIDamage] &&
                                        (   g_strRoundPlayerData[i][team][plyCommon] > g_strRoundPlayerData[highest][team][plyCommon] ||
                                            ( g_strRoundPlayerData[i][team][plyCommon] == g_strRoundPlayerData[highest][team][plyCommon] && highest < FIRST_NON_BOT ) )
                            ) {
                                highest = i;
                            }
                        }
                        else {
                            pickTeam = ( g_strRoundPlayerData[i][LTEAM_A][plySIDamage] >= g_strRoundPlayerData[i][LTEAM_B][plySIDamage] ) ? LTEAM_A : LTEAM_B;
                            if (    highest == -1 ||
                                    g_strRoundPlayerData[i][pickTeam][plySIDamage] > g_strRoundPlayerData[highest][highTeam][plySIDamage] ||
                                    g_strRoundPlayerData[i][pickTeam][plySIDamage] == g_strRoundPlayerData[highest][highTeam][plySIDamage] &&
                                        (   g_strRoundPlayerData[i][pickTeam][plyCommon] > g_strRoundPlayerData[highest][highTeam][plyCommon] ||
                                            ( g_strRoundPlayerData[i][pickTeam][plyCommon] == g_strRoundPlayerData[highest][highTeam][plyCommon] && highest < FIRST_NON_BOT ) )
                            ) {
                                highest = i;
                                g_iPlayerSortedUseTeam[sortCol][i] = pickTeam;
                                highTeam = pickTeam;
                            }
                        }
                    }
                    else {
                        if (    highest == -1 ||
                                g_strPlayerData[i][plySIDamage] > g_strPlayerData[highest][plySIDamage] ||
                                g_strPlayerData[i][plySIDamage] == g_strPlayerData[highest][plySIDamage] &&
                                    (   g_strPlayerData[i][plyCommon] > g_strPlayerData[highest][plyCommon] ||
                                        ( g_strPlayerData[i][plyCommon] == g_strPlayerData[highest][plyCommon] && highest < FIRST_NON_BOT ) )
                        ) {
                            highest = i;
                        }
                    }
                }
                case SORT_CI:
                {
                    if ( bRound ) {
                        if ( bTeam ) {
                            if (    highest == -1 ||
                                    g_strRoundPlayerData[i][team][plyCommon] > g_strRoundPlayerData[highest][team][plyCommon] ||
                                    g_strRoundPlayerData[i][team][plyCommon] == g_strRoundPlayerData[highest][team][plyCommon] &&
                                        (   g_strRoundPlayerData[i][team][plySIDamage] > g_strRoundPlayerData[highest][team][plySIDamage] ||
                                            ( g_strRoundPlayerData[i][team][plySIDamage] == g_strRoundPlayerData[highest][team][plySIDamage] && highest < FIRST_NON_BOT ) )
                            ) {
                                highest = i;
                            }
                        } else {
                            pickTeam = ( g_strRoundPlayerData[i][LTEAM_A][plyCommon] >= g_strRoundPlayerData[i][LTEAM_B][plyCommon] ) ? LTEAM_A : LTEAM_B;
                            if (    highest == -1 ||
                                    g_strRoundPlayerData[i][pickTeam][plyCommon] > g_strRoundPlayerData[highest][highTeam][plyCommon] ||
                                    g_strRoundPlayerData[i][pickTeam][plyCommon] == g_strRoundPlayerData[highest][highTeam][plyCommon] &&
                                        (   g_strRoundPlayerData[i][pickTeam][plySIDamage] > g_strRoundPlayerData[highest][highTeam][plySIDamage] ||
                                            ( g_strRoundPlayerData[i][pickTeam][plySIDamage] == g_strRoundPlayerData[highest][highTeam][plySIDamage] && highest < FIRST_NON_BOT ) )
                            ) {
                                highest = i;
                                g_iPlayerSortedUseTeam[sortCol][i] = pickTeam;
                                highTeam = pickTeam;
                            }
                        }
                    }
                    else {
                        if (    highest == -1 ||
                                g_strPlayerData[i][plyCommon] > g_strPlayerData[highest][plyCommon] ||
                                g_strPlayerData[i][plyCommon] == g_strPlayerData[highest][plyCommon] &&
                                    (   g_strPlayerData[i][plySIDamage] > g_strPlayerData[highest][plySIDamage] ||
                                        ( g_strPlayerData[i][plySIDamage] == g_strPlayerData[highest][plySIDamage] && highest < FIRST_NON_BOT ) )
                        ) {
                            highest = i;
                        }
                    }
                }
                case SORT_FF:
                {
                    if ( bRound ) {
                        if ( bTeam ) {
                            if (    highest == -1 ||
                                    g_strRoundPlayerData[i][team][plyFFGiven] > g_strRoundPlayerData[highest][team][plyFFGiven]
                            ) {
                                highest = i;
                            }
                        } else {
                            pickTeam = ( g_strRoundPlayerData[i][LTEAM_A][plyFFGiven] >= g_strRoundPlayerData[i][LTEAM_B][plyFFGiven] ) ? LTEAM_A : LTEAM_B;
                            if (    highest == -1 ||
                                    g_strRoundPlayerData[i][pickTeam][plyFFGiven] > g_strRoundPlayerData[highest][highTeam][plyFFGiven]
                            ) {
                                highest = i;
                                g_iPlayerSortedUseTeam[sortCol][i] = pickTeam;
                                highTeam = pickTeam;
                            }
                        }
                        
                    }
                    else {
                        if (    highest == -1 ||
                                g_strPlayerData[i][plyFFGiven] > g_strPlayerData[highest][plyFFGiven]
                        ) {
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

// return the player index for the player with the highest value for a given prop
stock GetPlayerWithHighestValue ( property, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    new i, highest, highTeam, pickTeam;
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1) : g_iCurTeam );
    
    highest = -1;
    
    for ( i = 0; i < g_iPlayers; i++ )
    {
        // if the index is the highest, take it
        if ( bRound ) {
            if ( bTeam ) {
                if ( highest == -1 || g_strRoundPlayerData[i][team][property] > g_strRoundPlayerData[highest][team][property] ) {
                    highest = i;
                }
            }
            else {
                pickTeam = ( g_strRoundPlayerData[i][LTEAM_A][property] >= g_strRoundPlayerData[i][LTEAM_B][property] ) ? LTEAM_A : LTEAM_B;
                if ( highest == -1 || g_strRoundPlayerData[i][pickTeam][property] > g_strRoundPlayerData[highest][highTeam][property] ) {
                    highest = i;
                    highTeam = pickTeam;
                }
            }
        }
        else {
            if ( highest == -1 || g_strPlayerData[i][property] > g_strPlayerData[highest][property] ) {
                highest = i;
            }
        }
    }
    
    return highest;
}
stock TableIncludePlayer ( index, team, bool:bRound = true, statA = plySIDamage, statB = plyCommon )
{
    // not on team at all: don't show
    if ( g_iPlayerRoundTeam[team][index] != team ) { return false; }
    
    // if on team right now, always show (or was last round?)
    if ( g_bPlayersLeftStart ) {
        if ( team == g_iCurTeam && g_iPlayerRoundTeam[LTEAM_CURRENT][index] == team ) { return true; }
    } else {
        // just allow it if he is currently a survivor
        if ( !IsIndexSurvivor(index) ) {
            if ( team == g_iCurTeam ) { return false; }
        } else { 
            if ( team != g_iCurTeam ) { return false; }
        }
    }
    
    // has positive relevant scores? show
    if ( bRound ) {
        if ( g_strRoundPlayerData[index][team][statA] || g_strRoundPlayerData[index][team][statB] ) { return true; }
    } else {
        if ( g_strPlayerData[index][statA] || g_strPlayerData[index][statB] ) { return true; }
    }
    
    // this point, any bot should not be shown
    if ( index < FIRST_NON_BOT ) { return false; }
    
    // been on the team for longer than X seconds? show
    new presTime = 0;
    new time = GetTime();
    if ( bRound ) {
        presTime = ( (g_strRoundPlayerData[index][team][plyTimeStopPresent]) ? g_strRoundPlayerData[index][team][plyTimeStopPresent] : time ) - g_strRoundPlayerData[index][team][plyTimeStartPresent];
    } else {
        presTime = ( (g_strPlayerData[index][plyTimeStopPresent]) ? g_strPlayerData[index][plyTimeStopPresent] : time ) - g_strPlayerData[index][plyTimeStartPresent];
    }
    if ( presTime >= MIN_TEAM_PRESENT_TIME ) { return true; }
    
    return false;
}

// get full, tank or pause time for this round, taking into account the time for a current/ongoing pause
stock GetFullRoundTime( bRound, bTeam, team, bool:bTank = false, bool:bPause = false )
{
    new start = rndStartTime;
    new stop = rndEndTime;
    
    if ( bTank ) {
        start = rndStartTimeTank;
        stop = rndStopTimeTank;
    } else if ( bPause ) {
        start = rndStartTimePause;
        stop = rndStopTimePause;
    }
    
    // get full time of this round (or both roundhalves) / or game
    new fullTime = 0;
    new time = GetTime();
    
    if ( bRound ) {
        if ( bTeam ) {
            if ( g_strRoundData[g_iRound][team][start] ) {
                fullTime = ( (g_strRoundData[g_iRound][team][stop]) ? g_strRoundData[g_iRound][team][stop] : time ) - g_strRoundData[g_iRound][team][start];
                if ( g_bPaused && team == g_iCurTeam ) {
                    if ( bPause ) {
                        fullTime += time - g_iPauseStart;
                    }
                    else if ( !bTank || g_bTankInGame ) {
                        fullTime -= time - g_iPauseStart;
                    }
                }
            }
        } else {
            if ( g_strRoundData[g_iRound][LTEAM_A][start] ) {
                fullTime = ( (g_strRoundData[g_iRound][LTEAM_A][stop]) ? g_strRoundData[g_iRound][LTEAM_A][stop] : time ) - g_strRoundData[g_iRound][LTEAM_A][start];
                if ( g_bPaused && LTEAM_A == g_iCurTeam ) {
                    if ( bPause ) {
                        fullTime += time - g_iPauseStart;
                    }
                    else if ( !bTank || g_bTankInGame ) {
                        fullTime -= time - g_iPauseStart;
                    }
                }
            }
            if ( g_strRoundData[g_iRound][LTEAM_B][start] ) {
                fullTime += ( (g_strRoundData[g_iRound][LTEAM_B][stop]) ? g_strRoundData[g_iRound][LTEAM_B][stop] : time ) - g_strRoundData[g_iRound][LTEAM_B][start];
                if ( g_bPaused && LTEAM_B == g_iCurTeam ) {
                    if ( bPause ) {
                        fullTime += time - g_iPauseStart;
                    }
                    else if ( !bTank || g_bTankInGame ) {
                        fullTime -= time - g_iPauseStart;
                    }
                }
            }
        }
    } else {
        if ( bTeam ) {
            if ( g_strAllRoundData[team][start] ) {
                fullTime = ( (g_strAllRoundData[team][stop]) ? g_strAllRoundData[team][stop] : time ) - g_strAllRoundData[team][start];
                if ( g_bPaused && team == g_iCurTeam ) {
                    if ( bPause ) {
                        fullTime += time - g_iPauseStart;
                    }
                    else if ( !bTank || g_bTankInGame ) {
                        fullTime -= time - g_iPauseStart;
                    }
                }
            }
        } else {
            if ( g_strAllRoundData[LTEAM_A][start] ) {
                fullTime = ( (g_strAllRoundData[LTEAM_A][stop]) ? g_strAllRoundData[LTEAM_A][stop] : time ) - g_strAllRoundData[LTEAM_A][start];
                if ( g_bPaused && LTEAM_A == g_iCurTeam ) {
                    if ( bPause ) {
                        fullTime += time - g_iPauseStart;
                    }
                    else if ( !bTank || g_bTankInGame ) {
                        fullTime -= time - g_iPauseStart;
                    }
                }
            }
            if ( g_strAllRoundData[LTEAM_B][start] ) {
                fullTime += ( (g_strAllRoundData[LTEAM_B][stop]) ? g_strAllRoundData[LTEAM_B][stop] : time ) - g_strAllRoundData[LTEAM_B][start];
                if ( g_bPaused && LTEAM_B == g_iCurTeam ) {
                    if ( bPause ) {
                        fullTime += time - g_iPauseStart;
                    }
                    else if ( !bTank || g_bTankInGame ) {
                        fullTime -= time - g_iPauseStart;
                    }
                }
            }
        }
    }
    
    return fullTime;
}

/*
    Automatic display
    -----------------
*/
stock AutomaticRoundEndPrint ( bool:doDelay = true )
{
    // remember that we printed it this second
    g_iLastRoundEndPrint = GetTime();
    
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
    new iFlags = GetConVarInt( ( g_bModeCampaign ) ? g_hCvarAutoPrintCoop : g_hCvarAutoPrintVs );
    
    // do automatic prints (only for clients that don't have cookie flags set)
    AutomaticPrintPerClient( iFlags, -1 );

    // for each client that has a cookie set, do the relevant reports
    for ( new client = 1; client <= MaxClients; client++ )
    {
        if ( g_iCookieValue[client] > 0 )
        {
            AutomaticPrintPerClient( g_iCookieValue[client], client );
        }
    }
}

stock AutomaticPrintPerClient( iFlags, client = -1, iTeam = -1 )
{
    // prints automatic stuff, optionally for one client only
    
    new bool: bSorted = (iFlags & AUTO_MVPCON_ROUND) || (iFlags & AUTO_MVPCON_GAME) || (iFlags & AUTO_MVPCON_TANK) || (iFlags & AUTO_MVPCON_MORE_ROUND);
    new bool: bSortedForGame = false;
    
    new bool: bTeam = bool:( iTeam != -1 );
    
    // mvp
    if ( iFlags & AUTO_MVPCON_ROUND ) {
        DisplayStatsMVP(client, false, false, true, bTeam, iTeam );
    }
    if ( iFlags & AUTO_MVPCON_GAME ) {
        DisplayStatsMVP(client, false, false, false, bTeam, iTeam );
        bSortedForGame = true;
    }
    if ( iFlags & AUTO_MVPCON_MORE_ROUND ) {
        DisplayStatsMVP(client, false, true, true, bTeam, iTeam );
    }
    if ( iFlags & AUTO_MVPCON_MORE_GAME ) {
        DisplayStatsMVP(client, false, true, false, bTeam, iTeam );
        bSortedForGame = true;
    }
    
    if ( iFlags & AUTO_MVPCON_TANK ) {
        DisplayStatsMVP(client, true, false, true, bTeam, iTeam );
    }
    
    if ( iFlags & AUTO_MVPCHAT_ROUND ) {
        if ( !bSorted || bSortedForGame ) {
            // not sorted yet, sort for SI [round]
            SortPlayersMVP( true, SORT_SI );
            bSorted = true;
        }
        DisplayStatsMVPChat(client, true);
    }
    if ( iFlags & AUTO_MVPCHAT_GAME ) {
        if ( !bSorted || !bSortedForGame ) {
            // not sorted yet, sort for SI
            bSortedForGame = true;
            SortPlayersMVP( false, SORT_SI );
            bSorted = true;
        }
        DisplayStatsMVPChat(client, false);
    }
    
    // fun fact
    if ( iFlags & AUTO_FUNFACT_ROUND ) {
        DisplayStatsFunFactChat( client, true, false );
    }
    if ( iFlags & AUTO_FUNFACT_GAME ) {
        DisplayStatsFunFactChat( client, false, false );
    }
    
    // special / skill
    if ( iFlags & AUTO_SKILLCON_ROUND ) {
        DisplayStatsSpecial(client, true, bTeam, false, iTeam );
    }
    if ( iFlags & AUTO_SKILLCON_GAME ) {
        DisplayStatsSpecial(client, false, bTeam, false, iTeam );
    }
    
    // ff
    if ( iFlags & AUTO_FFCON_ROUND ) {
        DisplayStatsFriendlyFire(client, true, bTeam, (bSorted && !bSortedForGame), iTeam );
    }
    if ( iFlags & AUTO_FFCON_GAME ) {
        DisplayStatsFriendlyFire(client, false, bTeam, (bSorted && bSortedForGame), iTeam );
    }
    
    // accuracy
    if ( iFlags & AUTO_ACCCON_ROUND ) {
        DisplayStatsAccuracy(client, false, true, bTeam, (bSorted && !bSortedForGame), iTeam );
    }
    if ( iFlags & AUTO_ACCCON_GAME ) {
        DisplayStatsAccuracy(client, false, false, bTeam, (bSorted && bSortedForGame), iTeam );
    }
    if ( iFlags & AUTO_ACCCON_MORE_ROUND ) {
        DisplayStatsAccuracy(client, true, true, bTeam, (bSorted && !bSortedForGame), iTeam );
    }
    if ( iFlags & AUTO_ACCCON_MORE_GAME ) {
        DisplayStatsAccuracy(client, true, false, bTeam, (bSorted && bSortedForGame), iTeam );
    }
    
    // to do:
    // - inf
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

// if not found, stores the steamid for a new index, stores the name and safe name too
stock GetPlayerIndexForSteamId ( const String:steamId[], client=-1 )
{
    new pIndex = -1;
    
    if ( !GetTrieValue( g_hTriePlayers, steamId, pIndex ) )
    {
        // add it
        pIndex = g_iPlayers;
        SetTrieValue( g_hTriePlayers, steamId, pIndex );
        
        // store steam id
        strcopy( g_sPlayerId[pIndex], 32, steamId );
        
        // store name
        if ( client != -1 ) {
            GetClientName( client, g_sPlayerName[pIndex], MAXNAME );
            strcopy( g_sPlayerNameSafe[pIndex], MAXNAME_TABLE, g_sPlayerName[pIndex] );
            stripUnicode( g_sPlayerNameSafe[pIndex], MAXNAME_TABLE );
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


stock IsIndexSurvivor ( index )
{
    new tmpind;
    for ( new client = 1; client <= MaxClients; client++ )
    {
        if ( !IS_VALID_SURVIVOR(client) ) { continue; }
        
        tmpind = GetPlayerIndexForClient( client );
        if ( tmpind == index ) { return true; }
    }
    
    return false;
}
stock bool: IsClientAndInGame ( index )
{
    if (index > 0 && index <= MaxClients)
    {
        return IsClientInGame(index);
    }
    return false;
}
stock bool: IsWitch ( iEntity )
{
    if ( iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity) )
    {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        new strOEC: entType;
        
        if ( !GetTrieValue(g_hTrieEntityCreated, strClassName, entType) ) { return false; }
        
        return bool:(entType == OEC_WITCH);
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
stock bool: IsHangingFromLedge ( client )
{
    return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}
stock bool: IsPlayerIncapacitatedAtAll ( client )
{
    return bool: ( IsPlayerIncapacitated(client) || IsHangingFromLedge(client) );
}

stock bool: AreClientsConnected()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if ( IS_VALID_INGAME(i) && !IsFakeClient(i) ) { return true; }
    }
    return false;
}
stock GetUprightSurvivors()
{
    new count = 0;
    new incapcount = 0;
    
    for ( new client = 1; client <= MaxClients; client++ )
    {
        if ( IS_VALID_SURVIVOR(client) && IsPlayerAlive(client) )
        {
            if ( IsPlayerIncapacitatedAtAll(client) ) {
                incapcount++;
            } else {
                count++;
            }
        }
    }
    
    // if incapped in saferoom with upright survivors, counts as survival
    if ( count ) { count += incapcount; }
    
    return count;
}

/*
    File / DB writing
    -----------------
*/
// delayed so roundscores can be trusted
public Action: Timer_WriteStats ( Handle:timer, any:iTeam )
{
    WriteStatsToFile( iTeam, true );
}
// write round stats to a text file
stock WriteStatsToFile( iTeam, bool:bSecondHalf )
{
    if ( g_bModeCampaign ) { return; }
    
    new i, j;
    new bool: bFirstWrite;
    new String: sStats[MAX_QUERY_SIZE];
    new String: strTmpLine[512];
    decl String: sTmpTime[20];
    decl String: sTmpRoundNo[6];
    decl String: sTmpMap[64];
    
    // filename: <dir/> <date>_<time>_<roundno>_<mapname>.txt
    new String: path[128];
    
    // create the file
    if ( g_bModeCampaign || !bSecondHalf || !strlen(g_sStatsFile) )
    {
        bFirstWrite = true;
        
        FormatTime( sTmpTime, sizeof(sTmpTime), "%Y-%m-%d_%H-%M" );
        IntToString( g_iRound, sTmpRoundNo, sizeof(sTmpRoundNo) );
        LeftPadString( sTmpRoundNo, sizeof(sTmpRoundNo), 4, true );
        GetCurrentMap( sTmpMap, sizeof(sTmpMap) );
        
        FormatEx( g_sStatsFile, sizeof(g_sStatsFile), "%s_%s_%s.txt", sTmpTime, sTmpRoundNo, sTmpMap );
    }
    
    // add directory to filename
    FormatEx( path, sizeof(path), "%s%s", DIR_OUTPUT, g_sStatsFile );
    BuildPath( Path_SM, path, PLATFORM_MAX_PATH, path );
    
    
    // build stats content
    if ( bFirstWrite )
    {
        FormatEx( strTmpLine, sizeof(strTmpLine), "[Gameround:%i]\n", g_iRound );
        StrCat( sStats, sizeof(sStats), strTmpLine );
        
        FormatTime( sTmpTime, sizeof(sTmpTime), "%Y-%m-%d;%H:%M" );
        FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%s;%i;%s;%s;\n\n",
                g_iRound,
                sTmpTime,
                g_iTeamSize,
                g_sConfigName,
                sTmpMap
            );
        StrCat( sStats, sizeof(sStats), strTmpLine );
    }
    
    
    
    // round data
    FormatEx( strTmpLine, sizeof(strTmpLine), "[RoundHalf:%i]\n", bSecondHalf );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    // round lines, ";"-delimited: <roundhalf>;<team (A/B)>;<rndStat0>;<etc>;\n
    FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%s;", bSecondHalf, (iTeam == LTEAM_A) ? "A" : "B" );
    for ( i = 0; i <= MAXRNDSTATS; i++ )
    {
        Format( strTmpLine, sizeof(strTmpLine), "%s%i;", strTmpLine, g_strRoundData[g_iRound][iTeam][i] );
    }
    Format( strTmpLine, sizeof(strTmpLine), "%s\n\n", strTmpLine );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    
    
    // progress data
    new Float: maxFlowDist = L4D2Direct_GetMapMaxFlowDistance();
    new Float: curFlowDist[MAXPLAYERS+1];
    new Float: farFlowDist[MAXPLAYERS+1];
    new clients = 0;
    for ( i = 1; i <= MaxClients; i++ )
    {
        if ( !IS_VALID_SURVIVOR(i) ) { continue; }
        
        farFlowDist[clients] = 0.0;                                 //GetEntPropFloat( i, Prop_Data, "m_farthestSurvivorFlowAtDeath" );     // this doesn't work/exist
        curFlowDist[clients] = L4D2Direct_GetFlowDistance( i );
        clients++;
    }
    
    FormatEx( strTmpLine, sizeof(strTmpLine), "[Progress:%s]\n", (iTeam == LTEAM_A) ? "A" : "B" );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%s;%i;%.2f;",
            g_bSecondHalf,
            (iTeam == LTEAM_A) ? "A" : "B",
            g_iSurvived[iTeam],
            maxFlowDist
        );
    
    for ( i = 0; i < clients; i++ )
    {
        Format( strTmpLine, sizeof(strTmpLine), "%s%.2f;%.f2;", strTmpLine, farFlowDist[i], curFlowDist[i] );
    }
    Format( strTmpLine, sizeof(strTmpLine), "%s\n\n", strTmpLine );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    
    // player data
    FormatEx( strTmpLine, sizeof(strTmpLine), "[Players:%s]:\n", (iTeam == LTEAM_A) ? "A" : "B" );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    new iPlayerCount;
    for ( j = 0; j < MAXTRACKED; j++ )
    {
        if ( g_iPlayerRoundTeam[iTeam][j] != iTeam ) { continue; }
        iPlayerCount++;
        
        // player lines, ";"-delimited: <#>;<index>;<steamid>;<plyStat0>;<etc>;\n
        FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%i;%s;", iPlayerCount, j, g_sPlayerId[j] );
        for ( i = 0; i <= MAXPLYSTATS; i++ )
        {
            Format( strTmpLine, sizeof(strTmpLine), "%s%i;", strTmpLine, g_strRoundPlayerData[j][iTeam][i] );
        }
        Format( strTmpLine, sizeof(strTmpLine), "%s\n", strTmpLine );
        StrCat( sStats, sizeof(sStats), strTmpLine );
    }
    StrCat( sStats, sizeof(sStats), "\n" );
    
    // scores (both rounds)
    if ( !bFirstWrite )
    {
        FormatEx( strTmpLine, sizeof(strTmpLine), "[Scoring:]\n" );
        StrCat( sStats, sizeof(sStats), strTmpLine );

        FormatEx( strTmpLine, sizeof(strTmpLine), "A;%i;%i;B;%i;%i;\n\n",
                g_iScores[LTEAM_A] - g_iOldScores[LTEAM_A],
                g_iScores[LTEAM_A],
                g_iScores[LTEAM_B] - g_iOldScores[LTEAM_B],
                g_iScores[LTEAM_B]
            );
        StrCat( sStats, sizeof(sStats), strTmpLine );
    }
    
    
    // write to file
    new Handle: fh = OpenFile( path, "a" );
    
    if (fh == INVALID_HANDLE) {
        PrintDebug(0, "Error: could not write to file: '%s'.", path);
        return;
    }
    WriteFileString( fh, sStats, false );
    CloseHandle(fh);
    
    // write pretty tables?
    if ( GetConVarInt(g_hCvarWriteStats) > 1 )
    {
        g_hStatsFile = OpenFile( path, "a" );
        if (g_hStatsFile == INVALID_HANDLE) {
            PrintDebug(0, "Error [table printing]: could not write to file: '%s'.", path);
            return;
        }
        
        // -2 = print to file (if open)
        AutomaticPrintPerClient( FILETABLEFLAGS, -2, iTeam );
        
        CloseHandle(g_hStatsFile);
    }
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
    g_sPlayerId[0] = "BOT_0";
    g_sPlayerId[1] = "BOT_1";
    g_sPlayerId[2] = "BOT_2";
    g_sPlayerId[3] = "BOT_3";
    g_iPlayers += FIRST_NON_BOT;
    
    for ( new i = 0; i < 4; i++ ) {
        g_sPlayerNameSafe[i] = g_sPlayerName[i];
    }
    
    // weapon recognition
    g_hTrieWeapons = CreateTrie();
    SetTrieValue(g_hTrieWeapons, "weapon_pistol",               WPTYPE_PISTOL);
    SetTrieValue(g_hTrieWeapons, "weapon_pistol_magnum",        WPTYPE_PISTOL);
    SetTrieValue(g_hTrieWeapons, "weapon_pumpshotgun",          WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_shotgun_chrome",       WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_autoshotgun",          WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_shotgun_spas",         WPTYPE_SHOTGUN);
    SetTrieValue(g_hTrieWeapons, "weapon_hunting_rifle",        WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_sniper_military",      WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_sniper_awp",           WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_sniper_scout",         WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "weapon_smg",                  WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_smg_silenced",         WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle",                WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_desert",         WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_ak47",           WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_smg_mp5",              WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_sg552",          WPTYPE_SMG);
    SetTrieValue(g_hTrieWeapons, "weapon_rifle_m60",            WPTYPE_SMG);
    //SetTrieValue(g_hTrieWeapons, "weapon_melee",               WPTYPE_NONE);
    //SetTrieValue(g_hTrieWeapons, "weapon_chainsaw",            WPTYPE_NONE);
    //SetTrieValue(g_hTrieWeapons, "weapon_grenade_launcher",    WP_NONE);
    
    g_hTrieEntityCreated = CreateTrie();
    SetTrieValue(g_hTrieEntityCreated, "infected",              OEC_INFECTED);
    SetTrieValue(g_hTrieEntityCreated, "witch",                 OEC_WITCH);
}
/*
    General functions
    -----------------
*/

stock LeftPadString ( String:text[], maxlength, cutOff = 20, bool:bNumber = false )
{
    new String: tmp[maxlength];
    new safe = 0;   // just to make sure we're never stuck in an eternal loop
    
    strcopy( tmp, maxlength, text );
    
    if ( !bNumber ) {
        while ( strlen(tmp) < cutOff && safe < 1000 )
        {
            Format( tmp, maxlength, " %s", tmp );
            safe++;
        }
    }
    else {
        while ( strlen(tmp) < cutOff && safe < 1000 )
        {
            Format( tmp, maxlength, "0%s", tmp );
            safe++;
        }
    }
    
    strcopy( text, maxlength, tmp );
}

stock RightPadString ( String:text[], maxlength, cutOff = 20 )
{
    new String: tmp[maxlength];
    new safe = 0;   // just to make sure we're never stuck in an eternal loop
    
    strcopy( tmp, maxlength, text );
    
    while ( strlen(tmp) < cutOff && safe < 1000 )
    {
        Format( tmp, maxlength, "%s ", tmp );
        safe++;
    }
    
    strcopy( text, maxlength, tmp );
}


stock FormatTimeAsDuration ( String:text[], maxlength, time, bool:bPad = true )
{
    new String: tmp[maxlength];
    
    if ( time < 1 ) { 
        Format( text, maxlength, "" );
        return;
    }
    
    if ( time > 3600 )
    {
        new tmpHr = RoundToFloor( float(time) / 3600.0 );
        Format( tmp, maxlength, "%ih", tmpHr );
        time -= (tmpHr * 3600);
    }
    
    if ( time > 60 )
    {
        if ( strlen( tmp ) ) {
            Format( tmp, maxlength, "%s ", tmp );
        }
        new tmpMin = RoundToFloor( float(time) / 60.0 );
        Format( tmp, maxlength, "%s%im",
                ( bPad && tmpMin < 10 ) ? " " : "" ,
                tmpMin
            );
        time -= (tmpMin * 60);
    }
    
    if ( time )
    {
        Format( tmp, maxlength, "%s%s%s%is",
                tmp,
                strlen( tmp ) ? " " : "",
                ( bPad && time < 10 ) ? " " : "",
                time
            );
    }
    
    strcopy( text, maxlength, tmp );
}

stock FormatPercentage ( String:text[], maxlength, part, whole, bool: bDecimal = false )
{
    new String: strTmp[maxlength];
    
    if ( !whole || !part )
    {
        FormatEx( strTmp, maxlength, "" );
        strcopy( text, maxlength, strTmp );
        return;
    }
    
    if ( bDecimal )
    {
        new Float: fValue = float( part ) / float( whole ) * 100.0;
        FormatEx( strTmp, maxlength, "%3.1f", fValue );
    }
    else
    {
        new iValue = RoundFloat( float( part ) / float( whole ) * 100.0 );
        FormatEx( strTmp, maxlength, "%i", iValue );
    }
    
    strcopy( text, maxlength, strTmp );
}
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
    if ( maxLength < 1 ) { maxLength = MAXNAME; }
    
    decl String: tmpString[maxLength];
    strcopy( tmpString, maxLength, testString );
    
    new uni=0;
    new currentChar;
    new tmpCharLength = 0;
    
    for ( new i = 0; i < maxLength && tmpString[i] != 0; i++ )
    {
        // estimate current character value
        if ( (tmpString[i]&0x80) == 0 ) 
        {
            // single byte character?
            currentChar = tmpString[i]; tmpCharLength = 0;
        }
        else if ( i < maxLength - 1 && ((tmpString[i]&0xE0) == 0xC0) && ((tmpString[i+1]&0xC0) == 0x80) ) 
        {
            // two byte character?
            currentChar=(tmpString[i++] & 0x1f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i] & 0x3f); 
            tmpCharLength = 1;
        }
        else if ( i < maxLength - 2 && ((tmpString[i]&0xF0) == 0xE0) && ((tmpString[i+1]&0xC0) == 0x80) && ((tmpString[i+2]&0xC0) == 0x80) )
        {
            // three byte character?
            currentChar=(tmpString[i++] & 0x0f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i] & 0x3f);
            tmpCharLength = 2;
        }
        else if ( i < maxLength - 3 && ((tmpString[i]&0xF8) == 0xF0) && ((tmpString[i+1]&0xC0) == 0x80) && ((tmpString[i+2]&0xC0) == 0x80) && ((tmpString[i+3]&0xC0) == 0x80) )
        {
            // four byte character?
            currentChar=(tmpString[i++] & 0x07); currentChar=currentChar<<6;
            currentChar+=(tmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i] & 0x3f);
            tmpCharLength = 3;
        }
        else 
        {
            currentChar = CHARTHRESHOLD + 1; // reaching this may be caused by bug in sourcemod or some kind of bug using by the user - for unicode users I do assume last ...
            tmpCharLength = 0;
        }
        
        // decide if character is allowed
        if (currentChar > CHARTHRESHOLD)
        {
            uni++;
            // replace this character
            // 95 = _, 32 = space
            for ( new j = tmpCharLength; j >= 0; j-- )
            {
                tmpString[i - j] = 95; 
            }
        }
    }
    
    if ( strlen(tmpString) > maxLength )
    {
        tmpString[maxLength] = 0;
    }
    
    strcopy( testString, maxLength, tmpString );
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

