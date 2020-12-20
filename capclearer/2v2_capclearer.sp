#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#define SOUND_CLEARED "/ui/critical_event_1.wav"

const TEAM_SURVIVOR = 2;

new Handle: hCvarDebug;

// The damage done to the survivors at the time they are double-capped.
// If a survivor is already incapped, they don't receive this damage.
new Handle: hCvarFixedDamageOnUprightSurvivorCapped;

// Delay after domination starts before checking whether we should clear.
new Handle: hCvarDelayBeforeCheckingToclearDominators;

// The amount of times that the survivors can be cleared each round.
// The next full cap after this means death.
new Handle: hCvarMaximumClearsPerRound;

// Whether we should clear the dominators when only one remaining survivor is dominated and the others are all incapped.
new Handle: hCvarClearDominatorWhenOneSurvivorIsUpright;

// Whether we should clear the dominators when only one survivor is left alive.
new Handle: hCvarClearDominatorWhenOneSurvivorIsAlive;

// Whether, when we're freeing the upright survivor, we should also clear other dominators from incapped survivors.
new Handle: hCvarClearDominatorFromIncappedSurvivor;

// By whom the given survivor player is currently dominated (capped) by.
new iPlayerDominatedBy[MAXPLAYERS+1];

// Amount of clears still possible this round (ignored if -1)
new iClearsLeftThisRound = -1;

public Plugin:myinfo =
{
    name = "2v2 Double-Cap Clearer",
    author = "Tabun",
    description = "A plugin that prevents double-caps from ending (2v2) rounds instantly",
    version = "0.0.1",
    url = "https://github.com/Tabbernault/l4d2-plugins"
};

/*
    To Do
        - maybe: different possible punishments
            - points: penalty bonus
            - damage
            - boomed / horde
            - teleport to start saferoom? (ugh)

        - make it clearer that the caps are cleared deliberately
            maybe some visual effect? sparkles? magic twinklies? hmm.
*/

public OnPluginStart()
{
    hCvarDebug = CreateConVar("capclear_debug", "0",
        "Debug mode. (0: only error reporting, -1: disable all reports, 1+: set debug report level).",
        FCVAR_NONE, true, -1.0);
    hCvarDelayBeforeCheckingToclearDominators = CreateConVar("capclear_check_delay", "0.5",
        "Delay in seconds before check & clear when a survivor is dominated.",
        FCVAR_NONE, true, 0.0);
    hCvarFixedDamageOnUprightSurvivorCapped = CreateConVar("capclear_punish_damage", "33",
        "Amount of damage done (at once) before SI suicides to upright survivors on double-cap.",
        FCVAR_NONE, true, 0.0);
    hCvarMaximumClearsPerRound = CreateConVar("capclear_maximum_clears", "3",
        "After this many clears, the survivors will not be cleared again this round (0 for no limit).",
        FCVAR_NONE, true, 0.0);
    hCvarClearDominatorWhenOneSurvivorIsUpright = CreateConVar("capclear_clear_last_upright", "1",
        "Whether the last upright survivor should be cleared when dominated as others are incapped.",
        FCVAR_NONE, true, 0.0);
    hCvarClearDominatorWhenOneSurvivorIsAlive = CreateConVar("capclear_clear_last_alive", "0",
        "Whether the last living survivor should be cleared when dominated.",
        FCVAR_NONE, true, 0.0);
    hCvarClearDominatorFromIncappedSurvivor = CreateConVar("capclear_clear_from_incapped", "0",
        "Whether we should also clear the dominator from incapped survivors aswell.",
        FCVAR_NONE, true, 0.0);

    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    HookEvent("lunge_pounce", Event_DominationStart, EventHookMode_Post);
    HookEvent("pounce_stopped", Event_DominationEnd, EventHookMode_Post);
    HookEvent("jockey_ride", Event_DominationStart, EventHookMode_Post);
    HookEvent("jockey_ride_end", Event_DominationEnd, EventHookMode_Post);
    HookEvent("charger_pummel_start", Event_DominationStart, EventHookMode_Post);
    HookEvent("charger_pummel_end", Event_DominationEnd, EventHookMode_Post);
    HookEvent("choke_start", Event_DominationStart, EventHookMode_Post);
    HookEvent("tongue_release", Event_DominationEnd, EventHookMode_Post);
    HookEvent("choke_stopped", Event_DominationEnd, EventHookMode_Post);

    HookEvent("player_ledge_grab", Event_PlayerIncapacitated, EventHookMode_Post);
    HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public OnMapStart()
{
    PrecacheSound(SOUND_CLEARED);

    ClearDominatedByStatus();
    ResetClearCount();
}

// -------------------------------
//      Events
// -------------------------------

public Action: Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    ClearDominatedByStatus();
    ResetClearCount();
}

