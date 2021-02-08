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

int m_nThrowableType[2049];

ConVar tf_throwable_brick_force;

#define THROWABLE_TYPE_BRICK 1
#define THROWABLE_TYPE_SMOKE_GRENADE 2
#define THROWABLE_TYPE_KNIFE 3
#define THROWABLE_BREAD_MONSTER 4

#define TF_THROWABLE_BRICK_MODEL "models/weapons/c_models/c_brick/c_brick.mdl"
#define TF_PROJECTILE_THROWABLE_BRICK "tf_projectile_throwable_brick"

public void OnMapStart()
{
	PrecacheModel(TF_THROWABLE_BRICK_MODEL);
}

Handle g_hSdkInitThrowable;

public void OnPluginStart()
{
	tf_throwable_brick_force = CreateConVar("tf_throwable_brick_force", "1200");
	
	Handle hGameConf = LoadGameConfigFile("tf2.throwables");
	if (hGameConf != null)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFProjectile_Throwable::InitThrowable");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hSdkInitThrowable = EndPrepSDKCall();

		CloseHandle(hGameConf);
	}
	
	AddNormalSoundHook(view_as<NormalSHook>(OnSoundHook));
}

public Action OnSoundHook(int[] clients, int &numClients, char[] sample, int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
	if (!IsClientReady(entity))return Plugin_Continue;
	
	if(TF2_GetPlayerClass(entity) == TFClass_Sniper)
	{
		int iWeapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
		if(IsValidEntity(iWeapon))
		{
			// Don't shout "Jarate" if we're shooting a custom throwable.
			if(m_nThrowableType[iWeapon] > 0)
			{
				if(StrEqual(sample, "vo/sniper_JarateToss01.mp3"))
				{
					strcopy(sample, 30, "vo/sniper_JarateToss02.mp3");
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}


public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if (!StrEqual(type, "weapon"))return;
	
	m_nThrowableType[entity] = CEconItems_GetEntityAttributeInteger(entity, "set throwable type");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	
	m_nThrowableType[entity] = 0;
	
	if(StrContains(classname, "tf_projectile_") != -1)
	{
		// We would use SpawnPost, but m_hLauncher is not available 
		// at the time.
		RequestFrame(RF_OnBaseProjectile_Spawn, entity);
	}
}

public void RF_OnBaseProjectile_Spawn(any entity)
{
	int iLauncher = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	
	if(iLauncher > -1)
	{
		if (!CEconItems_IsEntityCustomEconItem(iLauncher))return;
		if (m_nThrowableType[iLauncher] <= 0)return;
		
		KillNextFrame(entity);
	}
}

public Action BaseThrowable_OnSpawnPost(int entity)
{
	
	return Plugin_Handled;
	/*	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	int iTeamNum = GetEntProp(entity, Prop_Send, "m_iTeamNum");
	int iClient = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	int iWeapon = GetPlayerWeaponSlot(iClient, 1);
	
	if(iWeapon > -1)
	{
		// if (!m_bIsBrickLauncher[iWeapon])return Plugin_Handled;
		
		float flSpeed = tf_throwable_brick_force.FloatValue;
		
		float vecPos[3], vecAng[3], vecVel[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAng);
		
		KillNextFrame(entity);
		
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
	
	return Plugin_Continue;*/
}

public void KillNextFrame(int entity)
{
	RequestFrame(RF_KillNextFrame, entity);
}

public void RF_KillNextFrame(any entity)
{
	AcceptEntityInput(entity, "Kill");
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] name, bool &result)
{
	if (!CEconItems_IsEntityCustomEconItem(weapon))return;
	if (m_nThrowableType[weapon] <= 0)return;
	
	CreateTimer(0.035, Timer_DelayedCreateThrowableProjectile, weapon);
}

public Action Timer_DelayedCreateThrowableProjectile(Handle timer, any data)
{
	CreateWeaponThrowableProjectile(data);
}

public void CreateWeaponThrowableProjectile(int weapon)
{
	if (!CEconItems_IsEntityCustomEconItem(weapon))return;
	if (m_nThrowableType[weapon] <= 0)return;
	
	switch(m_nThrowableType[weapon])
	{
		#if defined HAS_BRICK
		case THROWABLE_TYPE_BRICK:
		{
			CreateWeaponThrowableProjectile_Brick(weapon);
		}
		#endif
	}
}

#if defined HAS_BRICK
public void CreateWeaponThrowableProjectile_Brick(int weapon)
{
	int iTeamNum = GetEntProp(weapon, Prop_Send, "m_iTeamNum");
	int iClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (iClient < 0)return;
	
	float vecPos[3], vecAng[3];
	GetClientEyeAngles(iClient, vecAng);
	GetClientEyePosition(iClient, vecPos);
		
	float flSpeed = tf_throwable_brick_force.FloatValue;
	
	int iProjectile = CreateEntityByName(TF_PROJECTILE_THROWABLE_BRICK);
	if(iProjectile > -1)
	{
		DispatchSpawn(iProjectile);
		SetEntityModel(iProjectile, TF_THROWABLE_BRICK_MODEL);
		
		SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeamNum);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", iClient);
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", weapon);
		
		SetBaseThrowableDamage(iProjectile, 30.0);
		
		float vecVelAng[3];
		vecVelAng = vecAng;
		vecVelAng[0] -= 10.0;
		
		float vecVel[3], vecShift[3];
		
		GetAngleVectors(vecVelAng, vecVel, vecShift, NULL_VECTOR);
		NormalizeVector(vecVel, vecVel);
		ScaleVector(vecVel, flSpeed);
		
		NormalizeVector(vecShift, vecShift);
		ScaleVector(vecShift, 8.0); // Shift by 8HU.
		
		AddVectors(vecPos, vecShift, vecPos);
		
		ActivateEntity(iProjectile);
		TeleportEntity(iProjectile, vecPos, vecAng, vecVel);
		
		switch(iTeamNum)
		{
			case 2: 
			{
				TF_StartAttachedParticle("peejar_trail_red", iProjectile, 5.0);
			}
			case 3:
			{
				TF_StartAttachedParticle("peejar_trail_blu", iProjectile, 5.0);
			}
		}
		
		SetDelayedProjectileLauncher(iProjectile, weapon);
	}
}
#endif

public void SetDelayedProjectileLauncher(int entity, int launcher)
{
	DataPack pack = new DataPack();
	pack.WriteCell(entity);
	pack.WriteCell(launcher);
	pack.Reset();
	
	RequestFrame(RF_SetDelayedProjectileLauncher, pack);
}

public void RF_SetDelayedProjectileLauncher(any data)
{
	DataPack pack = data;
	int proj = pack.ReadCell();
	int weapon = pack.ReadCell();
	delete pack;
	SetEntPropEnt(proj, Prop_Send, "m_hLauncher", weapon);
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

public void SetBaseThrowableDamage(int entity, float damage)
{
	SetBaseThrowableCharge(entity, (damage - 40) / 30);
}

public void SetBaseThrowableCharge(int entity, float charge)
{
	SDKCall(g_hSdkInitThrowable, entity, charge);
}

public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}