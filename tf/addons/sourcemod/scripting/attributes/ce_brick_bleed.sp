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

#define DEFAULT_BRICK_BLEED 4.0
#define DEFAULT_BRICK_BLEED_MIN 3.0
#define DEFAULT_BRICK_BLEED_MAX 8.0
#define DEFAULT_BRICK_BLEED_DIST 550.0
#define DEFAULT_BRICK_BLEED_DIST_MIN 400.0

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

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (bIsBrick[inflictor] && IsBrickEntity(inflictor))
	{
		float distance, bleed, bleedMin, bleedMax, baseDistance, minDist;
		
		// Grab the distance between client and attacker.
		float attackerpos[3], vicpos[3];
		GetClientAbsOrigin(attacker, attackerpos);
		GetClientAbsOrigin(client, vicpos);

		//Get our bleed attributes
		distance = (GetVectorDistance(attackerpos, vicpos));
		
		// If the weapon that dealt this damage wasn't a brick, grab the attackers original brick
		// and get attributes from there.
		if (!CEconItems_GetEntityAttributeBool(weapon, "proj is brick"))
		{
			int brickWeapon = GetPlayerWeaponSlot(attacker, TFWeaponSlot_Secondary);
			
			// Is this a brick weapon?
			if (IsValidEntity(brickWeapon) && CEconItems_GetEntityAttributeBool(brickWeapon, "proj is brick"))
			{
				bleed = CEconItems_GetEntityAttributeFloat(brickWeapon, "brick bleed");
				bleedMin = CEconItems_GetEntityAttributeFloat(brickWeapon, "brick bleed min");
				bleedMax = CEconItems_GetEntityAttributeFloat(brickWeapon, "brick bleed max");
				baseDistance = CEconItems_GetEntityAttributeFloat(brickWeapon, "brick bleed dist");
				minDist = CEconItems_GetEntityAttributeFloat(brickWeapon, "brick bleed dist min");
			}
			// This isn't a brick, use placeholder values.
			else
			{
				bleed = DEFAULT_BRICK_BLEED;
				bleedMin = DEFAULT_BRICK_BLEED_MIN;
				bleedMax = DEFAULT_BRICK_BLEED_MAX;
				baseDistance = DEFAULT_BRICK_BLEED_DIST;
				minDist = DEFAULT_BRICK_BLEED_DIST_MIN;
			}
		}
		else
		{
			// This is already a brick, grab it's attributes.
			bleed = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed");
			bleedMin = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed min");
			bleedMax = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed max");
			baseDistance = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed dist");
			minDist = CEconItems_GetEntityAttributeFloat(weapon, "brick bleed dist min");
		}
		
		//minimum distance for bleed
		if (distance >= minDist)
		{
			bleed = ClampFloat((distance / baseDistance) * bleed, bleedMin, bleedMax);
			
			// If we have a valid bleed duration, make the client bleed.
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

public void OnEntityDestroyed(int entity)
{
	Brick[entity] = false;
	bIsBrick[entity] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_jar"))
	{
		SDKHook(entity, SDKHook_SpawnPost, HookSpawn);
	}
	else
	{
		Brick[entity] = false;
		bIsBrick[entity] = false;
	}
}

public Action HookSpawn(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	PrintToChatAll("%d", owner);
	if (!IsValidClient(owner)) return Plugin_Continue;
	
	int weapon = GetPlayerWeaponSlot(owner, TFWeaponSlot_Secondary);
	//int weapon = GetEntPropEnt(owner, Prop_Send, "m_hActiveWeapon");
	if (CEconItems_GetEntityAttributeBool(weapon, "proj is brick"))
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
	return Plugin_Continue;
}

public bool IsBrickEntity(int projectile)
{
	bool result = false;
	char classname[64];
	GetEntityClassname(projectile, classname, sizeof classname);
	if (StrEqual(classname, "tf_projectile_throwable_brick"))
		result = true;
	
	return result;
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
