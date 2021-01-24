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