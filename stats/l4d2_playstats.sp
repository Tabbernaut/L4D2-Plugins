#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>
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

#define MAXNAME                 64
#define MAXCHARACTERS           4
#define MAXMAP                  32
#define MAXGAME                 24

#define STATS_RESET_DELAY       5.0
#define ROUNDSTART_DELAY        3.0
#define ROUNDEND_DELAY          3.0
#define ROUNDEND_DELAY_SCAV     2.0
#define PRINT_REPEAT_DELAY      15              // how many seconds to wait before re-doing automatic round end prints (opening/closing end door, etc)

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
    typInf,
    typFact
};

// information for entire game
enum _:strGameData
{
            gmFailed,               // survivors lost the mission * times
            gmStartTime,            // GetTime() value when starting
            gmFFDamageTotalA,
            gmFFDamageTotalB
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
            rndSISpawned,
            rndWitchKilled,
            rndTankKilled,
            rndIncaps,
            rndDeaths,              // 10
            rndFFDamageTotal,
            rndStartTime,           // GetTime() value when starting    
            rndEndTime              // GetTime() value when done
};
#define MAXRNDSTATS                 13

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
new     Handle: g_hCvarShowBots         = INVALID_HANDLE;

new     bool:   g_bGameStarted          = false;
new     bool:   g_bInRound              = false;
new     bool:   g_bTeamChanged          = false;                                        // to only do a teamcheck if a check is not already pending
new     bool:   g_bTankInGame           = false;
new     bool:   g_bPlayersLeftStart     = false;
new     bool:   g_bSecondHalf           = false;                                        // second roundhalf in a versus round
new             g_iRound                = 0;
new             g_iCurTeam              = LTEAM_A;                                      // current logical team
new             g_iTeamSize             = 4;
new             g_iLastRoundEndPrint    = 0;                                            // when the last automatic print was shown

new             g_iPlayerIndexSorted    [MAXSORTS][MAXTRACKED];                         // used to create a sorted list
new             g_iPlayerSortedUseTeam  [MAXSORTS][MAXTRACKED];                         // after sorting: which team to use as the survivor team for player
new             g_iPlayerRoundTeam      [3][MAXTRACKED];                                // which team is the player 0 = A, 1 = B, -1 = no team; [2] = current survivor round; [0]/[1] = team A / B (anyone who was ever on it)

new             g_strGameData           [strGameData];
new             g_strRoundData          [MAXROUNDS][2][strRoundData];                   // rounddata per game round, per team
new             g_strPlayerData         [MAXTRACKED][strPlayerData];
new             g_strRoundPlayerData    [MAXTRACKED][2][strPlayerData];                 // player data per team

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

new     String: g_sConsoleBuf           [MAXCHUNKS][CONBUFSIZELARGE];
new             g_iConsoleBufChunks                                 = 0;
new     bool:   g_bLastLineDivider                                  = false;

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

        fixes:
        ------
        - better 'team' checks (in list-building)
            - rule: don't include anyone who was in the team less than X time with 0 stats,
                or NOT at end and with 0 stats
        
        - garbage print on automated?
        
        
        build:
        ------
        - proper general stats tables
            - better rounds display (max 3 or so)
        
        - make confogl loading not cause round 1 to count...
            - if there were no stats, or the round was never started,
                survivors never left, or time was too short, reset it
            - listen to !forcematch / !match command and map restart after?
            
        - automatic reports
            - add client-side override
        
        - survivor
            - show time active (live round, per team) [show in mvp?]

        - skill
            - clears / instaclears / average clear time

        - make infected skills table
                dps (hunter / jockey),
                dc's,
                damage done (to HB/DB?)
        
        later:
        ------
        - add duration of tank fight(s)
        - write CSV files per round -- db-ready
        - fix: some way of 'listening' to CMT?
        - time fixes:
            - after round ends: add up times to strPlayerData[]
            - coop:
                player_bot_replace
                    short 	player 	user ID of the player
                    short 	bot 	user ID of the bot
                bot_player_replace
                    short 	bot 	user ID of the bot
                    short 	player 	user ID of the player
                player_afk
                    short 	player 	user ID of the player 
        
    details:
    --------
        - sort by common after si damage for Mvp
        - if divider line is last line, replace with table end line..
        - bots should always go at bottom (on equal scores)
        - cvar for % detail (1 decimal or no decimal option)
        - hide 0 and 0.0% values from tables
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
    HookEvent("player_ledge_grab",          Event_PlayerLedged,             EventHookMode_Post);
    HookEvent("player_ledge_release",       Event_PlayerLedgeRelease,       EventHookMode_Post);
    
    HookEvent("revive_success",             Event_PlayerRevived,            EventHookMode_Post);
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
            "133",                                      // default = 1 (mvpchat) + 4 (mvpcon-round) + 128 (special round) = 133
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
        
    g_iTeamSize = 4;
    
    
    // commands:
    RegConsoleCmd( "sm_stats",      Cmd_StatsDisplayGeneral,    "Prints stats for survivors" );
    RegConsoleCmd( "sm_mvp",        Cmd_StatsDisplayGeneral,    "Prints MVP stats for survivors" );
    RegConsoleCmd( "sm_skill",      Cmd_StatsDisplayGeneral,    "Prints special skills stats for survivors" );
    RegConsoleCmd( "sm_ff",         Cmd_StatsDisplayGeneral,    "Prints friendly fire stats stats" );
    RegConsoleCmd( "sm_acc",        Cmd_StatsDisplayGeneral,    "Prints accuracy stats for survivors" );
    
    RegAdminCmd(   "statsreset",    Cmd_StatsReset, ADMFLAG_CHANGEMAP, "Resets the statistics. Admins only." );
    
    RegConsoleCmd( "say",           Cmd_Say );
    RegConsoleCmd( "say_team",      Cmd_Say );
    
    // tries
    InitTries();
    
    // prepare team array
    ClearPlayerTeam();
    
    if ( g_bLateLoad )
    {
        for ( new i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) && !IsFakeClient(i) )
            {
                // store each player with a first check
                GetPlayerIndexForClient( i );
            }
        }
        
        // just assume this
        g_bInRound = true;
        g_bPlayersLeftStart = true;
        
        // team
        g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
        UpdatePlayerCurrentTeam();
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
}

public OnClientDisconnected( client )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    // only note time for survivor team players
    if ( g_iPlayerRoundTeam[LTEAM_CURRENT][index] != g_iCurTeam ) { return; }
    
    // store time they left
    new time = GetTime();
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
}

public OnMapEnd()
{
    //PrintDebug(2, "MapEnd (round %i)", g_iRound);
    g_bInRound = false;
    g_bSecondHalf = false;
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
    g_bPlayersLeftStart = false;
    
    CreateTimer( ROUNDSTART_DELAY, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE );
}

// delayed, so we can trust GetCurrentTeamSurvivor()
public Action: Timer_RoundStart ( Handle:timer )
{
    // easier to handle: store current survivor team
    g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
    
    // clear team for stats
    ClearPlayerTeam( g_iCurTeam );
    
    // reset stats for this round
    CreateTimer( STATS_RESET_DELAY, Timer_ResetStats, 1, TIMER_FLAG_NO_MAPCHANGE );
    
    //PrintDebug( 2, "Event_RoundStart (roundhalf: %i: survivor team: %i (cur survivor: %i))", (g_bSecondHalf) ? 1 : 0, g_iCurTeam, GetCurrentTeamSurvivor() );
}

