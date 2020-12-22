#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <ce_core>
#include <ce_util>
#include <ce_events>
#include <ce_manager_responses>
#include <ce_manager_attributes>
#include <tf2_stocks>

int m_hTarget[MAX_ENTITY_LIMIT + 1];
float m_flCreationTime[MAX_ENTITY_LIMIT + 1];
float m_vecStartCurvePos[MAX_ENTITY_LIMIT + 1][3];
float m_vecPreCurvePos[MAX_ENTITY_LIMIT + 1][3];
float m_flDuration[MAX_ENTITY_LIMIT + 1];

public Plugin myinfo =
{
	name = "[CE Entity] ent_gift",
	author = "Creators.TF Team",
	description = "Holiday Gift Pickup",
	version = "1.03",
	url = "https://creators.tf"
}

#define TF_GIFT_MODEL "models/items/tf_gift.mdl"

public void OnPluginStart()
{
	// Misc Events
	HookEvent("player_death", player_death);
}

public void OnMapStart()
{
	PrecacheModel(TF_GIFT_MODEL);
}

public bool IsValidGift(int entity)
{
	if (!IsValidEntity(entity) || entity <= 0)
	{
		return false;
	}

	char sName[128];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
	return StrEqual(sName, "ce_gift");
}

public void Gift_CreateForPlayer(int client, int origin)
{
	float vecPos[3];
	GetClientAbsOrigin(origin, vecPos);

	vecPos[2] += 60.0;

	int iGift = Gift_Create(client, vecPos);
	m_hTarget[iGift] = client;

	switch(TF2_GetClientTeam(client))
	{
		case TFTeam_Red:  TF_StartAttachedParticle("peejar_trail_red", iGift, 4.0);
		case TFTeam_Blue: TF_StartAttachedParticle("peejar_trail_blu", iGift, 4.0);
	}
}

public int Gift_Create(int client, float pos[3])
{
	int iEnt = CreateEntityByName("prop_physics_override");
	// stop fucking touching world spawn please
	if (IsValidEntity(iEnt) && iEnt > 0)
	{
		SetEntityModel(iEnt, TF_GIFT_MODEL);

		float vecAng[3];
		vecAng[0] = GetRandomFloat(-20.0, 20.0);
		vecAng[2] = GetRandomFloat(-20.0, 20.0);

		TeleportEntity(iEnt, pos, vecAng, NULL_VECTOR);

		DispatchKeyValue(iEnt, "targetname", "ce_gift");

		DispatchSpawn(iEnt);
		ActivateEntity(iEnt);

		SetEntProp(iEnt, Prop_Data, "m_nSolidType", 6);
		SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 0x0008 | 0x0200);
		SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 2);

		SDKHook(iEnt, SDKHook_StartTouch, Gift_OnTouch);

		// Gift is not flying to target when spawned.
		Gift_SetActive(iEnt, false);

		CreateTimer(1.0, Timer_Gift_SetActive, iEnt);
	}
	return iEnt;
}


public Action Timer_Gift_SetActive(Handle timer, any gift)
{
	if (!IsValidGift(gift))
	{
		return Plugin_Handled;
	}

	Gift_SetActive(gift, true);
	return Plugin_Handled;
}

public void Gift_StartTargetMovement(int ent)
{
	if (!IsValidGift(ent))
	{
		return;
	}

	Gift_InitSplineData(ent);
}

public Action Gift_OnTouch(int entity, int other)
{
	if (IsClientValid(other) && IsValidGift(entity))
	{
		if (other != m_hTarget[entity])
		{
			return Plugin_Handled;
		}

		ClientPlayResponse(other, "XmasGift.Pickup");
		RemoveEntity(entity);
		CEEvents_SendEventToClient(other, "LOGIC_COLLECT_GIFT", 1, GetRandomInt(0, 10000));

	}
	return Plugin_Handled;
}

public void Gift_SetActive(int entity, bool active)
{
	if (active)
	{
		// Gift is flying to the target.
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.3);
		AcceptEntityInput(entity, "DisableMotion");
		TF_StartAttachedParticle("soul_trail", entity, 2.0);
		Gift_StartTargetMovement(entity);
	}
	else
	{
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.7);
		AcceptEntityInput(entity, "EnableMotion");
	}
}

public void Gift_InitSplineData(int iEnt)
{
	if (!IsValidGift(iEnt))
	{
		return;
	}

	m_flCreationTime[iEnt] = GetEngineTime();
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", m_vecStartCurvePos[iEnt]);

	float vecRandom[3];
	for (int i = 0; i < 2; i++)
	{
		vecRandom[i] = GetRandomFloat(-2000.0, 2000.0);
	}
	vecRandom[2] = GetRandomFloat(-2000.0, -300.0);

	m_vecPreCurvePos[iEnt] = m_vecStartCurvePos[iEnt];
	for (int i = 0; i < 3; i++)
	{
		m_vecPreCurvePos[iEnt][i] += vecRandom[i];
	}
	if (m_vecPreCurvePos[iEnt][2] > 0.0)
	{
		m_vecPreCurvePos[iEnt][2] = 0.0;
	}

	m_flDuration[iEnt] = 1.1;

	RequestFrame(Gift_FlyTowardsTargetEntity, iEnt);
}

