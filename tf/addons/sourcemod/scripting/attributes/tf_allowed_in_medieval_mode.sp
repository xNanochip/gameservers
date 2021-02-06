#pragma semicolon 1

#include <cecon_items>
#include <sdkhooks>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "[CE Attribute] allowed in medieval mode",
	author = "Creators.TF Team",
	description = "allowed in medieval mode",
	version = "1.0",
	url = "https://creators.tf"
}

public bool CEconItems_ShouldItemBeBlocked(int client, CEItem xItem, const char[] type)
{
	if (!StrEqual(type, "weapon"))return false;
	
	if(GameRules_GetProp("m_bPlayingMedieval") == 1)
	{
		if(CEconItems_GetAttributeBoolFromArray(xItem.m_Attributes, "allowed in medieval mode"))
		{
			return true;
		}
		return true;
	}
	return false;
}