public Event_RoundEnd (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // called on versus round end
    // and mission failed coop
    
    if ( g_iLastRoundEndPrint == 0 || GetTime() - g_iLastRoundEndPrint > PRINT_REPEAT_DELAY )
    {
        AutomaticRoundEndPrint( false );
    }
    
    g_bInRound = false;
    g_bSecondHalf = true;
    g_bPlayersLeftStart = false;
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
    if ( g_bModeCampaign )
    {
        g_bInRound = false;
        AutomaticRoundEndPrint(false);  // no delay for this one
    }
}
public Event_FinaleWin (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    // campaign (ignore in versus)
    if ( g_bModeCampaign ) {
        g_bInRound = false;
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
        SetStartSurvivorTime(true);
    }
    
    if ( g_strRoundData[g_iRound][g_iCurTeam][rndRestarts] == 0 )
    {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] = GetTime();
    }
    
    //PrintDebug( 2, "RoundReallyStarting (round %i: roundhalf: %i: survivor team: %i)", g_iRound, (g_bSecondHalf) ? 1 : 0, g_iCurTeam );
    
    // make sure the teams are still what we think they are
    UpdatePlayerCurrentTeam();
    SetStartSurvivorTime();
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
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'other' ('o')                : for the other team (that is now infected)   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'tank'          [ MVP only ] : show stats for tank fight                   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   'more'          [ ACC only ] : show accuracy stats: headshots and SI hits  |\n", bufBasic);
            if ( IS_VALID_INGAME(client) ) { PrintToConsole( client, bufBasic); } else { PrintToServer( bufBasic); }
            
            Format(bufBasic, CONBUFSIZELARGE,    "|------------------------------------------------------------------------------|\n");
            Format(bufBasic, CONBUFSIZELARGE,  "%s| examples:                                                                    |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|------------------------------------------------------------------------------|\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats skill round all' => shows skeets etc for all players, this round   |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats ff team game'    => shows friendly fire for your team, this round  |\n", bufBasic);
            Format(bufBasic, CONBUFSIZELARGE,  "%s|   '/stats acc'             => shows accuracy stats (your team, this round)   |\n", bufBasic);
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
            //  the first -1 == round number (may think about allowing a number input here later)
            DisplayStats( client, ( bSetRound && bRound ) ? true : false, -1, ( bSetAll && bAll ) ? false : true, (bOther) ? otherTeam : -1  );
        }
        
        case typMVP:
        {
            // by default: only for round
            DisplayStatsMVP( client, bTank, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, (bOther) ? otherTeam : -1 );
            // only show chat for non-tank table
            if ( !bTank ) {
                DisplayStatsMVPChat( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, (bOther) ? otherTeam : -1 );
            }
        }
        
        case typFF:
        {
            // by default: only for round
            DisplayStatsFriendlyFire( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, false, (bOther) ? otherTeam : -1 );
        }
        
        case typSkill:
        {
            // by default: only for round
            DisplayStatsSpecial( client, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, false, (bOther) ? otherTeam : -1 );
        }
        
        case typAcc:
        {
            // by default: only for round
            DisplayStatsAccuracy( client, bMore, ( bSetGame && bGame ) ? false : true, ( bSetAll && bAll ) ? false : true, false, (bOther) ? otherTeam : -1 );
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
    
    // only record survivor-to-survivor damage done by humans
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
                g_strPlayerData[attIndex][plySIDamageTankUp] += damage;
                g_strRoundPlayerData[attIndex][g_iCurTeam][plySIDamageTankUp] += damage;
            }
            
            g_strPlayerData[attIndex][plySIDamage] += damage;
            g_strRoundPlayerData[attIndex][g_iCurTeam][plySIDamage] += damage;
            g_iMVPSIDamageTotal[g_iCurTeam] += damage;
            g_iMVPRoundSIDamageTotal[g_iCurTeam] += damage;
        }
        else if ( zClass == ZC_TANK && damage != 5000) // For some reason the last attacker does 5k damage?
        {
            new type = GetEventInt(event, "type");
            
            if ( type & DMG_CLUB || type & DMG_SLASH )
            {
                g_strPlayerData[attIndex][plyMeleesOnTank]++;
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyMeleesOnTank]++;
            }
            
            g_strPlayerData[attIndex][plyTankDamage] += damage;
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyTankDamage] += damage;
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
        g_strRoundData[g_iRound][g_iCurTeam][rndFFDamageTotal] += damage;
        if (g_iCurTeam == LTEAM_A) { g_strGameData[gmFFDamageTotalA] += damage; } else { g_strGameData[gmFFDamageTotalB] += damage; }
        
        g_strPlayerData[attIndex][plyFFGivenTotal] += damage;
        g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenTotal] += damage;
        g_strPlayerData[vicIndex][plyFFTakenTotal] += damage;
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenTotal] += damage;
        
        if ( attIndex == vicIndex ) {
            // damage to self
        }
        else if ( IsPlayerIncapacitated(victim) )
        {
            // don't count incapped damage for 'ffgiven' / 'fftaken'
            g_strPlayerData[attIndex][plyFFGivenIncap] += damage;
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenIncap] += damage;
            g_strPlayerData[vicIndex][plyFFTakenIncap] += damage;
            g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenIncap] += damage;
        }
        else
        {
            g_strPlayerData[attIndex][plyFFGiven] += damage;           // only count non-incapped for this
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGiven] += damage;
            if ( attIndex != vicIndex ) {
                g_strPlayerData[vicIndex][plyFFTaken] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTaken] += damage;
            }
            
            // which type to save it to?
            if ( type & DMG_BURN )
            {
                g_strPlayerData[attIndex][plyFFGivenFire] += damage;
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenFire] += damage;
                g_strPlayerData[vicIndex][plyFFTakenFire] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenFire] += damage;
            }
            else if ( type & DMG_BUCKSHOT )
            {
                g_strPlayerData[attIndex][plyFFGivenPellet] += damage;
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenPellet] += damage;
                g_strPlayerData[vicIndex][plyFFTakenPellet] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenPellet] += damage;
            }
            else if ( type & DMG_CLUB || type & DMG_SLASH )
            {
                g_strPlayerData[attIndex][plyFFGivenMelee] += damage;
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenMelee] += damage;
                g_strPlayerData[vicIndex][plyFFTakenMelee] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenMelee] += damage;
            }
            else if ( type & DMG_BULLET )
            {
                g_strPlayerData[attIndex][plyFFGivenBullet] += damage;
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenBullet] += damage;
                g_strPlayerData[vicIndex][plyFFTakenBullet] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenBullet] += damage;
            }
            else
            {
                g_strPlayerData[attIndex][plyFFGivenOther] += damage;
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenOther] += damage;
                g_strPlayerData[vicIndex][plyFFTakenOther] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenOther] += damage;
            }
        }
        
    }
    else if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) )
    {
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return Plugin_Continue; }
        
        g_strPlayerData[vicIndex][plyDmgTaken] += damage;           // only count non-incapped for this
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
        
        g_strPlayerData[attIndex][plyWitchDamage] += damage;
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
    new index, attacker;
    
    if ( IS_VALID_SURVIVOR(client) )
    {
        // survivor died
        
        g_strRoundData[g_iRound][g_iCurTeam][rndDeaths]++;
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        g_strRoundPlayerData[index][g_iCurTeam][plyDied]++;
        g_strPlayerData[index][plyDied]++;
        
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
            g_strRoundData[g_iRound][g_iCurTeam][rndSIKilled]++;
            //g_iMVPCommonTotal[g_iCurTeam]++;
            //g_iMVPRoundCommonTotal[g_iCurTeam]++;
            
            attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
            
            if ( IS_VALID_SURVIVOR(attacker) )
            {
                index = GetPlayerIndexForClient( attacker );
                if ( index == -1 ) { return; }
                
                g_strRoundPlayerData[index][g_iCurTeam][plySIKilled]++;
                g_strPlayerData[index][plySIKilled]++;
                g_iMVPSIKilledTotal[g_iCurTeam]++;
                g_iMVPRoundSIKilledTotal[g_iCurTeam]++;
                
                if ( g_bTankInGame )
                { 
                    g_strRoundPlayerData[index][g_iCurTeam][plySIKilledTankUp]++;
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
            g_strRoundData[g_iRound][g_iCurTeam][rndCommon]++;
            g_iMVPCommonTotal[g_iCurTeam]++;
            g_iMVPRoundCommonTotal[g_iCurTeam]++;
            
            if ( IS_VALID_SURVIVOR(attacker) )
            {
                index = GetPlayerIndexForClient( attacker );
                if ( index == -1 ) { return; }
                
                g_strRoundPlayerData[index][g_iCurTeam][plyCommon]++;
                g_strPlayerData[index][plyCommon]++;
                
                if ( g_bTankInGame ) {
                    g_strRoundPlayerData[index][g_iCurTeam][plyCommonTankUp]++;
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
        
        g_strRoundPlayerData[index][g_iCurTeam][plyIncaps]++;
        g_strPlayerData[index][plyIncaps]++;
        
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
        
        if ( !IsPlayerIncapacitatedAtAll(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += GetTime() - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
        }
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
        
        if ( !IsPlayerIncapacitatedAtAll(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
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
    if ( !IS_VALID_SURVIVOR(client) || !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    new weaponId = GetEventInt(event, "weaponid");
    
    if ( weaponId == WP_PISTOL || weaponId == WP_PISTOL_MAGNUM )
    {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsPistol]++;
        g_strPlayerData[index][plyShotsPistol]++;
    }
    else if (   weaponId == WP_SMG || weaponId == WP_SMG_SILENCED || weaponId == WP_SMG_MP5 ||
                weaponId == WP_RIFLE || weaponId == WP_RIFLE_DESERT || weaponId == WP_RIFLE_AK47 || weaponId == WP_RIFLE_SG552
    ) {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsSmg]++;
        g_strPlayerData[index][plyShotsSmg]++;
    }
    else if (   weaponId == WP_PUMPSHOTGUN || weaponId == WP_SHOTGUN_CHROME ||
                weaponId == WP_AUTOSHOTGUN || weaponId == WP_SHOTGUN_SPAS
    ) {
        // get pellets
        new count = GetEventInt(event, "count");
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsShotgun] += count;
        g_strPlayerData[index][plyShotsShotgun] += count;
    }
    else if (   weaponId == WP_HUNTING_RIFLE || weaponId == WP_SNIPER_MILITARY  ||
                weaponId == WP_SNIPER_AWP || weaponId == WP_SNIPER_SCOUT
    ) {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsSniper]++;
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
        case WPTYPE_SHOTGUN: {  g_strPlayerData[index][plyHitsShotgun]++; g_strPlayerData[index][plyHitsSIShotgun]++;   g_strRoundPlayerData[index][g_iCurTeam][plyHitsShotgun]++; g_strRoundPlayerData[index][g_iCurTeam][plyHitsSIShotgun]++; }
        case WPTYPE_SMG: {      g_strPlayerData[index][plyHitsSmg]++;     g_strPlayerData[index][plyHitsSISmg]++;       g_strRoundPlayerData[index][g_iCurTeam][plyHitsSmg]++;     g_strRoundPlayerData[index][g_iCurTeam][plyHitsSISmg]++; }
        case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHitsSniper]++;  g_strPlayerData[index][plyHitsSISniper]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHitsSniper]++;  g_strRoundPlayerData[index][g_iCurTeam][plyHitsSISniper]++; }
        case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHitsPistol]++;  g_strPlayerData[index][plyHitsSIPistol]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHitsPistol]++;  g_strRoundPlayerData[index][g_iCurTeam][plyHitsSIPistol]++; }
    }
    
    // headshots on anything but tank, separately store hits for tank
    if ( GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_TANK )
    {
        switch ( weaponType )
        {
            case WPTYPE_SHOTGUN: {  g_strPlayerData[index][plyHitsTankShotgun]++;   g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankShotgun]++; }
            case WPTYPE_SMG: {      g_strPlayerData[index][plyHitsTankSmg]++;       g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankSmg]++; }
            case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHitsTankSniper]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankSniper]++; }
            case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHitsTankPistol]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHitsTankPistol]++; }
        }
    }
    
    // headshots (only bullet-based)
    if ( damagetype & DMG_BULLET && hitgroup == HITGROUP_HEAD && GetEntProp(victim, Prop_Send, "m_zombieClass") != ZC_TANK )
    {
        switch ( weaponType )
        {
            case WPTYPE_SMG: {      g_strPlayerData[index][plyHeadshotsSmg]++;    g_strPlayerData[index][plyHeadshotsSISmg]++;      g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSmg]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSISmg]++; }
            case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHeadshotsSniper]++; g_strPlayerData[index][plyHeadshotsSISniper]++;   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSniper]++; g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSISniper]++; }
            case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHeadshotsPistol]++; g_strPlayerData[index][plyHeadshotsSIPistol]++;   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsPistol]++; g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSIPistol]++; }
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
        case WPTYPE_SHOTGUN: {  g_strPlayerData[index][plyHitsShotgun]++;   g_strRoundPlayerData[index][g_iCurTeam][plyHitsShotgun]++;}
        case WPTYPE_SMG: {      g_strPlayerData[index][plyHitsSmg]++;       g_strRoundPlayerData[index][g_iCurTeam][plyHitsSmg]++; }
        case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHitsSniper]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHitsSniper]++; }
        case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHitsPistol]++;    g_strRoundPlayerData[index][g_iCurTeam][plyHitsPistol]++; }
    }
    
    // headshots (only bullet-based)
    if ( damagetype & DMG_BULLET && hitgroup == HITGROUP_HEAD )
    {
        switch ( weaponType )
        {
            case WPTYPE_SMG: {      g_strPlayerData[index][plyHeadshotsSmg]++;      g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSmg]++; }
            case WPTYPE_SNIPER: {   g_strPlayerData[index][plyHeadshotsSniper]++;   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsSniper]++; }
            case WPTYPE_PISTOL: {   g_strPlayerData[index][plyHeadshotsPistol]++;   g_strRoundPlayerData[index][g_iCurTeam][plyHeadshotsPistol]++; }
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
    
    g_strPlayerData[index][plyShoves]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyShoves]++;
}
public OnHunterDeadstop ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyDeadStops]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyDeadStops]++;
}

