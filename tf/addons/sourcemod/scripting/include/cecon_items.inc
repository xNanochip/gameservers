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

enum CEEconLoadoutClass
{
	CEconLoadoutClass_Unknown,
	
	CEconLoadoutClass_General,
	CEconLoadoutClass_Scout,
	CEconLoadoutClass_Soldier,
	CEconLoadoutClass_Pyro,
	CEconLoadoutClass_Demoman,
	CEconLoadoutClass_Heavy,
	CEconLoadoutClass_Engineer,
	CEconLoadoutClass_Medic,
	CEconLoadoutClass_Sniper,
	CEconLoadoutClass_Spy
}

// Creates a CEItem struct with provided value and returns it in buffer.
native bool		CEconItems_CreateItem(CEItem buffer, int index, int defid, int quality, ArrayList override, const char[] name);
// Destroys the CEItem struct. This function is required to call if item struct is no longer needed to close connected handles.
native void		CEconItems_DestroyItem(CEItem item);
// Gives this item to player.
native bool		CEconItems_GivePlayerItem(int client, CEItem item);

// Called to define whether this item should be blocked from equipping.
forward bool 	CEconItems_ShouldItemBeBlocked(int client, CEItem item, const char[] type);
// Called when subplugins need to initialize the code for item types.
forward int 	CEconItems_OnEquipItem(int client, CEItem item, const char[] type);
// Called after this item has been equipped.
forward void 	CEconItems_OnItemIsEquipped(int client, int entity, CEItem item, const char[] type);

// True if a specific world entity is custom econ item.
native bool 	CEconItems_IsEntityCustomEconItem(int entity);
// Returns true is a specific attribute name exists in the base game.
native bool 	CEconItems_IsAttributeNameOriginal(const char[] name);

// Merges two attribute ArrayLists together. Attributes with same name from array1 will
// be overwritten by value in array2.
native ArrayList CEconItems_MergeAttributes(ArrayList array1, ArrayList array2);
// Transforms KeyValues object into ArrayList of CEAttribute.
native ArrayList CEconItems_AttributesKeyValuesToArrayList(KeyValues attributes);

native bool 	CEconItems_GetAttributeStringFromArray(ArrayList attributes, const char[] name, char[] buffer, int length);
native int 		CEconItems_GetAttributeIntegerFromArray(ArrayList attributes, const char[] name);
native float 	CEconItems_GetAttributeFloatFromArray(ArrayList attributes, const char[] name);
native bool 	CEconItems_GetAttributeBoolFromArray(ArrayList attributes, const char[] name);

native bool 	CEconItems_GetEntityAttributeString(int entity, const char[] name, char[] buffer, int length);
native int 		CEconItems_GetEntityAttributeInteger(int entity, const char[] name);
native float 	CEconItems_GetEntityAttributeFloat(int entity, const char[] name);
native bool 	CEconItems_GetEntityAttributeBool(int entity, const char[] name);

// Applies all base game attributes using TF2Attributes plugin.
native void 	CEconItems_ApplyOriginalAttributes(int entity);



native
