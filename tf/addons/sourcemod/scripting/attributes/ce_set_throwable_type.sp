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
bool m_bRemoveNextProjectile[MAXPLAYERS + 1];

int m_iSmokeEffectCycles[2049];

ConVar 	tf_throwable_brick_force,
		tf_throwable_bread_force,
		tf_throwable_smoke_grenade_force,
		tf_throwable_smoke_grenade_delay,
		tf_throwable_smoke_grenade_duration;

#define THROWABLE_TYPE_BRICK 1
#define THROWABLE_TYPE_SMOKE_GRENADE 2
#define THROWABLE_TYPE_KNIFE 3
#define THROWABLE_TYPE_BREAD 4

#define TF_THROWABLE_BRICK_MODEL "models/weapons/c_models/c_brick/c_brick.mdl"
#define TF_PROJECTILE_THROWABLE_BRICK "tf_projectile_throwable_brick"

#define TF_THROWABLE_SMOKE_GRENADE_INTERVAL 0.1

public void OnMapStart()
{
	PrecacheModel(TF_THROWABLE_BRICK_MODEL);
}

Handle g_hSdkInitThrowable;

public void OnPluginStart()
{
	tf_throwable_brick_force = CreateConVar("tf_throwable_brick_force", "1200");

	tf_throwable_bread_force = CreateConVar("tf_throwable_bread_force", "900");

	tf_throwable_smoke_grenade_force = CreateConVar("tf_throwable_smoke_grenade_force", "1200");
	tf_throwable_smoke_grenade_delay = CreateConVar("tf_throwable_smoke_grenade_delay", "2.0");
	tf_throwable_smoke_grenade_duration = CreateConVar("tf_throwable_smoke_grenade_duration", "5.0");

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

	if(StrContains(classname, "tf_projectile_jar") != -1)
	{
		SDKHook(entity, SDKHook_Spawn, SDKHook_Projectile_OnSpawn);
	}
}

public Action SDKHook_Projectile_OnSpawn(int entity)
{
	int iClient = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(iClient > 0)
	{
		if(m_bRemoveNextProjectile[iClient])
		{
			AcceptEntityInput(entity, "Kill");
			m_bRemoveNextProjectile[iClient] = false;
		}
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] name, bool &result)
{
	if (!CEconItems_IsEntityCustomEconItem(weapon))return;
	if (m_nThrowableType[weapon] <= 0)return;

	CreateTimer(0.035, Timer_DelayedCreateThrowableProjectile, weapon);

	if(StrContains(name, "tf_weapon_jar") != -1)
	{
		m_bRemoveNextProjectile[client] = true;
	}
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

		#if defined HAS_BREAD_MONSTER
		case THROWABLE_TYPE_BREAD:
		{
			CreateWeaponThrowableProjectile_BreadMonster(weapon);
		}
		#endif

		#if defined HAS_SMOKE_GRENADE
		case THROWABLE_TYPE_SMOKE_GRENADE:
		{
			CreateWeaponThrowableProjectile_SmokeGrenade(weapon);
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

		EmitGameSoundToAll("Passtime.Throw", iClient);
	}
}
#endif

#if defined HAS_BREAD_MONSTER
public void CreateWeaponThrowableProjectile_BreadMonster(int weapon)
{
	int iTeamNum = GetEntProp(weapon, Prop_Send, "m_iTeamNum");
	int iClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

	if (iClient < 0)return;


	float vecPos[3], vecAng[3];
	GetClientEyeAngles(iClient, vecAng);
	GetClientEyePosition(iClient, vecPos);

	float flSpeed = tf_throwable_bread_force.FloatValue;

	int iProjectile = CreateEntityByName("tf_projectile_throwable_breadmonster");
	if(iProjectile > -1)
	{
		DispatchSpawn(iProjectile);

		SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeamNum);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", iClient);
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", weapon);

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

		EmitGameSoundToAll("Passtime.Throw", iClient);
	}
}
#endif

#if defined HAS_SMOKE_GRENADE
public void CreateWeaponThrowableProjectile_SmokeGrenade(int weapon)
{
	int iTeamNum = GetEntProp(weapon, Prop_Send, "m_iTeamNum");
	int iClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

	if (iClient < 0)return;

	float vecPos[3], vecAng[3];
	GetClientEyeAngles(iClient, vecAng);
	GetClientEyePosition(iClient, vecPos);

	float flSpeed = tf_throwable_smoke_grenade_force.FloatValue;

	int iProjectile = CreateEntityByName("tf_projectile_stun_ball");
	if(iProjectile > -1)
	{
		DispatchSpawn(iProjectile);

		SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeamNum);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", iClient);
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", weapon);

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


		m_iSmokeEffectCycles[iProjectile] = SmokeGrenade_GetMaxCycleCount();

		CreateTimer(tf_throwable_smoke_grenade_delay.FloatValue, Timer_SmokeGrenade_StartSmokeCycle, iProjectile);

		SetDelayedProjectileLauncher(iProjectile, weapon);

		EmitGameSoundToAll("Passtime.Throw", iClient);
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

public int SmokeGrenade_GetMaxCycleCount()
{
	float flIntervalMult = 1 / TF_THROWABLE_SMOKE_GRENADE_INTERVAL;
	return RoundToFloor(tf_throwable_smoke_grenade_duration.FloatValue * flIntervalMult);
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
