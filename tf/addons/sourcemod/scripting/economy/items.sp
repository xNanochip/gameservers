//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Item manager.
//
//=========================================================================//

Handle 	g_CEEcon_ShouldItemBeBlocked,
		g_CEEcon_OnEquipItem,
		g_CEEcon_OnItemIsEquipped;

bool m_bIsEconItem[MAX_ENTITY_LIMIT + 1];
CEItem m_hEconItem[MAX_ENTITY_LIMIT + 1];

public void Items_AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_CEEcon_ShouldItemBeBlocked 	= new GlobalForward("CEEcon_ShouldItemBeBlocked", ET_Event, Param_Cell, Param_Array, Param_String);
	g_CEEcon_OnEquipItem 			= new GlobalForward("CEEcon_OnEquipItem", ET_Single, Param_Cell, Param_Array, Param_String);
	g_CEEcon_OnItemIsEquipped 		= new GlobalForward("CEEcon_OnItemIsEquipped", ET_Ignore, Param_Cell, Param_Cell, Param_Array, Param_String);
	
	CreateNative("CEEcon_IsEntityCustomEconItem", Native_IsEntityCustomEconItem);
}

ArrayList m_ItemDefinitons = null;

public void Items_PrecacheItems(KeyValues hSchema)
{
	if (hSchema == null)return;

	Items_FlushItemDefinitionCache();

	m_ItemDefinitons = new ArrayList(sizeof(CEItemDefinition));

	if(hSchema.JumpToKey("Items"))
	{
		if(hSchema.GotoFirstSubKey())
		{
			do {
				CEItemDefinition hDef;

				char sSectionName[11];
				hSchema.GetSectionName(sSectionName, sizeof(sSectionName));

				hDef.m_iIndex = StringToInt(sSectionName);

				hSchema.GetString("name", hDef.m_sName, sizeof(hDef.m_sName));
				hSchema.GetString("type", hDef.m_sType, sizeof(hDef.m_sType));

				// Converting attributes from KeyValues to ArrayList format.
				if(hSchema.JumpToKey("attributes"))
				{
					hDef.m_Attributes = Attributes_KeyValuesToArrayList(hSchema);
					hSchema.GoBack();
				}

				m_ItemDefinitons.PushArray(hDef);

			} while (hSchema.GotoNextKey());
		}
	}

	hSchema.Rewind();
}

public bool Items_GetItemDefinitionByIndex(int index, CEItemDefinition output)
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

public bool Items_GetItemDefinitionByName(const char[] name, CEItemDefinition output)
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

public void Items_FlushItemDefinitionCache()
{
	if (m_ItemDefinitons == null)return;

	for (int i = 0; i < m_ItemDefinitons.Length; i++)
	{
		CEItemDefinition buffer;
		m_ItemDefinitons.GetArray(i, buffer);

		// Delete the attribute ArrayList.
		delete buffer.m_Attributes;
	}

	delete m_ItemDefinitons;
}

public bool Items_IsEntityCustomEconItem(int entity)
{
	return m_bIsEconItem[entity];
}

public bool Items_CreateItem(CEItem buffer, int index, int defid, int quality, ArrayList override, char[] name)
{
	CEItemDefinition hDef;
	if (!Items_GetItemDefinitionByIndex(defid, hDef))return false;

	buffer.m_iIndex = index;
	buffer.m_iItemDefinitionIndex = defid;
	buffer.m_nQuality = quality;
	strcopy(buffer.m_sName, sizeof(buffer.m_sName), name);
	buffer.m_Attributes = Attributes_MergeAttributes(hDef.m_Attributes, override);

	return true;
}

public bool Items_GivePlayerItemByIndex(int client, CEItem item)
{
	// First, let's see if this item's definition even exists.
	// If it's not, we return false as a sign of an error.
	CEItemDefinition hDef;
	if (!Items_GetItemDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))return false;

	// This boolean will be returned in the end of this func's execution.
	// It shows whether item was actually created.
	bool bResult = false;

	// Let's ask subplugins if they're fine with equipping this item.
	Call_StartForward(g_CEEcon_ShouldItemBeBlocked);
	Call_PushCell(client);
	Call_PushArray(item, sizeof(CEItem));
	Call_PushString(hDef.m_sType);

	bool bShouldBlock = false;
	Call_Finish(bShouldBlock);

	// If noone responded or response is positive, equip this item.
	if (GetForwardFunctionCount(g_CEEcon_ShouldItemBeBlocked) == 0 || !bShouldBlock)
	{
		Call_StartForward(g_CEEcon_OnEquipItem);
		Call_PushCell(client);
		Call_PushArray(item, sizeof(CEItem));
		Call_PushString(hDef.m_sType);
		int iEntity = -1;

		Call_Finish(iEntity);

		if(IsEntityValid(iEntity))
		{
			m_bIsEconItem[iEntity] = true;
			m_hEconItem[iEntity] = item;

			Attributes_ApplyOriginalAttributes(iEntity);
		}

		// Alerting subplugins that this item was equipped.
		Call_StartForward(g_CEEcon_OnItemIsEquipped);
		Call_PushCell(client);
		Call_PushCell(iEntity);
		Call_PushArray(item, sizeof(CEItem));
		Call_PushString(hDef.m_sType);
		Call_Finish();

		bResult = true;
	}

	return bResult;
}

public any Native_IsEntityCustomEconItem(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	if(IsEntityValid(iEntity))
	{
		return m_bIsEconItem[iEntity];
	}
	return false;
}