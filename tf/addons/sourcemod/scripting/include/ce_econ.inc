//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Include file for plugins that use Creators.TF Custom Economy features.
//
//=========================================================================//

// Returns a list of all items in player's inventory.
// @param	client		Client to fetch inventory of.
// @param 	callback	Callback that contains a total list of items.
// @param	context		Any value that needs to be passed in the callback.
// @return 	Returns true if no errors occured, false otherwise.
// @error 	This function only accepts bots.
native bool CEEcon_GetAllItems(int client, CEEconResultItems callback, any context);

// Generates a list of items in player's inventory.
// @param	client		Client to generate items for.
// @param	defid		Array of item definition indexes of items.
// @param 	quality		Array of qualities for every 
native bool CEEcon_GenerateItem(int client, int[] defid, int[] quality, int count, int amount, CEEconResultItems callback, any context);

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

	ArrayList m_BaseAttributes;
}

enum struct CEAttribute
{
	char m_sName[128];
	char m_sValue[256];
}
