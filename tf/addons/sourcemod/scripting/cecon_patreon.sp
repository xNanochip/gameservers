#pragma semicolon 1

#include <steamtools>
#include <cecon_http>
#include <ccc>

public Plugin myinfo =
{
	name = "Creators.TF Patreon Perks",
	author = "Creators.TF Team",
	description = "Applies perks to Creators.TF Patreons.",
	version = "1.0",
	url = "https://creators.tf"
};

ConVar ce_patreon_debug;

public void OnPluginStart()
{
	AddCommandListener(Cmd_ReloadCCC, "sm_reloadccc");
	
	ce_patreon_debug = CreateConVar("ce_patreon_debug", "0");

	LoadAllClientsPledges();
}

public Action Cmd_ReloadCCC(int client, const char[] command, int argc)
{
	LoadAllClientsPledges();
}

public void LoadAllClientsPledges()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		
		LoadClientPledge(i);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsClientReady(client))return;
	
	LoadClientPledge(client);
}

public void LoadClientPledge(int client)
{
	LogMessage("LoadClientPledge(%d)", client);
	
	char sSteamID[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	HTTPRequestHandle httpRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserDonations", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID);

	Steam_SendHTTPRequest(httpRequest, httpPlayerDonation_Callback, client);
}

public void httpPlayerDonation_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	LogMessage("httpPlayerDonation_Callback %d %d %d", code, success, client);
	// We are not processing bots.
	if (!IsClientReady(client))return;

	//-------------------------------//
	// Making HTTP checks.

	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;

	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];

	// Getting actual response content body.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);
	
	KeyValues kv = new KeyValues("Response");
	kv.ImportFromString(content);
	
	int centsAmount = kv.GetNum("amount");
	delete kv;
	
	if(ce_patreon_debug.BoolValue)
	{
		PrintToServer("Amount of cents for %N: %d", client, centsAmount);
	}
		
	char tag[32], color[32];

	if (centsAmount >= 200 && centsAmount < 500)
	{
		Format(tag, sizeof(tag), "Patreon Tier I | ");
		Format(color, sizeof(color), "f0cca5");
	}
	else if (centsAmount >= 500 && centsAmount < 1000)
	{
		Format(tag, sizeof(tag), "Patreon Tier II | ");
		Format(color, sizeof(color), "e8af72");
	}
	else if (centsAmount >= 1000)
	{
		Format(tag, sizeof(tag), "Patreon Tier III | ");
		Format(color, sizeof(color), "e38a2b");
	}

	if (g_bCCC)
	{
		CCC_SetTag(client, tag);
		CCC_SetColor(client, CCC_TagColor, StringToInt(color, 16), false);
	}
	else
	{
		LogError("Custom-ChatColors was not detected, therefore patreon tags cannot be set.");
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