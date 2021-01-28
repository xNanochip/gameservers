//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Loadout, attributes, items module for Creators.TF
// Custom Economy.
//
//=========================================================================//

//===============================//
// DOCUMENTATION

/* HOW DOES THE LOADOUT SYSTEM WORK?
*
*	When player requests their loadout (this happens when player respawns
*	or touches ressuply locker), we run Loadout_InventoryApplication function.
*	This function checks if we already have loadout information loaded for this
*	specific player. If we have, apply the loadout right away using `Loadout_ApplyLoadout`.
*
*	If we dont, we request loadout info for the player from the backend using
*	`Loadout_RequestPlayerLoadout`. The response for this request is parsed into m_Loadout[client] array.
*	m_Loadout[client] contains X ArrayLists, where X is the amount of classes that we have loadouts for.
*	(For TF2, the X value is 11. In consists of: 9 (TF2 Classes) + 1 (General Items Class) + 1 (Unknown Class)).
*
*	When we are sure we have loadout information available, `Loadout_ApplyLoadout` is run. This function checks
*	which equipped items player is able to wear, and which items we need to holster from player.
*
*	If an item is eligible for being equipped, we run a forward with all the data about this item
*	to the subplugins, who will take care of managing what these items need to do when equipped.
*
*/

/* DIFFERENCE BETWEEN EQUIPPED AND WEARABLE ITEMS
*
*	Terminology:
*	"(Item) Equipped" 	- Item is in player loadout.
*	"Wearing (Item)"	- Player is currently wearing this item.
*
*	Why?
*	Sometimes player loadout might not match what player
*	actually has equipped. This can happen, for example, with
*	holiday restricted items. They are only wearable during holidays.
*	Also some specific item types are auto-unequipped by the game itself
*	when player touches ressuply locker. This happens with Cosmetics and
*	Weapons. To prevent mismatch between equipped items and wearable items,
*	we keep track of them separately.
*
*	To check if player has item equipped in their inventory you run:
*	- CEcon_IsPlayerEquippedItemIndex(int client, CEEconLoadoutClass class, int item_index);
*
*	To check if player has this item actually equipped right now, run:
*	- CEcon_IsPlayerWearingItemIndex(int client, int item_index);
*/
//===============================//

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define MAX_ENTITY_LIMIT 2048

#include <cecon_core>
#include <cecon_items>

#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

#pragma newdecls optional
#include <steamtools>
#pragma newdecls required

public Plugin myinfo =
{
	name = "Creators.TF Items Module",
	author = "Creators.TF Team",
	description = "Loadout, attributes, items module for Creators.TF Custom Economy.",
	version = "1.0",
	url = "https://creators.tf"
}

// Forwards.
Handle 	g_CEcon_ShouldItemBeBlocked,
		g_CEcon_OnEquipItem,
		g_CEcon_OnItemIsEquipped;

// SDKCalls for native TF2 economy reading.
Handle 	g_SDKCallGetEconItemSchema,
		g_SDKCallSchemaGetAttributeDefinitionByName;

// Variables, needed to attach a specific CEItem to an entity.
bool m_bIsEconItem[MAX_ENTITY_LIMIT + 1];
CEItem m_hEconItem[MAX_ENTITY_LIMIT + 1];

// ArrayLists
ArrayList m_ItemDefinitons = null;

// Loadouts
ArrayList m_PartialReapplicationTypes = null;

bool m_bLoadoutCached[MAXPLAYERS + 1];
ArrayList m_Loadout[MAXPLAYERS + 1][CEEconLoadoutClass]; 	// Cached loadout data of a user.
ArrayList m_MyItems[MAXPLAYERS + 1]; 					// Array of items this user is wearing.

bool m_bWaitingForLoadout[MAXPLAYERS + 1];
bool m_bInRespawn[MAXPLAYERS + 1];
bool m_bFullReapplication[MAXPLAYERS + 1];

