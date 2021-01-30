ArrayList m_PartialReapplicationTypes;

bool m_bLoadoutCached[MAXPLAYERS + 1];
ArrayList m_Loadout[MAXPLAYERS + 1][CEconLoadoutClass]; 	// Cached loadout data of a user.
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

	PrintToChatAll("Loadout_RequestPlayerLoadout()");
	Steam_SendHTTPRequest(httpRequest, Loadout_RequestPlayerLoadout_Callback, pack);
}

public void Loadout_RequestPlayerLoadout_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any pack)
{
	PrintToChatAll("Loadout_RequestPlayerLoadout_Callback()");
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

				CEconLoadoutClass nClass;
				if(StrEqual(sClassName, "general")) nClass = CEconLoadoutClass_General;
				if(StrEqual(sClassName, "scout")) nClass = CEconLoadoutClass_Scout;
				if(StrEqual(sClassName, "soldier")) nClass = CEconLoadoutClass_Soldier;
				if(StrEqual(sClassName, "pyro")) nClass = CEconLoadoutClass_Pyro;
				if(StrEqual(sClassName, "demo")) nClass = CEconLoadoutClass_Demoman;
				if(StrEqual(sClassName, "heavy")) nClass = CEconLoadoutClass_Heavy;
				if(StrEqual(sClassName, "engineer")) nClass = CEconLoadoutClass_Engineer;
				if(StrEqual(sClassName, "medic")) nClass = CEconLoadoutClass_Medic;
				if(StrEqual(sClassName, "sniper")) nClass = CEconLoadoutClass_Sniper;
				if(StrEqual(sClassName, "spy")) nClass = CEconLoadoutClass_Spy;

				m_Loadout[client][nClass] = new ArrayList(sizeof(CEItem));

				if(Response.GotoFirstSubKey())
				{
					do {

						int iIndex = Response.GetNum("id", -1);
						int iDefID = Response.GetNum("defid", -1);
						int iQuality = Response.GetNum("quality", -1);
						char sName[64];
						Response.GetString("name", sName, sizeof(sName));
						ArrayList hOverrides;

						if(Response.JumpToKey("attributes"))
						{
							hOverrides = Attributes_KeyValuesToArrayList(Response);
							Response.GoBack();
						}

						CEItem hItem;
						Items_CreateItem(hItem, iIndex, iDefID, iQuality, hOverrides, sName);

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
	CEconLoadoutClass nClass = Loadout_TFClassToCEClass(TF2_GetPlayerClass(client));

	if (nClass == CEconLoadoutClass_Unknown)return;
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
	for (int i = 0; i < view_as<int>(CEconLoadoutClass); i++)
	{
		CEconLoadoutClass nClass = view_as<CEconLoadoutClass>(i);
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

public CEconLoadoutClass Loadout_TFClassToCEClass(TFClassType class)
{
	switch(class)
	{
		case TFClass_Scout:return CEconLoadoutClass_Scout;
		case TFClass_Soldier:return CEconLoadoutClass_Soldier;
		case TFClass_Pyro:return CEconLoadoutClass_Pyro;
		case TFClass_DemoMan:return CEconLoadoutClass_Demoman;
		case TFClass_Heavy:return CEconLoadoutClass_Heavy;
		case TFClass_Engineer:return CEconLoadoutClass_Engineer;
		case TFClass_Medic:return CEconLoadoutClass_Medic;
		case TFClass_Sniper:return CEconLoadoutClass_Sniper;
		case TFClass_Spy:return CEconLoadoutClass_Spy;
	}
	return CEconLoadoutClass_Unknown;
}

public bool Loadout_ClientHasItemEquippedByIndex(int client, CEconLoadoutClass nClass, int index)
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
		i--;
	}
}
