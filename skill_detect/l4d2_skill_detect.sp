/**
 *  L4D2_skill_detect
 *
 *  Plugin to detect and forward reports about 'skill'-actions,
 *  such as skeets, crowns, levels, dp's.
 *  Works in campaign and versus modes.
 *
 *  m_isAttemptingToPounce  can only be trusted for
 *  AI hunters -- for human hunters this gets cleared
 *  instantly on taking killing damage
 *
 *  Shotgun skeets and teamskeets are only counted if the
 *  added up damage to pounce_interrupt is done by shotguns
 *  only. 'Skeeting' chipped hunters shouldn't count, IMO.
 *
 *  This performs global forward calls to:
 *      OnSkeet( survivor, hunter )
 *      OnSkeetMelee( survivor, hunter )
 *      OnSkeetGL( survivor, hunter )
 *      OnSkeetSniper( survivor, hunter )
 *      OnSkeetHurt( survivor, hunter, damage, isOverkill )
 *      OnSkeetMeleeHurt( survivor, hunter, damage, isOverkill )
 *      OnSkeetSniperHurt( survivor, hunter, damage, isOverkill )
 *      OnHunterDeadstop( survivor, hunter )
 *      OnBoomerPop( survivor, boomer )
 *      OnChargerLevel( survivor, charger )
 *      OnChargerLevelHurt( survivor, charger, damage )
 *      OnWitchCrown( survivor, damage )
 *      OnWitchCrownHurt( survivor, damage, chipdamage )
 *      OnTongueCut( survivor, smoker )
 *      OnSmokerSelfClear( survivor, smoker, withShove )
 *      OnTankRockSkeeted( survivor, tank )
 *      OnTankRockEaten( tank, survivor )
 *      OnHunterHighPounce( hunter, victim, Float:damage, Float:height )
 *      OnJockeyHighPounce( jockey, victim, Float:height )
 
 *      OnDeathCharge( charger, victim )                    ?
 *      OnBHop( player, isInfected, speed, streak )         ?
 
 *
 *  Where survivor == -2 if it was a team effort, -1 or 0 if unknown or invalid client.
 *  damage is the amount of damage done (that didn't add up to skeeting damage),
 *  and isOverkill indicates whether the shot would've been a skeet if the hunter
 *  had not been chipped.
 *
 *  @author         Tabun
 *  @libraryname    skill_detect
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "0.9.3"

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))
#define QUOTES(%1)              (%1)

#define SHOTGUN_BLAST_TIME  0.1
#define POUNCE_CHECK_TIME   0.1
#define SHOVE_TIME          0.05

#define ZC_SMOKER       1
#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_JOCKEY       5
#define ZC_CHARGER      6
#define ZC_TANK         8
#define HITGROUP_HEAD   1

#define DMG_CRUSH               (1 << 0)        // crushed by falling or moving object. 
#define DMG_BULLET              (1 << 1)        // shot
#define DMG_SLASH               (1 << 2)        // cut, clawed, stabbed
#define DMG_CLUB                (1 << 7)        // crowbar, punch, headbutt
#define DMG_BUCKSHOT            (1 << 29)       // not quite a bullet. Little, rounder, different. 

#define DMGARRAYEXT     7                       // MAXPLAYERS+# -- extra indices in witch_dmg_array + 1

#define CUT_SHOVED      1                       // .. i think
#define CUT_KILL        3                       // reason for tongue break (release_type)
#define CUT_SLASH       4                       // this is used for others shoving a survivor free too, don't trust

#define REP_SKEET               (1 << 0)
#define REP_HURTSKEET           (1 << 1)
#define REP_LEVEL               (1 << 2)
#define REP_HURTLEVEL           (1 << 3)
#define REP_CROWN               (1 << 4)
#define REP_DRAWCROWN           (1 << 5)
#define REP_TONGUECUT           (1 << 6)
#define REP_SELFCLEAR           (1 << 7)
#define REP_SELFCLEARSHOVE      (1 << 8)
#define REP_ROCKSKEET           (1 << 9)
#define REP_DEADSTOP            (1 << 10)
#define REP_POP                 (1 << 11)
#define REP_SHOVE               (1 << 12)
#define REP_HUNTERDP            (1 << 13)
#define REP_JOCKEYDP            (1 << 14)

#define REP_DEFAULT             "24629"  //(REP_SKEET | REP_LEVEL | REP_CROWN | REP_DRAWCROWN | REP_HUNTERDP | REP_JOCKEYDP) -- 1 4 16 32 8192 16384

// trie values: weapon type
enum strWeaponType
{
    WPTYPE_SNIPER,
    WPTYPE_MAGNUM,
    WPTYPE_GL
};

// trie values: OnEntityCreated classname
enum strOEC
{
    OEC_WITCH,
    OEC_TANKROCK
};

// trie values: special abilities
enum strAbility
{
    ABL_HUNTERLUNGE,
    ABL_ROCKTHROW
};

enum _:strRockData
{
    rckDamage,
    rckTank,
    rckSkeeter
};

// witch array entries (maxplayers+index)
enum _:strWitchArray
{
    WTCH_NONE,
    WTCH_HEALTH,
    WTCH_GOTSLASH,
    WTCH_STARTLED,
    WTCH_CROWNER,
    WTCH_CROWNSHOT,
    WTCH_CROWNTYPE
};

new     bool:           g_bLateLoad                                         = false;

new     Handle:         g_hForwardSkeet                                     = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetHurt                                 = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetMelee                                = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetMeleeHurt                            = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetSniper                               = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetSniperHurt                           = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetGL                                   = INVALID_HANDLE;
new     Handle:         g_hForwardHunterDeadstop                            = INVALID_HANDLE;
new     Handle:         g_hForwardSIShove                                   = INVALID_HANDLE;
new     Handle:         g_hForwardBoomerPop                                 = INVALID_HANDLE;
new     Handle:         g_hForwardLevel                                     = INVALID_HANDLE;
new     Handle:         g_hForwardLevelHurt                                 = INVALID_HANDLE;
new     Handle:         g_hForwardCrown                                     = INVALID_HANDLE;
new     Handle:         g_hForwardDrawCrown                                 = INVALID_HANDLE;
new     Handle:         g_hForwardTongueCut                                 = INVALID_HANDLE;
new     Handle:         g_hForwardSmokerSelfClear                           = INVALID_HANDLE;
new     Handle:         g_hForwardRockSkeeted                               = INVALID_HANDLE;
new     Handle:         g_hForwardRockEaten                                 = INVALID_HANDLE;
new     Handle:         g_hForwardHunterDP                                  = INVALID_HANDLE;
new     Handle:         g_hForwardJockeyDP                                  = INVALID_HANDLE;

new     Handle:         g_hTrieWeapons                                      = INVALID_HANDLE;   // weapon check
new     Handle:         g_hTrieEntityCreated                                = INVALID_HANDLE;   // getting classname of entity created
new     Handle:         g_hTrieAbility                                      = INVALID_HANDLE;   // ability check
new     Handle:         g_hWitchTrie                                        = INVALID_HANDLE;   // witch tracking (Crox)
new     Handle:         g_hRockTrie                                         = INVALID_HANDLE;   // tank rock tracking

// skeets
new                     g_iHunterShotDmgTeam    [MAXPLAYERS + 1];                               // counting shotgun blast damage for hunter, counting entire survivor team's damage
new                     g_iHunterShotDmg        [MAXPLAYERS + 1][MAXPLAYERS + 1];               // counting shotgun blast damage for hunter / skeeter combo
new     Float:          g_fHunterShotStart      [MAXPLAYERS + 1][MAXPLAYERS + 1];               // when the last shotgun blast on hunter started (if at any time) by an attacker
new     Float:          g_fHunterTracePouncing  [MAXPLAYERS + 1];                               // time when the hunter was still pouncing (in traceattack) -- used to detect pouncing status
new     Float:          g_fHunterLastShot       [MAXPLAYERS + 1];                               // when the last shotgun damage was done (by anyone) on a hunter
new                     g_iHunterLastHealth     [MAXPLAYERS + 1];                               // last time hunter took any damage, how much health did it have left?
new                     g_iHunterOverkill       [MAXPLAYERS + 1];                               // how much more damage a hunter would've taken if it wasn't already dead
new     bool:           g_bHunterKilledPouncing [MAXPLAYERS + 1];                               // whether the hunter was killed when actually pouncing

// highpounces
new     Float:          g_fPouncePosition       [MAXPLAYERS + 1][3];                            // position that a hunter (jockey?) pounced from

// deadstops
new     Float:          g_fVictimLastShove      [MAXPLAYERS + 1][MAXPLAYERS + 1];               // when was the player shoved last (by attacker)? (to prevent doubles)

// levels
new                     g_iChargerHealth        [MAXPLAYERS + 1];                               // how much health the charger had the last time it was seen taking damage

// pops
new                     g_bBoomerHitSomebody    [MAXPLAYERS + 1];                               // false if boomer didn't puke/exploded on anybody

// crowns
new     Float:          g_fWitchShotStart       [MAXPLAYERS + 1];                               // when the last shotgun blast from a survivor started (on any witch)

// smoker clears
new     bool:           g_bSmokerClearCheck     [MAXPLAYERS + 1];                               // [smoker] smoker dies and this is set, it's a self-clear if g_iSmokerVictim is the killer
new                     g_iSmokerVictim         [MAXPLAYERS + 1];                               // [smoker] the one that's being pulled
new                     g_iSmokerVictimDamage   [MAXPLAYERS + 1];                               // [smoker] amount of damage done to a smoker by the one he pulled
new     bool:           g_bSmokerShoved         [MAXPLAYERS + 1];                               // [smoker] set if the victim of a pull manages to shove the smoker

// rocks
new                     g_iTankRock             [MAXPLAYERS + 1];                               // rock entity per tank
new                     g_iRocksBeingThrown     [10];                                           // 10 tanks max simultanously throwing rocks should be ok (this stores the tank client)
new                     g_iRocksBeingThrownCount                            = 0;                // so we can do a push/pop type check for who is throwing a created rock

// cvars
new     Handle:         g_hCvarReport                                       = INVALID_HANDLE;   // cvar whether to report at all
new     Handle:         g_hCvarReportFlags                                  = INVALID_HANDLE;   // cvar what to report

new     Handle:         g_hCvarAllowMelee                                   = INVALID_HANDLE;   // cvar whether to count melee skeets
new     Handle:         g_hCvarAllowSniper                                  = INVALID_HANDLE;   // cvar whether to count sniper headshot skeets
new     Handle:         g_hCvarAllowGLSkeet                                 = INVALID_HANDLE;   // cvar whether to count direct hit GL skeets
new     Handle:         g_hCvarDrawCrownThresh                              = INVALID_HANDLE;   // cvar damage in final shot for drawcrown-req.
new     Handle:         g_hCvarSelfClearThresh                              = INVALID_HANDLE;   // cvar damage while self-clearing from smokers
new     Handle:         g_hCvarHunterDPThresh                               = INVALID_HANDLE;   // cvar damage for hunter highpounce
new     Handle:         g_hCvarJockeyDPThresh                               = INVALID_HANDLE;   // cvar distance for jockey highpounce
new     Handle:         g_hCvarHideFakeDamage                               = INVALID_HANDLE;   // cvar damage while self-clearing from smokers

new     Handle:         g_hCvarPounceInterrupt                              = INVALID_HANDLE;   // z_pounce_damage_interrupt
new                     g_iPounceInterrupt                                  = 150;
new     Handle:         g_hCvarChargerHealth                                = INVALID_HANDLE;   // z_charger_health
new     Handle:         g_hCvarWitchHealth                                  = INVALID_HANDLE;   // z_witch_health
new     Handle:         g_hCvarMaxPounceDistance                            = INVALID_HANDLE;   // z_pounce_damage_range_max
new     Handle:         g_hCvarMinPounceDistance                            = INVALID_HANDLE;   // z_pounce_damage_range_min
new     Handle:         g_hCvarMaxPounceDamage                              = INVALID_HANDLE;   // z_hunter_max_pounce_bonus_damage;

/*
    Reports:
    --------
    Damage shown is damage done in the last shot/slash. So for crowns, this means
    that the 'damage' value is one shotgun blast
    

    Quirks:
    -------
    Does not report people cutting smoker tongues that target players other
    than themselves. Could be done, but would require (too much) tracking.
    
    Fake Damage
    -----------
    Hiding of fake damage has the following consequences:
        - Drawcrowns are less likely to be registered: if a witch takes too
          much chip before the crowning shot, the final shot will be considered
          as doing too little damage for a crown (even if it would have been a crown
          had the witch had more health).
        - Charger levels are harder to get on chipped chargers. Any charger that
          has taken (600 - 390 =) 210 damage or more cannot be leveled (even if
          the melee swing would've killed the charger (1559 damage) if it'd have
          had full health).
    I strongly recommend leaving fakedamage visible: it will offer more feedback on
    the survivor's action and reward survivors doing (what would be) full crowns and
    levels on chipped targets.
    
    
    To do
    -----
    - reconsider popping conditions.. distance? if it ever got close?
        after it boomed?
    
    - sir
        - add 's since spawn' to onboomerpop forward
        - add 'm2'd' to onboomerpop forward (bool)
        - make separate teamskeet forward, with (for now, up to) 4 skeeters + the damage each did
    
    detect...
        - ? show meatshots on teammates / report meatshots?
        - ? speedcrown detection?
        - ? bhop (streaks) detection
        - ? deathcharge detection
        - ? " assist detection
        - ? spit-on-cap detection
        - ? insta-clears?
*/

