#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define BLUEPRINT_MODEL "models/buildables/sentry1_blueprint.mdl"

int iCurrentSentryLevel[2049];
//int iOldSentryLevel[2049];
bool bIsSentryActive[2049];

public Plugin myinfo = 
{
	name = "[Creators.TF] Building Model Override",
	author = "Creators.TF Team",
	description = "Functionality for custom sentry guns.",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	HookEvent("player_builtobject", OnBuildObject);
}

// Purpose: When a sentry gun is created, we're going to hook it's
// Think() function so we can change our models that way instead of
// relying entirely on events which can be buggy sometimes, especially
// when building and it automatically upgrades from 1->2 or 1->2->3.
public Action OnBuildObject(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	
	// TODO: Remove me later! This just grabs the object type from the event
	// and prints it for debugging.
	PrintToChatAll("OnBuildObject %d", iObject);

	// Grab our sentry gun:
	int iSentryGun = GetEventInt(hEvent, "index");

	// Is this a sentry gun object?
	if (iObject == 2)
	{
		// Hook our Think function here:
		SDKHook(iSentryGun, SDKHook_Think, OnSentryGunThink);
		bIsSentryActive[iSentryGun] = true;
		iCurrentSentryLevel[iSentryGun] = 1;
		//iOldSentryLevel[entity] = -1;
	}
}

// Purpose: As outlined in OnBuildObject, we'll be changing the model
// of the sentry gun here. To do this, we'll compare the level of the sentry
// and if it's changed from our last known value, we'll update it accordingly.
public void OnSentryGunThink(int iSentryGun)
{
	// If this sentry gun is NOT active for some reason, we're not going to
	// bother with doing anything for now:
	if (!bIsSentryActive)
	{
		return;
	}
	
	// Grab the sentry guns current upgrade level here:
	int iLocalUpgradeLevel = GetEntProp(iSentryGun, Prop_Send, "m_iUpgradeLevel");
	
	// Is this local level different from the one we have stored?
	if (iLocalUpgradeLevel > iCurrentSentryLevel[iSentryGun])
	{
		iCurrentSentryLevel[iSentryGun] = iLocalUpgradeLevel;
	}
	
	PrintToChatAll("Sentry %d current level %d", iSentryGun, iCurrentSentryLevel[iSentryGun]);
	
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}