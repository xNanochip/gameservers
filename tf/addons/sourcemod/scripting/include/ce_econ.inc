//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Include file for plugins that use Creators.TF Custom Economy features.
// 
//=========================================================================//

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