public Plugin:myinfo = 
{
    name = "Skill Detection (skeets, crowns, levels)",
    author = "Tabun",
    description = "Detects and reports skeets, crowns, levels, highpounces, etc.",
    version = PLUGIN_VERSION,
    url = "https://github.com/Tabbernaut/L4D2-Plugins"
}


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    RegPluginLibrary("skill_detect");
    
    g_hForwardSkeet =           CreateGlobalForward("OnSkeet", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardSkeetHurt =       CreateGlobalForward("OnSkeetHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    g_hForwardSkeetMelee =      CreateGlobalForward("OnSkeetMelee", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardSkeetMeleeHurt =  CreateGlobalForward("OnSkeetMeleeHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    g_hForwardSkeetSniper =     CreateGlobalForward("OnSkeetSniperHeadshot", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardSkeetSniperHurt = CreateGlobalForward("OnSkeetSniperHeadshotHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    g_hForwardSkeetGL =         CreateGlobalForward("OnSkeetGL", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardSIShove =         CreateGlobalForward("OnSpecialShoved", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardHunterDeadstop =  CreateGlobalForward("OnHunterDeadstop", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardBoomerPop =       CreateGlobalForward("OnBoomerPop", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardLevel =           CreateGlobalForward("OnChargerLevel", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardLevelHurt =       CreateGlobalForward("OnChargerLevelHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    g_hForwardCrown =           CreateGlobalForward("OnWitchCrown", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardDrawCrown =       CreateGlobalForward("OnWitchDrawCrown", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    g_hForwardTongueCut =       CreateGlobalForward("OnTongueCut", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardSmokerSelfClear = CreateGlobalForward("OnSmokerSelfClear", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    g_hForwardRockSkeeted =     CreateGlobalForward("OnTankRockSkeeted", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardRockEaten =       CreateGlobalForward("OnTankRockEaten", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardHunterDP =        CreateGlobalForward("OnHunterHighPounce", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Float );
    g_hForwardJockeyDP =        CreateGlobalForward("OnJockeyHighPounce", ET_Ignore, Param_Cell, Param_Cell, Param_Float );
    
    g_bLateLoad = late;
    
    return APLRes_Success;
}

public OnPluginStart()
{
    // hooks
    HookEvent("player_spawn",               Event_PlayerSpawn,              EventHookMode_Post);
    HookEvent("player_hurt",                Event_PlayerHurt,               EventHookMode_Pre);
    HookEvent("player_death",               Event_PlayerDeath,              EventHookMode_Pre);
    HookEvent("ability_use",                Event_AbilityUse,               EventHookMode_Post);
    HookEvent("lunge_pounce",               Event_LungePounce,              EventHookMode_Post);
    HookEvent("player_shoved",              Event_PlayerShoved,             EventHookMode_Post);
    HookEvent("player_jump",                Event_PlayerJumped,             EventHookMode_Post);
    
    HookEvent("player_now_it",              Event_PlayerBoomed,             EventHookMode_Post);
    HookEvent("boomer_exploded",            Event_BoomerExploded,           EventHookMode_Post);
    
    //HookEvent("infected_hurt",              Event_InfectedHurt,             EventHookMode_Post);
    HookEvent("witch_spawn",                Event_WitchSpawned,             EventHookMode_Post);
    HookEvent("witch_killed",               Event_WitchKilled,              EventHookMode_Post);
    HookEvent("witch_harasser_set",         Event_WitchHarasserSet,         EventHookMode_Post);
    
    HookEvent("tongue_grab",                Event_TongueGrab,               EventHookMode_Post);
    HookEvent("tongue_pull_stopped",        Event_TonguePullStopped,        EventHookMode_Post);
    HookEvent("jockey_ride",                Event_JockeyRide,               EventHookMode_Post);
    
    // version cvar
    CreateConVar( "sm_skill_detect_version", PLUGIN_VERSION, "Skill detect plugin version.", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD );
    
    // cvars: config
    
    g_hCvarReport = CreateConVar(           "sm_skill_report_enable" ,      "0", "Whether to report in chat (see sm_skill_report_flags).", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarReportFlags = CreateConVar(      "sm_skill_report_flags" ,       REP_DEFAULT, "What to report skeets in chat (bitflags: 1,2:skeets/hurt; 4,8:level/chip; 16,32:crown/draw; 64,128:cut/selfclear, ... ).", FCVAR_PLUGIN, true, 0.0 );
    
    g_hCvarAllowMelee = CreateConVar(       "sm_skill_skeet_allowmelee",    "1", "Whether to count/forward melee skeets.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarAllowSniper = CreateConVar(      "sm_skill_skeet_allowsniper",   "1", "Whether to count/forward sniper/magnum headshots as skeets.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarAllowGLSkeet = CreateConVar(     "sm_skill_skeet_allowgl",       "1", "Whether to count/forward direct GL hits as skeets.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarDrawCrownThresh = CreateConVar(  "sm_skill_drawcrown_damage",  "500", "How much damage a survivor must at least do in the final shot for it to count as a drawcrown.", FCVAR_PLUGIN, true, 0.0, false );
    g_hCvarSelfClearThresh = CreateConVar(  "sm_skill_selfclear_damage",  "200", "How much damage a survivor must at least do to a smoker for him to count as self-clearing.", FCVAR_PLUGIN, true, 0.0, false );
    g_hCvarHunterDPThresh = CreateConVar(   "sm_skill_hunterdp_damage",    "15", "How much damage a hunter must do for his pounce to count as a DP.", FCVAR_PLUGIN, true, 0.0, false );
    g_hCvarJockeyDPThresh = CreateConVar(   "sm_skill_jockeydp_height",   "300", "How much height distance a jockey must make for his 'DP' to count as a reportable highpounce.", FCVAR_PLUGIN, true, 0.0, false );
    g_hCvarHideFakeDamage = CreateConVar(   "sm_skill_hidefakedamage",      "0", "If set, any damage done that exceeds the health of a victim is hidden in reports.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    
    // cvars: built in
    g_hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
    HookConVarChange(g_hCvarPounceInterrupt, CvarChange_PounceInterrupt);
    g_iPounceInterrupt = GetConVarInt(g_hCvarPounceInterrupt);
    
    g_hCvarChargerHealth = FindConVar("z_charger_health");
    g_hCvarWitchHealth = FindConVar("z_witch_health");
    
    g_hCvarMaxPounceDistance = FindConVar("z_pounce_damage_range_max");
    g_hCvarMinPounceDistance = FindConVar("z_pounce_damage_range_min");
    g_hCvarMaxPounceDamage = FindConVar("z_hunter_max_pounce_bonus_damage");
    if ( g_hCvarMaxPounceDistance == INVALID_HANDLE ) { g_hCvarMaxPounceDistance = CreateConVar( "z_pounce_damage_range_max",  "1000.0", "Not available on this server, added by l4d2_skill_detect.", FCVAR_PLUGIN, true, 0.0, false ); }
    if ( g_hCvarMinPounceDistance == INVALID_HANDLE ) { g_hCvarMinPounceDistance = CreateConVar( "z_pounce_damage_range_min",  "300.0", "Not available on this server, added by l4d2_skill_detect.", FCVAR_PLUGIN, true, 0.0, false ); }
    if ( g_hCvarMaxPounceDamage == INVALID_HANDLE ) { g_hCvarMaxPounceDamage = CreateConVar( "z_hunter_max_pounce_bonus_damage",  "49", "Not available on this server, added by l4d2_skill_detect.", FCVAR_PLUGIN, true, 0.0, false ); }
    
    
    // tries
    g_hTrieWeapons = CreateTrie();
    SetTrieValue(g_hTrieWeapons, "hunting_rifle",               WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_military",             WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_awp",                  WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_scout",                WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "pistol_magnum",               WPTYPE_MAGNUM);
    SetTrieValue(g_hTrieWeapons, "grenade_launcher_projectile", WPTYPE_GL);
    
    g_hTrieEntityCreated = CreateTrie();
    SetTrieValue(g_hTrieEntityCreated, "tank_rock",             OEC_TANKROCK);
    SetTrieValue(g_hTrieEntityCreated, "witch",                 OEC_WITCH);
    
    g_hTrieAbility = CreateTrie();
    SetTrieValue(g_hTrieAbility, "ability_lunge",               ABL_HUNTERLUNGE);
    SetTrieValue(g_hTrieAbility, "ability_throw",               ABL_ROCKTHROW);
    
    
    g_hWitchTrie = CreateTrie();
    g_hRockTrie = CreateTrie();
    
    if ( g_bLateLoad )
    {
        for ( new client = 1; client <= MaxClients; client++ )
        {
            if ( IS_VALID_INGAME(client) )
            {
                SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamageByWitch );
            }
        }
    }
}

public CvarChange_PounceInterrupt( Handle:convar, const String:oldValue[], const String:newValue[] )
{
    g_iPounceInterrupt = GetConVarInt(convar);
}

public OnClientPostAdminCheck(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageByWitch);
}

public OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamageByWitch);
}



/*
    Tracking
    --------
*/
public Action: Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast )
{
    g_iRocksBeingThrownCount = 0;
}

public Action: Event_PlayerHurt( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new zClass;
    
    if ( IS_VALID_INFECTED(victim) )
    {
        zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        new health = GetEventInt(event, "health");
        new damage = GetEventInt(event, "dmg_health");
        new damagetype = GetEventInt(event, "type");
        new hitgroup = GetEventInt(event, "hitgroup");
        
        if ( damage < 1 ) { return Plugin_Continue; }
        
        switch ( zClass )
        {
            case ZC_HUNTER:
            {
                // if it's not a survivor doing the work, only get the remaining health
                if ( !IS_VALID_SURVIVOR(attacker) )
                {
                    g_iHunterLastHealth[victim] = health;
                    return Plugin_Continue;
                }
                
                // if the damage done is greater than the health we know the hunter to have remaining, reduce the damage done
                if ( g_iHunterLastHealth[victim] > 0 && damage > g_iHunterLastHealth[victim] )
                {
                    damage = g_iHunterLastHealth[victim];
                    g_iHunterOverkill[victim] = g_iHunterLastHealth[victim] - damage;
                    g_iHunterLastHealth[victim] = 0;
                }
                
                /*  
                    handle old shotgun blast: too long ago? not the same blast
                */
                if ( g_iHunterShotDmg[victim][attacker] > 0 && FloatSub(GetGameTime(), g_fHunterShotStart[victim][attacker]) > SHOTGUN_BLAST_TIME )
                {
                    g_fHunterShotStart[victim][attacker] = 0.0;
                }
                
                /*
                    m_isAttemptingToPounce is set to 0 here if the hunter is actually skeeted
                    so the g_fHunterTracePouncing[victim] value indicates when the hunter was last seen pouncing in traceattack
                    (should be DIRECTLY before this event for every shot).
                */
                new bool: isPouncing = bool:(
                        GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce")     ||
                        g_fHunterTracePouncing[victim] != 0.0 && FloatSub( GetGameTime(), g_fHunterTracePouncing[victim] ) < 0.001
                    );
                
                if ( isPouncing )
                {
                    if ( damagetype & DMG_BUCKSHOT )
                    {
                        // first pellet hit?
                        if ( g_fHunterShotStart[victim][attacker] == 0.0 )
                        {
                            // new shotgun blast
                            g_fHunterShotStart[victim][attacker] = GetGameTime();
                            g_fHunterLastShot[victim] = g_fHunterShotStart[victim][attacker];
                        }
                        g_iHunterShotDmg[victim][attacker] += damage;
                        g_iHunterShotDmgTeam[victim] += damage;
                        
                        if ( health == 0 ) {
                            g_bHunterKilledPouncing[victim] = true;
                        }
                    }
                    else if ( damagetype & (DMG_BLAST | DMG_PLASMA) && health == 0 )
                    {
                        // direct GL hit?
                        /*
                            direct hit is DMG_BLAST | DMG_PLASMA
                            indirect hit is DMG_AIRBOAT
                        */
                        
                        decl String: weaponB[32];
                        new strWeaponType: weaponTypeB;
                        GetEventString(event, "weapon", weaponB, sizeof(weaponB));
                        
                        if ( GetTrieValue(g_hTrieWeapons, weaponB, weaponTypeB) && weaponTypeB == WPTYPE_GL )
                        {
                            if ( GetConVarBool(g_hCvarAllowGLSkeet) ) {
                                HandleSkeet( attacker, victim, false, false, true );
                            }
                        }
                    }
                    else if (   damagetype & DMG_BULLET &&
                                health == 0 &&
                                hitgroup == HITGROUP_HEAD
                    ) {
                        // headshot with bullet based weapon (only single shots) -- only snipers
                        decl String: weaponA[32];
                        new strWeaponType: weaponTypeA;
                        GetEventString(event, "weapon", weaponA, sizeof(weaponA));
                        
                        if (    GetTrieValue(g_hTrieWeapons, weaponA, weaponTypeA) &&
                                (   weaponTypeA == WPTYPE_SNIPER ||
                                    weaponTypeA == WPTYPE_MAGNUM )
                        ) {
                            if ( damage >= g_iPounceInterrupt )
                            {
                                g_iHunterShotDmgTeam[victim] = 0;
                                if ( GetConVarBool(g_hCvarAllowSniper) ) {
                                    HandleSkeet( attacker, victim, false, true );
                                }
                                ResetHunter(victim);
                            }
                            else
                            {
                                // hurt skeet
                                if ( GetConVarBool(g_hCvarAllowSniper) ) {
                                    HandleNonSkeet( attacker, victim, damage, ( g_iHunterOverkill[victim] + g_iHunterShotDmgTeam[victim] > g_iPounceInterrupt ), false, true );
                                }
                                ResetHunter(victim);
                            }
                        }
                        
                        // already handled hurt skeet above
                        //g_bHunterKilledPouncing[victim] = true;
                    }
                    else if ( damagetype & DMG_SLASH || damagetype & DMG_CLUB )
                    {
                        // melee skeet
                        if ( damage >= g_iPounceInterrupt )
                        {
                            g_iHunterShotDmgTeam[victim] = 0;
                            if ( GetConVarBool(g_hCvarAllowMelee) ) {
                                HandleSkeet( attacker, victim, true );
                            }
                            ResetHunter(victim);
                            //g_bHunterKilledPouncing[victim] = true;
                        }
                        else if ( health == 0 )
                        {
                            // hurt skeet (always overkill)
                            if ( GetConVarBool(g_hCvarAllowMelee) ) {
                                HandleNonSkeet( attacker, victim, damage, true, true, false );
                            }
                            ResetHunter(victim);
                        }
                    }
                }
                else if ( health == 0 )
                {
                    // make sure we don't mistake non-pouncing hunters as 'not skeeted'-warnable
                    g_bHunterKilledPouncing[victim] = false;
                }
                
                // store last health seen for next damage event
                g_iHunterLastHealth[victim] = health;
            }
            
            case ZC_CHARGER:
            {
                if ( IS_VALID_SURVIVOR(attacker) )
                {                
                    // check for levels
                    if ( health == 0 && ( damagetype & DMG_CLUB || damagetype & DMG_SLASH ) )
                    {
                        new iChargeHealth = GetConVarInt(g_hCvarChargerHealth);
                        new abilityEnt = GetEntPropEnt( victim, Prop_Send, "m_customAbility" );
                        if ( IsValidEntity(abilityEnt) && GetEntProp(abilityEnt, Prop_Send, "m_isCharging") )
                        {
                            // fix fake damage?
                            if ( GetConVarBool(g_hCvarHideFakeDamage) )
                            {
                                damage = iChargeHealth - g_iChargerHealth[victim];
                            }
                            
                            // charger was killed, was it a full level?
                            if ( damage > (iChargeHealth * 0.65) ) {
                                HandleLevel( attacker, victim );
                            }
                            else {
                                HandleLevelHurt( attacker, victim, damage );
                            }
                        }
                    }
                }
                
                // store health for next damage it takes
                if ( health > 0 )
                {
                    g_iChargerHealth[victim] = health;
                }
            }
            
            case ZC_SMOKER:
            {
                if ( !IS_VALID_SURVIVOR(attacker) ) { return Plugin_Continue; }
                
                g_iSmokerVictimDamage[victim] += damage;
            }
            
        }
    }
    else if ( IS_VALID_INFECTED(attacker) )
    {
        zClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
        
        switch ( zClass )
        {
            case ZC_TANK:
            {
                new String: weapon[10];
                GetEventString(event, "weapon", weapon, sizeof(weapon));
                
                if ( StrEqual(weapon, "tank_rock") )
                {
                    // find rock entity through tank
                    if ( g_iTankRock[attacker] )
                    {
                        // remember that the rock wasn't shot
                        decl String:rock_key[10];
                        FormatEx(rock_key, sizeof(rock_key), "%x", g_iTankRock[attacker]);
                        new rock_array[3];
                        rock_array[rckDamage] = -1;
                        SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
                    }
                    
                    if ( IS_VALID_SURVIVOR(victim) )
                    {
                        HandleRockEaten( attacker, victim );
                    }
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action: Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if ( !IS_VALID_INFECTED(client) ) { return Plugin_Continue; }
    
    new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    switch ( zClass )
    {
        case ZC_BOOMER:
        {
            g_bBoomerHitSomebody[client] = false;
        }
        case ZC_SMOKER:
        {
            g_bSmokerClearCheck[client] = false;
            g_iSmokerVictim[client] = 0;
            g_iSmokerVictimDamage[client] = 0;
        }
        case ZC_HUNTER:
        {
            SDKHook(client, SDKHook_TraceAttack, TraceAttack_Hunter);
    
            g_fPouncePosition[client][0] = 0.0;
            g_fPouncePosition[client][1] = 0.0;
            g_fPouncePosition[client][2] = 0.0;
        }
        case ZC_JOCKEY:
        {
            g_fPouncePosition[client][0] = 0.0;
            g_fPouncePosition[client][1] = 0.0;
            g_fPouncePosition[client][2] = 0.0;
        }
        case ZC_CHARGER:
        {
            g_iChargerHealth[client] = GetConVarInt(g_hCvarChargerHealth);
        }
    }
    
    return Plugin_Continue;
}

// trace attacks on hunters
public Action: TraceAttack_Hunter (victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if ( !IS_VALID_SURVIVOR(attacker) || !IsValidEdict(inflictor) ) { return; }
    
    if ( GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") )
    {
        g_fHunterTracePouncing[victim] = GetGameTime();
    }
    else
    {
        g_fHunterTracePouncing[victim] = 0.0;
    }   
}

public Action: Event_PlayerDeath( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId( GetEventInt(hEvent, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(hEvent, "attacker") ); 
    
    if ( !IS_VALID_INFECTED(victim) ) { return Plugin_Continue; }
    
    new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    
    if ( !IS_VALID_SURVIVOR(attacker) ) { return Plugin_Continue; }
    
    switch ( zClass )
    {
        case ZC_HUNTER:
        {
            if ( g_iHunterShotDmgTeam[victim] > 0 && g_bHunterKilledPouncing[victim] )
            {
                // skeet?
                if (    g_iHunterShotDmgTeam[victim] > g_iHunterShotDmg[victim][attacker] &&
                        g_iHunterShotDmgTeam[victim] >= g_iPounceInterrupt
                ) {
                    // team skeet
                    HandleSkeet( -2, victim );
                }
                else if ( g_iHunterShotDmg[victim][attacker] >= g_iPounceInterrupt )
                {
                    // single player skeet
                    HandleSkeet( attacker, victim );
                }
                else if ( g_iHunterOverkill[victim] > 0 )
                {
                    // overkill? might've been a skeet, if it wasn't on a hurt hunter (only for shotguns)
                    HandleNonSkeet( attacker, victim, g_iHunterShotDmgTeam[victim], ( g_iHunterOverkill[victim] + g_iHunterShotDmgTeam[victim] > g_iPounceInterrupt ) );
                }
                else
                {
                    // not a skeet at all
                    HandleNonSkeet( attacker, victim, g_iHunterShotDmg[victim][attacker] );
                }
            }
            
            ResetHunter(victim);
        }
        
        case ZC_SMOKER:
        {
            if ( g_bSmokerClearCheck[victim] )
            {
                if ( g_iSmokerVictim[victim] == attacker && g_iSmokerVictimDamage[victim] >= GetConVarInt(g_hCvarSelfClearThresh) )
                {
                    HandleSmokerSelfClear( attacker, victim );
                }
            }
            else
            {
                g_bSmokerClearCheck[victim] = false;
                g_iSmokerVictim[victim] = 0;
            }
        }
    }
    
    return Plugin_Continue;
}

public Action: Event_PlayerShoved( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    if ( !IS_VALID_SURVIVOR(attacker) || !IS_VALID_INFECTED(victim) ) { return Plugin_Continue; }
    
    if ( g_fVictimLastShove[victim][attacker] == 0.0 || FloatSub( GetGameTime(), g_fVictimLastShove[victim][attacker] ) > SHOVE_TIME )
    {
        if ( GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") )
        {
            HandleDeadstop( attacker, victim );
        }
        
        HandleShove( attacker, victim );
        
        g_fVictimLastShove[victim][attacker] = GetGameTime();
    }
    
    
    // check for shove on smoker by pull victim
    if ( g_iSmokerVictim[victim] == attacker )
    {
        g_bSmokerShoved[victim] = true;
    }
    
    //PrintDebug(0, "shove by %i on %i", attacker, victim );
    return Plugin_Continue;
}

public Action: Event_LungePounce( Handle:event, const String:name[], bool:dontBroadcast )
{
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    
    // clear hunter-hit stats (not skeeted)
    ResetHunter(client);
    
    // check if it was a DP    
    // ignore if no real pounce start pos
    if ( g_fPouncePosition[client][0] == 0.0 && g_fPouncePosition[client][1] == 0.0 && g_fPouncePosition[client][2] == 0.0 ) { return Plugin_Continue; }
        
    new Float: endPos[3];
    GetClientAbsOrigin( client, endPos );
    new Float: fHeight = g_fPouncePosition[client][2] - endPos[2];
    
    // from pounceannounce:
    // distance supplied isn't the actual 2d vector distance needed for damage calculation. See more about it at
    // http://forums.alliedmods.net/showthread.php?t=93207
    
    new Float: fMin = GetConVarFloat(g_hCvarMinPounceDistance);
    new Float: fMax = GetConVarFloat(g_hCvarMaxPounceDistance);
    new Float: fMaxDmg = GetConVarFloat(g_hCvarMaxPounceDamage);
    
    // calculate 2d distance between previous position and pounce position
    new distance = RoundToNearest( GetVectorDistance(g_fPouncePosition[client], endPos) );
    
    // get damage using hunter damage formula
    // damage in this is expressed as a float because my server has competitive hunter pouncing where the decimal counts
    new Float: fDamage = ( ( (float(distance) - fMin) / (fMax - fMin) ) * fMaxDmg ) + 1.0;
    
    if ( fDamage >= GetConVarFloat(g_hCvarHunterDPThresh) )
    {
        HandleHunterDP( client, victim, fDamage, fHeight );
    }
    
    return Plugin_Continue;
}

public Action: Event_PlayerJumped( Handle:event, const String:name[], bool:dontBroadcast )
{
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    
    if ( !IS_VALID_INFECTED(client) ) { return Plugin_Continue; }
    
    new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( zClass != ZC_JOCKEY ) { return Plugin_Continue; }
    
    // where did jockey jump from?
    GetClientAbsOrigin( client, g_fPouncePosition[client] );
    
    return Plugin_Continue;
}

public Action: Event_JockeyRide( Handle:event, const String:name[], bool:dontBroadcast )
{
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    
    if ( !IS_VALID_INFECTED(client) || !IS_VALID_SURVIVOR(victim) ) { return Plugin_Continue; }
    
    
    // minimum distance travelled?
    // ignore if no real pounce start pos
    if ( g_fPouncePosition[client][0] == 0.0 && g_fPouncePosition[client][1] == 0.0 && g_fPouncePosition[client][2] == 0.0 ) { return Plugin_Continue; }
    
    new Float: endPos[3];
    GetClientAbsOrigin( client, endPos );
    new Float: fHeight = g_fPouncePosition[client][2] - endPos[2];
    
    //PrintToChatAll("jockey height: %.3f", fHeight);
    
    if ( fHeight >= GetConVarFloat(g_hCvarJockeyDPThresh) )
    {
        // high pounce
        HandleJockeyDP( client, victim, fHeight );
    }
    
    return Plugin_Continue;
}

public Action: Event_AbilityUse( Handle:event, const String:name[], bool:dontBroadcast )
{
    // track hunters pouncing
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new String: abilityName[64];
    GetEventString( event, "ability", abilityName, sizeof(abilityName) );
    
    if ( !IS_VALID_INGAME(client) ) { return Plugin_Continue; }
    
    new strAbility: ability;
    if ( !GetTrieValue(g_hTrieAbility, abilityName, ability) ) { return Plugin_Continue; }
    
    switch ( ability )
    {
        case ABL_HUNTERLUNGE:
        {
            // hunter started a pounce
            ResetHunter(client);
            GetClientAbsOrigin( client, g_fPouncePosition[client] );
        }
    
        case ABL_ROCKTHROW:
        {
            // tank throws rock
            g_iRocksBeingThrown[g_iRocksBeingThrownCount] = client;
            
            // safeguard
            if ( g_iRocksBeingThrownCount < 9 ) { g_iRocksBeingThrownCount++; }
        }
    }
    
    return Plugin_Continue;
}

stock ResetHunter(client)
{
    g_iHunterShotDmgTeam[client] = 0;
    
    for ( new i=1; i <= MaxClients; i++ )
    {
        g_iHunterShotDmg[client][i] = 0;
        g_fHunterShotStart[client][i] = 0.0;
    }
    g_iHunterOverkill[client] = 0;
}




// entity creation
public OnEntityCreated ( entity, const String:classname[] )
{
    if ( entity < 1 || !IsValidEntity(entity) || !IsValidEdict(entity) ) { return; }
    
    // track infected / witches, so damage on them counts as hits
    
    new strOEC: classnameOEC;
    if (!GetTrieValue(g_hTrieEntityCreated, classname, classnameOEC)) { return; }
    
    switch ( classnameOEC )
    {
        case OEC_TANKROCK:
        {
            decl String:rock_key[10];
            FormatEx(rock_key, sizeof(rock_key), "%x", entity);
            new rock_array[3];
            
            // store which tank is throwing what rock
            new tank = ShiftTankThrower();
            
            if ( IS_VALID_INGAME(tank) )
            {
                g_iTankRock[tank] = entity;
                rock_array[rckTank] = tank;
            }
            SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
            
            SDKHook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
            SDKHook(entity, SDKHook_Touch, OnTouch_Rock);
        }
    }
}

// entity destruction
public OnEntityDestroyed ( entity )
{
    decl String:witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", entity);
    
    if ( RemoveFromTrie(g_hWitchTrie, witch_key) )
    {
        // witch
        SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost_Witch);
        return;
    }
    
    decl rock_array[3];
    
    if ( GetTrieArray(g_hRockTrie, witch_key, rock_array, sizeof(rock_array)) )
    {
        // tank rock
        CreateTimer( SHOTGUN_BLAST_TIME, Timer_CheckRockSkeet, entity );
        SDKUnhook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
    }
}

public Action: Timer_CheckRockSkeet (Handle:timer, any:rock)
{
    decl rock_array[3];
    decl String: rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", rock);
    if (!GetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array)) ) { return Plugin_Continue; }
    
    RemoveFromTrie(g_hRockTrie, rock_key);
    
    // if rock didn't hit anyone / didn't touch anything, it was shot
    if ( rock_array[rckDamage] > 0 )
    {
        HandleRockSkeeted( rock_array[rckSkeeter], rock_array[rckTank] );
    }
    
    return Plugin_Continue;
}

// boomer got somebody
public Action: Event_PlayerBoomed (Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    new bool: byBoom = GetEventBool(event, "by_boomer");
    
    if ( byBoom && IS_VALID_INFECTED(attacker) )
    {
        g_bBoomerHitSomebody[attacker] = true;
    }
}

// boomers that didn't bile anyone
public Action: Event_BoomerExploded (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new bool: biled = GetEventBool(event, "splashedbile");
    if ( !biled && !g_bBoomerHitSomebody[client] )
    {
        new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
        if ( IS_VALID_SURVIVOR(attacker) )
        {
            HandlePop( attacker, client );
        }
    }
}

// crown tracking
public Action: Event_WitchSpawned ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new witch = GetEventInt(event, "witchid");
    
    SDKHook(witch, SDKHook_OnTakeDamagePost, OnTakeDamagePost_Witch);
    
    new witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    decl String:witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", witch);
    witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = GetConVarInt(g_hCvarWitchHealth);
    SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
}

public Action: Event_WitchKilled ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new witch = GetEventInt(event, "witchid");
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
    SDKUnhook(witch, SDKHook_OnTakeDamagePost, OnTakeDamagePost_Witch);
    
    if ( !IS_VALID_SURVIVOR(attacker) ) { return Plugin_Continue; }
    
    // is it a crown / drawcrown?
    CheckWitchCrown( witch, attacker );
    
    return Plugin_Continue;
}
public Action: Event_WitchHarasserSet ( Handle:event, const String:name[], bool:dontBroadcast )
{
    new witch = GetEventInt(event, "witchid");
    
    decl String:witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", witch);
    decl witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    
    if ( !GetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT) )
    {
        for ( new i = 0; i <= MAXPLAYERS; i++ )
        {
            witch_dmg_array[i] = 0;
        }
        witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = GetConVarInt(g_hCvarWitchHealth);
        witch_dmg_array[MAXPLAYERS+WTCH_STARTLED] = 1;  // harasser set
        SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
    }
    else
    {
        witch_dmg_array[MAXPLAYERS+WTCH_STARTLED] = 1;  // harasser set
        SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
    }
}

/* public Event_InfectedHurt ( Handle:event, const String:name[], bool:dontBroadcast )
{
    // catch damage done to witch
    new entity = GetEventInt(event, "entityid");
    
    if ( IsWitch(entity) )
    {
        new damage = GetEventInt(event, "amount");
        

    }
} */

public Action:OnTakeDamageByWitch ( victim, &attacker, &inflictor, &Float:damage, &damagetype )
{
    // if a survivor is hit by a witch, note it in the witch damage array (maxplayers+2 = 1)
    if ( IS_VALID_SURVIVOR(victim) && damage > 0.0 )
    {
        
        // not a crown if witch hit anyone for > 0 damage
        if ( IsWitch(attacker) )
        {
            decl String:witch_key[10];
            FormatEx(witch_key, sizeof(witch_key), "%x", attacker);
            decl witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
            
            if ( !GetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT) )
            {
                for ( new i = 0; i <= MAXPLAYERS; i++ )
                {
                    witch_dmg_array[i] = 0;
                }
                witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = GetConVarInt(g_hCvarWitchHealth);
                witch_dmg_array[MAXPLAYERS+WTCH_GOTSLASH] = 1;  // failed
                SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
            }
            else
            {
                witch_dmg_array[MAXPLAYERS+WTCH_GOTSLASH] = 1;  // failed
                SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
            }
        }
    }
}

public OnTakeDamagePost_Witch ( victim, attacker, inflictor, Float:damage, damagetype )
{
    // only called for witches, so no check required
    
    decl String:witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", victim);
    decl witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    
    if ( !GetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT) )
    {
        for ( new i = 0; i <= MAXPLAYERS; i++ )
        {
            witch_dmg_array[i] = 0;
        }
        witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = GetConVarInt(g_hCvarWitchHealth);
        SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
    }
    
    // store damage done to witch
    if ( IS_VALID_SURVIVOR(attacker) )
    {
        witch_dmg_array[attacker] += RoundToFloor(damage);
        witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] -= RoundToFloor(damage);
        
        // remember last shot
        if ( g_fWitchShotStart[attacker] == 0.0 || FloatSub(GetGameTime(), g_fWitchShotStart[attacker]) > SHOTGUN_BLAST_TIME )
        {
            // reset last shot damage count and attacker
            g_fWitchShotStart[attacker] = GetGameTime();
            witch_dmg_array[MAXPLAYERS+WTCH_CROWNER] = attacker;
            witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] = 0;
            witch_dmg_array[MAXPLAYERS+WTCH_CROWNTYPE] = ( damagetype & DMG_BUCKSHOT ) ? 1 : 0; // only allow shotguns
        }
        
        // continued blast, add up
        witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] += RoundToFloor(damage);
        
        SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
    }
    else
    {
        // store all chip from other sources than survivor in [0]
        witch_dmg_array[0] += RoundToFloor(damage);
        //witch_dmg_array[MAXPLAYERS+1] -= RoundToFloor(damage);
        SetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
    }
}

stock CheckWitchCrown ( witch, attacker )
{
    decl String:witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", witch);
    decl witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    if ( !GetTrieArray(g_hWitchTrie, witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT) ) { return; }
    
    new chipDamage = 0;
    new iWitchHealth = GetConVarInt(g_hCvarWitchHealth);
    
    /*
        the attacker is the last one that did damage to witch
            if their damage is full damage on an unharrassed witch, it's a full crown
            if their damage is full or > drawcrown_threshhold, it's a drawcrown
    */
    
    // not a crown at all if anyone was hit, or if the killing damage wasn't a shotgun blast
    if ( witch_dmg_array[MAXPLAYERS+WTCH_GOTSLASH] || !witch_dmg_array[MAXPLAYERS+WTCH_CROWNTYPE] ) { return; }
    
    
    // full crown? unharrassed
    if ( !witch_dmg_array[MAXPLAYERS+WTCH_STARTLED] && witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] >= iWitchHealth )
    {
        // make sure that we don't count any type of chip
        if ( GetConVarBool(g_hCvarHideFakeDamage) )
        {
            chipDamage = 0;
            for ( new i = 0; i <= MAXPLAYERS; i++ )
            {
                if ( i == attacker ) { continue; }
                chipDamage += witch_dmg_array[i];
            }
            witch_dmg_array[attacker] = iWitchHealth - chipDamage;
        }
        HandleCrown( attacker, witch_dmg_array[attacker] );
    }
    else if ( witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] >= GetConVarInt(g_hCvarDrawCrownThresh) )
    {
        // draw crown: harassed + over X damage done by one survivor -- in ONE shot
        
        for ( new i = 0; i <= MAXPLAYERS; i++ )
        {
            if ( i == attacker ) {
                // count any damage done before final shot as chip
                chipDamage += witch_dmg_array[i] - witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT];
            } else {
                chipDamage += witch_dmg_array[i];
            }
        }
        
        // make sure that we don't count any type of chip
        if ( GetConVarBool(g_hCvarHideFakeDamage) )
        {
            // unlikely to happen, but if the chip was A LOT
            if ( chipDamage >= iWitchHealth ) {
                chipDamage = iWitchHealth - 1;
                witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] = 1;
            }
            else {
                witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] = iWitchHealth - chipDamage;
            }
            // re-check whether it qualifies as a drawcrown:
            if ( witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] < GetConVarInt(g_hCvarDrawCrownThresh) ) { return; }
        }
        
        // plus, set final shot as 'damage', and the rest as chip
        HandleDrawCrown( attacker, witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT], chipDamage );
    }
}

