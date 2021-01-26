//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Managing players loadouts.
// 
//=========================================================================//

//===============================//
// DOCUMENTATION

/* HOW DOES THE LOADOUT SYSTEM ACTUALLY WORK?
*	
*	When player requests their loadout (this happens when player respawns 
*	or touches ressuply locker), we run Loadout_InventoryApplication function.
*	This function checks if we already have loadout information loaded for this
*	specific player. If we have, apply the loadout right away using `Loadout_ApplyLoadout`.
*
*	If we dont, we request loadout info for the player from the backend using 
*	`Loadout_RequestPlayerLoadout`. The response for this request is parsed into m_Loadout[client] array.
*	m_Loadout[client] contains X ArrayLists, where X is the amount of classes that we have loadouts for.
*	(For TF2, the X value is 11. In consists of: 9 (TF2 Classes) + 1 (General Items Class) + 1 (Unknown Class)).
*
*	When we are sure we have loadout information available, `Loadout_ApplyLoadout` is run. This function checks 
*	which equipped items player is able to wear, and which items we need to holster from player.
*
*	If an item is eligible for being equipped, we run a forward with all the data about this item 
*	to the subplugins, who will take care of managing what these items need to do when equipped.
*
*/

/* DIFFERENCE BETWEEN EQUIPPED AND WEARABLE ITEMS
*	
*	Terminology:
*	"(Item) Equipped" 	- Item is in player loadout.
*	"Wearing (Item)"	- Player is currently wearing this item.
*
*	Why? 
*	Sometimes player loadout might not match what player 
*	actually has equipped. This can happen, for example, with
*	holiday restricted items. They are only wearable during holidays.
*	Also some specific item types are auto-unequipped by the game itself
*	when player touches ressuply locker. This happens with Cosmetics and
*	Weapons. To prevent mismatch between equipped items and wearable items,
*	we keep track of them separately.
*
*	To check if player has item equipped in their inventory you run:
*	- CEEcon_IsPlayerEquippedItemIndex(int client, CELoadoutClass class, int item_index);
*
*	To check if player has this item actually equipped right now, run:
*	- CEEcon_IsPlayerWearingItemIndex(int client, int item_index);
*/
//===============================//

ArrayList m_PartialReapplicationTypes;

bool m_bLoadoutCached[MAXPLAYERS + 1];
ArrayList m_Loadout[MAXPLAYERS + 1][CELoadoutClass]; 	// Cached loadout data of a user.
ArrayList m_MyItems[MAXPLAYERS + 1]; 					// Array of items this user is wearing.

bool m_bWaitingForLoadout[MAXPLAYERS + 1];
bool m_bInRespawn[MAXPLAYERS + 1];
bool m_bFullReapplication[MAXPLAYERS + 1];

public void Loadout_OnPluginStart()
{
	HookEvent("post_inventory_application", Loadout_post_inventory_application);
	HookEvent("player_spawn", Loadout_player_spawn);
	HookEvent("player_death", Loadout_player_death);
	
	RegServerCmd("ce_loadout_reset", cLoadoutReset);
	
	m_PartialReapplicationTypes = new ArrayList(ByteCountToCells(32));
	
	m_PartialReapplicationTypes.PushString("cosmetic");
	m_PartialReapplicationTypes.PushString("weapon");
}

// Entry point for loadout application. Requests user loadout if not yet cached.
public void Loadout_InventoryApplication(int client, bool full)
{
	// We do not apply loadouts on bots.
	if (!IsClientReady(client))return;
	
	// This user is currently already waiting for a loadout.
	if (m_bWaitingForLoadout[client])return;
	
	if(full)
	{
		Loadout_RemoveAllWearingItems(client);
	} else {
		if(m_MyItems[client] != null)
		{	
			for (int i = 0; i < m_PartialReapplicationTypes.Length; i++)
			{
				char sType[32];
				m_PartialReapplicationTypes.GetString(i, sType, sizeof(sType));
				Loadout_RemoveWearingItemsByType(client, sType);
			}
		}	
	}

	if (Loadout_HasCachedLoadout(client))
	{
		// If cached loadout is still recent, we parse cached response.
		 Loadout_ApplyLoadout(client);
	} else {
		// Otherwise request for the most recent data.
		Loadout_RequestPlayerLoadout(client, true);
	}
}

public Action cLoadoutReset(int args)
{
	char sArg1[64], sArg2[11];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	int iTarget = FindTargetBySteamID(sArg1);
	if (IsClientValid(iTarget))
	{
		if (m_bWaitingForLoadout[iTarget])return Plugin_Handled;
		Loadout_RequestPlayerLoadout(iTarget, false);

	}
	return Plugin_Handled;
}

