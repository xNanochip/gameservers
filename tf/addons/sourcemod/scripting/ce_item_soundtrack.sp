//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Handler for the Soundtrack custom item type.
// 
//=========================================================================//

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <cecon>
#include <cecon_items>

public Plugin myinfo =
{
	name = "Creators.TF (Soundtrack)",
	author = "Creators.TF Team",
	description = "Handler for the Cosmetic custom item type.",
	version = "1.0",
	url = "https://creators.tf"
};

//--------------------------------------------------------------------
// Purpose: Preload soundtrack indexes of all the players that are 
// already on the server.
//--------------------------------------------------------------------
public void OnPluginStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		
		UpdateClientSountrack(i);
	}
}

//--------------------------------------------------------------------
// Purpose: Update soundtrack for the client whos loadout was just
// updated.
//--------------------------------------------------------------------
public void CEconItems_OnClientLoadoutUpdated(int client)
{
	UpdateClientSountrack(client);
}

//--------------------------------------------------------------------
// Purpose: Read client's loadout and see what music kit they have
// equipped.
//--------------------------------------------------------------------
public void UpdateClientSountrack(int client)
{
	int iMusicKitIndex = -1;
	
	int iCount = CEconItems_GetClientLoadoutSize(client, CEconLoadoutClass_General);
	for (int i = 0; i <= iCount; i++)
	{
		CEItem xItem;
		if(CEconItems_GetClientItemFromLoadoutByIndex(client, CEconLoadoutClass_General, i, xItem))
		{
			iMusicKitIndex = xItem.m_iItemDefinitionIndex;
		}
	}
	
	if(iMusicKitIndex > -1)
	{
		CEItemDefinition xDef;
		if(CEconItems_GetItemDefinitionByIndex(iMusicKitIndex, xDef))
		{
			PrintToChatAll("%N's music kit is: %s", client, xDef.m_sName);
		}
	}
}