// tank rock
public Action: TraceAttack_Rock (victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if ( IS_VALID_SURVIVOR(attacker) )
    {
        /*
            can't really use this for precise detection, though it does
            report the last shot -- the damage report is without distance falloff
        */
        decl String:rock_key[10];
        decl rock_array[3];
        FormatEx(rock_key, sizeof(rock_key), "%x", victim);
        GetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array));
        rock_array[rckDamage] += RoundToFloor(damage);
        rock_array[rckSkeeter] = attacker;
        SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
    }
}

public OnTouch_Rock ( entity )
{
    // remember that the rock wasn't shot
    decl String:rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", entity);
    new rock_array[3];
    rock_array[rckDamage] = -1;
    SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
    
    // test
    //PrintToChatAll("rock owner: %i", GetEntProp(entity, Prop_Send, "m_owner") );
    
    SDKUnhook(entity, SDKHook_Touch, OnTouch_Rock);
}

// smoker tongue cutting & self clears
public Action: Event_TonguePullStopped (Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    new smoker = GetClientOfUserId( GetEventInt(event, "smoker") );
    new reason = GetEventInt(event, "release_type");
    
    if ( !IS_VALID_SURVIVOR(attacker) || !IS_VALID_INFECTED(smoker) ) { return Plugin_Continue; }
    
    //PrintDebug(0, "smoker %i: tongue broke (att: %i, vic: %i): reason: %i, shoved: %i", smoker, attacker, victim, reason, g_bSmokerShoved[smoker] );
    
    if ( attacker != victim ) { return Plugin_Continue; }
    
    if ( reason == CUT_KILL )
    {
        g_bSmokerClearCheck[smoker] = true;
    }
    else if ( g_bSmokerShoved[smoker] )
    {
        HandleSmokerSelfClear( attacker, smoker, true );
    }
    else if ( reason == CUT_SLASH ) // note: can't trust this to actually BE a slash..
    {
        // check weapon
        decl String:weapon[32];
        GetClientWeapon( attacker, weapon, 32 );
        
        // this doesn't count the chainsaw, but that's no-skill anyway
        if ( StrEqual(weapon, "weapon_melee", false) )
        {
            HandleTongueCut( attacker, smoker );
        }
    }
    
    return Plugin_Continue;
}

