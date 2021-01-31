#pragma semicolon 1
#pragma newdecls required

#include <cecon>
#include <cecon_items>
#include <sdkhooks>
#include <tf2_stocks>

enum struct CEStrangePartDefinition 
{
	int m_iIndex;
	char m_sEvent[256];
}

#define MAX_ENTITIES 2048
#define MAX_STRANGE_PARTS 10

int m_iStrangeLevel[MAX_ENTITIES + 1]; // Stores strange level of the entity.

CEStrangePartDefinition m_xParts[MAX_ENTITIES + 1][MAX_STRANGE_PARTS + 1]; // Array of Strange parts of every entity.
ArrayList m_hPartsDefinitions; // Strange Part Definitions

public Plugin myinfo =
{
	name = "Creators.TF Economy - Stranges Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Stranges Handler",
	version = "1.00",
	url = "https://creators.tf"
};

Handle g_hOnEconItemNewLevel;

public void OnPluginStart()
{
	// RegServerCmd("ce_stranges_announce_levelup", cItemLevelUp);
}

public void OnAllPluginsLoaded()
{
	ParseEconomySchema(CEcon_GetEconomySchema());
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseEconomySchema(hSchema);
}

public void ParseEconomySchema(KeyValues hConf)
{
	FlushPartsMemory();
	
	m_hPartsDefinitions = new ArrayList(sizeof(CEStrangePartDefinition));
	
	if(hConf.JumpToKey("Stranges/StrangeParts", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			do {
				char sIndex[11];
				hConf.GetSectionName(sIndex, sizeof(sIndex));
				int iPart = StringToInt(sIndex);

				CEStrangePartDefinition hPart;
				hPart.m_iIndex = iPart;
				hConf.GetString("event", hPart.m_sEvent, sizeof(hPart.m_sEvent));

				m_hPartsDefinitions.PushArray(hPart);

			} while (hConf.GotoNextKey());
		}
	}
	
	hConf.Rewind();
}

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem item, const char[] type)
{
	if(entity == -1) return;
	FlushEntityData(entity);

	int iPart = CEconItems_GetEntityAttributeInteger(entity, "strange eater");
	
	if(iPart > 0)
	{
		// TODO: Level calculation.
		/*
		int iValue = CE_GetAttributeInteger(entity, "strange eater value");
		KeyValues hLevels = CEEaters_GetItemLevelData(defid);

		int iLevel, iStyle;

		if(hLevels.GotoFirstSubKey())
		{
			do{
				char sPoints[11];
				hLevels.GetSectionName(sPoints, sizeof(sPoints));
				int iPoints = StringToInt(sPoints);

				if (iPoints > iValue)break;

				iLevel = iPoints;
				iStyle = hLevels.GetNum("item_style", 0);

			} while (hLevels.GotoNextKey());
		}
		m_iLevel[entity] = iLevel;

		bool bLevelChangesStyle = CE_GetAttributeInteger(entity, "style changes on strange level") > 0;
		if(bLevelChangesStyle)
		{
			CEStyles_SetStyle(entity, iStyle);
		}

		delete hLevels;*/
	}

	// Dont track points if this item is a campaign item.
	if (CEconItems_GetEntityAttributeBool(entity, "is_operation_pass"))return;

	for(int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		char sName[96];
		GetStrangeAttributeByPartIndex(i, sName, sizeof(sName));

		int iPartID = CEconItems_GetEntityAttributeInteger(entity, sName);
		if(iPartID > 0)
		{
			CEStrangePartDefinition xDef;
			if(GetPartDefinitionFromIndex(iPartID, xDef))
			{
				m_xParts[entity][i] = xDef;
			} else {
				continue;
			}
		}
	}
}

public any GetStrangeAttributeByPartIndex(int part, char[] buffer, int size)
{
	if(part == 0) Format(buffer, size, "strange eater");
	else Format(buffer, size, "strange eater part %d", part);
}

