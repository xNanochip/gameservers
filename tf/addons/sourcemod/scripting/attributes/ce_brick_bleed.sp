#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <tf2>
#include <cecon_items>

#define BRICKMODEL "models/weapons/c_models/c_brick/c_brick.mdl"

bool bIsBrick[2049];
bool Brick[2049];

int brickModelIndex;

//Handle g_SDKGetVelocity;

public Plugin myinfo =
{
	name    = "[Attribute] Brick",
	author  = "IvoryPal",
	version = "1.0"
}

public void OnPluginStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnMapStart()
{
    brickModelIndex = PrecacheModel(BRICKMODEL);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}


public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if (StrEqual(type, "weapon"))
	{
		if (CEconItems_GetEntityAttributeInteger(entity, "proj is brick") > 0)
		{
			Brick[entity] = true;
		}
	}
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (bIsBrick[inflictor])
	{
		float attackerpos[3], vicpos[3];
		GetClientAbsOrigin(attacker, attackerpos);
		GetClientAbsOrigin(client, vicpos);

		//Get our bleed attributes
		float distance = (GetVectorDistance(attackerpos, vicpos));
		float bleed = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed");
		float bleedMin = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed min");
		float bleedMax = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed max");
		float baseDistance = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed dist");
		float minDist = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed dist min");

		//minimum distance for bleed
		if (distance >= minDist)
		{
			bleed = ClampFloat((distance / baseDistance) * bleed, bleedMin, bleedMax);
			TF2_MakeBleed(client, attacker, bleed);
		}
		bIsBrick[inflictor] = false;
	}
	return Plugin_Continue;
}

//Self explanatory, just clamps a float value
public float ClampFloat(float val, float min, float max)
{
	return val > max ? max : val < min ? min : val;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_jar"))
	{
		SDKHook(entity, SDKHook_SpawnPost, HookSpawn);
	}
}

public Action HookSpawn(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	int weapon = GetEntPropEnt(owner, Prop_Send, "m_hActiveWeapon"); //gets weapon
	if (IsValidClient(owner) && IsValidEntity(weapon) && Brick[weapon])
	{
		float position[3], rot[3], velocity[3];
		int team = GetEntProp(entity, Prop_Send, "m_iTeamNum"); //gets team of projectile
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position); //get pos

		//vecVelocity, vInitialVelcity, and CBaseEntity::GetSmoothedVelocity ALL return a zero vector.. so just setting our own speed and angle
		GetEntPropVector(entity, Prop_Send, "m_angRotation", rot); //Won't get the actual angle of the velocity but whatever
		rot[0] -= 7.0; //increase pitch to try and match how projectiles arc upwards at first
		float speed = CEconItems_GetEntityAttributeFloat(weapon, "brick speed");
		AcceptEntityInput(entity, "Kill");

		int proj = CreateEntityByName("tf_projectile_throwable_brick"); //Spawn brick projectile
		SetEntProp(proj, Prop_Send, "m_iTeamNum", team);
		SetEntPropEnt(proj, Prop_Send, "m_hOwnerEntity", owner); //assign owner
		SetEntPropEnt(proj, Prop_Send, "m_hThrower", owner); //assign thrower
		SetEntPropEnt(proj, Prop_Send, "m_hLauncher", weapon); //assign weapon launching brick
		SetEntPropEnt(proj, Prop_Send, "m_hOriginalLauncher", weapon);
		SetProjectileModel(proj, brickModelIndex);
		//SetEntityModel(proj, BRICKMODEL); //Swap model to brick model

		//Get our forward vector so we can set a proper velocity
		GetAngleVectors(rot, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, speed);

		//Should be using an extension but this should be good enough
		SetEntPropVector(proj, Prop_Send, "m_vInitialVelocity", velocity);
		DispatchSpawn(proj);
		TeleportEntity(proj, position, rot, velocity);
		ActivateEntity(proj);

		bIsBrick[proj] = true;
	}
}

public void SetProjectileModel(int proj, int modelIndex)
{
	if (HasEntProp(proj, Prop_Send, "m_nModelIndexOverrides"))
	{
		for (int i = 0; i < 4; i++)
		{
			SetEntProp(proj, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, i);
		}
	}
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
	{
		return false;
	}
	if (IsClientSourceTV(iClient) || IsClientReplay(iClient))
	{
		return false;
	}
	return true;
}