public Action: Event_DominationStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim   = GetClientOfUserId(GetEventInt(event, "victim"));
    new attacker = GetClientOfUserId(GetEventInt(event, "userid"));

    if (! victim || ! attacker) {
        return;
    }

    PrintDebug(5, "[2v2cap] Domination START survivor %i, infected %i", victim, attacker);
    HandleSurvivorDominatedBy(victim, attacker);
}

public Action: Event_DominationEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim   = GetClientOfUserId(GetEventInt(event, "victim"));
    new attacker = GetClientOfUserId(GetEventInt(event, "userid"));

    if (! victim) {
        return;
    }

    PrintDebug(5, "[2v2cap] Domination END survivor %i, infected %i", victim, attacker);
    HandleSurvivorCleared(victim);
}

public Action: Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    CheckIfWeNeedToClearDominators();
}

public Action: Event_PlayerIncapacitated(Handle:event, const String:name[], bool:dontBroadcast)
{
    CheckIfWeNeedToClearDominators();
}


// -------------------------------
//      Dominator Handling
// -------------------------------

void ClearDominatedByStatus()
{
    for (new i = 1; i <= MaxClients; i++) {
        iPlayerDominatedBy[i] = -1;
    }
}

void ResetClearCount()
{
    iClearsLeftThisRound = GetConVarInt(hCvarMaximumClearsPerRound);

    if (iClearsLeftThisRound == 0) {
        iClearsLeftThisRound = -1;
    }
}

void HandleSurvivorDominatedBy(survivor, infected)
{
    iPlayerDominatedBy[survivor] = infected;

    CheckIfWeNeedToClearDominators();
}

void HandleSurvivorCleared(survivor)
{
    iPlayerDominatedBy[survivor] = -1;
}