// skeets
public OnSkeet ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeets]++;
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeetsHurt]++;
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}
public OnSkeetMelee ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeetsMelee]++;
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsMelee]++;
}
/* public OnSkeetMeleeHurt ( attacker, victim, damage )
{
    //new index = GetPlayerIndexForClient( attacker );
    //if ( index == -1 ) { return; }
    //g_strPlayerData[index][plySkeetsHurt]++;
    //g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}
*/
public OnSkeetSniper ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeets]++;
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetSniperHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySkeetsHurt]++;
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}

// pops
public OnBoomerPop ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyPops]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyPops]++;
}

// levels
public OnChargerLevel ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyLevels]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyLevels]++;
}
public OnChargerLevelHurt ( attacker, victim, damage )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyLevelsHurt]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyLevelsHurt]++;
}

// smoker clears
public OnTongueCut ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyTongueCuts]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyTongueCuts]++;
}
public OnSmokerSelfClear ( attacker, victim, withShove )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plySelfClears]++;
    g_strRoundPlayerData[index][g_iCurTeam][plySelfClears]++;
}

// crowns
public OnWitchCrown ( attacker, damage )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyCrowns]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyCrowns]++;
}
public OnWitchDrawCrown ( attacker, damage, chipdamage )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyCrownsHurt]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyCrownsHurt]++;
}
// tank rock
public OnTankRockEaten ( attacker, victim )
{
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( victim );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyRockEats]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyRockEats]++;
}