public void Gift_FlyTowardsTargetEntity(any iEnt)
{
	if (!IsValidGift(iEnt))
	{
		return;
	}

	int iTarget = m_hTarget[iEnt];
	float flLife = GetEngineTime() - m_flCreationTime[iEnt];
	float flT = flLife / m_flDuration[iEnt];

	if (!IsClientValid(iTarget))
	{
		return;
	}

	if (flLife > 5.0 || flT > 2.0 || !IsPlayerAlive(iTarget))
	{
		RemoveEntity(iEnt);
		return;
	}

	const float flBiasAmt = 0.2;
	flT = Bias(flT, flBiasAmt);

	if (flT < 0.0)
	{
		flT = 0.0;
	}

	if (flT > 1.0)
	{
		flT = 1.0;
	}

	float angEyes[3];
	GetClientEyeAngles(iTarget, angEyes);
	float vecBehindChest[3];
	GetAngleVectors(angEyes, vecBehindChest, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vecBehindChest, -2000.0);

	float vecTargetPos[3], vecNextCuvePos[3];
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vecTargetPos);
	for (int i = 0; i < 3; i++)
	{
		vecNextCuvePos[i] = vecTargetPos[i] + vecBehindChest[i];
	}

	vecTargetPos[2] += 60.0;

	float vecOutput[3];
	Catmull_Rom_Spline(m_vecPreCurvePos[iEnt], m_vecStartCurvePos[iEnt], vecTargetPos, vecNextCuvePos, flT, vecOutput);

	TeleportEntity(iEnt, vecOutput, NULL_VECTOR, NULL_VECTOR);

	RequestFrame(Gift_FlyTowardsTargetEntity, iEnt);
}

public Action Projectile_OnTouch(int entity, int other)
{
	return Plugin_Handled;
}

public Action player_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	// don't detect dead ringer deaths
	int victim_deathflags = GetEventInt(hEvent, "death_flags");
	if (victim_deathflags & 32)
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(hEvent, "assister"));

	if (IsClientReady(attacker) && attacker != client)
	{
		float vecPos[3];
		GetClientAbsOrigin(client, vecPos);

		vecPos[2] += 60.0;

		Gift_CreateForPlayer(attacker, client);
	}

	if (IsClientReady(assister))
	{
		Gift_CreateForPlayer(assister, client);
	}

	return Plugin_Continue;
}

// -----------------------------------------------------------------------------------------
// Credit: Valve. I have no clue how this function works, but it works, so we'll use it.
// -----------------------------------------------------------------------------------------
public void Catmull_Rom_Spline(float p1[3], float p2[3], float p3[3], float p4[3], float t, float output[3])
{

	float tSqr = t * t * 0.5;
	float tSqrSqr = t * tSqr;

	t *= 0.5;

	float a[3], b[3], c[3], d[3];

	// Matrix row 1
	VectorScale(p1, -tSqrSqr, a);
	VectorScale(p2, tSqrSqr * 3.0, b);
	VectorScale(p3, tSqrSqr * -3.0, c);
	VectorScale(p4, tSqrSqr, d);

	AddVectors(a, output, output);
	AddVectors(b, output, output);
	AddVectors(c, output, output);
	AddVectors(d, output, output);

	// Matrix row 2
	VectorScale(p1, tSqr * 2, a);
	VectorScale(p2, tSqr * -5.0, b);
	VectorScale(p3, tSqr * 4.0, c);
	VectorScale(p4, -tSqr, d);

	AddVectors(a, output, output);
	AddVectors(b, output, output);
	AddVectors(c, output, output);
	AddVectors(d, output, output);

	// Matrix row 3
	VectorScale(p1, -t, a);
	VectorScale(p3, t, b);

	AddVectors(a, output, output);
	AddVectors(b, output, output);

	// Matrix row 4
	AddVectors(p2, output, output);
}

public void VectorScale(float input[3], float scale, float output[3])
{
	output = input;
	ScaleVector(output, scale);
}

public float Bias(float x, float biasAmt)
{
	static float lastAmt = -1.0;
	static float lastExponent = 0.0;
	if (lastAmt != biasAmt)
	{
		lastExponent = Logarithm( biasAmt ) * -1.4427;
	}
	float fRet = Pow( x, lastExponent );
	return fRet;
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