// Native and Forward creation.
public void AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_CEcon_ShouldItemBeBlocked 	= new GlobalForward("CEconItems_ShouldItemBeBlocked", ET_Event, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnEquipItem 			= new GlobalForward("CEconItems_OnEquipItem", ET_Single, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnItemIsEquipped 		= new GlobalForward("CEconItems_OnItemIsEquipped", ET_Ignore, Param_Cell, Param_Cell, Param_Array, Param_String);

	CreateNative("CEconItems_CreateItem", Native_CreateItem);
	CreateNative("CEconItems_GivePlayerItem", Native_GivePlayerItem);
	CreateNative("CEconItems_DestroyItem", Native_DestroyItem);

    CreateNative("CEconItems_IsEntityCustomEconItem", Native_IsEntityCustomEconItem);

	CreateNative("CEconItems_MergeAttributes", Native_MergeAttributes);
	CreateNative("CEconItems_AttributesKeyValuesToArrayList", Native_AttributesKeyValuesToArrayList);

	CreateNative("CEconItems_GetAttributeStringFromArray", Native_GetAttributeStringFromArray);
	CreateNative("CEconItems_GetAttributeIntegerFromArray", Native_GetAttributeIntegerFromArray);
	CreateNative("CEconItems_GetAttributeFloatFromArray", Native_GetAttributeFloatFromArray);
	CreateNative("CEconItems_GetAttributeBoolFromArray", Native_GetAttributeBoolFromArray);

	CreateNative("CEconItems_GetEntityAttributeString", Native_GetEntityAttributeString);
	CreateNative("CEconItems_GetEntityAttributeInteger", Native_GetEntityAttributeInteger);
	CreateNative("CEconItems_GetEntityAttributeFloat", Native_GetEntityAttributeFloat);
	CreateNative("CEconItems_GetEntityAttributeBool", Native_GetEntityAttributeBool);

    CreateNative("CEconItems_IsAttributeNameOriginal", Native_IsAttributeNameOriginal);
    CreateNative("CEconItems_ApplyOriginalAttributes", Native_ApplyOriginalAttributes);
}

//---------------------------------------------------------------------
// Purpose: Precache item definitions on plugin load.
//---------------------------------------------------------------------
public void OnPluginStart()
{
	// Items
    PrecacheItemsFromSchema(CEcon_GetEconomySchema());

	// Attributes
	Handle hGameConf = LoadGameConfigFile("tf2.creators");
	if (!hGameConf)
	{
		SetFailState("Failed to load gamedata (tf2.creators).");
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetEconItemSchema = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_SDKCallSchemaGetAttributeDefinitionByName = EndPrepSDKCall();


	// Loadout
	HookEvent("post_inventory_application", post_inventory_application);
	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);

	RegServerCmd("ce_loadout_reset", cLoadoutReset);

	m_PartialReapplicationTypes = new ArrayList(ByteCountToCells(32));
	m_PartialReapplicationTypes.PushString("cosmetic");
	m_PartialReapplicationTypes.PushString("weapon");
}

//---------------------------------------------------------------------
// Purpose: Precache item definitions on late schema update.
//---------------------------------------------------------------------
public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
    PrecacheItemsFromSchema(hSchema);
}

