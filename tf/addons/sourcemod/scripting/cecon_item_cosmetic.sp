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

// Why? 
// The game supports up to 8 concurrent wearables, equipped on a player.
// This is due to that m_MyWearables array netprop in the player entity 
// can store up to 8 members.
// If we exceed this limit, bugs with randomly dissapearing cosmetics may occur.
// 
// To address this, we limit the maximum amount of possible cosmetics on a player
// to 4. We reserve 3 cosmetics for weapons' display. And one spare cosmetic as a
// threshold to prevent array overflowing.
//
// To properly equip custom cosmetics, we perform a few optimization techniques. 
// We unequip base TF2 cosmetics with intersecting equip regions. This is to
// prevent clipping between overlapping cosmetics. If we still can't get enough space 
// to equip a custom cosmetic, we just remove one base TF2 cosmetic to free up space.
#define MAX_COSMETICS 4

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
	char m_sWorldModel[256];
	int m_iBaseIndex;
	int m_iEquipRegion;
}

ArrayList m_hDefinitions;

//--------------------------------------------------------------------
// Purpose: Precaches all the items of a specific type on plugin
// startup.
//--------------------------------------------------------------------
public void OnAllPluginsLoaded()
{
	ProcessEconSchema(CEcon_GetEconomySchema());
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
	if (FindCosmeticDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))
	{
		// If there are any weapons that occupy this equip
		// regions, we do not equip this cosmetic.
		if (HasOverlappingWeapons(client, hDef.m_iEquipRegion))
		{
			return -1;
		}
		
		char sModel[512];
		strcopy(sModel, sizeof(sModel), hDef.m_sWorldModel);
		ParseCosmeticModel(client, sModel, sizeof(sModel));
		
		// Let's try to remove base TF2 cosmetics with similar equip regions.
		int iEdict = -1;
		while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
		{
			char sNetClassName[32];
			GetEntityNetClass(iEdict, sNetClassName, sizeof(sNetClassName));
			
			// We only remove CTFWearable and CTFWearableCampaignItem items.
			if (!StrEqual(sNetClassName, "CTFWearable") && !StrEqual(sNetClassName, "CTFWearableCampaignItem"))continue;
			
			if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;
			if (CEconItems_IsEntityCustomEconItem(iEdict))continue;
			if (!HasEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex"))continue;
			
			int iItemDefIndex = GetEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex");
			
			// Invalid Item Definiton Index.
			if (iItemDefIndex == 0xFFFF)continue;
			
			int iCompareBits = TF2Econ_GetItemEquipRegionGroupBits(iItemDefIndex);
			if (hDef.m_iEquipRegion & iCompareBits != 0)
			{
				// We found a merging base TF2 cosmetic. Remove it.
				TF2Wear_RemoveWearable(client, iEdict);
				AcceptEntityInput(iEdict, "Kill");
			}
		}
		
		int iAttempts = MAX_COSMETICS;
		bool bShouldRemove = !CanGetAnotherCosmetic(client);
		
		while(iAttempts > 0 && bShouldRemove)
		{
			iAttempts--;
			
			iEdict = -1;
			while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
			{
				if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;
				
				if (!IsWearableCosmetic(iEdict))continue;
				if (CEconItems_IsEntityCustomEconItem(iEdict))continue;
				
				TF2Wear_RemoveWearable(client, iEdict);
				AcceptEntityInput(iEdict, "Kill");
			}
		}
		
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
		
		if (hDef.m_iIndex == defid)
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
	
	if (kv == null)return;
	
	if (kv.JumpToKey("Items"))
	{
		if (kv.GotoFirstSubKey())
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
		if (iWeapon != -1)
		{
			int idx = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			int iCompareBits = TF2Econ_GetItemEquipRegionGroupBits(idx);
			if (bits & iCompareBits != 0)return true;
		}
	}
	return false;
}

public int GetClientCosmeticsCount(int client)
{
	int iCount = 0;
	
	int iEdict = -1;
	while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
	{
		// This cosmetic does not belong to the client.
		if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;
		if (!IsWearableCosmetic(iEdict))continue;
		
		iCount++;
	}
	
	return iCount;
}

public bool CanGetAnotherCosmetic(int client)
{
	return GetClientCosmeticsCount(client) < MAX_COSMETICS;
}

public bool IsWearableCosmetic(int wearable)
{
	char sNetClassName[32];
	GetEntityNetClass(wearable, sNetClassName, sizeof(sNetClassName));
	
	// We only remove CTFWearable and CTFWearableCampaignItem items.
	if (!StrEqual(sNetClassName, "CTFWearable") && !StrEqual(sNetClassName, "CTFWearableCampaignItem")) return false;
	
	// Cosmetics have this set.
	if (!HasEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex")) return false;
	int iItemDefIndex = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex");
	if (iItemDefIndex == 0xFFFF) return false;
	
	return true;
}