public OnTankRockSkeeted ( attacker, victim )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyRockSkeets]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyRockSkeets]++;
}
// highpounces
public OnHunterHighPounce ( attacker, victim, Float:damage, Float:height )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyHunterDPs]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyHunterDPs]++;
}
public OnJockeyHighPounce ( attacker, victim, Float:height )
{
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strPlayerData[index][plyJockeyDPs]++;
    g_strRoundPlayerData[index][g_iCurTeam][plyJockeyDPs]++;
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
    
    // if we're cleaning the entire GAME ('round' refers to two roundhalves here)
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
            for ( j = 0; j < 2; j++ ) {
                for ( k = 0; k <= MAXRNDSTATS; k++ ) {
                    g_strRoundData[i][j][k] = 0;
                }
            }
        }
        
        // clear players
        for ( i = 0; i < MAXTRACKED; i++ ) {
            for ( j = 0; j <= MAXPLYSTATS; j++ ) {
                g_strPlayerData[i][j] = 0;
            }
        }
        
        // ff
        g_strGameData[gmFFDamageTotalA] = 0;
        g_strGameData[gmFFDamageTotalB] = 0;
        
        g_iRound = 0;
    }
    else
    {
        for ( k = 0; k <= MAXRNDSTATS; k++ ) {
            g_strRoundData[g_iRound][iTeam][k] = 0;
        }
    }
    
    // other round data
    if ( iTeam == -1 )  // both
    {
        g_iMVPRoundSIDamageTotal[0] = 0;    g_iMVPRoundSIDamageTotal[1] = 0;
        g_iMVPRoundCommonTotal[0] = 0;      g_iMVPRoundCommonTotal[1] = 0;
        
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
        g_iMVPRoundSIDamageTotal[iTeam] = 0;
        g_iMVPRoundCommonTotal[iTeam] = 0;
        
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
            
            // for tracking which players ever were in the team (only useful if they were in the team when round was live)
            g_iPlayerRoundTeam[g_iCurTeam][index] = g_iCurTeam;
            
            // if player wasn't present, update presence (shift start forward)
            // if player wasn't alive and is now, update
            // if player wasn't upright and is now, update
            
            /*
                playerdata is updated after round(half) ends
            if ( g_strPlayerData[index][plyTimeStopPresent] && g_strPlayerData[index][plyTimeStartPresent] )  {
                g_strPlayerData[index][plyTimeStartPresent] += time - g_strPlayerData[index][plyTimeStopPresent];
                g_strPlayerData[index][plyTimeStopPresent] = 0;
            } */
            if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] )  {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent];
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] = 0;
            }
            if ( IsPlayerAlive(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] )  {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive];
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = 0;
            }
            if ( !IsPlayerIncapacitatedAtAll(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] )  {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
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
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time;
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time;
            }
        }
    }
}

stock ClearPlayerTeam( iTeam = -1 )
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

stock SetStartSurvivorTime( bool:bGame = false )
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
            if ( bGame ) {
                g_strPlayerData[index][plyTimeStartPresent] = time;
                g_strPlayerData[index][plyTimeStartAlive] = time;
                g_strPlayerData[index][plyTimeStartUpright] = time;
            } else {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] = time;
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] = time;
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] = time;
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
    //decl String:bufBasic[CONBUFSIZELARGE];
    decl String: strTmp[24];
    decl String: strTmpA[40];
    //decl String: strTmpB[32];
    new iCount, i, j;
    
    g_iConsoleBufChunks = 0;
    
    new team = g_iCurTeam;
    if ( iTeam != -1 ) { team = iTeam; }
    else if ( g_bSecondHalf && !g_bPlayersLeftStart ) { team = (team) ? 0 : 1; }
    
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
        while (strlen(strTmp) < 14 && iCount < 1000) { iCount++; Format(strTmp, sizeof(strTmp), " %s", strTmp); }
        
        
        // kill stats
        new tmpSpecial, tmpCommon, tmpWitches, tmpTanks, tmpIncap, tmpDeath;
        
        for ( i = 0; i <= g_iRound; i++ )
        {
            tmpSpecial += g_strRoundData[i][team][rndSIKilled];
            tmpCommon +=  g_strRoundData[i][team][rndCommon];
            tmpWitches += g_strRoundData[i][team][rndWitchKilled];
            tmpTanks +=   g_strRoundData[i][team][rndTankKilled];
            tmpIncap +=   g_strRoundData[i][team][rndIncaps];
            tmpDeath +=   g_strRoundData[i][team][rndDeaths];
        }
        
        Format(bufBasicHeader, CONBUFSIZE, "\n");
        Format(bufBasicHeader, CONBUFSIZE, "%s| General Stats                                    |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Time: %14s | Rounds/Fails: %4i /%5i |\n", bufBasicHeader, strTmp, g_iRound, g_strGameData[gmFailed] );
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|                      | Kills:   %6i  specials |\n", bufBasicHeader, tmpSpecial );
        Format(bufBasicHeader, CONBUFSIZE, "%s|                      |          %6i  commons  |\n", bufBasicHeader, tmpCommon );
        Format(bufBasicHeader, CONBUFSIZE, "%s| Deaths:       %6i |          %6i  witches  |\n", bufBasicHeader, tmpDeath, tmpWitches );
        Format(bufBasicHeader, CONBUFSIZE, "%s| Incaps:       %6i |          %6i  tanks    |\n", bufBasicHeader, tmpIncap, tmpTanks );
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
            if ( g_strRoundData[i][team][rndStartTime] )
            {
                new tmpInt = 0;
                if ( g_strRoundData[i][team][rndEndTime] ) {
                    tmpInt = g_strRoundData[i][team][rndEndTime];
                } else {
                    tmpInt = GetTime() - g_strRoundData[i][team][rndStartTime];
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
                    g_strRoundData[i][team][rndRestarts]
                );
            Format(bufBasicHeader, CONBUFSIZE, "%s| Kills SI, CI, Witch: |     %5i / %5i / %5i |\n", bufBasicHeader,
                    g_strRoundData[i][team][rndSIKilled],
                    g_strRoundData[i][team][rndCommon],
                    g_strRoundData[i][team][rndWitchKilled]
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
        
        if ( g_strRoundData[i][team][rndStartTime] )
        {
            new tmpInt = 0;
            if ( g_strRoundData[i][team][rndEndTime] ) {
                tmpInt = g_strRoundData[i][team][rndEndTime];
            } else {
                tmpInt = GetTime() - g_strRoundData[i][team][rndStartTime];
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
                g_strRoundData[i][team][rndRestarts]
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s| Kills SI, CI, Witch: |     %5i / %5i / %5i |\n", bufBasicHeader,
                g_strRoundData[i][team][rndSIKilled],
                g_strRoundData[i][team][rndCommon],
                g_strRoundData[i][team][rndWitchKilled]
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
stock DisplayStatsMVPChat( client, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    // make sure the MVP stats itself is called first, so the players are already sorted
    
    decl String:printBuffer[1024];
    decl String:tmpBuffer[512];
    new String:strLines[8][192];
    new i, x;
    
    printBuffer = GetMVPChatString( bRound, bTeam, iTeam );
    
    if ( client != 0 ) {
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
        for ( i = 0; i < intPieces; i++ ) {
            PrintToChatAll("\x01%s", strLines[i]);
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
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }
            
            if ( listNumber && ( !IS_VALID_CLIENT(client) || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg,\x05 %d \x01kills)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            (bRound) ? g_strRoundPlayerData[index][team][plySIKilled] : g_strPlayerData[index][plySIKilled]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(dmg \x04%.0f%%\x01, kills \x04%.0f%%\x01)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[index][team][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100) ),
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[index][team][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100) )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg [\x04%.0f%%\x01],\x05 %d \x01kills [\x04%.0f%%\x01])",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[index][team][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100) ),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIKilled] : g_strPlayerData[index][plySIKilled],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[index][team][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[index][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100) )
                        );
                }
                PrintToChat( found, "\x01%s", tmpBuffer );
            }
            
            listNumber++;
        }
    }

    // tell them they sucked with Common
    listNumber = 0;
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
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }
            
            if ( listNumber && ( !IS_VALID_CLIENT(client) || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) )
            {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plyCommon] : g_strPlayerData[index][plyCommon]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(kills \x04%.0f%%\x01)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[index][team][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strPlayerData[index][plyCommon]) / float(g_iMVPCommonTotal[team])) * 100) )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills [\x04%.0f%%\x01])",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plyCommon] : g_strPlayerData[index][plyCommon],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[index][team][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strPlayerData[index][plyCommon]) / float(g_iMVPCommonTotal[team])) * 100) )
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
            for ( x = 1; x <= MAXPLAYERS; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            if ( found == -1 ) { continue; }
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }

            if ( bRound && !g_strRoundPlayerData[index][team][plyFFGiven] || !bRound && !g_strPlayerData[index][plyFFGiven] ) { continue; }
            
            if ( listNumber && ( !IS_VALID_CLIENT(client) || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) )
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
    new mvp_SI = g_iPlayerIndexSorted[SORT_SI][0];
    new mvp_Common = g_iPlayerIndexSorted[SORT_CI][0];
    new mvp_FF = g_iPlayerIndexSorted[SORT_FF][0];
    
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
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(dmg \x04%2.0f%%\x01, kills \x04%.0f%%\x01)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][team][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100) ),
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][team][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100) )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(\x05%d \x01dmg[\x04%.0f%%\x01],\x05 %d \x01kills [\x04%.0f%%\x01])\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIDamage] : g_strPlayerData[mvp_SI][plySIDamage],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][team][plySIDamage]) / float(g_iMVPRoundSIDamageTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_iMVPSIDamageTotal[team])) * 100) ),
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIKilled] : g_strPlayerData[mvp_SI][plySIKilled],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[mvp_SI][team][plySIKilled]) / float(g_iMVPRoundSIKilledTotal[team])) * 100) : ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_iMVPSIKilledTotal[team])) * 100) )
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
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x04%.0f%%\x01)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[mvp_Common][team][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strPlayerData[mvp_Common][plyCommon]) / float(g_iMVPCommonTotal[team])) * 100) )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x05%d \x01common [\x04%.0f%%\x01])\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? g_strRoundPlayerData[mvp_Common][team][plyCommon] : g_strPlayerData[mvp_Common][plyCommon],
                            RoundFloat( (bRound) ? ((float(g_strRoundPlayerData[mvp_Common][team][plyCommon]) / float(g_iMVPRoundCommonTotal[team])) * 100) : ((float(g_strPlayerData[mvp_Common][plyCommon]) / float(g_iMVPCommonTotal[team])) * 100) )
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

