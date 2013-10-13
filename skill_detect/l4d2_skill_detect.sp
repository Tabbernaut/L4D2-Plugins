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
 *      OnHighPounce( hunter, victim, damage )
 *      OnDeathCharge( charger, victim )
 *      OnRockSkeeted( survivor )
 *      OnTongueCut( survivor, victim )
 *
 *  Where survivor == -2 if it was a team skeet, -1 or 0 if unknown or invalid client.
 *  damage is the amount of damage done (that didn't add up to skeeting damage),
 *  and isOverkill indicates whether the shot would've been a skeet if the hunter
 *  had not been chipped.
 *
 *  @author         Tabun
 *  @libraryname    skill_detect
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION "0.9.1"

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

#define SHOTGUN_BLAST_TIME  0.1
#define POUNCE_CHECK_TIME   0.1
#define SHOVE_TIME          0.1

#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_CHARGER      6
#define HITGROUP_HEAD   1

#define DMG_CRUSH               (1 << 0)        // crushed by falling or moving object. 
#define DMG_BULLET              (1 << 1)        // shot
#define DMG_SLASH               (1 << 2)        // cut, clawed, stabbed
#define DMG_CLUB                (1 << 7)        // crowbar, punch, headbutt
#define DMG_BUCKSHOT            (1 << 29)       // not quite a bullet. Little, rounder, different. 

// trie values: weapon type
enum _:strWeaponType
{
    WPTYPE_SNIPER,
    WPTYPE_MAGNUM
};

// trie values: OnEntityCreated classname
enum strOEC
{
    OEC_TONGUE,
    OEC_TANKROCK
};

new     Handle:         g_hForwardSkeet                                     = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetHurt                                 = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetMelee                                = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetMeleeHurt                            = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetSniper                               = INVALID_HANDLE;
new     Handle:         g_hForwardSkeetSniperHurt                           = INVALID_HANDLE;
new     Handle:         g_hForwardHunterDeadstop                            = INVALID_HANDLE;
new     Handle:         g_hForwardSIShove                                   = INVALID_HANDLE;
new     Handle:         g_hForwardBoomerPop                                 = INVALID_HANDLE;
new     Handle:         g_hForwardLevel                                     = INVALID_HANDLE;
new     Handle:         g_hForwardLevelHurt                                 = INVALID_HANDLE;


new     Handle:         g_hTrieWeapons                                      = INVALID_HANDLE;
new     Handle:         g_hTrieEntityCreated                                = INVALID_HANDLE;   // trie for getting classname of entity created

// skeets
new                     g_iHunterShotDmgTeam    [MAXPLAYERS + 1];                               // counting shotgun blast damage for hunter, counting entire survivor team's damage
new                     g_iHunterShotDmg        [MAXPLAYERS + 1][MAXPLAYERS + 1];               // counting shotgun blast damage for hunter / skeeter combo
new     Float:          g_fHunterShotStart      [MAXPLAYERS + 1][MAXPLAYERS + 1];               // when the last shotgun blast on hunter started (if at any time) by an attacker
new     Float:          g_fHunterLastShot       [MAXPLAYERS + 1];                               // when the last shotgun damage was done (by anyone) on a hunter
new     bool:           g_bHunterPouncing       [MAXPLAYERS + 1];                               // whether the hunter should be considered pouncing with lame onground check (only for snipers)
new     bool:           g_bHunterPouncingShot   [MAXPLAYERS + 1];                               // whether the shotgun should be considered to be pouncing when damage-checking
new                     g_iHunterLastHealth     [MAXPLAYERS + 1];                               // last time hunter took any damage, how much health did it have left?
new                     g_iHunterOverkill       [MAXPLAYERS + 1];                               // how much more damage a hunter would've taken if it wasn't already dead
new     bool:           g_bHunterKilledPouncing [MAXPLAYERS + 1];                               // whether the hunter was killed when actually pouncing

// deadstops
new     Float:          g_fVictimLastShove      [MAXPLAYERS + 1];                               // when was the player shoved last? (to prevent doubles)

// pops
new                     g_bBoomerHitSomebody    [MAXPLAYERS + 1];                               // false if boomer didn't puke/exploded on anybody

// levels
new     bool:           g_bChargerCharging      [MAXPLAYERS + 1];                               // false if boomer didn't puke/exploded on anybody

new     Handle:         g_hCvarReportSkeets                                 = INVALID_HANDLE;   // cvar whether to report skeets
new     Handle:         g_hCvarReportNonSkeets                              = INVALID_HANDLE;   // cvar whether to report non-/hurt skeets
new     Handle:         g_hCvarReportLevels                                 = INVALID_HANDLE;
new     Handle:         g_hCvarReportLevelsHurt                             = INVALID_HANDLE;
new     Handle:         g_hCvarReportDeadstops                              = INVALID_HANDLE;

new     Handle:         g_hCvarAllowMelee                                   = INVALID_HANDLE;   // cvar whether to count melee skeets
new     Handle:         g_hCvarAllowSniper                                  = INVALID_HANDLE;   // cvar whether to count sniper headshot skeets

new     Handle:         g_hCvarPounceInterrupt                              = INVALID_HANDLE;   // z_pounce_damage_interrupt
new                     g_iPounceInterrupt                                  = 150;
new     Handle:         g_hCvarChargerHealth                                = INVALID_HANDLE;   // z_charger_health

/*
    To do
    -----
    
    - witch crown detection
    - witch drawcrown/hurtcrown detection (how precisely?)
            - shot by surv X, then final damage done in blast > 700 by X
    
    - highpounce detection
    - tongue cuts
    
    - timeout handling for m2s / deadstops: only count it once per 0.1 sec for surv-hunt combo

*/

public Plugin:myinfo = 
{
    name = "Skill Detection (skeets, crowns, levels)",
    author = "Tabun",
    description = "Detects and reports skeets, crowns, levels, highpounces, deathcharges.",
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
    
    g_hForwardSIShove =         CreateGlobalForward("OnSpecialShoved", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardHunterDeadstop =  CreateGlobalForward("OnHunterDeadstop", ET_Ignore, Param_Cell, Param_Cell );
    
    g_hForwardBoomerPop =       CreateGlobalForward("OnBoomerPop", ET_Ignore, Param_Cell, Param_Cell );
    
    g_hForwardLevel =           CreateGlobalForward("OnChargerLevel", ET_Ignore, Param_Cell, Param_Cell );
    g_hForwardLevelHurt =       CreateGlobalForward("OnChargerLevelHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    
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
    
    HookEvent("player_now_it",              Event_PlayerBoomed,             EventHookMode_Post);
    HookEvent("boomer_exploded",            Event_BoomerExploded,           EventHookMode_Post);
    
    HookEvent("charger_charge_start",       Event_ChargeStart,              EventHookMode_Post);
    HookEvent("charger_charge_end",         Event_ChargeEnd,                EventHookMode_Post);
    
    
    // version cvar
    CreateConVar( "skill_detect_version", PLUGIN_VERSION, "Skill detect plugin version.", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD );
    
    g_hCvarReportSkeets = CreateConVar(     "skill_report_skeet" ,      "0", "Whether to report skeets in chat.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarReportNonSkeets = CreateConVar(  "skill_report_hurtskeet",   "0", "Whether to report hurt/failed skeets in chat.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarReportLevels = CreateConVar(     "skill_report_level" ,      "0", "Whether to report charger levels in chat.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarReportLevelsHurt = CreateConVar( "skill_report_hurtlevel",   "0", "Whether to report chipped levels in chat.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    
    g_hCvarReportDeadstops = CreateConVar(  "skill_report_deadstop" ,   "0", "Whether to report deadstops in chat.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    
    g_hCvarAllowMelee = CreateConVar(       "skill_skeet_allowmelee",   "1", "Whether to count/forward melee skeets.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    g_hCvarAllowSniper = CreateConVar(      "skill_skeet_allowsniper",  "1", "Whether to count/forward sniper/magnum headshots as skeets.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    
    
    // cvars
    g_hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
    HookConVarChange(g_hCvarPounceInterrupt, CvarChange_PounceInterrupt);
    g_iPounceInterrupt = GetConVarInt(g_hCvarPounceInterrupt);
    
    g_hCvarChargerHealth = FindConVar("z_charger_health");
    
    // tries
    g_hTrieWeapons = CreateTrie();
    SetTrieValue(g_hTrieWeapons, "hunting_rifle",       WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_military",     WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_awp",          WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_scout",        WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "pistol_magnum",       WPTYPE_MAGNUM);
    
    g_hTrieEntityCreated = CreateTrie();
    SetTrieValue(g_hTrieEntityCreated, "ability_tongue",    OEC_TONGUE);
    SetTrieValue(g_hTrieEntityCreated, "tank_rock",         OEC_TANKROCK);
}

public CvarChange_PounceInterrupt( Handle:convar, const String:oldValue[], const String:newValue[] )
{
	g_iPounceInterrupt = GetConVarInt(convar);
}


public Event_PlayerHurt( Handle:event, const String:name[], bool:dontBroadcast )
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    if ( IS_VALID_INFECTED(victim) )
    {
        new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        new health = GetEventInt(event, "health");
        new damage = GetEventInt(event, "dmg_health");
        new damagetype = GetEventInt(event, "type");
        new hitgroup = GetEventInt(event, "hitgroup");
        
        if ( damage < 1 ) { return; }
        
        switch ( zClass )
        {
            case ZC_HUNTER:
            {
                // if it's not a survivor doing the work, only get the remaining health
                if ( !IS_VALID_SURVIVOR(attacker) )
                {
                    g_iHunterLastHealth[victim] = health;
                    return;
                }
                
                // if the damage done is greater than the health we know the hunter to have remaining, reduce the damage done
                if ( g_iHunterLastHealth[victim] > 0 && damage > g_iHunterLastHealth[victim] )
                {
                    damage = g_iHunterLastHealth[victim];
                    g_iHunterOverkill[victim] = g_iHunterLastHealth[victim] - damage;
                    g_iHunterLastHealth[victim] = 0;
                }
                
                /*  
                    handle old shotgun blast: previous shotgun damage done by a player that was too long ago to be still this (new) blast
                    g_bHunterPouncingShot[] is used to remember whether the first pellet of a blast did damage while the hunter was
                    still pouncing: if the last pellet (killing the hunter) reports as not pouncing, it's NOT TRUE. LIES.
                    this must be reset whenever a new shotgun blast takes place (no matter who shoots this)
                */
                if ( g_iHunterShotDmg[victim][attacker] > 0 && FloatSub(GetGameTime(), g_fHunterShotStart[victim][attacker]) > SHOTGUN_BLAST_TIME )
                {
                    g_bHunterPouncingShot[victim] = false;
                    g_fHunterShotStart[victim][attacker] = 0.0;
                }
                else if ( FloatSub(GetGameTime(), g_fHunterLastShot[victim]) > SHOTGUN_BLAST_TIME )
                {
                    // make sure any shotgun damage from other attackers will also reset
                    g_bHunterPouncingShot[victim] = false;
                }
                
                new bool: isPouncingShotgun = bool: ( g_bHunterPouncingShot[victim] || GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") );
                
                /*
                    handle new hit (only shotgun), and only on pouncing hunters
                    flag is reset before killing damage is actually recorded, so count the remaining shotgun blast
                */
                if ( g_bHunterPouncing[victim] || isPouncingShotgun )
                {
                    if ( damagetype & DMG_BUCKSHOT && isPouncingShotgun )
                    {
                        // first pellet hit?
                        if ( g_fHunterShotStart[victim][attacker] == 0.0 )
                        {
                            // new shotgun blast
                            g_fHunterShotStart[victim][attacker] = GetGameTime();
                            g_fHunterLastShot[victim] = g_fHunterShotStart[victim][attacker];
                            g_bHunterPouncingShot[victim] = ( GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") > 0);
                        }
                        g_iHunterShotDmg[victim][attacker] += damage;
                        g_iHunterShotDmgTeam[victim] += damage;
                        
                        if ( health == 0 ) {
                            g_bHunterKilledPouncing[victim] = true;
                        }
                    }
                    else if (   damagetype & DMG_BULLET &&
                                health == 0 &&
                                hitgroup == HITGROUP_HEAD
                    ) {
                        // headshot with bullet based weapon (only single shots) -- only snipers
                        
                        new String: weapon[32];
                        GetEventString(event, "weapon", weapon, sizeof(weapon));
                        
                        new strWeaponType: weaponType;
                        if ( GetTrieValue(g_hTrieWeapons, weapon, weaponType) )
                        {
                            // no need to check further, only magnum & snipers are in the trie
                            
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
                // check for levels
                if ( g_bChargerCharging[victim] && health == 0 && ( damagetype & DMG_CLUB || damagetype & DMG_SLASH ) )
                {
                    // charger was killed, was it a full level?
                    if ( damage >=  GetConVarInt(g_hCvarChargerHealth) ) {
                        HandleLevel( attacker, victim );
                    }
                    else {
                        HandleLevelHurt( attacker, victim, damage );
                    }
                }
            }
        }
    }
}

public Action: Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if ( !IS_VALID_INFECTED(client) ) { return; }
    
    new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( zClass == ZC_BOOMER )
    {
        g_bBoomerHitSomebody[client] = false;
    }
    else if ( zClass == ZC_CHARGER )
    {
        g_bChargerCharging[client] = false;
    }
}

public Action: Event_PlayerDeath(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId( GetEventInt(hEvent, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(hEvent, "attacker") ); 
    
    if ( !IS_VALID_INFECTED(victim) ) { return Plugin_Continue; }
    
    new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    
    if ( zClass == ZC_HUNTER && IS_VALID_SURVIVOR(attacker) )
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
    
    return Plugin_Continue;
}

public Event_PlayerShoved(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    if ( !IS_VALID_SURVIVOR(attacker) || !IS_VALID_INFECTED(victim) ) { return; }
    
    if ( g_fVictimLastShove[victim] == 0.0 || FloatSub( GetGameTime(), g_fVictimLastShove[victim] ) > SHOVE_TIME )
    {
        if ( g_bHunterPouncing[victim] || GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") )
        {
            HandleDeadstop( attacker, victim );
        }
        
        HandleShove( attacker, victim );
    }
    
    g_fVictimLastShove[victim] = GetGameTime();
}

public Event_LungePounce(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );

    // clear hunter-hit stats (not skeeted)
    ResetHunter(attacker);
}

public Event_AbilityUse( Handle:event, const String:name[], bool:dontBroadcast )
{
    // track hunters pouncing
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new String: abilityName[64];
    GetEventString( event, "ability", abilityName, sizeof(abilityName) );
    
    if ( IS_VALID_INGAME(client) && strcmp(abilityName, "ability_lunge", false) == 0 )
    {
        // hunter started a pounce
        ResetHunter(client);
        g_bHunterPouncing[client] = true;
        CreateTimer( POUNCE_CHECK_TIME, Timer_HunterGroundTouch, client, TIMER_REPEAT );
    }
}

public Action: Timer_HunterGroundTouch( Handle:timer, any:client )
{
    /*
        note: a new timer gets started every time a hunter pounces
        but it is only killed once it actually hits the ground again!
        this might create too many timers when a hunter actually pounces
        around on walls.. build a safeguard to prevent this?
    
        static countTimes = 0;
        
        countTimes++;
        
        if ( countTimes > 150 ) {
            // reached the ground or died in mid-air
            countTimes = 0;
            KillTimer( timer );
        }
        // else...
    */
    
    if (    IS_VALID_INGAME(client) &&
            (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND > 0 ||
            !IsPlayerAlive(client))
    ) {
        // reached the ground or died in mid-air
        ResetHunter( client );
        KillTimer( timer );
    }
}

stock ResetHunter(client)
{
    g_iHunterShotDmgTeam[client] = 0;
    
    for ( new i=1; i <= MaxClients; i++ )
    {
        g_iHunterShotDmg[client][i] = 0;
        g_fHunterShotStart[client][i] = 0.0;
    }
    
    g_bHunterPouncingShot[client] = false;
    g_bHunterPouncing[client] = false;
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
        case OEC_TONGUE:
        {
            //SDKHook(entity, SDKHook_TraceAttack, TraceAttack_Infected);
        }
    }
}

// boomer got somebody
public Event_PlayerBoomed (Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    new bool: byBoom = GetEventBool(event, "by_boomer");
    
    if ( byBoom && IS_VALID_INFECTED(attacker) )
    {
        g_bBoomerHitSomebody[attacker] = true;
    }
}

// boomers that didn't bile anyone
public Event_BoomerExploded (Handle:event, const String:name[], bool:dontBroadcast)
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

// charge tracking
public Event_ChargeStart (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    g_bChargerCharging[client] = true;
}
public Event_ChargeEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    g_bChargerCharging[client] = false;
}
// boomer pop
stock HandlePop( attacker, victim )
{
    // report?
    /*
    if ( GetConVarBool(g_hCvarReportPops) )
    {
        if ( attacker == -2 )
        {
            // team skeet sets to -2
            if ( IS_VALID_INGAME(victim) ) {
                PrintToChatAll( "\x05%N\x01 was team-skeeted.", victim );
            } else {
                PrintToChatAll( "\x01A hunter was team-skeeted." );
            }
        }
        else if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) )
        {
            PrintToChatAll( "\x04%N\x01 %sskeeted \x05%N\x01.", attacker, (bMelee) ? "melee-": ((bSniper) ? "headshot-" : ""), victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 %sskeeted a hunter.", attacker, (bMelee) ? "melee-": ((bSniper) ? "headshot-" : "") );
        }
    }
    */
    
    Call_StartForward(g_hForwardBoomerPop);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}

// charger level
stock HandleLevel( attacker, victim )
{
    // report?
    if ( GetConVarBool(g_hCvarReportLevels) )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) )
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
    if ( GetConVarBool(g_hCvarReportLevelsHurt) )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) )
        {
            PrintToChatAll( "\x04%N\x01 chip-leveled \x05%N\x01 (\x03%i\x01 damage).", attacker, victim, damage );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 leveled a charger. (\x03%i\x01 damage)", attacker, damage );
        }
        else {
            PrintToChatAll( "A charger was leveled (\x03%i\x01 damage).", damage );
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
    if ( GetConVarBool(g_hCvarReportDeadstops) )
    {
        if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) )
        {
            PrintToChatAll( "\x04%N\x01 deadstopped \x05%N\x01.", attacker, victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 deadstopped a hunter.", attacker );
        }
        /*else {
            PrintToChatAll( "A hunter was deadstopped." );
        }*/
    }
    
    Call_StartForward(g_hForwardHunterDeadstop);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}
stock HandleShove( attacker, victim )
{
    Call_StartForward(g_hForwardSIShove);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}

// real skeet
stock HandleSkeet( attacker, victim, bool:bMelee = false, bool:bSniper = false )
{
    // report?
    if ( GetConVarBool(g_hCvarReportSkeets) )
    {
        if ( attacker == -2 )
        {
            // team skeet sets to -2
            if ( IS_VALID_INGAME(victim) ) {
                PrintToChatAll( "\x05%N\x01 was team-skeeted.", victim );
            } else {
                PrintToChatAll( "\x01A hunter was team-skeeted." );
            }
        }
        else if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) )
        {
            PrintToChatAll( "\x04%N\x01 %sskeeted \x05%N\x01.", attacker, (bMelee) ? "melee-": ((bSniper) ? "headshot-" : ""), victim );
        }
        else if ( IS_VALID_INGAME(attacker) )
        {
            PrintToChatAll( "\x04%N\x01 %sskeeted a hunter.", attacker, (bMelee) ? "melee-": ((bSniper) ? "headshot-" : "") );
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
    if ( GetConVarBool(g_hCvarReportNonSkeets) )
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
