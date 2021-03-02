#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define ARTILERRY_SENTRY_GUN_MODEL_1 "models/buildables/artillery_sentry1.mdl"
#define ARTILERRY_SENTRY_GUN_MODEL_2 "models/buildables/artillery_sentry2.mdl"
#define ARTILERRY_SENTRY_GUN_MODEL_3 "models/buildables/artillery_sentry3.mdl"


public Plugin myinfo = 
{
	name = "[Creators.TF] Building Model Override",
	author = "Creators.TF Team",
	description = "Functionality for custom sentry guns.",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook the entity creation of this new sentry gun.
	if (StrEqual(classname, "obj_sentrygun"))
	{
		SDKHook(entity, SDKHook_Spawn, Sentry_OnSpawn);
	}
}

public Action Sentry_OnSpawn(int iSentryGun)
{
	// Grab the owner of this sentry gun so we can grab their weapon:
	int iBuilder;
	PrintToChatAll("Sentry_OnSpawn");
	
	if (IsClientValid(iBuilder) && TF2_GetPlayerClass(iBuilder) == TFClass_Engineer)
	{
		// Grab their PDA weapon which is in slot 3:
		int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
		
		// Grab the model override attribute.
		char modelName[PLATFORM_MAX_PATH];
		CEconItems_GetEntityAttributeString(iWeapon, "override sentry model", modelName, sizeof(modelName));
		
		// Grab the current level of the sentry:
		int iUpgradeLevel = GetEntProp(iSentryGun, Prop_Send, "m_iUpgradeLevel");
		char sUpgradeLevel[1]; 
		IntToString(iUpgradeLevel, sUpgradeLevel, sizeof(sUpgradeLevel));
		
		
		if (!StrEqual(modelName, ""))
		{	
			ReplaceString(modelName, sizeof(modelName), "%d", sUpgradeLevel);
			PrintToChatAll(modelName);
			SetEntProp(iSentryGun, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(modelName), 4, 0);
		}
	}
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}