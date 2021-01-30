//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Handler for the Cosmetic custom item type.
// 
//=========================================================================//

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <cecon>
#include <cecon_items>

#include <tf2wearables>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>

public Plugin myinfo =
{
	name = "Creators.TF (Cosmetics)",
	author = "Creators.TF Team",
	description = "Handler for the Cosmetic custom item type.",
	version = "1.0",
	url = "https://creators.tf"
};

enum struct CEItemDefinitionCosmetic 
{
	int m_iIndex;
	char m_sWorldModel[512];
	int m_iBaseIndex;
	int m_iEquipRegion;
}

ArrayList m_hDefinitions;

//--------------------------------------------------------------------
// Purpose: Precaches all the items of a specific type on plugin
// startup.
//--------------------------------------------------------------------
public void OnPluginStart()
{
	ProcessEconSchema(CEcon_GetEconomySchema());
	
	RegConsoleCmd("ce_givemetheitem", ce_givemetheitem);
}

public Action ce_givemetheitem(int client, int args)
{
	ArrayList Attributes = new ArrayList(sizeof(CEAttribute));
	
	CEAttribute buffer;
	strcopy(buffer.m_sName, sizeof(buffer.m_sName), "attach particle effect");
	strcopy(buffer.m_sValue, sizeof(buffer.m_sValue), "8");
	Attributes.PushArray(buffer);
	
	CEItem xCrowbar;
	if(CEconItems_CreateNamedItem(xCrowbar, "Boston Bling", 6, Attributes))
	{
		CEconItems_GiveItemToClient(client, xCrowbar);
	}
	
	if(CEconItems_CreateNamedItem(xCrowbar, "Dugout Scratchers", 6, Attributes))
	{
		CEconItems_GiveItemToClient(client, xCrowbar);
	}
	
	delete Attributes;
	
	return Plugin_Handled;
}

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem item, const char[] type)
{
	PrintToChatAll("(%d) attach particle effect = %d", entity, CEconItems_GetEntityAttributeInteger(entity, "attach particle effect"));
}

//--------------------------------------------------------------------
// Purpose: If schema was late updated (by an update), reprecache
// everything again.
//--------------------------------------------------------------------
public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ProcessEconSchema(hSchema);
}

//--------------------------------------------------------------------
// Purpose: This is called upon item equipping process.
//--------------------------------------------------------------------
public int CEconItems_OnEquipItem(int client, CEItem item, const char[] type)
{
	if (!StrEqual(type, "cosmetic"))return -1;
		
	CEItemDefinitionCosmetic hDef;
	if(FindCosmeticDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))
	{
		// If there are any weapons that occupy this equip
		// regions, we do not equip this cosmetic.
		if(HasOverlappingWeapons(client, hDef.m_iEquipRegion))
		{
			return -1;
		}		
		
		char sModel[512];
		strcopy(sModel, sizeof(sModel), hDef.m_sWorldModel);
		ParseCosmeticModel(client, sModel, sizeof(sModel));
		
		int iWear = TF2Wear_CreateWearable(client, false, sModel);
		SetEntProp(iWear, Prop_Send, "m_iItemDefinitionIndex", hDef.m_iBaseIndex);
		
		return iWear;
	}
	return -1;
}

//--------------------------------------------------------------------
// Purpose: Finds a cosmetic's definition by the definition index.
// Returns true if found, false otherwise. 
//--------------------------------------------------------------------
public bool FindCosmeticDefinitionByIndex(int defid, CEItemDefinitionCosmetic output)
{
	if (m_hDefinitions == null)return false;
	
	for (int i = 0; i < m_hDefinitions.Length; i++)
	{
		CEItemDefinitionCosmetic hDef;
		m_hDefinitions.GetArray(i, hDef);
		
		if(hDef.m_iIndex == defid)
		{
			output = hDef;
			return true;
		}
	}
	
	return false;
}

//--------------------------------------------------------------------
// Purpose: Parses the schema and reads precaches all the items.
//--------------------------------------------------------------------
public void ProcessEconSchema(KeyValues kv)
{
	delete m_hDefinitions;
	m_hDefinitions = new ArrayList(sizeof(CEItemDefinitionCosmetic));
	
	if(kv.JumpToKey("Items"))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				char sType[16];
				kv.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "cosmetic"))continue;
				
				char sIndex[11];
				kv.GetSectionName(sIndex, sizeof(sIndex));
				
				CEItemDefinitionCosmetic hDef;
				hDef.m_iIndex = StringToInt(sIndex);
				hDef.m_iBaseIndex = kv.GetNum("item_index");
				
				char sEquipRegions[64];
				kv.GetString("equip_region", sEquipRegions, sizeof(sEquipRegions));
				hDef.m_iEquipRegion = TF2Wear_ParseEquipRegionString(sEquipRegions);
				
				kv.GetString("world_model", hDef.m_sWorldModel, sizeof(hDef.m_sWorldModel));
					
				m_hDefinitions.PushArray(hDef);
			} while (kv.GotoNextKey());
		}
	}
	
	kv.Rewind();
}

//--------------------------------------------------------------------
// Purpose: Replaces %s symbol in model path with TF2 class name.
//--------------------------------------------------------------------
public void ParseCosmeticModel(int client, char[] sModel, int size)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:ReplaceString(sModel, size, "%s", "scout");
		case TFClass_Soldier:ReplaceString(sModel, size, "%s", "soldier");
		case TFClass_Pyro:ReplaceString(sModel, size, "%s", "pyro");
		case TFClass_DemoMan:ReplaceString(sModel, size, "%s", "demo");
		case TFClass_Heavy:ReplaceString(sModel, size, "%s", "heavy");
		case TFClass_Engineer:ReplaceString(sModel, size, "%s", "engineer");
		case TFClass_Medic:ReplaceString(sModel, size, "%s", "medic");
		case TFClass_Sniper:ReplaceString(sModel, size, "%s", "sniper");
		case TFClass_Spy:ReplaceString(sModel, size, "%s", "spy");
	}
}

//--------------------------------------------------------------------
// Purpose: Returns true if there are weapons that occupy specific
// equip regions.
//--------------------------------------------------------------------
public bool HasOverlappingWeapons(int client, int bits)
{
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon != -1)
		{
			int idx = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			int iCompareBits = TF2Econ_GetItemEquipRegionGroupBits(idx);
			if (bits & iCompareBits != 0)return true;
		}
	}
	return false;
}