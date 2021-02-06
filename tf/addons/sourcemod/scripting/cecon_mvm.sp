#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <cecon_items>

public Plugin myinfo =
{
	name = "Creators.TF - Mann vs Machines",
	author = "Creators.TF Team",
	description = "Creators.TF - Mann vs Machines",
	version = "1.00",
	url = "https://creators.tf"
};

ConVar ce_mvm_check_itemname_cvar;

public void OnPluginStart()
{
	RegServerCmd("ce_mvm_equip_itemname", cMvMEquipItemName, "");
	RegServerCmd("ce_mvm_get_itemdef_id", cMvMGetItemDefID, "");
	RegServerCmd("ce_mvm_set_attribute", cMvMSetEntityAttribute, "");
	ce_mvm_check_itemname_cvar = CreateConVar("ce_mvm_check_itemname_cvar", "-1", "", FCVAR_PROTECTED);
}

public bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}

/**
*	Purpose: 	ce_mvm_equip_itemname command.
*/
public Action cMvMEquipItemName(int args)
{
	char sArg1[11], sArg2[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int iClient = StringToInt(sArg1);
	
	if (!StrEqual(sArg2, "")) 
	{
		if (IsClientValid(iClient))
		{
			CEItem xItem;
			if(CEconItems_CreateNamedItem(xItem, sArg2, 6, null))
			{
				CEconItems_GiveItemToClient(iClient, xItem);
			}
		}
	}
	
	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_get_itemdef_id command.
*/
public Action cMvMGetItemDefID(int args)
{
	char sArg1[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	if (!StrEqual(sArg1, "")) 
	{
		CEItemDefinition xDef;
		if(CEconItems_GetItemDefinitionByName(sArg1, xDef))
		{
			ce_mvm_check_itemname_cvar.SetInt(xDef.m_iIndex);
			return Plugin_Handled;
		}
	}
	ce_mvm_check_itemname_cvar.SetInt(-1);
	
	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_set_attribute command.
*/
public Action cMvMSetEntityAttribute(int args)
{	
	char sName[128], sEntity[11], sValue[11];
	GetCmdArg(1, sEntity, sizeof(sEntity));
	int iEntity = StringToInt(sEntity);
	if (!IsValidEntity(iEntity))return Plugin_Handled;
	
	GetCmdArg(2, sName, sizeof(sName));
	GetCmdArg(3, sValue, sizeof(sValue));
	float flValue = StringToFloat(sValue);
	
	CEconItems_SetEntityAttributeFloat(iEntity, sName, flValue);
	
	return Plugin_Handled;
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