stock DisplayStatsMVP( client, bool:bTank = false, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    new i, j;
    
    // get sorted players list
    SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    
    new bool: bTankUp = bool:( !g_bModeCampaign && IsTankInGame() && g_bInRound );
    
    // prepare buffer(s) for printing
    if ( !bTank || !bTankUp )
    {
        BuildConsoleBufferMVP( bTank, bRound, bTeam, iTeam );
    }
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
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
            if ( g_iConsoleBufChunks > -1 && !g_bLastLineDivider ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks],
                        CONBUFSIZELARGE,
                                               "%s|------------------------------------------------------------------------------|\n",
                        g_sConsoleBuf[g_iConsoleBufChunks]
                );
            }
            if ( g_iConsoleBufChunks == -1 ) {
                Format( bufBasicHeader,
                        CONBUFSIZE,
                                             "%s\n| (nothing to display)                                                         |\n",
                        bufBasicHeader,
                                               "\n|------------------------------------------------------------------------------|"
                );
            }
        }
    }
    else
    {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                           "\n| Survivor MVP Stats -- %10s -- %11s                                                 |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|-------------------------------------------------------------------------------------------------|\n",   bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Specials   kills/dmg  | Commons         | Tank   | Witch  | FF    | Rcvd |\n",   bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|-----------------------|-----------------|--------|--------|-------|------|",     bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 && !g_bLastLineDivider ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                           "%s|-------------------------------------------------------------------------------------------------|\n",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        }
        if ( g_iConsoleBufChunks == -1 ) {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                            |%s",
                    bufBasicHeader,
                                           "\n|-------------------------------------------------------------------------------------------------|"
                );
        }
    }
    
    if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) )
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
            PrintToServer(g_sConsoleBuf[j] );
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
        if ( g_iConsoleBufChunks > -1 && !g_bLastLineDivider ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                           "%s|--------------------------------------------------------------------------------------------------------------|\n",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        }
        if ( g_iConsoleBufChunks == -1 ) {
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
        if ( g_iConsoleBufChunks > -1 && !g_bLastLineDivider ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                           "%s|--------------------------------------------------------------------------------------------------------------|\n",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        }
        if ( g_iConsoleBufChunks == -1 ) {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                         |%s",
                    bufBasicHeader,
                                           "\n|--------------------------------------------------------------------------------------------------------------|"
                );
        }

    }
    
    if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) )
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
stock DisplayStatsSpecial( client, bool:bRound = false, bool:bTeam = true, bool:bSorted = false, iTeam = -1 )
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
    if ( g_iConsoleBufChunks > -1 && !g_bLastLineDivider ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                       "%s|---------------------------------------------------------------------------------------------------|\n",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    }
    if ( g_iConsoleBufChunks == -1 ) {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                              |%s",
                bufBasicHeader,
                                       "\n|---------------------------------------------------------------------------------------------------|"
            );
    }
    
    if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) )
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
        if ( g_strRoundData[g_iRound][team][rndFFDamageTotal] || !bTeam && g_strRoundData[g_iRound][!team][rndFFDamageTotal] ) { bNoStatsToShow = false; }
    }
    else {
        if ( bTeam ) {
            if ( team == LTEAM_A && g_strGameData[gmFFDamageTotalA] || team == LTEAM_B && g_strGameData[gmFFDamageTotalB] ) { bNoStatsToShow = false; }
        } else {
            if ( g_strGameData[gmFFDamageTotalA] || g_strGameData[gmFFDamageTotalB] ) { bNoStatsToShow = false; }
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
        if ( g_iConsoleBufChunks > -1 && !g_bLastLineDivider ) {
            Format(g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE,
                                           "%s|--------------------------------||---------------------------------------------------------||---------|",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
        }
        if ( g_iConsoleBufChunks == -1 ) {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                 |%s",
                    bufBasicHeader,
                                           "\n|------------------------------------------------------------------------------------------------------|"
                );
        }
    }

    if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) )
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
    if ( g_iConsoleBufChunks > -1 && !g_bLastLineDivider ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                       "%s|--------------------------------||---------------------------------------------------------||---------|\n",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    }
    if ( g_iConsoleBufChunks == -1 ) {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                                 |%s",
                bufBasicHeader,
                                       "\n|------------------------------------------------------------------------------------------------------|"
            );
    }
    
    
    if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) )
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

