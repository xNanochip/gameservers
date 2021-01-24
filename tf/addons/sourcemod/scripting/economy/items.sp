//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Item manager.
// 
//=========================================================================//

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
					hDef.m_BaseAttributes = Attributes_KeyValuesToArrayList(hSchema);
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
		delete buffer.m_BaseAttributes;
	}
	
	delete m_ItemDefinitons;
}

public void Items_GivePlayerItemByIndex(int client, CEItem item)
{
	
}