//---------------------------------------------------------------------
// Purpose: Parses the schema keyvalues and adds all the definition
// structs in the cache.
//---------------------------------------------------------------------
public void PrecacheItemsFromSchema(KeyValues hSchema)
{
	if (hSchema == null)return;

    // Make sure to remove all previous definitions if exist.
	FlushItemDefinitionCache();

    // Initiate the array.
	m_ItemDefinitons = new ArrayList(sizeof(CEItemDefinition));

	if(hSchema.JumpToKey("Items"))
	{
		if(hSchema.GotoFirstSubKey())
		{
			do {
				CEItemDefinition hDef;

                // We retrieve the defid of this defintion from the section name
                // of the current KV stack we're in.
				char sSectionName[11];
				hSchema.GetSectionName(sSectionName, sizeof(sSectionName));

                // Definition index.
				hDef.m_iIndex = StringToInt(sSectionName);

                // Base item name and type.
				hSchema.GetString("name", hDef.m_sName, sizeof(hDef.m_sName));
				hSchema.GetString("type", hDef.m_sType, sizeof(hDef.m_sType));

                // Getting attributes.
                if(hSchema.JumpToKey("attributes"))
				{
                    // Converting attributes from KeyValues to ArrayList format.
					hDef.m_Attributes = Attributes_KeyValuesToArrayList(hSchema);
					hSchema.GoBack();
				}

                // Push this struct to the cache storage.
				m_ItemDefinitons.PushArray(hDef);

			} while (hSchema.GotoNextKey());
		}
	}

    // Make sure we do that every time
	hSchema.Rewind();
}