public Action: Event_TongueGrab (Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    
    if ( IS_VALID_INFECTED(attacker) && IS_VALID_SURVIVOR(victim) )
    {
        // new pull, clean damage
        g_bSmokerClearCheck[attacker] = false;
        g_bSmokerShoved[attacker] = false;
        g_iSmokerVictim[attacker] = victim;
        g_iSmokerVictimDamage[attacker] = 0;
    }
    
    return Plugin_Continue;
}

/*
    Reporting and forwards
    ----------------------
*/
// boomer pop
stock HandlePop( attacker, victim )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_POP )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 popped \x05%N\x01.", attacker, victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 popped a boomer.", attacker );
        }
    }
    
    Call_StartForward(g_hForwardBoomerPop);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}

// charger level
stock HandleLevel( attacker, victim )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_LEVEL )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 leveled \x05%N\x01.", attacker, victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 leveled a charger.", attacker );
        }
        else {
            PrintToChatAll( "A charger was leveled." );
        }
    }
    
    // call forward
    Call_StartForward(g_hForwardLevel);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}
// charger level hurt
stock HandleLevelHurt( attacker, victim, damage )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_HURTLEVEL )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 chip-leveled \x05%N\x01 (\x03%i\x01 damage).", attacker, victim, damage );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 chip-leveled a charger. (\x03%i\x01 damage)", attacker, damage );
        }
        else {
            PrintToChatAll( "A charger was chip-leveled (\x03%i\x01 damage).", damage );
        }
    }
    
    // call forward
    Call_StartForward(g_hForwardLevelHurt);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_PushCell(damage);
    Call_Finish();
}