/*
public Action cItemLevelUp(int args)
{
	char sArg1[64], sArg2[11], sArg3[128], sArg4[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	GetCmdArg(3, sArg3, sizeof(sArg3));
	GetCmdArg(4, sArg4, sizeof(sArg4));

	int client = FindTargetBySteamID(sArg1);
	if(IsClientReady(client))
	{
		int index = StringToInt(sArg2);

		Call_StartForward(g_hOnEconItemNewLevel);
		Call_PushCell(client);
		Call_PushCell(index);
		Call_PushString(sArg4);
		Call_Finish();

		char sTarget[512];
		Format(sTarget, sizeof(sTarget), "Your %s\nhas reached a new rank:\n\"%s\"!\n ", sArg3, sArg4);

		Panel hMenu = new Panel();
		hMenu.SetTitle(sTarget);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.Send(client, Handler_DoNothing, 5);

		ClientCommand(client, "playgamesound Hud.Hint");

	}

	return Plugin_Handled;
}
*/


public void FlushPartsMemory()
{
	delete m_hPartsDefinitions;
}

public void FlushEntityData(int entity)
{
	for (int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		m_xParts[entity][i].m_iIndex = 0;
	}
}

public bool GetPartDefinitionFromIndex(int index, CEStrangePartDefinition xDef)
{
	if (m_hPartsDefinitions == null)return false;
	
	for (int i = 0; i < m_hPartsDefinitions.Length; i++)
	{
		CEStrangePartDefinition part;
		m_hPartsDefinitions.GetArray(i, part);
		if(part.m_iIndex == index)
		{
			xDef = part;
			return true;
		}
	}
	return false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 0)return;
	FlushEntityData(entity);
}

public void OnEntityDestroyed(int entity)
{
	if (entity < 0)return;
	FlushEntityData(entity);
}


public void CEcon_OnClientEvent(int client, const char[] name, int add, int unique_id)
{
	int iActiveWeapon = CEcon_GetLastUsedWeapon(client);
	if(IsValidEntity(iActiveWeapon))
	{
		char sName[32];
		GetEntityClassname(iActiveWeapon, sName, sizeof(sName));
		
		for (int i = 0; i < 5; i++)
		{	
			int iWeapon = GetPlayerWeaponSlot(client, i);
			if (!IsValidEntity(iWeapon))continue;
			if (iWeapon != iActiveWeapon)continue;
			if (!CEconItems_IsEntityCustomEconItem(iWeapon))continue;
			
			
			CEItem xItem;
			if(CEconItems_GetEntityItemStruct(iWeapon, xItem))
			{
				TickleEntityStrangeParts(iWeapon, name, add);
			}
		}
	}

	int iEdict = -1;
	while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
	{
		if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;
		
		char sClass[32];
		GetEntityNetClass(iEdict, sClass, sizeof(sClass));
		if (!StrEqual(sClass, "CTFWearable") && !StrEqual(sClass, "CTFWearableCampaignItem"))continue;

		if (!CEconItems_IsEntityCustomEconItem(iEdict))continue;
				
		CEItem xItem;
		if(CEconItems_GetEntityItemStruct(iEdict, xItem))
		{
			TickleEntityStrangeParts(iEdict, name, add);
		}
	}
}

public void TickleEntityStrangeParts(int entity, const char[] event, int add)
{
	for (int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		int iPart = m_xParts[entity][i].m_iIndex;
		
		if (iPart == 0)continue;
		if (!StrEqual(m_xParts[entity][i].m_sEvent, event))continue;
		
		char sAttr[96];
		GetStrangeAttributeByPartIndex(i, sAttr, sizeof(sAttr));
		Format(sAttr, sizeof(sAttr), "%s value", sAttr);

		PrintToChatAll("%s old %d new %d", sAttr, CEconItems_GetEntityAttributeInteger(entity, sAttr), CEconItems_GetEntityAttributeInteger(entity, sAttr) + add);
	}
}


