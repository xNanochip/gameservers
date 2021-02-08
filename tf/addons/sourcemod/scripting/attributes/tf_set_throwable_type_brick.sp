#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <cecon_items>

#define HAS_BRICK
#define HAS_SMOKE_GRENADE
#define HAS_KNIFE
#define HAS_BREAD_MONSTER

public Plugin myinfo =
{
	name = "[CE Attribute] set throwable type",
	author = "Creators.TF Team",
	description = "set throwable type",
	version = "1.0",
	url = "https://creators.tf"
};

int m_bIsThrowableType[MAX_ENTITY_LIMIT + 1];

ConVar tf_throwable_brick_force;

#define THROWABLE_TYPE_BRICK 1
#define THROWABLE_TYPE_SMOKE_GRENADE 2
#define THROWABLE_TYPE_KNIFE 3
#define THROWABLE_BREAD_MONSTER 4

#define TF_THROWABLE_BRICK_MODEL "models/weapons/c_models/c_brick/c_brick.mdl"
#define TF_PROJECTILE_BRICK "tf_projectile_throwable_brick"

public void OnMapStart()
{
	PrecacheModel(TF_THROWABLE_BRICK_MODEL);
}

public void OnPluginStart()
{
	tf_throwable_brick_force = CreateConVar("tf_throwable_brick_force", "1200");
}

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if (!StrEqual(type, "weapon"))return;
	
	m_bIsThrowableType[entity] = CEconItems_GetEntityAttributeInteger(entity, "set throwable type");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	
	m_bIsThrowableType[entity] = 0;
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
		if (!m_bIsBrickLauncher[iWeapon])return Plugin_Handled;
		
		float flSpeed = tf_throwable_brick_force.FloatValue;
		
		float vecPos[3], vecAng[3], vecVel[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAng);
		
		RequestFrame(KillNextFrame, entity);
		
		int iProjectile = CreateEntityByName("tf_projectile_throwable_brick");
		if(iProjectile > -1)
		{
			DispatchSpawn(iProjectile);
			SetEntityModel(iProjectile, TF_THROWABLE_BRICK_MODEL);
			
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
		}
	}
	
	return Plugin_Continue;
}

public void KillEntityNext

public void RF_KillNextFrame(any entity)
{
	AcceptEntityInput(entity, "Kill");
}

public int TF_StartAttachedParticle(const char[] system, int entity, float lifetime)
{
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(iParticle) && iParticle > 0)
	{
		float vecPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		TeleportEntity(iParticle, vecPos, NULL_VECTOR, NULL_VECTOR);

		DispatchKeyValue(iParticle, "effect_name", system);
		DispatchSpawn(iParticle);

		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", entity, entity, 0);

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
