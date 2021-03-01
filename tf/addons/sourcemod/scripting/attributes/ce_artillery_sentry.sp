#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[Creators.TF] Artillery Sentry Attribute",
	author = "Creators.TF Team",
	description = "Functionality for a custom sentry gun.",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnPluginStart()
{

}

public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook the entity creation of this new sentry gun.
	if (StrEqual(classname, "obj_sentrygun"))
	{
		SDKHook(entity, SDKHook_Spawn, Sentry_OnSpawn);
	}
}

public Action Sentry_OnSpawn(int entity)
{
	// Grab the owner of this sentry gun so we can grab their weapon:
	int iBuilder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	
	if (IsClientValid(iBuilder) && TF2_GetPlayerClass(iBuilder) == TFClass_Engineer)
	{
		// Grab their PDA weapon which is in slot 3:
		int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
		
		// Does this weapon have the "sentry gun override" attribute?
		if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry gun override") == 2)
		{
			// Apply custom attributes here. These are specific to the sentry gun itself!
			
			// Set maximum health if there's an increased value (should be a percentage!)
			/*if (CEconItems_GetEntityAttributeFloat(iWeapon, "sentry max health increased") > 0.1)
				SetEntProp(entity, Prop_Data, "m_iMaxHealth", 216 * RoundToNearest(CEconItems_GetEntityAttributeFloat(iWeapon, "sentry max health increased")));
			
			// Set maximum health if there's an decreased value (should be a percentage!)
			if (CEconItems_GetEntityAttributeFloat(iWeapon, "sentry max health decreased") > 0.1)
				SetEntProp(entity, Prop_Data, "m_iMaxHealth", 216 / RoundToNearest(CEconItems_GetEntityAttributeFloat(iWeapon, "sentry max health decreased")));
			
			// Set the amount of metal needed for an upgrade (should be an interger!)
			if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry upgrade amount") > 1)
				SetEntProp(entity, Prop_Data, "m_iUpgradeMetalRequired", CEconItems_GetEntityAttributeInteger(iWeapon, "sentry upgrade amount"));
			
			// Set the maximum upgrade level (should be an interger, generally don't exceed 3!)
			if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry max upgrade level") > 1)
				SetEntProp(entity, Prop_Data, "m_iHighestUpgradeLevel", CEconItems_GetEntityAttributeInteger(iWeapon, "sentry max upgrade level"));*/

			PrintToChat(iBuilder, "Constructed Artillery Sentry!");
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