//---------------------------------------------------------------------
// Purpose: Finds a definition struct in the cache with defid that
// matches the provided one.
//---------------------------------------------------------------------
public bool GetItemDefinitionByIndex(int index, CEItemDefinition output)
{
	if (m_ItemDefinitons == null)return false;

	for (int i = 0; i < m_ItemDefinitons.Length; i++)
	{
		CEItemDefinition buffer;
		m_ItemDefinitons.GetArray(i, buffer);

		if(buffer.m_iIndex == index)
		{
			output = buffer;
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------
// Purpose: Finds a definition struct in the cache with base name that
// matches the provided one.
//---------------------------------------------------------------------
public bool GetItemDefinitionByName(const char[] name, CEItemDefinition output)
{
	if (m_ItemDefinitons == null)return false;

	for (int i = 0; i < m_ItemDefinitons.Length; i++)
	{
		CEItemDefinition buffer;
		m_ItemDefinitons.GetArray(i, buffer);

		if(StrEqual(buffer.m_sName, name))
		{
			output = buffer;
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------
// Purpose: Flushes item definition cache.
//---------------------------------------------------------------------
public void FlushItemDefinitionCache()
{
	if (m_ItemDefinitons == null)return;

    // We go through every element in the array...
	for (int i = 0; i < m_ItemDefinitons.Length; i++)
	{
		CEItemDefinition buffer;
		m_ItemDefinitons.GetArray(i, buffer);

        // And make sure to remove the ArrayList of attrubutes.
        // So that we don't cause a memory leak.
		delete buffer.m_Attributes;
	}

    // Clean the array itself.
	delete m_ItemDefinitons;
}

//---------------------------------------------------------------------
// Purpose: Returns true if this item was made by the economy.
//---------------------------------------------------------------------
public bool IsEntityCustomEconItem(int entity)
{
	return m_bIsEconItem[entity];
}

//---------------------------------------------------------------------
// Purpose: Creates a CEItem struct out of all the params that were
// provided.
// Note: m_Attributes member of returned CEItem contains merged static
// and override attributes. However you only provide override
// attrubutes in this function.
// Native: CEconItems_CreateItem
//---------------------------------------------------------------------
public any Native_CreateItem(Handle plugin, int numParams)
{
    int index = GetNativeCell(2);
    int defid = GetNativeCell(3);
    int quality = GetNativeCell(4);
    ArrayList overrides = GetNativeCell(5);

    char sName[128];
    GetNativeString(6, sName, sizeof(sName));

	CEItemDefinition hDef;
	if (!GetItemDefinitionByIndex(defid, hDef))return false;

	buffer.m_iIndex = index;
	buffer.m_iItemDefinitionIndex = defid;
	buffer.m_nQuality = quality;
	strcopy(buffer.m_sName, sizeof(buffer.m_sName), name);
	buffer.m_Attributes = Attributes_MergeAttributes(hDef.m_Attributes, override);

    SetNativeArray(1, buffer, sizeof(CEItemDefinition));

	return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_DestroyItem
//---------------------------------------------------------------------
public any Native_DestroyItem(Handle plugin, int numParams)
{
	CEItem hItem;
	GetNativeCell(1, sizeof(CEItem));

	delete hItem.m_Attributes;
}

//---------------------------------------------------------------------
// Purpose: Gives players a specific item, defined by the struct.
// Native: CEconItems_GivePlayerItem
//---------------------------------------------------------------------
public any Native_GivePlayerItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    CEItem item;
    GetNativeArray(2, item, sizeof(CEItem));

    // TODO: Make a client check.

	// First, let's see if this item's definition even exists.
	// If it's not, we return false as a sign of an error.
	CEItemDefinition hDef;
	if (!GetItemDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))return false;

	// This boolean will be returned in the end of this func's execution.
	// It shows whether item was actually created.
	bool bResult = false;

	// Let's ask subplugins if they're fine with equipping this item.
	Call_StartForward(g_CEcon_ShouldItemBeBlocked);
	Call_PushCell(client);
	Call_PushArray(item, sizeof(CEItem));
	Call_PushString(hDef.m_sType);

	bool bShouldBlock = false;
	Call_Finish(bShouldBlock);

	// If noone responded or response is positive, equip this item.
	if (GetForwardFunctionCount(g_CEcon_ShouldItemBeBlocked) == 0 || !bShouldBlock)
	{
        // Start a forward to engage subplugins to initialize the item.
		Call_StartForward(g_CEcon_OnEquipItem);
		Call_PushCell(client);
		Call_PushArray(item, sizeof(CEItem));
		Call_PushString(hDef.m_sType);
		int iEntity = -1;
		Call_Finish(iEntity);

        // If subplugins return an entity index, we attach the given CEItem struct to it
        // and apply original TF attributes if possible.
		if(IsEntityValid(iEntity))
		{
			m_bIsEconItem[iEntity] = true;
			m_hEconItem[iEntity] = item;

			Attributes_ApplyOriginalAttributes(iEntity);
		}

		// Alerting subplugins that this item was equipped.
		Call_StartForward(g_CEcon_OnItemIsEquipped);
		Call_PushCell(client);
		Call_PushCell(iEntity);
		Call_PushArray(item, sizeof(CEItem));
		Call_PushString(hDef.m_sType);
		Call_Finish();

        // Item was successfully created.
		bResult = true;
	}

	return bResult;
}

//---------------------------------------------------------------------
// Native: CEconItems_IsEntityCustomEconItem
//---------------------------------------------------------------------
public any Native_IsEntityCustomEconItem(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	if(IsEntityValid(iEntity))
	{
		return IsEntityCustomEconItem(iEntity);
	}
	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_IsEntityCustomEconItem
//---------------------------------------------------------------------
public any Native_CreateItem(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	if(IsEntityValid(iEntity))
	{
		return IsEntityCustomEconItem(iEntity);
	}
	return false;
}

//=======================================================//
// ATTRIBUTES
//=======================================================//

//---------------------------------------------------------------------
// Purpose: Transforms a keyvalues of attributes into an ArrayList of
// CEAttribute-s.
// Native: CEconItems_AttributesKeyValuesToArrayList
//---------------------------------------------------------------------
public any Native_AttributesKeyValuesToArrayList(Handle plugin, int numParams)
{
    KeyValues kv = GetNativeCell(1);
	if (kv == null)return null;

	ArrayList Attributes = new ArrayList(sizeof(CEAttribute));
	if(kv.GotoFirstSubKey())
	{
		do {
			CEAttribute attr;

			kv.GetString("name", attr.m_sName, sizeof(attr.m_sName));
			kv.GetString("value", attr.m_sValue, sizeof(attr.m_sValue));

			Attributes.PushArray(attr);
		} while (kv.GotoNextKey());
		kv.GoBack();
	}

	return Attributes;
}

//---------------------------------------------------------------------
// Purpose: Merges two attribute arrays together. Attributes with same
// names from array1 will be overwritten by value in array2.
// Native: CEconItems_MergeAttributes
//---------------------------------------------------------------------
public any Native_MergeAttributes(Handle plugin, int numParams)
{
    ArrayList hArray1 = GetNativeCell(1);
    ArrayList hArray1 = GetNativeCell(2);

	if (hArray1 == null)return null;

	ArrayList hResult = hArray1.Clone();

	if (hArray2 == null)return hResult;

	int size = hResult.Length;
	for (int i = 0; i < hArray2.Length; i++)
	{
		CEAttribute newAttr;
		hArray2.GetArray(i, newAttr);

		for (int j = 0; j < size; j++)
		{
			CEAttribute oldAttr;
			hResult.GetArray(j, oldAttr);
			if (StrEqual(oldAttr.m_sName, newAttr.m_sName))
			{
				hResult.Erase(j);
				j--;
				size--;
			}
		}
		hResult.PushArray(newAttr);
	}

	return hResult;
}

// ARRAYLIST ATTRIBUTES
// ================================== //

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeStringFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeStringFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return false;
    char sName[128];
    GetNativeString(2, sName, sizeof(sName));
    int length = GetNativeCell(4);

	for(int i = 0; i < hArray.Length; i++)
	{
		CEAttribute hAttr;
		hArray.GetArray(i, hAttr);

		if(StrEqual(hAttr.m_sName, sName))
		{
            SetNativeString(3, hAttr.m_sValue, length);
			return true;
		}
	}
	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeIntegerFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeIntegerFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return 0;

    char name[128];
    GetNativeString(2, name, sizeof(name));

	char sBuffer[11];
	CEconItems_GetAttributeStringFromArray(hArray, name, sBuffer, sizeof(sBuffer));

	return StringToInt(sBuffer);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeFloatFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeFloatFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return 0.0;

    char name[128];
    GetNativeString(2, name, sizeof(name));

	char sBuffer[11];
	CEconItems_GetAttributeStringFromArray(hArray, name, sBuffer, sizeof(sBuffer));

	return StringToFloat(sBuffer);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeBoolFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeBoolFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return false;

    char name[128];
    GetNativeString(2, name, sizeof(name));

	char sBuffer[11];
	CEconItems_GetAttributeStringFromArray(hArray, name, sBuffer, sizeof(sBuffer));

	return StringToInt(sBuffer) > 0;
}


// ENTITY ATTRIBUTES
// ================================== //

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeString
//---------------------------------------------------------------------
public any Native_GetEntityAttributeString(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

    int length = GetNativeCell(4);

	if(!CEconItems_IsEntityCustomEconItem(entity)) return false;
	if(m_hEconItem[entity].m_Attributes == null) return false;

    char[] buffer = new char[length + 1];
	CEconItems_GetEntityAttributeString(m_hEconItem[entity].m_Attributes, name, buffer, length);

    SetNativeString(3, buffer, length);
    return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeInteger
//---------------------------------------------------------------------
public any Native_GetEntityAttributeInteger(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

	if(!CEconItems_IsEntityCustomEconItem(entity)) return 0;
	if(m_hEconItem[entity].m_Attributes == null) return 0;

	return CEconItems_GetAttributeIntegerFromArray(m_hEconItem[entity].m_Attributes, sName);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeFloat
//---------------------------------------------------------------------
public any Native_GetEntityAttributeFloat(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

	if(!CEconItems_IsEntityCustomEconItem(entity)) return 0.0;
	if(m_hEconItem[entity].m_Attributes == null) return 0.0;

	return CEconItems_GetAttributeFloatFromArray(m_hEconItem[entity].m_Attributes, sName);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeBool
//---------------------------------------------------------------------
public any Native_GetEntityAttributeBool(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

	if(!CEconItems_IsEntityCustomEconItem(entity)) return false;
	if(m_hEconItem[entity].m_Attributes == null) return false;

	return CEconItems_GetAttributeBoolFromArray(m_hEconItem[entity].m_Attributes, sName);
}

//---------------------------------------------------------------------
// Native: CEconItems_ApplyOriginalAttributes
//---------------------------------------------------------------------
public any Native_ApplyOriginalAttributes(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

	if(!CEconItems_IsEntityCustomEconItem(entity)) return;
	if(m_hEconItem[entity].m_Attributes == null) return;

	// TODO: Make a check to see if entity accepts TF2 attributes.

	for(int i = 0; i < m_hEconItem[entity].m_Attributes.Length; i++)
	{
		CEAttribute hAttr;
		m_hEconItem[entity].m_Attributes.GetArray(i, hAttr);

		if(CEconItems_IsAttributeNameOriginal(hAttr.m_sName))
		{
			float flValue = StringToFloat(hAttr.m_sValue);
			TF2Attrib_SetByName(entity, hAttr.m_sName, flValue);
		}
	}
}

//---------------------------------------------------------------------
// Native: CEconItems_IsAttributeNameOriginal
//---------------------------------------------------------------------
public any Native_IsAttributeNameOriginal(Handle plugin, int numParams)
{
    char sName[64];
    GetNativeString(1, sName, sizeof(sName));

	Address pSchema = SDKCall(g_SDKCallGetEconItemSchema);
	if(pSchema)
	{
		return SDKCall(g_SDKCallSchemaGetAttributeDefinitionByName, pSchema, sName) != Address_Null;
	}
	return false;
}

// Loadout
//======================================//


// Entry point for loadout application. Requests user loadout if not yet cached.
public void LoadoutApplication(int client, bool bFullReapplication)
{
	// We do not apply loadouts on bots.
	if (!IsClientReady(client))return;

	// This user is currently already waiting for a loadout.
	if (m_bWaitingForLoadout[client])return;

	// If it's full reapplication.
	if(bFullReapplication)
	{
		// We unequip all the items from the player.
		RemoveAllClientWearableItems(client);
	} else {
		// If it's partial reapplication, we only unequip items of specific type.
		if(m_MyItems[client] != null)
		{
			for (int i = 0; i < m_PartialReapplicationTypes.Length; i++)
			{
				char sType[32];
				m_PartialReapplicationTypes.GetString(i, sType, sizeof(sType));
				RemoveClientWearableItemsByType(client, sType);
			}
		}
	}

	if (ClientHasCachedLoadout(client))
	{
		// If cached loadout is still recent, we parse cached response.
		 ApplyClientLoadout(client);
	} else {
		// Otherwise request for the most recent data.
		RequestClientLoadout(client, true);
	}
}

public CEEconLoadoutClass GetCEEconLoadoutClassFromTFClass(TFClassType class)
{
	switch(class)
	{
		case TFClass_Scout:return CEconLoadoutClass_Scout;
		case TFClass_Soldier:return CEconLoadoutClass_Soldier;
		case TFClass_Pyro:return CEconLoadoutClass_Pyro;
		case TFClass_DemoMan:return CEconLoadoutClass_Demoman;
		case TFClass_Heavy:return CEconLoadoutClass_Heavy;
		case TFClass_Engineer:return CEconLoadoutClass_Engineer;
		case TFClass_Medic:return CEconLoadoutClass_Medic;
		case TFClass_Sniper:return CEconLoadoutClass_Sniper;
		case TFClass_Spy:return CEconLoadoutClass_Spy;
	}
	return CEconLoadoutClass_Unknown;
}

public bool ClientHasItemInLoadoutByIndex(int client, CEEconLoadoutClass nClass, int index)
{
	if (m_Loadout[client][nClass] == null)return false;

	for (int i = 0; i < m_Loadout[client][nClass].Length; i++)
	{
		CEItem hItem;
		m_Loadout[client][nClass].GetArray(i, hItem);

		if (hItem.m_iIndex == index)return true;
	}

	return false;
}

public bool IsClientWearingItemIndex(int client, int index)
{
	if (m_MyItems[client] == null)return false;

	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);

		if (hItem.m_iIndex == index)return true;
	}

	return false;
}

public void AddClientWearableItem(int client, CEItem item)
{
	if (m_MyItems[client] == null)
	{
		m_MyItems[client] = new ArrayList(sizeof(CEItem));
	}

	m_MyItems[client].PushArray(item);

	CEconItems_GivePlayerItem(client, item);
}

public void RemoveClientWearableItem(int client, CEItem item)
{
	if (m_MyItems[client] == null)return;

	bool bRemoved = false;
	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);
		if(hItem.m_iIndex == item.m_iIndex)
		{
			m_MyItems[client].Erase(i);
			bRemoved = true;
			i--;
		}
	}

	if(bRemoved)
	{
		PrintToChatAll("Holstered: %s", item.m_sName);
	}
}

public void RemoveClientWearableItemsByType(int client, const char[] type)
{
	if (m_MyItems[client] == null)return;

	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);

		CEItemDefinition hDef;
		if(GetItemDefinitionByIndex(hItem.m_iItemDefinitionIndex, hDef))
		{
			if(StrEqual(hDef.m_sType, type))
			{
				RemoveClientWearableItem(client, hItem);
				i--;
			}
		}
	}
}

public void RemoveAllClientWearableItems(int client)
{
	if (m_MyItems[client] == null)return;

	// I would just delete the m_MyItems, but we still need to notify other plugins about
	// all the items being holstered.

	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);

		RemoveClientWearableItem(client, hItem);
		i--;
	}
}

