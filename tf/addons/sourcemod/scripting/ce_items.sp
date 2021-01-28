//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Loadout, attributes, items module for Creators.TF
// Custom Economy.
//
//=========================================================================//

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

// Definitions cache.
ArrayList m_ItemDefinitons = null;

// Native and Forward creation.
public void AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_CEcon_ShouldItemBeBlocked 	= new GlobalForward("CEconItems_ShouldItemBeBlocked", ET_Event, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnEquipItem 			= new GlobalForward("CEconItems_OnEquipItem", ET_Single, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnItemIsEquipped 		= new GlobalForward("CEconItems_OnItemIsEquipped", ET_Ignore, Param_Cell, Param_Cell, Param_Array, Param_String);

	CreateNative("CEconItems_CreateItem", Native_CreateItem);
	CreateNative("CEconItems_GivePlayerItem", Native_GivePlayerItem);

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
    PrecacheItemsFromSchema(CEcon_GetEconomySchema());

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
// Purpose: Returns true if attribute name exists within base TF2
// economy
//---------------------------------------------------------------------
public bool IsAttributeNameOriginal(const char[] name)
{
	Address pSchema = SDKCall(g_SDKCallGetEconItemSchema);
	if(pSchema)
	{
		return SDKCall(g_SDKCallSchemaGetAttributeDefinitionByName, pSchema, name) != Address_Null;
	}
	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_IsAttributeNameOriginal
//---------------------------------------------------------------------
public any Native_IsAttributeNameOriginal(Handle plugin, int numParams)
{
    char sName[64];
    GetNativeString(1, sName, sizeof(sName));

    return IsAttributeNameOriginal(sName);
}
