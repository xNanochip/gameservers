//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Core plugin for Creators.TF Custom Economy plugin.
//
//=========================================================================//

#include <steamtools>

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define MAX_ENTITY_LIMIT 2048

#include <cecon>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

#define DEFAULT_ECONOMY_BASE_URL "https://creators.tf"

public Plugin myinfo =
{
	name = "Creators.TF Core",
	author = "Creators.TF Team",
	description = "Core plugin for Creators.TF Custom Economy plugin.",
	version = "1.0",
	url = "https://creators.tf"
}

char m_sBaseEconomyURL[64];
char m_sEconomyAccessKey[150];
char m_sBranchName[32];
char m_sBranchPassword[64];

bool m_bCredentialsLoaded = false;

ConVar ce_debug_mode;

// System Features
#include "economy/schema.sp"
#include "economy/coordinator.sp"


public void OnPluginStart()
{
	ce_debug_mode = CreateConVar("ce_debug_mode", "0");

	ReloadEconomyCredentials();

	// Subscripts callbacks.
	Schema_OnPluginStart(); // schema.sp
}

public void OnMapStart()
{
	// Subscripts callbacks.
	Schema_OnMapStart(); // schema.sp
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("cecon_core");

	Schema_AskPluginLoad2(myself, late, error, err_max); // schema.sp
	return APLRes_Success;
}

// Used to refresh economy credentials from economy.cfg file.
public void ReloadEconomyCredentials()
{
	m_bCredentialsLoaded = false;

	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/economy.cfg");

	KeyValues kv = new KeyValues("Economy");
	if (!kv.ImportFromFile(sLoc))return;

	kv.GetString("Key", m_sEconomyAccessKey, sizeof(m_sEconomyAccessKey));
	kv.GetString("Branch", m_sBranchName, sizeof(m_sBranchName));
	kv.GetString("Password", m_sBranchPassword, sizeof(m_sBranchPassword));
	kv.GetString("Domain", m_sBaseEconomyURL, sizeof(m_sBaseEconomyURL), DEFAULT_ECONOMY_BASE_URL);

	m_bCredentialsLoaded = true;

	SafeStartCoordinatorPolling();
	CreateTimer(5.0, Timer_CoordinatorWatchDog);
}

public void DebugLog(const char[] message, any ...)
{
	if(ce_debug_mode.BoolValue)
	{
		int length = strlen(message) + 255;
		char[] sOutput = new char[length];

		VFormat(sOutput, length, message, 2);
		LogMessage(sOutput);
	}
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

public int FindTargetBySteamID(const char[] steamid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientAuthorized(i))
		{
			char szAuth[256];
			GetClientAuthId(i, AuthId_SteamID64, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, steamid))return i;
		}
	}
	return -1;
}

public bool IsEntityValid(int entity)
{
	return entity > 0 && entity < MAX_ENTITY_LIMIT && IsValidEntity(entity);
}
