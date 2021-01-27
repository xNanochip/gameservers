public bool Attribute_IsOriginalTFAttributeName(const char[] name)
{
	return TFSchema_IsAttributeNameValid(name);
}

public ArrayList Attributes_KeyValuesToArrayList(KeyValues kv)
{
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

public ArrayList Attributes_MergeAttributes(ArrayList hArray1, ArrayList hArray2)
{
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

// ======================================= //
// ARRAYLIST ATTRIBUTES

// Returns attribute value by name in the arraylist.
public bool Attributes_GetAttributeStringFromArray(ArrayList hArray, const char[] name, char[] buffer, int length)
{
	if(hArray == null) return false;

	for(int i = 0; i < hArray.Length; i++)
	{
		CEAttribute hAttr;
		hArray.GetArray(i, hAttr);

		if(StrEqual(hAttr.m_sName, name))
		{
			strcopy(buffer, length, hAttr.m_sValue);
			return true;
		}
	}
	return false;
}

// Returns a float attribute value from ArrayList
public float Attributes_GetAttributeFloatFromArray(ArrayList, const char[] name)
{
	if(hArray == null) return 0.0;

	char sBuffer[11];
	Attributes_GetAttributeStringFromArray(ArrayList, name, sBuffer, sizeof(sBuffer));

	return StringToFloat(sBuffer);
}

public int Attributes_GetAttributeIntegerFromArray(ArrayList hArray, const char[] name)
{
	if(hArray == null) return 0;

	char sBuffer[11];
	Attributes_GetAttributeStringFromArray(ArrayList, name, sBuffer, sizeof(sBuffer));

	return StringToInt(sBuffer);
}

public bool Attributes_GetAttributeBoolFromArray(ArrayList hArray, const char[] name)
{
	if(hArray == null) return false;

	char sBuffer[11];
	Attributes_GetAttributeStringFromArray(ArrayList, name, sBuffer, sizeof(sBuffer));

	return StringToInt(sBuffer) > 0;
}


// ================================== //
// ENTITY ATTRIBUTES

public bool Attributes_GetEntityAttributeString(int entity, const char[] name, char[] buffer, int length)
{
	if(!Items_IsEntityCustomEconItem(entity)) return false;
	if(m_hEconItem[entity].m_Attributes == null) return false;

	return Attributes_GetAttributeStringFromArray(m_hEconItem[entity].m_Attributes, name, buffer, length);
}

public float Attributes_GetEntityAttributeFloat(int entity, const char[] name)
{
	if(!Items_IsEntityCustomEconItem(entity)) return 0.0;
	if(m_hEconItem[entity].m_Attributes == null) return 0.0;

	return Attributes_GetAttributeFloatFromArray(m_hEconItem[entity].m_Attributes, name);
}

public int Attributes_GetEntityAttributeInteger(int entity, const char[] name)
{
	if(!Items_IsEntityCustomEconItem(entity)) return 0;
	if(m_hEconItem[entity].m_Attributes == null) return 0;

	return Attributes_GetAttributeIntegerFromArray(m_hEconItem[entity].m_Attributes, name);
}

public bool Attributes_GetEntityAttributeInteger(int entity, const char[] name)
{
	if(!Items_IsEntityCustomEconItem(entity)) return false;
	if(m_hEconItem[entity].m_Attributes == null) return false;

	return Attributes_GetAttributeBoolFromArray(m_hEconItem[entity].m_Attributes, name);
}

public void Attributes_ApplyOriginalAttributes(int entity)
{
	if(!Items_IsEntityCustomEconItem(entity)) return;
	if(m_hEconItem[entity].m_Attributes == null) return;

	// TODO: Make a check to see if entity accepts TF2 attributes.

	for(int i = 0; i < m_hEconItem[entity].m_Attributes; i++)
	{
		CEAttribute hAttr;
		m_hEconItem[entity].m_Attributes.GetArray(i, hAttr);

		if(Attribute_IsOriginalTFAttributeName(hAttr.m_sName))
		{
			float flValue = StringToFloat(hAttr.m_sValue);
			TF2Attrib_SetByName(entity, hAttr.m_sName, flValue);
		}
	}
}