// Used to request loadout information from backend.
public void Loadout_RequestPlayerLoadout(int client, bool apply)
{
	m_bWaitingForLoadout[client] = true;

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(apply);
	pack.Reset();

	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/IUsers/GLoadout", m_sBaseEconomyURL);
	
	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Cookie", "session_id=f457c545a9ded88f18ecee47145a72c04ac9f435bbbd8973d18b0723aae4c7b5295fefe1.b92b2b3f8a0439d2632195a560aa101b");
	
	Steam_SendHTTPRequest(httpRequest, Loadout_RequestPlayerLoadout_Callback, pack);
}

public void Loadout_RequestPlayerLoadout_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any pack)
{
	// Retrieving DataPack parameter. 
	DataPack hPack = pack;
	
	// Getting client index and apply boolean from datapack.
	int client = hPack.ReadCell();
	bool apply = hPack.ReadCell();
	
	// Removing Datapack.
	delete hPack;
	
	// We are not processing bots.
	if (!IsClientReady(client))return;

	// ======================== //
	// Making HTTP checks.
	
	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;

	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];
	
	// Getting actual response content body.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	KeyValues Response = new KeyValues("Response");
	
	// ======================== //
	// Parsing loadout response.
	
	// If we fail to import content return. 
	if (!Response.ImportFromString(content))return;
	
	Loadout_ClearLoadout(client);

	if(Response.JumpToKey("loadout"))
	{
		if(Response.GotoFirstSubKey())
		{
			do {
				char sClassName[32];
				Response.GetSectionName(sClassName, sizeof(sClassName));
				
				CELoadoutClass nClass;
				if(StrEqual(sClassName, "general")) nClass = CEClass_General; 
				if(StrEqual(sClassName, "scout")) nClass = CEClass_Scout; 
				if(StrEqual(sClassName, "soldier")) nClass = CEClass_Soldier; 
				if(StrEqual(sClassName, "pyro")) nClass = CEClass_Pyro; 
				if(StrEqual(sClassName, "demo")) nClass = CEClass_Demoman; 
				if(StrEqual(sClassName, "heavy")) nClass = CEClass_Heavy; 
				if(StrEqual(sClassName, "engineer")) nClass = CEClass_Engineer; 
				if(StrEqual(sClassName, "medic")) nClass = CEClass_Medic; 
				if(StrEqual(sClassName, "sniper")) nClass = CEClass_Sniper; 
				if(StrEqual(sClassName, "spy")) nClass = CEClass_Spy; 
				
				m_Loadout[client][nClass] = new ArrayList(sizeof(CEItem));
				
				if(Response.GotoFirstSubKey())
				{
					do {
					
						CEItemDefinition hDef;
						int iDefID = Response.GetNum("defid", -1);
						if (!Items_GetItemDefinitionByIndex(iDefID, hDef))continue;
					
						CEItem hItem;
						hItem.m_iIndex = Response.GetNum("id", -1);
						hItem.m_iItemDefinitionIndex = Response.GetNum("defid", -1);
						hItem.m_nQuality = Response.GetNum("quality", -1);
						Response.GetString("name", hItem.m_sName, sizeof(hItem.m_sName));
						
						if(Response.JumpToKey("attributes"))
						{
							ArrayList Frog = Attributes_KeyValuesToArrayList(Response);
							hItem.m_Attributes = Attributes_MergeAttributes(hDef.m_Attributes, Frog);
							Response.GoBack();
						}
						
						m_Loadout[client][nClass].PushArray(hItem);
					
					} while (Response.GotoNextKey());
					Response.GoBack();
				}
			} while (Response.GotoNextKey());
		}
	}
	
	m_bLoadoutCached[client] = true;
	
	delete Response;
	m_bWaitingForLoadout[client] = false;
	
	Loadout_InventoryApplication(client, true);
}

public void Loadout_ApplyLoadout(int client)
{
	CELoadoutClass nClass = Loadout_TFClassToCEClass(TF2_GetPlayerClass(client));
	
	if (nClass == CEClass_Unknown)return;
	if (m_Loadout[client][nClass] == null)return;
	
	// See if we need to holster something.
	if(m_MyItems[client] != null)
	{
		for (int i = 0; i < m_MyItems[client].Length; i++)
		{
			CEItem hItem;
			m_MyItems[client].GetArray(i, hItem);

			if(!Loadout_ClientHasItemEquippedByIndex(client, nClass, hItem.m_iIndex))
			{
				Loadout_RemoveWearingClientItem(client, hItem);
				i--;
			}
		}
	}
	
	// See if we need to equip something.
	if(m_Loadout[client][nClass] != null)
	{
		for (int i = 0; i < m_Loadout[client][nClass].Length; i++)
		{
			CEItem hItem;
			m_Loadout[client][nClass].GetArray(i, hItem);

			if(!Loadout_IsClientWearingItemIndex(client, hItem.m_iIndex))
			{
				Loadout_AddWearingClientItem(client, hItem);
			}
		}
	}
	
	
}

