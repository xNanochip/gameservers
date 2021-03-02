#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define BLUEPRINT_MODEL "models/buildables/sentry1_blueprint.mdl"

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
	HookEvent("player_carryobject", OnBuiltCarry);
	HookEvent("player_dropobject", OnDropCarry);
}

public Action OnBuildObject(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	PrintToChatAll("OnBuildObject %d", iObject);
	int iSentryGun = GetEventInt(hEvent, "index");

	if (iObject == 2)
	{
		SetSentryOverrideModel(iSentryGun);
	}
}

public Action OnBuiltCarry(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	PrintToChatAll("OnBuiltCarry %d", iObject);
	int iSentryGun = GetEventInt(hEvent, "index");

	if (iObject == 2)
	{
		SetEntProp(iSentryGun, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(BLUEPRINT_MODEL), 4, 0);
	}
}

public void SetSentryOverrideModel(int iSentryGun)
{
	// Grab the owner of this sentry gun so we can grab their weapon:
	int iBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");
	
	if (IsClientValid(iBuilder) && TF2_GetPlayerClass(iBuilder) == TFClass_Engineer)
	{
		// Grab their PDA weapon which is in slot 3:
		int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
		
		// Grab the model override attribute.
		char modelName[PLATFORM_MAX_PATH];
		CEconItems_GetEntityAttributeString(iWeapon, "override sentry model", modelName, sizeof(modelName));
		
		// Grab the current level of the sentry:
		int iUpgradeLevel = GetEntProp(iSentryGun, Prop_Send, "m_iUpgradeLevel");

		// Quick workaround to stop "level 0" sentry guns from producing error models:
		if (iUpgradeLevel < 1) { iUpgradeLevel = 1; }
		
		char sUpgradeLevel[4];
		IntToString(iUpgradeLevel, sUpgradeLevel, sizeof(sUpgradeLevel));
		
		if (!StrEqual(modelName, ""))
		{	
			ReplaceString(modelName, sizeof(modelName), "%d", sUpgradeLevel);
			SetEntProp(iSentryGun, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(modelName), 4, 0);
		}
	}
}

public Action OnDropCarry(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	int iSentryGun = GetEventInt(hEvent, "index");

	if (iObject == 1)
	{
		SetSentryOverrideModel(iSentryGun);
	}
	
	
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}