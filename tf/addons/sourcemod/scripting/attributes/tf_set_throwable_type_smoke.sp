#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <ce_core>
#include <ce_manager_attributes>
#include <ce_util>

public Plugin myinfo =
{
	name = "[CE Attribute] set throwable type (smoke grenade)",
	author = "Creators.TF Team",
	description = "set throwable type",
	version = "1.0",
	url = "https://creators.tf"
};

ConVar tf_throwable_smoke_grenade_force;
ConVar tf_throwable_smoke_grenade_delay;
ConVar tf_throwable_smoke_grenade_duration;

bool m_bIsSmokeGrenade[MAX_ENTITY_LIMIT + 1];
int m_iSmokeEffectCycles[MAX_ENTITY_LIMIT + 1];
#define TF_PROJECTILE_JAR "tf_projectile_jar"

#define TF_THROWABLE_SMOKE_GRENADE_INTERVAL 0.1

public void OnPluginStart()
{
	tf_throwable_smoke_grenade_force = CreateConVar("tf_throwable_smoke_grenade_force", "1200");
	tf_throwable_smoke_grenade_delay = CreateConVar("tf_throwable_smoke_grenade_delay", "2.0");
	tf_throwable_smoke_grenade_duration = CreateConVar("tf_throwable_smoke_grenade_duration", "5.0");
}

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, char[] type)
{
	if (!StrEqual(type, "weapon"))return;
	
	m_bIsSmokeGrenade[entity] = CE_GetAttributeInteger(entity, "set throwable type") == 4;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	
	m_bIsSmokeGrenade[entity] = false;
	m_iSmokeEffectCycles[entity] = 0;
	
	if(StrEqual(classname, TF_PROJECTILE_JAR))
	{
    	SDKHook(entity, SDKHook_SpawnPost, Jar_OnSpawnPost);
	}
}

public Action Jar_OnSpawnPost(int entity)
{
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	int iTeamNum = GetEntProp(entity, Prop_Send, "m_iTeamNum");
	int iClient = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	int iWeapon = GetPlayerWeaponSlot(iClient, 1);
	
	if(iWeapon > -1)
	{
		if (!m_bIsSmokeGrenade[iWeapon])return Plugin_Handled;
		
		float flSpeed = tf_throwable_smoke_grenade_force.FloatValue;
		
		float vecPos[3], vecAng[3], vecVel[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAng);
		
		RequestFrame(KillNextFrame, entity);
		
		int iProjectile = CreateEntityByName("tf_projectile_stun_ball");
		if(iProjectile > -1)
		{
			
			DispatchSpawn(iProjectile); 
			
			SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeamNum);
			SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", iClient);
			
			SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
			
			if(iClient != -1)
			{
				SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", iClient);
				GetClientEyeAngles(iClient, vecAng);
			}
			
			SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", iWeapon);
			SetEntPropEnt(iProjectile, Prop_Send, "m_hLauncher", iWeapon);
			
			float vecVelAng[3];
			vecVelAng = vecAng;
			vecVelAng[0] -= 10.0;
			
			GetAngleVectors(vecVelAng, vecVel, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(vecVel, vecVel);
			ScaleVector(vecVel, flSpeed);
			
			ActivateEntity(iProjectile);
			TeleportEntity(iProjectile, vecPos, vecAng, vecVel);
			
			m_iSmokeEffectCycles[iProjectile] = SmokeGrenade_GetMaxCycleCount();
			
			CreateTimer(tf_throwable_smoke_grenade_delay.FloatValue, Timer_SmokeGrenade_StartSmokeCycle, iProjectile);
		}
	}
	
	return Plugin_Continue;
}


public Action Timer_SmokeGrenade_StartSmokeCycle(Handle timer, any grenade)
{
	CreateTimer(0.1, Timer_SmokeGrenade_CycleSmoke, grenade);
}

public Action Timer_SmokeGrenade_CycleSmoke(Handle timer, any grenade)
{
	// Only perform smoke cycle if we more cycles.
	if(m_iSmokeEffectCycles[grenade] > 0)
	{
		// Spawn explosion on first cycle.
			
		if(m_iSmokeEffectCycles[grenade] == SmokeGrenade_GetMaxCycleCount())
		{
			TF_StartParticleOnEntity("ExplosionCore_MidAir", grenade, 2.0);
			SetEntityMoveType(grenade, MOVETYPE_CUSTOM);
			SetEntityRenderMode(grenade, RENDER_NONE);
		}
		
		TF_StartParticleOnEntity("grenade_smoke_cycle", grenade, 2.0);
		m_iSmokeEffectCycles[grenade]--;
		
		if(m_iSmokeEffectCycles[grenade] == 0)
		{
			AcceptEntityInput(grenade, "Kill");
		} else {
			CreateTimer(TF_THROWABLE_SMOKE_GRENADE_INTERVAL, Timer_SmokeGrenade_CycleSmoke, grenade);
		}
	}
}

public int SmokeGrenade_GetMaxCycleCount()
{
	float flIntervalMult = 1 / TF_THROWABLE_SMOKE_GRENADE_INTERVAL;
	return RoundToFloor(tf_throwable_smoke_grenade_duration.FloatValue * flIntervalMult);
}

public void KillNextFrame(any entity)
{
	AcceptEntityInput(entity, "Kill");
}

public int TF_StartParticleOnEntity(const char[] system, int entity, float lifetime)
{
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(iParticle) && iParticle > 0)
	{
		float vecPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		TeleportEntity(iParticle, vecPos, NULL_VECTOR, NULL_VECTOR);

		DispatchKeyValue(iParticle, "effect_name", system);
		DispatchSpawn(iParticle);

		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");

		char info[64];
		Format(info, sizeof(info), "OnUser1 !self:kill::%d:1", RoundFloat(lifetime));
		SetVariantString(info);
		AcceptEntityInput(iParticle, "AddOutput");
		AcceptEntityInput(iParticle, "FireUser1");
	}
	return iParticle;
}