public bool Loadout_HasCachedLoadout(int client)
{
	return m_bLoadoutCached[client];
}


public Action Loadout_player_death(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	// RemoveAllWearables(client);
	m_bInRespawn[client] = false;
}

public Action Loadout_post_inventory_application(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	RequestFrame(RF_Loadout_InventoryApplication, client);
}

public Action Loadout_player_spawn(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	m_bFullReapplication[client] = true;

	// Users are in respawn room by default when they spawn.
	m_bInRespawn[client] = true;
}

public void RF_Loadout_InventoryApplication(int client)
{
	if(m_bFullReapplication[client])
	{
		PrintToChatAll("Full Reapplication");
		Loadout_InventoryApplication(client, true);
	} else {
		PrintToChatAll("Partial Reapplication");
		Loadout_InventoryApplication(client, false);
	}

	m_bFullReapplication[client] = false;
}

public void Loadout_ClearLoadout(int client)
{
	for (int i = 0; i < view_as<int>(CELoadoutClass); i++)
	{
		CELoadoutClass nClass = view_as<CELoadoutClass>(i);
		if (m_Loadout[client][nClass] == null)continue;
		
		for (int j = 0; j < m_Loadout[client][nClass].Length; j++)
		{
			CEItem hItem;
			m_Loadout[client][nClass].GetArray(j, hItem);
			
			delete hItem.m_Attributes;
		}
	
		delete m_Loadout[client][nClass];
	}
}

public CELoadoutClass Loadout_TFClassToCEClass(TFClassType class)
{
	switch(class)
	{
		case TFClass_Scout:return CEClass_Scout;
		case TFClass_Soldier:return CEClass_Soldier;
		case TFClass_Pyro:return CEClass_Pyro;
		case TFClass_DemoMan:return CEClass_Demoman;
		case TFClass_Heavy:return CEClass_Heavy;
		case TFClass_Engineer:return CEClass_Engineer;
		case TFClass_Medic:return CEClass_Medic;
		case TFClass_Sniper:return CEClass_Sniper;
		case TFClass_Spy:return CEClass_Spy;
	}
	return CEClass_Unknown;
}

public bool Loadout_ClientHasItemEquippedByIndex(int client, CELoadoutClass nClass, int index)
{
	if (m_Loadout[client][nClass] == null)return false;
	
	for (int i = 0; i < m_Loadout[client][nClass].Length; i++)
	{
		CEItem hItem;
		m_Loadout[client][nClass].GetArray(i, hItem);
		
		if (hItem.m_iIndex == index)return true;
	}
	
	return false;
}

public bool Loadout_IsClientWearingItemIndex(int client, int index)
{
	if (m_MyItems[client] == null)return false;
		
	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);
		
		if (hItem.m_iIndex == index)return true;
	}
	
	return false;
}

public void Loadout_AddWearingClientItem(int client, CEItem item)
{
	if (m_MyItems[client] == null)
	{
		m_MyItems[client] = new ArrayList(sizeof(CEItem));
	}
	
	m_MyItems[client].PushArray(item);
	
	Items_GivePlayerItemByIndex(client, item);
}

public void Loadout_RemoveWearingClientItem(int client, CEItem item)
{
	if (m_MyItems[client] == null)return;
	
	bool bRemoved = false;
	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);
		if(hItem.m_iIndex == item.m_iIndex)
		{
			m_MyItems[client].Erase(i);
			i--;
			bRemoved = true;
		}
	}
	
	if(bRemoved)
	{
		//PrintToChatAll("Holstered: %s", item.m_sName);
	}
}

public void Loadout_RemoveWearingItemsByType(int client, const char[] type)
{
	if (m_MyItems[client] == null)return;
	
	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);
		
		CEItemDefinition hDef;
		if(Items_GetItemDefinitionByIndex(hItem.m_iItemDefinitionIndex, hDef))
		{
			if(StrEqual(hDef.m_sType, type))
			{
				Loadout_RemoveWearingClientItem(client, hItem);
				i--;
			}
		}
	}
}

public void Loadout_RemoveAllWearingItems(int client)
{
	if (m_MyItems[client] == null)return;
	
	// I would just delete the m_MyItems, but we still need to notify other plugins about
	// all the items being holstered.
	
	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);
		
		Loadout_RemoveWearingClientItem(client, hItem);
	}
}