// deadstops
stock HandleDeadstop( attacker, victim )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_DEADSTOP )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 deadstopped \x05%N\x01.", attacker, victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 deadstopped a hunter.", attacker );
        }
    }
    
    Call_StartForward(g_hForwardHunterDeadstop);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}
stock HandleShove( attacker, victim )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_SHOVE )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 shoved \x05%N\x01.", attacker, victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 shoved an SI.", attacker );
        }
    }
    
    Call_StartForward(g_hForwardSIShove);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}

// real skeet
stock HandleSkeet( attacker, victim, bool:bMelee = false, bool:bSniper = false, bool:bGL = false )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_SKEET )
    {
        if ( attacker == -2 )
        {
            // team skeet sets to -2
            if ( IS_VALID_INGAME(victim) && !IsFakeClient(victim) ) {
                PrintToChatAll( "\x05%N\x01 was team-skeeted.", victim );
            } else {
                PrintToChatAll( "\x01A hunter was team-skeeted." );
            }
        }
        else if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 %sskeeted \x05%N\x01.",
                    attacker,
                    (bMelee) ? "melee-": ((bSniper) ? "headshot-" : ((bGL) ? "grenade-" : "") ),
                    victim 
                );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 %sskeeted a hunter.",
                    attacker,
                    (bMelee) ? "melee-": ((bSniper) ? "headshot-" : ((bGL) ? "grenade-" : "") )
                );
        }
    }
    
    // call forward
    if ( bSniper )
    {
        Call_StartForward(g_hForwardSkeetSniper);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
    if ( bSniper )
    {
        Call_StartForward(g_hForwardSkeetGL);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
    else if ( bMelee )
    {
        Call_StartForward(g_hForwardSkeetMelee);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
    else
    {
        Call_StartForward(g_hForwardSkeet);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
}

// hurt skeet / non-skeet
//  NOTE: bSniper not set yet, do this
stock HandleNonSkeet( attacker, victim, damage, bool:bOverKill = false, bool:bMelee = false, bool:bSniper = false )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_HURTSKEET )
    {
        if ( IS_VALID_INGAME(victim) )
        {
            PrintToChatAll( "\x05%N\x01 was \x04not\x01 skeeted (\x03%i\x01 damage).%s", victim, damage, (bOverKill) ? "(Would've skeeted if hunter were unchipped!)" : "" );
        }
        else
        {
            PrintToChatAll( "\x01Hunter was \x04not\x01 skeeted (\x03%i\x01 damage).%s", damage, (bOverKill) ? "(Would've skeeted if hunter were unchipped!)" : "" );
        }
    }
    
    // call forward
    if ( bSniper )
    {
        Call_StartForward(g_hForwardSkeetSniperHurt);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_PushCell(damage);
        Call_PushCell(bOverKill);
        Call_Finish();
    }
    else if ( bMelee )
    {
        Call_StartForward(g_hForwardSkeetMeleeHurt);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_PushCell(damage);
        Call_PushCell(bOverKill);
        Call_Finish();
    }
    else
    {
        Call_StartForward(g_hForwardSkeetHurt);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_PushCell(damage);
        Call_PushCell(bOverKill);
        Call_Finish();
    }
}


// crown
HandleCrown( attacker, damage )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_CROWN )
    {
        if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 crowned a witch (\x03%i\x01 damage).", attacker, damage );
        }
        else {
            PrintToChatAll( "A witch was crowned." );
        }
    }
    
    // call forward
    Call_StartForward(g_hForwardCrown);
    Call_PushCell(attacker);
    Call_PushCell(damage);
    Call_Finish();
}
// drawcrown
HandleDrawCrown( attacker, damage, chipdamage )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_DRAWCROWN )
    {
        if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 draw-crowned a witch (\x03%i\x01 damage, \x05%i\x01 chip).", attacker, damage, chipdamage );
        }
        else {
            PrintToChatAll( "A witch was draw-crowned (\x03%i\x01 damage, \x05%i\x01 chip).", damage, chipdamage );
        }
    }
    
    // call forward
    Call_StartForward(g_hForwardDrawCrown);
    Call_PushCell(attacker);
    Call_PushCell(damage);
    Call_PushCell(chipdamage);
    Call_Finish();
}

