#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define MAX_ENTITY_LIMIT 2048

enum struct CE_SentryGun
{
	// Are we actively using this struct?
	bool m_bIsActive;
	
	// Player related:
	int m_iBuilder;
	int m_iBuilderPDA;
	
	// Attributes of the sentry gun:
	int m_iCustomMaxHealth;
	int m_iCurrentHealth;
	int m_iUpgradeLevel;
	int m_iCurrentUpgradeLevel;
}

CE_SentryGun hPlayerSentryGuns[MAX_ENTITY_LIMIT+1];


public Plugin myinfo = 
{
	name = "[Creators.TF] Sentry Attributes",
	author = "Creators.TF Team",
	description = "Functionality for custom sentry guns.",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	HookEvent("player_dropobject", OnDropObject);
	HookEvent("player_upgradedobject", OnObjectUpgraded);
	HookEvent("object_destroyed", OnObjectDestroyed);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook the entity creation of this new sentry gun.
	if (StrEqual(classname, "obj_sentrygun"))
	{
		SDKHook(entity, SDKHook_Spawn, Sentry_OnSpawn);
	}
}

// Apply custom attributes here. These are specific to the sentry gun itself!
public void SetSentryAttributes(any data)
{
	// data should ALWAYS be an int!
	int iSentryGun = data;
	PrintToChat(hPlayerSentryGuns[iSentryGun].m_iBuilder, "%d", hPlayerSentryGuns[iSentryGun].m_iCurrentUpgradeLevel); //TODO: Remove me!
	
	// Get the name of the attribute from the current sentry gun level:
	char attribute[64];
	Format(attribute, sizeof(attribute), "sentry level %d max health value", hPlayerSentryGuns[iSentryGun].m_iCurrentUpgradeLevel);
	
	// Set maximum health if there's an increased value:
	int iValue = CEconItems_GetEntityAttributeInteger(hPlayerSentryGuns[iSentryGun].m_iBuilderPDA, attribute);
	if (iValue > 1)
	{
		// Set the attribute.
		SetEntProp(iSentryGun, Prop_Send, "m_iMaxHealth", iValue);
		hPlayerSentryGuns[iSentryGun].m_iCustomMaxHealth = iValue;
	}
	
	SetEntProp(iSentryGun, Prop_Send, "m_iUpgradeMetalRequired", 9999);
	
	PrintToChat(hPlayerSentryGuns[iSentryGun].m_iBuilder, "%d", GetEntProp(iSentryGun, Prop_Send, "m_iUpgradeLevel")); //TODO: Remove me!
	PrintToChat(hPlayerSentryGuns[iSentryGun].m_iBuilder, "Constructed Custom Sentry!");//TODO: Remove me!
}

public Action Sentry_OnSpawn(int iSentryGun)
{
	// Grab the owner of this sentry gun so we can grab their weapon:
	int iBuilder;
	
	if (!IsClientValid(hPlayerSentryGuns[iSentryGun].m_iBuilder))
	{
		iBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");
		hPlayerSentryGuns[iSentryGun].m_iBuilder = iBuilder;
	}
	else
		iBuilder = hPlayerSentryGuns[iSentryGun].m_iBuilder;
	
	if (IsClientValid(iBuilder) && TF2_GetPlayerClass(iBuilder) == TFClass_Engineer)
	{
		// Grab their PDA weapon which is in slot 3:
		int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
		
		// Does this weapon have the "sentry gun override" attribute?
		if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry gun stats override") > 1)
		{	
			// This is a sentry gun with custom attributes.
			// We're going to make sure it's fully setup first before we do anything with it:
			if (!hPlayerSentryGuns[iSentryGun].m_bIsActive)
			{
				hPlayerSentryGuns[iSentryGun].m_bIsActive = true;
				hPlayerSentryGuns[iSentryGun].m_iBuilderPDA = iWeapon;
			}
			// On the next frame, setup the sentry attributes:
			RequestFrame(SetSentryAttributes, iSentryGun);
		}
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