stock BuildConsoleBufferSpecial ( bool:bRound = false, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    g_bLastLineDivider = false;
    
    new const s_len = 24;
    new String: strTmp[6][s_len];
    new i, x, line;
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // Special skill stats
    for ( x = 0; x < g_iPlayers; x++ )
    {
        i = g_iPlayerIndexSorted[SORT_SI][x];
        
        // also skip bots for this list
        if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( bTeam ) {
            if ( g_iPlayerRoundTeam[team][i] != team ) { continue; }
        } else {
            team = g_iPlayerSortedUseTeam[SORT_SI][i];
        }
        
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
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[i] );
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s| %20s | %16s | %9s | %9s | %4s | %11s | %10s |%s",
                g_sConsoleBuf[g_iConsoleBufChunks],
                g_sTmpString,
                strTmp[0], strTmp[1], strTmp[2],
                strTmp[3], strTmp[4], strTmp[5],
                ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
            );
        
        line++;
        
        if ( line >= DIVIDERINTERVAL ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| -------------------- | ---------------- | --------- | --------- | ---- | ----------- | ---------- |%s",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( line < MAXLINESPERCHUNK ) ? "" : "\n",
                    ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                );
            g_bLastLineDivider = true;
            line++;
        } else {
            g_bLastLineDivider = false;
        }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            line = 0;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        }
    }
}

stock BuildConsoleBufferAccuracy ( bool:details = false, bool:bRound = false, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    g_bLastLineDivider = false;
    
    new const s_len = 24;
    new String: strTmp[5][s_len], String: strTmpA[s_len], String: strTmpB[s_len];
    new i, line;
    
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
            if ( bTeam ) {
                if ( g_iPlayerRoundTeam[team][i] != team ) { continue; }
            } else {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            
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
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSISmg] ) / float( g_strRoundPlayerData[i][team][plyHitsSISmg] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISmg] ) / float( g_strPlayerData[i][plyHitsSISmg] ) * 100.0 );
                }
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
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSISniper] ) / float( g_strRoundPlayerData[i][team][plyHitsSISniper] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISniper] ) / float( g_strPlayerData[i][plyHitsSISniper] ) * 100.0 );
                }
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
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSIPistol] ) / float( g_strRoundPlayerData[i][team][plyHitsSIPistol] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSIPistol] ) / float( g_strPlayerData[i][plyHitsSIPistol] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[3], s_len, "%6d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSIPistol] : g_strPlayerData[i][plyHitsSIPistol] ),
                        strTmpA,
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsTankPistol] : g_strPlayerData[i][plyHitsTankPistol] )
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s| %20s | %19s | %19s | %19s | %19s |%s",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    g_sTmpString,
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3],
                    ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                );
            
            line++;
            
            if ( line >= DIVIDERINTERVAL ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks],
                        CONBUFSIZELARGE,
                        "%s%s| -------------------- | ------------------- | ------------------- | ------------------- | ------------------- |%s",
                        g_sConsoleBuf[g_iConsoleBufChunks],
                        ( line < MAXLINESPERCHUNK ) ? "" : "\n",
                        ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                    );
                g_bLastLineDivider = true;
                line++;
            } else {
                g_bLastLineDivider = false;
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                line = 0;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
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
            if ( bTeam ) {
                if ( g_iPlayerRoundTeam[team][i] != team ) { continue; }
            } else {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            
            // shotgun:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsShotgun] || !bRound && g_strPlayerData[i][plyShotsShotgun] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsShotgun] ) / float( g_strRoundPlayerData[i][team][plyShotsShotgun] ) * 100.0);
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsShotgun] ) / float( g_strPlayerData[i][plyShotsShotgun] ) * 100.0);
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[0], s_len, "%7d      %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsShotgun] : g_strPlayerData[i][plyHitsShotgun] ),
                        //( (bRound) ? g_strRoundPlayerData[i][team][plyShotsShotgun] : g_strPlayerData[i][plyShotsShotgun] ),
                        strTmpA
                    );
            } else {
                Format( strTmp[0], s_len, "                   " );
            }
            
            // smg:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsSmg] || !bRound && g_strPlayerData[i][plyShotsSmg] ) {
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsSmg] ) / float( g_strRoundPlayerData[i][team][plyShotsSmg] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSmg] ) / float( g_strPlayerData[i][plyShotsSmg] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) {
                    Format( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSmg] ) / float( g_strRoundPlayerData[i][team][plyHitsSmg] - g_strRoundPlayerData[i][team][plyHitsTankSmg] ) * 100.0 );
                } else {
                    Format( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSmg] ) / float( g_strPlayerData[i][plyHitsSmg] - g_strPlayerData[i][plyHitsTankSmg] ) * 100.0 );
                }
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
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsSniper] ) / float( g_strRoundPlayerData[i][team][plyShotsSniper] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSniper] ) / float( g_strPlayerData[i][plyShotsSniper] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) {
                    Format( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSniper] ) / float( g_strRoundPlayerData[i][team][plyHitsSniper] - g_strRoundPlayerData[i][team][plyHitsTankSniper] ) * 100.0 );
                } else {
                    Format( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSniper] ) / float( g_strPlayerData[i][plyHitsSniper] - g_strPlayerData[i][plyHitsTankSniper] ) * 100.0 );
                }
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
                if ( bRound ) {
                    Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsPistol] ) / float( g_strRoundPlayerData[i][team][plyShotsPistol] ) * 100.0 );
                } else {
                    Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsPistol] ) / float( g_strPlayerData[i][plyShotsPistol] ) * 100.0 );
                }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) {
                    Format( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsPistol] ) / float( g_strRoundPlayerData[i][team][plyHitsPistol] - g_strRoundPlayerData[i][team][plyHitsTankPistol] ) * 100.0 );
                } else {
                    Format( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsPistol] ) / float( g_strPlayerData[i][plyHitsPistol] - g_strPlayerData[i][plyHitsTankPistol] ) * 100.0 );
                }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[3], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsPistol] : g_strPlayerData[i][plyHitsPistol] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s| %20s | %19s | %19s | %19s | %19s |%s",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    g_sTmpString,
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3],
                    ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                );
            
            line++;
            
            if ( line >= DIVIDERINTERVAL ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks],
                        CONBUFSIZELARGE,
                        "%s%s| -------------------- | ------------------- | ------------------- | ------------------- | ------------------- |%s",
                        g_sConsoleBuf[g_iConsoleBufChunks],
                        ( line < MAXLINESPERCHUNK ) ? "" : "\n",
                        ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                    );
                g_bLastLineDivider = true;
                line++;
            } else {
                g_bLastLineDivider = false;
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                line = 0;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            }
        }
    }
}

