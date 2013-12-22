#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
//#include <sdkhooks>
#include <l4d2_skill_detect>

#define JOCKEY_POUNCE_MIN_HEIGHT    300.0

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

new                     g_iPounceUncapDamageMax     = 49;
new     Float:          g_fPounceUncapRangeMax      = 1729.1666;

public Plugin:myinfo = 
{
    name = "Jockey Pounce Damage (Skill Detect Version)",
    author = "Tabun",
    description = "Does damage based on jockey pounce height.",
    version = "0.9.1",
    url = "none"
}


public OnJockeyHighPounce(attacker, victim, Float:height, bool:bReportedHigh)
{
    // let height determine damage to do..
    if ( !IS_VALID_SURVIVOR(victim) || !IsPlayerAlive(victim) || height <= JOCKEY_POUNCE_MIN_HEIGHT ) {
        return;
    }
    
    // damage to do = max + 1 * height factor
    new damage = RoundFloat( float(g_iPounceUncapDamageMax + 1) * (height / g_fPounceUncapRangeMax) );

    if (damage <= 0) {
        return;
    }
    
    // do damage
    ApplyDamageToPlayer( damage, victim, attacker );
    
    // report damage / pounce
    if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(attacker) )
    {
        PrintToChatAll( "\x04%N\x01 jockey-pounced \x05%N\x01 for \x03%i\x01 damage (height: \x05%i\x01).",
            attacker,  victim, damage, RoundFloat(height)
        );
    }
    else if ( IS_VALID_INGAME(victim) )
    {
        PrintToChatAll( "A jockey jockey-pounced \x05%N\x01 for \x03%i\x01 damage (height: \x05%i\x01).",
            victim, damage, RoundFloat(height)
        );
    }
}

ApplyDamageToPlayer( damage, victim, attacker )
{
    new Handle: pack = CreateDataPack();
    WritePackCell(pack, damage);
    WritePackCell(pack, victim);
    WritePackCell(pack, attacker);
    CreateTimer( 0.1, Timer_ApplyDamage, pack);
}

public Action: Timer_ApplyDamage (Handle:timer, Handle:dataPack)
{
    ResetPack(dataPack);
    new damage = ReadPackCell(dataPack);  
    new victim = ReadPackCell(dataPack);
    new attacker = ReadPackCell(dataPack);
    CloseHandle(dataPack);   

    decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
    
    GetClientEyePosition(victim, victimPos);
    IntToString(damage, strDamage, sizeof(strDamage));
    Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
    
    new entPointHurt = CreateEntityByName("point_hurt");
    if (!entPointHurt) { return; }

    // Config, create point_hurt
    DispatchKeyValue(victim, "targetname", strDamageTarget);
    DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
    DispatchKeyValue(entPointHurt, "Damage", strDamage);
    DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
    DispatchSpawn(entPointHurt);
    
    // Teleport, activate point_hurt
    TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(entPointHurt, "Hurt", (IS_VALID_INGAME(attacker)) ? attacker : -1);
    
    // Config, delete point_hurt
    DispatchKeyValue(entPointHurt, "classname", "point_hurt");
    DispatchKeyValue(victim, "targetname", "null");
    RemoveEdict(entPointHurt);
}