/*

public void CEEvents_OnSendEvent(int client, const char[] event, int add)
{
	if (!IsClientValid(client))return;
	
	int iActiveWeapon = CEEvents_LastUsedWeapon(client);
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if (!IsValidEntity(iWeapon))continue;
		if (iWeapon != iActiveWeapon)continue;
		if (!CE_IsEntityCustomEcomItem(iWeapon))continue;

		CEStranges_TickleStrangeParts(client, iWeapon, event, add);
	}

	int iEdict = -1;
	while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
	{
		char sClass[32];
		GetEntityNetClass(iEdict, sClass, sizeof(sClass));
		if (!StrEqual(sClass, "CTFWearable") && !StrEqual(sClass, "CTFWearableCampaignItem"))continue;

		if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;
		if (!CE_IsEntityCustomEcomItem(iEdict))continue;

		CEStranges_TickleStrangeParts(client, iEdict, event, add);
	}
}

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, char[] type)
{
	if(entity == -1) return;
	FlushEntityData(entity);

	int iPart = CE_GetAttributeInteger(entity, "strange eater");
	if(iPart > 0)
	{
		int iValue = CE_GetAttributeInteger(entity, "strange eater value");
		KeyValues hLevels = CEEaters_GetItemLevelData(defid);

		int iLevel, iStyle;

		if(hLevels.GotoFirstSubKey())
		{
			do{
				char sPoints[11];
				hLevels.GetSectionName(sPoints, sizeof(sPoints));
				int iPoints = StringToInt(sPoints);

				if (iPoints > iValue)break;

				iLevel = iPoints;
				iStyle = hLevels.GetNum("item_style", 0);

			} while (hLevels.GotoNextKey());
		}
		m_iLevel[entity] = iLevel;

		bool bLevelChangesStyle = CE_GetAttributeInteger(entity, "style changes on strange level") > 0;
		if(bLevelChangesStyle)
		{
			CEStyles_SetStyle(entity, iStyle);
		}

		delete hLevels;
	}

	if (CE_GetAttributeInteger(entity, "is_operation_pass") > 0)return;

	for(int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		char sName[96];
		CEEaters_GetAttributeByPartIndex(i, sName, sizeof(sName));

		int iPartID = CE_GetAttributeInteger(entity, sName);
		if(iPartID > 0)
		{
			bool bFound = FindPartPrefab(iPartID, m_hParts[entity][i]);
			if (!bFound)continue;
		}
	}
}

public any Native_GetItemLevelData(Handle plugin, int numParams)
{
	int iIndex = GetNativeCell(1);
	KeyValues kv = CE_FindItemConfigByDefIndex(iIndex);
	if(!UTIL_IsValidHandle(kv)) return INVALID_HANDLE;

	char sName[128];
	kv.GetString("strange_level_data", sName, sizeof(sName));
	delete kv;

	KeyValues hConf = CEEaters_FindLevelDataByName(sName);

	KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, hConf));
	delete hConf;
	return hReturn;
}

public any Native_FindLevelDataByName(Handle plugin, int numParams)
{
	char sName[512];
	GetNativeString(1, sName, sizeof(sName));
	Format(sName, sizeof(sName), "Stranges/LevelData/%s", sName);

	KeyValues hConf = CE_GetEconomyConfig();
	KeyValues hLevelData;
	
	if(hConf.JumpToKey(sName, false))
	{
		hLevelData = KvSetRoot(hConf);
		delete hConf;

		KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, hLevelData));
		delete hLevelData;
		return hReturn;
	}

	delete hConf;
	return INVALID_HANDLE;
}


public void CEStranges_TickleStrangeParts(int client, int entity, const char[] event, int add)
{
	for (int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		int iPart = m_hParts[entity][i].m_iIndex;
		if (iPart == 0)continue;
		for (int j = 0; j < MAX_HOOKS; j++)
		{
			if (StrEqual(m_sPartsEvents[iPart][j], ""))continue;
			if (!StrEqual(m_sPartsEvents[iPart][j], event))continue;

			char sAttribute[96];
			CEEaters_GetAttributeByPartIndex(i, sAttribute, sizeof(sAttribute));
			Format(sAttribute, sizeof(sAttribute), "%s value", sAttribute);

			CE_SetAttributeInteger(entity, sAttribute, CE_GetAttributeInteger(entity, sAttribute) + add);

			CESC_SendStrangeEaterMessage(client, entity, i, add);
			break;
		}
	}
}

public void CESC_SendStrangeEaterMessage(int client, int iEntity, int part_id, int increment_value)
{
	int iIndex = CE_GetEntityEconIndex(iEntity);
	if (!IsClientReady(client) || iIndex <= 0)return;

	char sMessage[125];
	Format(sMessage, sizeof(sMessage), "strange_increment:client=%d,item=%d,part=%d,delta=%d", client, iIndex, part_id, increment_value);
	
	CESC_SendMessage(sMessage);
}
*/