stock BuildConsoleBufferMVP ( bool:bTank = false, bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    g_bLastLineDivider = false;
    
    new const s_len = 24;
    new String: strTmp[6][s_len], String: strTmpA[s_len];
    new i, x, line;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    if ( bTank )
    {
        // MVP - tank related
        
        for ( x = 0; x < g_iPlayers; x++ )
        {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( bTeam ) {
                if ( g_iPlayerRoundTeam[team][i] != team ) { continue; }
            } else {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            
            // si damage
            Format( strTmp[0], s_len, "%5d %8d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySIKilledTankUp] : g_strPlayerData[i][plySIKilledTankUp] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySIDamageTankUp] : g_strPlayerData[i][plySIDamageTankUp] ),
                    strTmpA
                );
            
            // commons
            Format( strTmp[1], s_len, "  %8d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyCommonTankUp] : g_strPlayerData[i][plyCommonTankUp] )
                );
            
            // melee on tank
            Format( strTmp[2], s_len, "%6d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyMeleesOnTank] : g_strPlayerData[i][plyMeleesOnTank] )
                );
            
            // rock skeets / eats       ----- / -----
            Format( strTmp[3], s_len, " %5d /%6d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyRockSkeets] : g_strPlayerData[i][plyRockSkeets] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyRockEats] : g_strPlayerData[i][plyRockEats] )
                );
            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s| %20s | %14s | %10s | %6s | %14s |%s",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    g_sTmpString,
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3],
                    ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                );
            
            line++;
            
            if ( line >= DIVIDERINTERVAL ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks],
                        CONBUFSIZELARGE,
                        "%s%s| -------------------- | -------------- | ---------- | ------ | -------------- |%s",
                        g_sConsoleBuf[g_iConsoleBufChunks],
                        ( line < MAXLINESPERCHUNK ) ? "" : "\n",
                        ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                    );
                g_bLastLineDivider = true;
                line++;
            } else {
                g_bLastLineDivider = false;
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                line = 0;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            }
        }
    }
    else
    {
        // MVP normal
        new bool: bTankUp = bool:( !g_bModeCampaign && IsTankInGame() && g_bInRound );
        
        for ( x = 0; x < g_iPlayers; x++ )
        {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( bTeam ) {
                if ( bRound && g_iPlayerRoundTeam[team][i] != team ) { continue; }
            } else {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            
            // si damage
            if ( bRound ) { Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plySIDamage] ) / float( g_iMVPRoundSIDamageTotal[team] ) * 100.0);
            } else {        Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plySIDamage] ) / float( g_iMVPSIDamageTotal[team] ) * 100.0); }
            while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
            Format( strTmp[0], s_len, "%4d %8d  %5s%%%%",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySIKilled] : g_strPlayerData[i][plySIKilled] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySIDamage] : g_strPlayerData[i][plySIDamage] ),
                    strTmpA
                );
            
            
            // commons
            if ( bRound ) { Format( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyCommon] ) / float( g_iMVPRoundCommonTotal[team] ) * 100.0);
            } else {        Format( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyCommon] ) / float( g_iMVPCommonTotal[team] ) * 100.0); }
            while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
            Format( strTmp[1], s_len, "%7d  %5s%%%%",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyCommon] : g_strPlayerData[i][plyCommon] ),
                    strTmpA
                );
            
            // tank
            if ( bTankUp ) {
                // hide 
                Format( strTmp[2], s_len, "%s", "hidden" );
            } else {
                Format( strTmp[2], s_len, "%6d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyTankDamage] : g_strPlayerData[i][plyTankDamage] )
                    );
            }
            
            // witch
            Format( strTmp[3], s_len, "%6d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyWitchDamage] : g_strPlayerData[i][plyWitchDamage] )
                );
            
            // ff
            Format( strTmp[4], s_len, "%5d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyFFGiven] : g_strPlayerData[i][plyFFGiven] )
                );
            
            // damage received
            Format( strTmp[5], s_len, "%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyDmgTaken] : g_strPlayerData[i][plyDmgTaken] )
                );
            
            // prepare non-unicode string
            stripUnicode( g_sPlayerName[i] );
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s| %20s | %21s | %15s | %6s | %6s | %5s | %4s |%s",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    g_sTmpString,
                    strTmp[0], strTmp[1], strTmp[2],
                    strTmp[3], strTmp[4], strTmp[5],
                    ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                );
            
            line++;
            
            if ( line >= DIVIDERINTERVAL ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks],
                        CONBUFSIZELARGE,
                        "%s%s| -------------------- | --------------------- | --------------- | ------ | ------ | ----- | ---- |%s",
                        g_sConsoleBuf[g_iConsoleBufChunks],
                        ( line < MAXLINESPERCHUNK ) ? "" : "\n",
                        ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                    );
                g_bLastLineDivider = true;
                line++;
            } else {
                g_bLastLineDivider = false;
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                line = 0;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            }
        }
    }
}

stock BuildConsoleBufferFriendlyFireGiven ( bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    g_bLastLineDivider = false;
    
    new const s_len = 15;
    decl String:strPrint[FFTYPE_MAX][s_len];
    new i, x, line;
    
    // current logical survivor team?
    new team = g_iCurTeam;
    if ( iTeam != -1 ) { team = iTeam; }
    else if ( g_bSecondHalf && !g_bPlayersLeftStart ) { team = (team) ? 0 : 1; }
    
    // GIVEN
    for ( x = 0; x < g_iPlayers; x++ )
    {
        i = g_iPlayerIndexSorted[SORT_FF][x];
        
        // also skip bots for this list?
        if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( bTeam ) {
            if ( g_iPlayerRoundTeam[team][i] != team ) { continue; }
        } else {
            team = g_iPlayerSortedUseTeam[SORT_FF][i];
        }
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[i][team][plyFFGivenTotal] && !g_strRoundPlayerData[i][team][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[i][plyFFGivenTotal] && !g_strPlayerData[i][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // prepare print
        if ( !bRound && g_strPlayerData[i][plyFFGivenTotal] || bRound && g_strRoundPlayerData[i][team][plyFFGivenTotal] ) {
            Format(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenTotal] : g_strRoundPlayerData[i][team][plyFFGivenTotal] );
        } else {                            Format(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenPellet] || bRound && g_strRoundPlayerData[i][team][plyFFGivenPellet] ) {
            Format(strPrint[FFTYPE_PELLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenPellet] : g_strRoundPlayerData[i][team][plyFFGivenPellet] );
        } else {                            Format(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenBullet] || bRound && g_strRoundPlayerData[i][team][plyFFGivenBullet] ) {
            Format(strPrint[FFTYPE_BULLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenBullet] : g_strRoundPlayerData[i][team][plyFFGivenBullet] );
        } else {                            Format(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenMelee] || bRound && g_strRoundPlayerData[i][team][plyFFGivenMelee] ) {
            Format(strPrint[FFTYPE_MELEE],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenMelee] : g_strRoundPlayerData[i][team][plyFFGivenMelee] );
        } else {                            Format(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenFire] || bRound && g_strRoundPlayerData[i][team][plyFFGivenFire] ) {
            Format(strPrint[FFTYPE_FIRE],       s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenFire] : g_strRoundPlayerData[i][team][plyFFGivenFire] );
        } else {                            Format(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenIncap] || bRound && g_strRoundPlayerData[i][team][plyFFGivenIncap] ) {
            Format(strPrint[FFTYPE_INCAP],      s_len, "%8d", (!bRound) ? g_strPlayerData[i][plyFFGivenIncap] : g_strRoundPlayerData[i][team][plyFFGivenIncap] );
        } else {                            Format(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenOther] || bRound && g_strRoundPlayerData[i][team][plyFFGivenOther] ) {
            Format(strPrint[FFTYPE_OTHER],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenOther] : g_strRoundPlayerData[i][team][plyFFGivenOther] );
        } else {                            Format(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenSelf] || bRound && g_strRoundPlayerData[i][team][plyFFGivenSelf] ) {
            Format(strPrint[FFTYPE_SELF],       s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenSelf] : g_strRoundPlayerData[i][team][plyFFGivenSelf] );
        } else {                            Format(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[i] );

        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |%s",
                g_sConsoleBuf[g_iConsoleBufChunks],
                g_sTmpString,
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE], strPrint[FFTYPE_INCAP], strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF],
                ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
            );
        
        line++;
        
        if ( line >= DIVIDERINTERVAL ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| -------------------- | ------- || ------- | ------- | ------ | ------ | -------- | ------ || ------- |%s",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( line < MAXLINESPERCHUNK ) ? "" : "\n",
                    ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                );
            g_bLastLineDivider = true;
            line++;
        } else {
            g_bLastLineDivider = false;
        }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            line = 0;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        }
    }
}

