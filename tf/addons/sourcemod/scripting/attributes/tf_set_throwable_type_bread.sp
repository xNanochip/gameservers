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
	name = "[CE Attribute] set throwable type (Bread Monster)",
	author = "Creators.TF Team",
	description = "set throwable type (Bread Monster)",
	version = "1.0",
	url = "https://creators.tf"
};

bool m_bIsBrickLauncher[MAX_ENTITY_LIMIT + 1];

ConVar tf_throwable_bread_force;

#define TF_PROJECTILE_JAR "tf_projectile_jar"

public void OnPluginStart()
{
	tf_throwable_bread_force = CreateConVar("tf_throwable_bread_force", "900");
}

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, char[] type)
{
	if (!StrEqual(type, "weapon"))return;
	
	m_bIsBrickLauncher[entity] = CE_GetAttributeInteger(entity, "set throwable type") == 3;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	
	m_bIsBrickLauncher[entity] = false;
	
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
		if (!m_bIsBrickLauncher[iWeapon])return Plugin_Handled;
		
		float flSpeed = tf_throwable_bread_force.FloatValue;
		
		float vecPos[3], vecAng[3], vecVel[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAng);
		
		RequestFrame(KillNextFrame, entity);
		
		int iProjectile = CreateEntityByName("tf_projectile_throwable_breadmonster");
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
		}
	}
	
	return Plugin_Continue;
}

public void KillNextFrame(any entity)
{
	AcceptEntityInput(entity, "Kill");
}