void CheckIfWeNeedToClearDominators()
{
    float fDelay = GetConVarFloat(hCvarDelayBeforeCheckingToclearDominators);

    if (fDelay < 0.05) {
        CheckIfWeNeedToClearDominatorsNow();
        return;
    }

    CreateTimer(fDelay, DelayedCheckIfWeNeedToClearDominators_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:DelayedCheckIfWeNeedToClearDominators_Timer(Handle:timer)
{
    CheckIfWeNeedToClearDominatorsNow();
}

void CheckIfWeNeedToClearDominatorsNow()
{
    if (! ShouldDominatorsBeClearedFromSurvivors()) {
        return;
    }

    ClearDominatorsAndPunishSurvivors();
}

bool: ShouldDominatorsBeClearedFromSurvivors()
{
    if (iClearsLeftThisRound == 0) {
        PrintDebug(3, "[2v2cap] Not clearing because the maximum number of clears were done.");
        return false;
    }

    new iSurvivorCount                = 0;
    new iDominatedCount               = 0;
    new iDominatedAndUprightCount     = 0;
    new iNotDominatedButIncappedCount = 0;
    new iDeadCount                    = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (! IsSurvivor(i)) {
            continue;
        }

        iSurvivorCount++;

        if (! IsPlayerAlive(i)) {
            iDeadCount++;
            continue;
        }

        // If even one survivor is free and upright, nothing to do!
        if (! IsPlayerDominated(i) && ! IsPlayerIncapacitated(i)) {
            PrintDebug(3, "[2v2cap] Not clearing because at least one survivor is not dominated and upright");
            return false;
        }

        if (IsPlayerDominated(i)) {
            iDominatedCount++;

            if (! IsPlayerIncapacitated(i)) {
                iDominatedAndUprightCount++;
            }

            continue;
        }

        if (IsPlayerIncapacitated(i)) {
            iNotDominatedButIncappedCount++;
        }
    }

    PrintDebug(7, "[2v2cap] %i survivors; %i dominated upright; %i dominated total; %i incapped (not dominated); %i dead", iSurvivorCount, iDominatedAndUprightCount, iDominatedCount, iNotDominatedButIncappedCount, iDeadCount);

    // If there are no survivors at all, ignore.
    if (iSurvivorCount == 0) {
        PrintDebug(2, "[2v2cap] Not clearing because there are no survivors");
        return false;
    }

    // If more than one upright survivor is capped, then always clear.
    if (iDominatedAndUprightCount > 1) {
        PrintDebug(2, "[2v2cap] Clearing because more than 1 survivor is dominated & upright");
        return true;
    }

    // Only one upright survivor is being dominated.

    // If none of the survivors are incapped or otherwise alive, then the dominated survivor is the last alive.
    if (iNotDominatedButIncappedCount + (iDominatedCount - iDominatedAndUprightCount) == 0) {
        PrintDebug(2, "[2v2cap] Clearing (or not) depending on 'capclear_clear_last_alive' cvar");
        return GetConVarBool(hCvarClearDominatorWhenOneSurvivorIsAlive);
    }

    // Otherwise, the remaining survivors not dominated are incapped.
    PrintDebug(2, "[2v2cap] Clearing (or not) depending on 'capclear_clear_last_upright' cvar");
    return GetConVarBool(hCvarClearDominatorWhenOneSurvivorIsUpright);
}

void ClearDominatorsAndPunishSurvivors()
{
    iClearsLeftThisRound--;

    ReportCleared();


    EmitSoundToAll(SOUND_CLEARED, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.75);

    for (new i = 1; i <= MaxClients; i++) {
        if (! IsSurvivor(i) || iPlayerDominatedBy[i] == -1) {
            continue;
        }

        if (IsPlayerIncapacitated(i) && ! GetConVarBool(hCvarClearDominatorFromIncappedSurvivor)) {
            continue;
        }

        PunishSurvivorDominatedBy(i, iPlayerDominatedBy[i]);
        KillDominatorAndReportRemainingHealth(iPlayerDominatedBy[i]);
    }
}

void PunishSurvivorDominatedBy(survivor, infected)
{
    if (IsPlayerIncapacitated(survivor)) {
        return;
    }

    new iDamageToDo    = GetConVarInt(hCvarFixedDamageOnUprightSurvivorCapped);
    new iCurrentHealth = GetClientHealth(survivor);

    if (iCurrentHealth <= iDamageToDo) {
        iDamageToDo = iCurrentHealth - 1;
    }

    // Note: this means that when a survivor has 1 health, he's basically immune to domination...
    // let's try it out like this for now. Maybe you want a 1 health survivor to just get incapped on being dominated.
    if (iDamageToDo > 0) {
        ApplyDamageToPlayer(iDamageToDo, survivor, infected);
    }
}

void KillDominatorAndReportRemainingHealth(infected)
{
    new iRemainingHealth = GetClientHealth(infected);

    CPrintToChatAll(
        "[{olive}capclear{default}] {red}%N{default} had {olive}%d{default} health remaining.",
        infected, iRemainingHealth
    );

    ForcePlayerSuicide(infected);
}

void ApplyDamageToPlayer(damage, victim, attacker)
{
    PrintDebug(4, "[2v2cap] Applying %d punish damage to client %i", damage, victim);

    decl Float: victimPos[3];
    decl String: strDamage[16];
    decl String: strDamageTarget[16];

    GetClientEyePosition(victim, victimPos);
    IntToString(damage, strDamage, sizeof(strDamage));
    Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);

    new entPointHurt = CreateEntityByName("point_hurt");
    if (!entPointHurt) {
        return;
    }

    // Config, create point_hurt
    DispatchKeyValue(victim, "targetname", strDamageTarget);
    DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
    DispatchKeyValue(entPointHurt, "Damage", strDamage);
    DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
    DispatchSpawn(entPointHurt);

    // Teleport, activate point_hurt
    TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(entPointHurt, "Hurt", (IsClientAndInGame(attacker)) ? attacker : -1);

    // Config, delete point_hurt
    DispatchKeyValue(entPointHurt, "classname", "point_hurt");
    DispatchKeyValue(victim, "targetname", "null");
    RemoveEdict(entPointHurt);
}

void ReportCleared()
{
    CPrintToChatAll("[{olive}capclear{default}] {red}Full cap{default}! Clearing cappers to allow survivors to struggle some more.");

    if (iClearsLeftThisRound == 0) {
        PrintHintTextToAll("Survivors cleared!\nCareful! Next time it's game over!");
    } else if (iClearsLeftThisRound > 0) {
        PrintHintTextToAll("Survivors cleared!\nClears remaining: %d", iClearsLeftThisRound);
    } else {
        PrintHintTextToAll("Survivors cleared!");
    }
}

// -------------------------------
//      Basic Helpers
// -------------------------------

bool: IsPlayerIncapacitated(client)
{
    return bool: GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool: IsPlayerDominated(client)
{
    return iPlayerDominatedBy[client] != -1;
}

bool: IsSurvivor(client)
{
    return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool: IsClientAndInGame(index)
{
    return index > 0 && index <= MaxClients && IsClientInGame(index);
}

void PrintDebug(debugLevel, const String:Message[], any:...)
{
    if (debugLevel > GetConVarInt(hCvarDebug)) {
        return;
    }

    decl String:DebugBuff[256];
    VFormat(DebugBuff, sizeof(DebugBuff), Message, 3);
    LogMessage(DebugBuff);
    PrintToServer(DebugBuff);
}