public bool ClientHasCachedLoadout(int client)
{
	return m_bLoadoutCached[client];
}

public Action player_death(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	m_bInRespawn[client] = false;
}

public Action post_inventory_application(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	RequestFrame(RF_LoadoutApplication, client);
}

public Action player_spawn(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	m_bFullReapplication[client] = true;

	// Users are in respawn room by default when they spawn.
	m_bInRespawn[client] = true;
}

public void RF_LoadoutApplication(int client)
{
	if(m_bFullReapplication[client])
	{
		LoadoutApplication(client, true);
	} else {
		LoadoutApplication(client, false);
	}

	m_bFullReapplication[client] = false;
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

// Used to request loadout information from backend.
public void RequestClientLoadout(int client, bool apply)
{
	m_bWaitingForLoadout[client] = true;

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(apply);
	pack.Reset();

	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/IUsers/GLoadout", m_sBaseEconomyURL);

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Cookie", "session_id=f457c545a9ded88f18ecee47145a72c04ac9f435bbbd8973d18b0723aae4c7b5295fefe1.b92b2b3f8a0439d2632195a560aa101b");

	PrintToChatAll("Loadout_RequestPlayerLoadout()");
	Steam_SendHTTPRequest(httpRequest, RequestClientLoadout_Callback, pack);
}


public void RequestClientLoadout_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any pack)
{
	PrintToChatAll("RequestClientLoadout_Callback()");
	// Retrieving DataPack parameter.
	DataPack hPack = pack;

	// Getting client index and apply boolean from datapack.
	int client = hPack.ReadCell();
	bool apply = hPack.ReadCell();

	// Removing Datapack.
	delete hPack;

	// We are not processing bots.
	if (!IsClientReady(client))return;

	// ======================== //
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

	KeyValues Response = new KeyValues("Response");

	// ======================== //
	// Parsing loadout response.

	// If we fail to import content return.
	if (!Response.ImportFromString(content))return;

	ClearClientLoadout(client);

	if(Response.JumpToKey("loadout"))
	{
		if(Response.GotoFirstSubKey())
		{
			do {
				char sClassName[32];
				Response.GetSectionName(sClassName, sizeof(sClassName));

				CEEconLoadoutClass nClass;
				if(StrEqual(sClassName, "general")) nClass = CEconLoadoutClass_General;
				if(StrEqual(sClassName, "scout")) nClass = CEconLoadoutClass_Scout;
				if(StrEqual(sClassName, "soldier")) nClass = CEconLoadoutClass_Soldier;
				if(StrEqual(sClassName, "pyro")) nClass = CEconLoadoutClass_Pyro;
				if(StrEqual(sClassName, "demo")) nClass = CEconLoadoutClass_Demoman;
				if(StrEqual(sClassName, "heavy")) nClass = CEconLoadoutClass_Heavy;
				if(StrEqual(sClassName, "engineer")) nClass = CEconLoadoutClass_Engineer;
				if(StrEqual(sClassName, "medic")) nClass = CEconLoadoutClass_Medic;
				if(StrEqual(sClassName, "sniper")) nClass = CEconLoadoutClass_Sniper;
				if(StrEqual(sClassName, "spy")) nClass = CEconLoadoutClass_Spy;

				m_Loadout[client][nClass] = new ArrayList(sizeof(CEItem));

				if(Response.GotoFirstSubKey())
				{
					do {

						int iIndex = Response.GetNum("id", -1);
						int iDefID = Response.GetNum("defid", -1);
						int iQuality = Response.GetNum("quality", -1);
						char sName[64];
						Response.GetString("name", sName, sizeof(sName));
						ArrayList hOverrides;

						if(Response.JumpToKey("attributes"))
						{
							hOverrides = Attributes_KeyValuesToArrayList(Response);
							Response.GoBack();
						}

						CEItem hItem;
						if(CEconItems_CreateItem(hItem, iIndex, iDefID, iQuality, hOverrides, sName))
						{
							m_Loadout[client][nClass].PushArray(hItem);
						}

					} while (Response.GotoNextKey());
					Response.GoBack();
				}
			} while (Response.GotoNextKey());
		}
	}

	m_bLoadoutCached[client] = true;

	delete Response;
	m_bWaitingForLoadout[client] = false;

	LoadoutApplication(client, true);
}