stock BuildConsoleBufferFriendlyFireTaken ( bool:bRound = true, bool:bTeam = true, iTeam = -1 )
{
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    g_bLastLineDivider = false;
    
    new const s_len = 15;
    decl String:strPrint[FFTYPE_MAX][s_len];
    new i, j, x, line;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // TAKEN
    for ( x = 0; x < g_iPlayers; x++ )
    {
        j = g_iPlayerIndexSorted[SORT_FF][x];
        
        // also skip bots for this list?
        //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( bTeam ) {
            if ( g_iPlayerRoundTeam[team][i] != team ) { continue; }
        } else {
            team = g_iPlayerSortedUseTeam[SORT_FF][i];
        }
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[j][team][plyFFGivenTotal] && !g_strRoundPlayerData[j][team][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[j][plyFFGivenTotal] && !g_strPlayerData[j][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // prepare print
        if ( !bRound && g_strPlayerData[j][plyFFTakenTotal] || bRound && g_strRoundPlayerData[j][team][plyFFTakenTotal] ) {
            Format(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (!bRound) ? g_strPlayerData[j][plyFFTakenTotal] : g_strRoundPlayerData[j][team][plyFFTakenTotal] );
        } else {                            Format(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenPellet] || !bRound && g_strRoundPlayerData[j][team][plyFFTakenPellet] ) {
            Format(strPrint[FFTYPE_PELLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[j][plyFFTakenPellet] : g_strRoundPlayerData[j][team][plyFFTakenPellet] );
        } else {                            Format(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenBullet] || bRound && g_strRoundPlayerData[j][team][plyFFTakenBullet] ) {
            Format(strPrint[FFTYPE_BULLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[j][plyFFTakenBullet] : g_strRoundPlayerData[j][team][plyFFTakenBullet] );
        } else {                            Format(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenMelee] || bRound && g_strRoundPlayerData[j][team][plyFFTakenMelee] ) {
            Format(strPrint[FFTYPE_MELEE],      s_len, "%6d", (!bRound) ? g_strPlayerData[j][plyFFTakenMelee] : g_strRoundPlayerData[j][team][plyFFTakenMelee] );
        } else {                            Format(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenFire] || bRound && g_strRoundPlayerData[j][team][plyFFTakenFire] ) {
            Format(strPrint[FFTYPE_FIRE],       s_len, "%6d", (!bRound) ? g_strPlayerData[j][plyFFTakenFire] : g_strRoundPlayerData[j][team][plyFFTakenFire] );
        } else {                            Format(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenIncap] || bRound && g_strRoundPlayerData[j][team][plyFFTakenIncap] ) {
            Format(strPrint[FFTYPE_INCAP],      s_len, "%8d", (!bRound) ? g_strPlayerData[j][plyFFTakenIncap] : g_strRoundPlayerData[j][team][plyFFTakenIncap] );
        } else {                            Format(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[j][plyFFTakenOther] || bRound && g_strRoundPlayerData[j][team][plyFFTakenOther] ) {
            Format(strPrint[FFTYPE_OTHER],      s_len, "%6d", (!bRound) ? g_strPlayerData[j][plyFFTakenOther] : g_strRoundPlayerData[j][team][plyFFTakenOther] );
        } else {                            Format(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[j][plyFallDamage] || bRound && g_strRoundPlayerData[j][team][plyFallDamage] ) {
            Format(strPrint[FFTYPE_SELF],       s_len, "%7d", (!bRound) ? g_strRoundPlayerData[j][team][plyFallDamage] : g_strPlayerData[j][plyFallDamage] );
        } else {                            Format(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // prepare non-unicode string
        stripUnicode( g_sPlayerName[j] );
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |%s",
                g_sConsoleBuf[g_iConsoleBufChunks],
                g_sTmpString,
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE], strPrint[FFTYPE_INCAP], strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF],
                ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
            );
        
        line++;
        
        if ( line >= DIVIDERINTERVAL ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| -------------------- | ------- || ------- | ------- | ------ | ------ | -------- | ------ || ------- |%s",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( line < MAXLINESPERCHUNK ) ? "" : "\n",
                    ( line < MAXLINESPERCHUNK - 1 ) ? "\n" : ""
                );
            g_bLastLineDivider = true;
            line++;
        } else {
            g_bLastLineDivider = false;
        }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            line = 0;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        }
    }
}

stock SortPlayersMVP( bool:bRound = true, sortCol = SORT_SI, bool:bTeam = true, iTeam = -1 )
{
    new iStored = 0;
    new i, j;
    new bool: found, highest, pickTeam;
    
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
                            if ( highest == -1 || g_strRoundPlayerData[i][team][plySIDamage] > g_strRoundPlayerData[highest][team][plySIDamage] ) {
                                highest = i;
                            }
                        } else {
                            pickTeam = ( g_strRoundPlayerData[i][LTEAM_A][plySIDamage] >= g_strRoundPlayerData[i][LTEAM_B][plySIDamage] ) ? LTEAM_A : LTEAM_B;
                            if ( highest == -1 || g_strRoundPlayerData[i][pickTeam][plySIDamage] > g_strRoundPlayerData[highest][pickTeam][plySIDamage] ) {
                                highest = i;
                                g_iPlayerSortedUseTeam[sortCol][i] = pickTeam;
                            }
                        }
                    } else {
                        if ( highest == -1 || g_strPlayerData[i][plySIDamage] > g_strPlayerData[highest][plySIDamage] ) {
                            highest = i;
                        }
                    }
                }
                case SORT_CI:
                {
                    if ( bRound ) {
                        if ( bTeam ) {
                            if ( highest == -1 || g_strRoundPlayerData[i][team][plyCommon] > g_strRoundPlayerData[highest][team][plyCommon] ) {
                                highest = i;
                            }
                        } else {
                            pickTeam = ( g_strRoundPlayerData[i][LTEAM_A][plyCommon] >= g_strRoundPlayerData[i][LTEAM_B][plyCommon] ) ? LTEAM_A : LTEAM_B;
                            if ( highest == -1 || g_strRoundPlayerData[i][pickTeam][plyCommon] > g_strRoundPlayerData[highest][pickTeam][plyCommon] ) {
                                highest = i;
                                g_iPlayerSortedUseTeam[sortCol][i] = pickTeam;
                            }
                        }
                    } else {
                        if ( highest == -1 || g_strPlayerData[i][plyCommon] > g_strPlayerData[highest][plyCommon] ) {
                            highest = i;
                        }
                    }
                }
                case SORT_FF:
                {
                    if ( bRound ) {
                        if ( bTeam ) {
                            if ( highest == -1 || g_strRoundPlayerData[i][team][plyFFGiven] > g_strRoundPlayerData[highest][team][plyFFGiven] ) {
                                highest = i;
                            }
                        } else {
                            pickTeam = ( g_strRoundPlayerData[i][LTEAM_A][plyFFGiven] >= g_strRoundPlayerData[i][LTEAM_B][plyFFGiven] ) ? LTEAM_A : LTEAM_B;
                            if ( highest == -1 || g_strRoundPlayerData[i][pickTeam][plyFFGiven] > g_strRoundPlayerData[highest][pickTeam][plyFFGiven] ) {
                                highest = i;
                                g_iPlayerSortedUseTeam[sortCol][i] = pickTeam;
                            }
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
stock bool: IsHangingFromLedge ( client )
{
    return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}
stock bool: IsPlayerIncapacitatedAtAll ( client )
{
    return bool: ( IsPlayerIncapacitated(client) || IsHangingFromLedge(client) );
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

