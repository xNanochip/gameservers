enum struct CEItem
{
	int m_iIndex;
	int m_iItemDefinitionIndex;
	int m_nQuality;
	char m_sName[64];

	ArrayList m_Attributes;
}

enum struct CEItemDefinition
{
	int m_iIndex;
	char m_sName[128];
	char m_sType[32];

	ArrayList m_Attributes;
}

enum struct CEAttribute
{
	char m_sName[128];
	char m_sValue[256];
}

enum CELoadoutClass
{
	CEClass_Unknown,
	CEClass_General,
	CEClass_Scout,
	CEClass_Soldier,
	CEClass_Pyro,
	CEClass_Demoman,
	CEClass_Heavy,
	CEClass_Engineer,
	CEClass_Medic,
	CEClass_Sniper,
	CEClass_Spy
}

native bool		CEconItems_CreateItem(CEItem buffer, int index, int defid, int quality, ArrayList override, const char[] name);
native bool		CEconItems_GivePlayerItem(int client, CEItem item);

forward bool 	CEconItems_ShouldItemBeBlocked(int client, CEItem item);
forward int 	CEconItems_OnEquipItem(int client, CEItem item);
forward void 	CEconItems_OnItemIsEquipped(int client, int entity, CEItem item);

native bool 	CEconItems_IsEntityCustomEconItem(int entity);
native bool 	CEconItems_IsAttributeNameOriginal(const char[] name);

native ArrayList CEconItems_MergeAttributes(ArrayList array1, ArrayList array2);
native ArrayList CEconItems_AttributesKeyValuesToArrayList(KeyValues attributes);

native bool 	CEconItems_GetAttributeStringFromArray(ArrayList attributes, const char[] name, char[] buffer, int length);
native int 		CEconItems_GetAttributeIntegerFromArray(ArrayList attributes, const char[] name);
native float 	CEconItems_GetAttributeFloatFromArray(ArrayList attributes, const char[] name);
native bool 	CEconItems_GetAttributeBoolFromArray(ArrayList attributes, const char[] name);

native bool 	CEconItems_GetEntityAttributeString(int entity, const char[] name, char[] buffer, int length);
native int 		CEconItems_GetEntityAttributeInteger(int entity, const char[] name);
native float 	CEconItems_GetEntityAttributeFloat(int entity, const char[] name);
native bool 	CEconItems_GetEntityAttributeBool(int entity, const char[] name);

native void 	CEconItems_ApplyOriginalAttributes(int entity);