// smoker clears
HandleTongueCut( attacker, victim )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_TONGUECUT )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 cut \x05%N\x01's tongue.", attacker, victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 cut smoker tongue.", attacker );
        }
    }
    
    // call forward
    Call_StartForward(g_hForwardTongueCut);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}

HandleSmokerSelfClear( attacker, victim, bool:withShove = false )
{
    // report?
    if (    GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_SELFCLEAR &&
            (!withShove || GetConVarInt(g_hCvarReport) & REP_SELFCLEARSHOVE )
    ) {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 cleared himself from \x05%N\x01's tongue%s.", attacker, victim, (withShove) ? " by shoving" : "" );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 cleared himself from a smoker tongue%s.", attacker, (withShove) ? " by shoving" : "" );
        }
    }
    
    // call forward
    Call_StartForward(g_hForwardSmokerSelfClear);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_PushCell(withShove);
    Call_Finish();
}

// rocks
HandleRockEaten( attacker, victim )
{
    Call_StartForward(g_hForwardRockEaten);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}
HandleRockSkeeted( attacker, victim )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_ROCKSKEET )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
        {
            PrintToChatAll( "\x04%N\x01 skeeted \x05%N\x01's rock.", attacker, victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 skeeted a tank rock.", attacker );
        }
    }
    
    Call_StartForward(g_hForwardRockSkeeted);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}

