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
	g_CEEcon_OnEquipItem 			= new GlobalForward("CEEcon_OnEquipItem", ET_Single, Param_Cell, Param_Array);
	g_CEEcon_OnItemIsEquipped 		= new GlobalForward("CEEcon_OnItemIsEquipped", ET_Ignore, Param_Cell, Param_Cell, Param_Array);
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
		int iEntity = -1;

		Call_Finish(iEntity);

		if(IsEntityValid(iEntity))
		{
			m_bIsEconItem[iEntity] = true;
			m_hEconItem[iEntity] = item;

			//CE_SetEntityAttributes(iEntity, hAttributes);
			//CE_ApplyOriginalAttributes(iEntity, hAttributes);
		}

		for (int i = 0; i < item.m_Attributes.Length; i++)
		{
			CEAttribute Attr;
			item.m_Attributes.GetArray(i, Attr);

			if(Attribute_IsOriginalTFAttributeName(Attr.m_sName))
			{
				PrintToChatAll("%s is official", Attr.m_sName);
			}
		}
		/*
		if(UTIL_IsEntityValid(iEntity))
		{
			m_bIsCustomEconItem[iEntity] = true;
			m_iEconIndex[iEntity] = iIndex;
			m_iEconDefIndex[iEntity] = iDefID;
			m_iEconQuality[iEntity] = iQuality;

			CE_SetEntityAttributes(iEntity, hAttributes);
			CE_ApplyOriginalAttributes(iEntity, hAttributes);
		}
		// Alerting subplugins that this item was equipped.
		Call_StartForward(g_hOnPostEquip);
		Call_PushCell(iClient);
		Call_PushCell(iEntity);
		Call_PushCell(iIndex);
		Call_PushCell(iDefID);
		Call_PushCell(iQuality);
		Call_PushCell(hAttributes);
		Call_PushString(sType);
		Call_Finish();

		bResult = true;*/
	}

	return bResult;
}