public void ApplyClientLoadout(int client)
{
	CEEconLoadoutClass nClass = GetCEEconLoadoutClassFromTFClass(TF2_GetPlayerClass(client));

	if (nClass == CEconLoadoutClass_Unknown)return;
	if (m_Loadout[client][nClass] == null)return;

	// See if we need to holster something.
	if(m_MyItems[client] != null)
	{
		for (int i = 0; i < m_MyItems[client].Length; i++)
		{
			CEItem hItem;
			m_MyItems[client].GetArray(i, hItem);

			if(!ClientHasItemInLoadoutByIndex(client, nClass, hItem.m_iIndex))
			{
				RemoveClientWearableItem(client, hItem);
				i--;
			}
		}
	}

	// See if we need to equip something.
	if(m_Loadout[client][nClass] != null)
	{
		for (int i = 0; i < m_Loadout[client][nClass].Length; i++)
		{
			CEItem hItem;
			m_Loadout[client][nClass].GetArray(i, hItem);

			if(!IsClientWearingItemIndex(client, hItem.m_iIndex))
			{
				AddClientWearableItem(client, hItem);
			}
		}
	}
}

public void ClearClientLoadout(int client)
{
	for (int i = 0; i < view_as<int>(CEEconLoadoutClass); i++)
	{
		CEEconLoadoutClass nClass = view_as<CEEconLoadoutClass>(i);
		if (m_Loadout[client][nClass] == null)continue;

		for (int j = 0; j < m_Loadout[client][nClass].Length; j++)
		{
			CEItem hItem;
			m_Loadout[client][nClass].GetArray(j, hItem);

			CEconItems_DestroyItem(client, hItem);
		}

		delete m_Loadout[client][nClass];
	}
	m_bLoadoutCached[client] = false;
}
