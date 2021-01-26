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