// highpounces
stock HandleHunterDP( attacker, victim, Float:damage, Float:height )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_HUNTERDP )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 high-pounced \x05%N\x01 (\x03%i\x01 damage, height: \x05%i\x01).", attacker,  victim, RoundToFloor(damage), RoundFloat(height) );
        }
        else if ( IS_VALID_INGAME(victim) )
        {
            PrintToChatAll( "A hunter high-pounced \x05%N\x01 (\x03%i\x01 damage, height: \x05%i\x01).", victim, RoundToFloor(damage), RoundFloat(height) );
        }
    }
    
    Call_StartForward(g_hForwardHunterDP);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_PushFloat(damage);
    Call_PushFloat(height);
    Call_Finish();
}
stock HandleJockeyDP( attacker, victim, Float:height )
{
    // report?
    if ( GetConVarBool(g_hCvarReport) && GetConVarInt(g_hCvarReportFlags) & REP_JOCKEYDP )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 jockey high-pounced \x05%N\x01 (height: \x05%i\x01).", attacker,  victim, RoundFloat(height) );
        }
        else if ( IS_VALID_INGAME(victim) )
        {
            PrintToChatAll( "A jockey high-pounced \x05%N\x01 (height: \x05%i\x01).", victim, RoundFloat(height) );
        }
    }
    
    Call_StartForward(g_hForwardJockeyDP);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_PushFloat(height);
    Call_Finish();
}

// support
// -------
stock ShiftTankThrower()
{
    new tank = -1;
    
    if ( !g_iRocksBeingThrownCount ) { return -1; }
    
    tank = g_iRocksBeingThrown[0];
    
    // shift the tank array downwards, if there are more than 1 throwers
    if ( g_iRocksBeingThrownCount > 1 )
    {
        for ( new x = 1; x <= g_iRocksBeingThrownCount; x++ )
        {
            g_iRocksBeingThrown[x-1] = g_iRocksBeingThrown[x];
        }
    }
    
    g_iRocksBeingThrownCount--;
    
    return tank;
}
stock PrintDebug(debuglevel, const String:Message[], any:... )
{
    decl String:DebugBuff[256];
    VFormat(DebugBuff, sizeof(DebugBuff), Message, 3);
    LogMessage(DebugBuff);
}
stock bool: IsWitch(entity)
{
    if ( !IsValidEntity(entity) ) { return false; }
    
    decl String: classname[24];
    new strOEC: classnameOEC;
    GetEdictClassname(entity, classname, sizeof(classname));
    if ( !GetTrieValue(g_hTrieEntityCreated, classname, classnameOEC) || classnameOEC != OEC_WITCH ) { return false; }
    
    return true;
}
