//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Contracts handler for Creators.TF Economy.
//
//=========================================================================//

#include <steamtools>

#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

#include <cecon_http>
#include <cecon_items>
#include <cecon>
#include <tf2>
#include <tf2_stocks>
#include <cecon_contracts>

#define QUEST_HUD_REFRESH_RATE 0.5
#define QUEST_PANEL_MAX_CHARS 30
#define BACKEND_QUEST_UPDATE_INTERVAL 20.0 // Every 20 seconds.

#define CHAR_FULL "█"
#define CHAR_PROGRESS "▓"
#define CHAR_EMPTY "▒"

public Plugin myinfo =
{
	name = "Creators.TF Economy - Contracts Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Contracts Handler",
	version = "1.0",
	url = "https://creators.tf"
}

ArrayList m_hQuestDefinitions;
ArrayList m_hObjectiveDefinitions;
ArrayList m_hHooksDefinitions;

ArrayList m_hFriends[MAXPLAYERS + 1];
ArrayList m_hProgress[MAXPLAYERS + 1];

bool m_bWaitingForFriends[MAXPLAYERS + 1];
bool m_bWaitingForProgress[MAXPLAYERS + 1];

CEQuestDefinition m_xActiveQuestStruct[MAXPLAYERS + 1];

int m_iLastUniqueEvent[MAXPLAYERS + 1];
bool m_bIsObjectiveMarked[MAXPLAYERS + 1][MAX_OBJECTIVES + 1];

public void OnPluginStart()
{
	RegServerCmd("ce_quest_dump", cDump, "");
	RegServerCmd("ce_quest_activate", cQuestActivate, "");
	
	OnLateLoad();

	CreateTimer(QUEST_HUD_REFRESH_RATE, Timer_HudRefresh, _, TIMER_REPEAT);
	CreateTimer(BACKEND_QUEST_UPDATE_INTERVAL, Timer_QuestUpdateInterval, _, TIMER_REPEAT);
	
	HookEvent("teamplay_round_win", teamplay_round_win);
}

public Action cQuestActivate(int args)
{
	char sArg1[MAX_NAME_LENGTH], sArg2[11];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	int iTarget = FindTargetBySteamID64(sArg1);
	if (!IsClientValid(iTarget))return Plugin_Handled;

	int iQuest = StringToInt(sArg2);

	SetClientActiveQuestByIndex(iTarget, iQuest);
	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	ParseEconomyConfig(CEcon_GetEconomySchema());
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseEconomyConfig(hSchema);
}

public void ParseEconomyConfig(KeyValues kv)
{
	if (kv == null)return;
	
	FlushQuestDefinitions();
	m_hQuestDefinitions = 		new ArrayList(sizeof(CEQuestDefinition));
	m_hObjectiveDefinitions = 	new ArrayList(sizeof(CEQuestObjectiveDefinition));
	m_hHooksDefinitions = 		new ArrayList(sizeof(CEQuestObjectiveHookDefinition));
	
	if(kv.JumpToKey("Contracker/Quests", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				int iQuestWorldIndex = m_hQuestDefinitions.Length;
				
				char sSectionName[11];
				kv.GetSectionName(sSectionName, sizeof(sSectionName));
				
				CEQuestDefinition xQuest;
				xQuest.m_iIndex = StringToInt(sSectionName);
				
				xQuest.m_bBackground = kv.GetNum("background", 0) == 1;
				
				kv.GetString("name", xQuest.m_sName, sizeof(xQuest.m_sName));
				kv.GetString("postfix", xQuest.m_sPostfix, sizeof(xQuest.m_sPostfix), "CP");
				
				// Map Restrictions
				kv.GetString("restrictions/map", xQuest.m_sRestrictedToMap, sizeof(xQuest.m_sRestrictedToMap));
				kv.GetString("restrictions/map_s", xQuest.m_sStrictRestrictedToMap, sizeof(xQuest.m_sStrictRestrictedToMap));
				
				// CE Weapon Restriction
				char sCEWeapon[64];
				kv.GetString("restrictions/ce_weapon", sCEWeapon, sizeof(sCEWeapon));
				
				CEItemDefinition xDef;
				if(CEconItems_GetItemDefinitionByName(sCEWeapon, xDef))
				{
					xQuest.m_iRestrictedToCEWeaponIndex = xDef.m_iIndex;
				} else {
					xQuest.m_iRestrictedToCEWeaponIndex = StringToInt(sCEWeapon);
				}
				
				// TF2 Class Restriction
				char sTFClassName[64];
				kv.GetString("restrictions/class", sTFClassName, sizeof(sTFClassName));
				xQuest.m_nRestrictedToClass = TF2_GetClass(sTFClassName);
				
				if(kv.JumpToKey("objectives", false))
				{
					if(kv.GotoFirstSubKey())
					{
						do {
							
							int iObjectiveLocalIndex = xQuest.m_iObjectivesCount;
							int iObjectiveWorldIndex = m_hObjectiveDefinitions.Length;
							xQuest.m_Objectives[iObjectiveLocalIndex] = iObjectiveWorldIndex;
							xQuest.m_iObjectivesCount++;
							
							CEQuestObjectiveDefinition xObjective;
							xObjective.m_iIndex = iObjectiveLocalIndex;
							xObjective.m_iQuestIndex = iQuestWorldIndex;
							
							kv.GetString("name", xObjective.m_sName, sizeof(xObjective.m_sName));
							
							xObjective.m_iLimit = kv.GetNum("limit", 100);
							xObjective.m_iPoints = kv.GetNum("points", 0);
							xObjective.m_iEnd = kv.GetNum("end", 0);
							
							// CE Weapon Restriction
							kv.GetString("restrictions/ce_weapon", sCEWeapon, sizeof(sCEWeapon));
				
							if(CEconItems_GetItemDefinitionByName(sCEWeapon, xDef))
							{
								xObjective.m_iRestrictedToCEWeaponIndex = xDef.m_iIndex;
							} else {
								xObjective.m_iRestrictedToCEWeaponIndex = StringToInt(sCEWeapon);
							}
							
							if(kv.JumpToKey("hooks", false))
							{
								if(kv.GotoFirstSubKey())
								{	
									do {
							
										int iHookLocalIndex = xObjective.m_iHooksCount;
										int iHookWorldIndex = m_hHooksDefinitions.Length;
										xObjective.m_Hooks[iHookLocalIndex] = iHookWorldIndex;
										xObjective.m_iHooksCount++;
										
										char sAction[16];
										kv.GetString("action", sAction, sizeof(sAction));
										
										CEQuestActions nAction;
										if (StrEqual(sAction, "increment"))nAction = CEQuestAction_Increment;
										else if (StrEqual(sAction, "reset"))nAction = CEQuestAction_Reset;
										else if (StrEqual(sAction, "subtract"))nAction = CEQuestAction_Subtract;
										else if (StrEqual(sAction, "set"))nAction = CEQuestAction_Set;
										else nAction = CEQuestAction_Singlefire;
										
										CEQuestObjectiveHookDefinition xHook;
										xHook.m_iIndex = iHookLocalIndex;
										xHook.m_iObjectiveIndex = iObjectiveWorldIndex;
										xHook.m_iQuestIndex = iQuestWorldIndex;
										xHook.m_Action = nAction;
										
										kv.GetString("event", xHook.m_sEvent, sizeof(xHook.m_sEvent));
										
										m_hHooksDefinitions.PushArray(xHook);
									
									} while (kv.GotoNextKey());
									kv.GoBack();
								}
								kv.GoBack();
							}
							
							m_hObjectiveDefinitions.PushArray(xObjective);
							
						} while (kv.GotoNextKey());
						kv.GoBack();
					}
					kv.GoBack();
				}
				
				m_hQuestDefinitions.PushArray(xQuest);
			
			} while (kv.GotoNextKey());
		}
	}
	kv.Rewind();
}

public Action cDump(int args)
{
	LogMessage("Dumping precached data");
	for (int i = 0; i < 1; i++)
	{
		CEQuestDefinition xQuest;
		GetQuestByIndex(i, xQuest);

		LogMessage("CEQuestDefinition");
		LogMessage("{");
		LogMessage("  m_iIndex = %d", xQuest.m_iIndex);
		LogMessage("  m_bBackground = %d", xQuest.m_bBackground);
		LogMessage("  m_iObjectivesCount = %d", xQuest.m_iObjectivesCount);
		LogMessage("  m_sRestrictedToMap = \"%s\"", xQuest.m_sRestrictedToMap);
		LogMessage("  m_sStrictRestrictedToMap = \"%s\"", xQuest.m_sStrictRestrictedToMap);
		LogMessage("  m_nRestrictedToClass = %d", xQuest.m_nRestrictedToClass);
		LogMessage("  m_iRestrictedToCEWeaponIndex = %d", xQuest.m_iRestrictedToCEWeaponIndex);
		LogMessage("  m_Objectives =");
		LogMessage("  [");
		
		for (int j = 0; j < xQuest.m_iObjectivesCount; j++)
		{
			CEQuestObjectiveDefinition xObjective;
			if(GetQuestObjectiveByIndex(xQuest, j, xObjective))
			{
				LogMessage("    %d => CEQuestObjectiveDefinition", j);
				LogMessage("    {");
				LogMessage("      m_iIndex = %d", xObjective.m_iIndex);
				LogMessage("      m_iQuestIndex = %d", xObjective.m_iQuestIndex);
				LogMessage("      m_sName = \"%s\"", xObjective.m_sName);
				LogMessage("      m_iPoints = %d", xObjective.m_iPoints);
				LogMessage("      m_iLimit = %d", xObjective.m_iLimit);
				LogMessage("      m_iEnd = %d", xObjective.m_iEnd);
				LogMessage("      m_iHooksCount = %d", xObjective.m_iHooksCount);
				LogMessage("      m_iRestrictedToCEWeaponIndex = %d", xObjective.m_iRestrictedToCEWeaponIndex);
				LogMessage("      m_Hooks =");
				LogMessage("      [");
		
				for (int k = 0; k < xObjective.m_iHooksCount; k++)
				{
					CEQuestObjectiveHookDefinition xHook;
					if(GetObjectiveHookByIndex(xObjective, k, xHook))
					{
						LogMessage("        %d => CEQuestObjectiveHookDefinition", k);
						LogMessage("        {");
						LogMessage("          m_iIndex = %d", xHook.m_iIndex);
						LogMessage("          m_iObjectiveIndex = %d", xHook.m_iObjectiveIndex);
						LogMessage("          m_iQuestIndex = %d", xHook.m_iQuestIndex);
						
						LogMessage("          m_sEvent = \"%s\"", xHook.m_sEvent);
						LogMessage("          m_Action = %d", xHook.m_Action);
						LogMessage("        }");
					}
				}
				LogMessage("      ]");
				LogMessage("    }");
			}
		}
		
		LogMessage("  ]");
		LogMessage("}");

	}
	
	LogMessage("");
	LogMessage("CEQuestDefinition Count: %d", m_hQuestDefinitions.Length);
	LogMessage("CEQuestObjectiveDefinition Count: %d", m_hObjectiveDefinitions.Length);
	LogMessage("CEQuestObjectiveHookDefinition Count: %d", m_hHooksDefinitions.Length);
}

public void FlushQuestDefinitions()
{
	delete m_hQuestDefinitions;
	delete m_hObjectiveDefinitions;
	delete m_hHooksDefinitions;
}

public bool GetQuestByIndex(int index, CEQuestDefinition xStruct)
{
	if (m_hQuestDefinitions == null)return false;
	if (index >= m_hQuestDefinitions.Length)return false;
	if (index < 0)return false;
	
	m_hQuestDefinitions.GetArray(index, xStruct);
	return true;
}

public bool GetObjectiveByIndex(int index, CEQuestObjectiveDefinition xStruct)
{
	if (m_hObjectiveDefinitions == null)return false;
	if (index >= m_hObjectiveDefinitions.Length)return false;
	if (index < 0)return false;
	
	m_hObjectiveDefinitions.GetArray(index, xStruct);
	return true;
}

public bool GetHookByIndex(int index, CEQuestObjectiveHookDefinition xStruct)
{
	if (m_hHooksDefinitions == null)return false;
	if (index >= m_hHooksDefinitions.Length)return false;
	if (index < 0)return false;
	
	m_hHooksDefinitions.GetArray(index, xStruct);
	return true;
}

public bool GetQuestObjectiveByIndex(CEQuestDefinition xQuest, int index, CEQuestObjectiveDefinition xStruct)
{
	if (index < 0)return false;
	
	if (index >= xQuest.m_iObjectivesCount)return false;
	int iWorldIndex = xQuest.m_Objectives[index];
	
	GetObjectiveByIndex(iWorldIndex, xStruct);
	return true;
}

public bool GetObjectiveHookByIndex(CEQuestObjectiveDefinition xObjective, int index, CEQuestObjectiveHookDefinition xStruct)
{
	if (index < 0)return false;

	if (index >= xObjective.m_iHooksCount)return false;
	int iWorldIndex = xObjective.m_Hooks[index];
	
	GetHookByIndex(iWorldIndex, xStruct);
	return true;
}

public bool GetQuestByDefIndex(int defid, CEQuestDefinition xBuffer)
{
	if (m_hQuestDefinitions == null)return false;
	
	for (int i = 0; i < m_hQuestDefinitions.Length; i++)
	{
		CEQuestDefinition xStruct;
		m_hQuestDefinitions.GetArray(i, xStruct);
		
		if(xStruct.m_iIndex == defid)
		{
			xBuffer = xStruct;
			return true;
		}
	}
	
	return false;
}

public bool GetQuestByObjective(CEQuestObjectiveDefinition xObjective, CEQuestDefinition xBuffer)
{
	return GetQuestByIndex(xObjective.m_iQuestIndex, xBuffer);
}

public bool GetObjectiveByHook(CEQuestObjectiveHookDefinition xHook, CEQuestObjectiveDefinition xBuffer)
{
	return GetObjectiveByIndex(xHook.m_iObjectiveIndex, xBuffer);
}

public void RequestClientSteamFriends(int client)
{	
	if (!IsClientReady(client))return;
	if (m_bWaitingForFriends[client])return;
	
	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));

	HTTPRequestHandle httpRequest = CEconHTTP_CreateBaseHTTPRequest("/api/ISteamInterface/GUserFriends", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID64);

	Steam_SendHTTPRequest(httpRequest, RequestClientSteamFriends_Callback, client);
	return;
}

public void RequestClientSteamFriends_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	// We are not processing bots.
	if (!IsClientReady(client))return;
	
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

	delete m_hFriends[client];
	m_hFriends[client] = new ArrayList(ByteCountToCells(64));

	if(Response.JumpToKey("friends"))
	{
		if(Response.GotoFirstSubKey(false))
		{
			do {
				
				char sSteamID[64];
				Response.GetString(NULL_STRING, sSteamID, sizeof(sSteamID));
				m_hFriends[client].PushString(sSteamID);
				
			} while (Response.GotoNextKey(false));
		}
	}
	
	// Make a Callback.
	
	delete Response;
}

public void RequestClientContractProgress(int client)
{	
	if (!IsClientReady(client))return;
	if (m_bWaitingForProgress[client])return;
	
	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));

	HTTPRequestHandle httpRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserQuests", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "get", "progress");
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID64);

	Steam_SendHTTPRequest(httpRequest, RequestClientContractProgress_Callback, client);
	return;
}

public void RequestClientContractProgress_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	// We are not processing bots.
	if (!IsClientReady(client))return;
	
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

	delete m_hProgress[client];
	
	int iActive = Response.GetNum("activated");

	if(Response.JumpToKey("progress"))
	{
		if(Response.GotoFirstSubKey())
		{
			do {
				
				char sSectionName[11];
				Response.GetSectionName(sSectionName, sizeof(sSectionName));
				
				int iIndex = StringToInt(sSectionName);
				
				CEQuestClientProgress xProgress;
				xProgress.m_iClient = client;
				xProgress.m_iQuest = iIndex;
				
				if(Response.GotoFirstSubKey(false))
				{
					do {
				
						Response.GetSectionName(sSectionName, sizeof(sSectionName));
						iIndex = StringToInt(sSectionName);
						
						if (iIndex < 0 || iIndex >= MAX_OBJECTIVES)continue;
						xProgress.m_iProgress[iIndex] = Response.GetNum(NULL_STRING);
						
					} while (Response.GotoNextKey(false));
					
					Response.GoBack();
				}
				
				UpdateClientQuestProgress(client, xProgress);
				
			} while (Response.GotoNextKey());
		}
	}
	
	SetClientActiveQuestByIndex(client, iActive);
	
	// TODO: Make a forward call.
	
	delete Response;
}

public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

public void OnLateLoad()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		
		PrepareClientData(i);
	}
}

public void OnClientPostAdminCheck(int client)
{
	FlushClientData(client);
	PrepareClientData(client);
}

public void OnClientDisconnect(int client)
{
	FlushClientData(client);
}

public void PrepareClientData(int client)
{
	RequestClientSteamFriends(client);
	RequestClientContractProgress(client);
}

public void FlushClientData(int client)
{
	delete m_hFriends[client];
	delete m_hProgress[client];
	
	m_bWaitingForProgress[client] = false;
	m_bWaitingForFriends[client] = false;
	
	m_xActiveQuestStruct[client].m_iIndex = 0;
	m_iLastUniqueEvent[client] = 0;
}

public void UpdateClientQuestProgress(int client, CEQuestClientProgress xProgress)
{
	if(m_hProgress[client] == null)
	{
		m_hProgress[client] = new ArrayList(sizeof(CEQuestClientProgress));
	}
	
	for (int i = 0; i < m_hProgress[client].Length; i++)
	{
		CEQuestClientProgress xStruct;
		m_hProgress[client].GetArray(i, xStruct);
		
		if(xStruct.m_iQuest == xProgress.m_iQuest)
		{
			m_hProgress[client].Erase(i);
			i--;
		}
	}
	
	m_hProgress[client].PushArray(xProgress);
}

public bool GetClientQuestProgress(int client, CEQuestDefinition xQuest, CEQuestClientProgress xBuffer)
{
	xBuffer.m_iClient = client;
	xBuffer.m_iQuest = xQuest.m_iIndex;
	
	for (int i = 0; i < m_hProgress[client].Length; i++)
	{
		CEQuestClientProgress xStruct;
		m_hProgress[client].GetArray(i, xStruct);
		
		if(xStruct.m_iQuest == xQuest.m_iIndex)
		{
			xBuffer = xStruct;
			return true;
		}
	}
	
	return false;
}

public bool IsClientProgressLoaded(int client)
{
	return m_hProgress[client] != null;
}

public void SetClientActiveQuestByIndex(int client, int quest)
{
	// We can't change contract if we didn't load progress yet.
	if (!IsClientProgressLoaded(client))return;
	// We don't reactivate the quest if it's already active.
	if (m_xActiveQuestStruct[client].m_iIndex == quest)return;
	
	CEQuestDefinition xQuest;
	if(GetQuestByDefIndex(quest, xQuest))
	{
		m_xActiveQuestStruct[client] = xQuest;
		
		PrintToChat(client, "\x03You have activated '\x05%s\x03' contract. Type \x05!quest \x03or \x05!contract \x03to view current completion progress.", xQuest.m_sName);
		PrintToChat(client, "\x03You can change your contract on \x05creators.tf \x03in \x05ConTracker \x03tab.");

		char sDecodeSound[64];
		strcopy(sDecodeSound, sizeof(sDecodeSound), "Quest.Decode");
		if(StrEqual(xQuest.m_sPostfix, "MP"))
		{
			Format(sDecodeSound, sizeof(sDecodeSound), "%sHalloween", sDecodeSound);
		}

		ClientCommand(client, "playgamesound %s", sDecodeSound);
	}
}

public bool GetClientActiveQuest(int client, CEQuestDefinition xBuffer)
{
	if (m_xActiveQuestStruct[client].m_iIndex <= 0)return false;
	
	xBuffer = m_xActiveQuestStruct[client];
	return true;
}

public bool IsQuestActive(CEQuestDefinition xQuest)
{
	// Checking what is the current map.
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if (!StrEqual(xQuest.m_sRestrictedToMap, "") && StrContains(sMap, xQuest.m_sRestrictedToMap) == -1)return false;
	if (!StrEqual(xQuest.m_sStrictRestrictedToMap, "") && !StrEqual(xQuest.m_sStrictRestrictedToMap, sMap))return false;

	return true;
}

public Action Timer_HudRefresh(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		
		CEQuestDefinition xQuest;
		if(GetClientActiveQuest(i, xQuest))
		{
			CEQuestClientProgress xProgress;
			GetClientQuestProgress(i, xQuest, xProgress);
			
			char sText[256];
			Format(sText, sizeof(sText), "%s: \n", xQuest.m_sName);
			
			if(IsQuestActive(xQuest))
			{
				for (int j = 0; j < xQuest.m_iObjectivesCount; j++)
				{
					CEQuestObjectiveDefinition xObjective;
					if(GetQuestObjectiveByIndex(xQuest, j, xObjective))
					{
						int iLimit = xObjective.m_iLimit;
						int iProgress = xProgress.m_iProgress[j];
					
						if(j == 0)
						{
							Format(sText, sizeof(sText), "%s%d/%d%s \n", sText, iProgress, iLimit, xQuest.m_sPostfix);
						} else {
							if (iLimit == 0)continue;
							Format(sText, sizeof(sText), "%s[%d/%d] ", sText, iProgress, iLimit);
						}
					}
				}
			} else {
				Format(sText, sizeof(sText), "%s- Inactive - ", sText);
			}
			
			bool bByMe = xProgress.m_iSource == i;
			bool bByFriend = !bByMe && IsClientValid(xProgress.m_iSource);
			
			if(bByFriend)
			{
				Format(sText, sizeof(sText), "%s\n%N ", sText, xProgress.m_iSource);
				SetHudTextParams(1.0, -1.0, QUEST_HUD_REFRESH_RATE + 0.1, 50, 200, 50, 255);
	
			} else {
	
				if(bByMe)
				{
					SetHudTextParams(1.0, -1.0, QUEST_HUD_REFRESH_RATE + 0.1, 255, 200, 50, 255);
				} else {
					SetHudTextParams(1.0, -1.0, QUEST_HUD_REFRESH_RATE + 0.1, 255, 255, 255, 255);
				}
				Format(sText, sizeof(sText), "%s\n", sText);
			}

			ShowHudText(i, -1, sText);
			
			if (xProgress.m_iSource > 0)
			{
				xProgress.m_iSource = 0;
				UpdateClientQuestProgress(i, xProgress);
			}
		}
	}
}

public bool CanClientTriggerQuest(int client, CEQuestDefinition xQuest)
{
	if (!IsQuestActive(xQuest))return false;

	// Class Restriction.
	if (xQuest.m_nRestrictedToClass != TFClass_Unknown && 
		xQuest.m_nRestrictedToClass != TF2_GetPlayerClass(client)
	)return false;

	int iLastWeapon = CEcon_GetLastUsedWeapon(client);
	int iItemDef = xQuest.m_iRestrictedToCEWeaponIndex;
	if(iItemDef > 0)
	{
		if (!IsValidEntity(iLastWeapon))return false;
		if (!CEconItems_IsEntityCustomEconItem(iLastWeapon))return false;

		CEItem xItem;
		if(CEconItems_GetEntityItemStruct(iLastWeapon, xItem))
		{
			if (xItem.m_iItemDefinitionIndex != iItemDef)return false;
		} else {
			return false;
		}
	}

	return true;
}

public bool CanClientTriggerObjective(int client, CEQuestObjectiveDefinition xObjective)
{
	int iLastWeapon = CEcon_GetLastUsedWeapon(client);
	int iItemDef = xObjective.m_iRestrictedToCEWeaponIndex;
	if(iItemDef > 0)
	{
		if (!IsValidEntity(iLastWeapon))return false;
		if (!CEconItems_IsEntityCustomEconItem(iLastWeapon))return false;

		CEItem xItem;
		if(CEconItems_GetEntityItemStruct(iLastWeapon, xItem))
		{
			if (xItem.m_iItemDefinitionIndex != iItemDef)return false;
		} else {
			return false;
		}
	}
	return true;
}

public bool HasClientCompletedObjective(int client, CEQuestObjectiveDefinition xObjective)
{
	if (xObjective.m_iLimit <= 0)return false;
	
	CEQuestDefinition xQuest;
	if(GetQuestByObjective(xObjective, xQuest))
	{
		CEQuestClientProgress xProgress;
		GetClientQuestProgress(client, xQuest, xProgress);
		
		return xProgress.m_iProgress[xObjective.m_iIndex] >= xObjective.m_iLimit;
	}
	return false;
}

public void CEcon_OnClientEvent(int client, const char[] event, int add, int unique)
{
	IterateAndTickleClientQuests(client, client, event, add, unique);
	
	SendEventToFriends(client, event, add, unique);
}

public void IterateAndTickleClientQuests(int client, int source, const char[] event, int add, int unique)
{
	CEQuestDefinition xQuest;
	if(GetClientActiveQuest(client, xQuest))
	{
		TickleClientQuestObjectives(client, xQuest, client, event, add, unique);
	}
}

public void SendEventToFriends(int client, const char[] event, int add, int unique)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientReady(i))
		{
			if(GetClientTeam(client) == GetClientTeam(i))
			{
				if(AreClientsFriends(client, i))
				{
					IterateAndTickleClientQuests(i, client, event, add, unique);
				}
			}
		}
	}
}

public void TickleClientQuestObjectives(int client, CEQuestDefinition xQuest, int source, const char[] event, int add, int unique)
{
	if (!CanClientTriggerQuest(client, xQuest))return;
	
	bool bShouldResetObjectiveMark = false;
	
	if (m_iLastUniqueEvent[client] == 0)		bShouldResetObjectiveMark = true;
	if (m_iLastUniqueEvent[client] != unique)	bShouldResetObjectiveMark = true;
	
	// Event is new, unmark all events.
	if (bShouldResetObjectiveMark)
	{
		for (int i = 0; i < MAX_OBJECTIVES; i++)
		{
			m_bIsObjectiveMarked[client][i] = false;
		}
	}
	
	m_iLastUniqueEvent[client] = unique;

	for (int i = 0; i < xQuest.m_iObjectivesCount; i++)
	{
		if (m_bIsObjectiveMarked[client][i])continue;
		
		CEQuestObjectiveDefinition xObjective;
		if(GetQuestObjectiveByIndex(xQuest, i, xObjective))
		{
			if (!CanClientTriggerObjective(client, xObjective))continue;
			
			for (int j = 0; j < xObjective.m_iHooksCount; j++)
			{
				CEQuestClientProgress xProgress;
				GetClientQuestProgress(client, xQuest, xProgress);
				
				CEQuestObjectiveHookDefinition xHook;
				if(GetObjectiveHookByIndex(xObjective, j, xHook))
				{
					if (StrEqual(xHook.m_sEvent, ""))continue;
					if (!StrEqual(xHook.m_sEvent, event))continue;
					
					if(client == source)
					{
						// Send progress to friends.
					}
					
					m_bIsObjectiveMarked[client][i] = true;
					
					if (HasClientCompletedObjective(client, xObjective))continue;
					
					switch(xHook.m_Action)
					{
						// Just straight up fires the event.
						case CEQuestAction_Singlefire:
						{
							AddPointsToClientObjective(client, xObjective, add * xObjective.m_iPoints, source, false);
						}
						
						// Increments the internal objective variable by `add`.
						case CEQuestAction_Increment:
						{
							if(xObjective.m_iEnd > 0)
							{
								int iPrevValue = xProgress.m_iVariable[i];
								xProgress.m_iVariable[i] += add;
								
								int iToAdd = 0;
								while(xProgress.m_iVariable[i] >= xObjective.m_iEnd)
								{
									xProgress.m_iVariable[i] -= xObjective.m_iEnd;
									iToAdd += xObjective.m_iPoints;
								}
								
								// We only run update quest progress if we're really sure,
								// that variables have changed.
								if(iPrevValue != xProgress.m_iVariable[i])
								{
									UpdateClientQuestProgress(client, xProgress);
								}
								
								if(iToAdd > 0)
								{
									AddPointsToClientObjective(client, xObjective, iToAdd, source, false);
								}
							}
						}
						
						// Resets the internal objective value back to zero.
						case CEQuestAction_Reset:
						{
							// We only update values if we're really sure that something 
							// has changed.
							if(xProgress.m_iVariable[i] > 0)
							{
								xProgress.m_iVariable[i] = 0;
								UpdateClientQuestProgress(client, xProgress);
							}
						}
						
						// Subtracts the internal var by `var`.
						case CEQuestAction_Subtract:
						{
							int iPrevValue = xProgress.m_iVariable[i];
							xProgress.m_iVariable[i] -= add;
								
							// We only run update quest progress if we're really sure,
							// that variables have changed.
							if(iPrevValue != xProgress.m_iVariable[i])
							{
								UpdateClientQuestProgress(client, xProgress);
							}
						}
					}
				}
			}
		}
	}
}

public bool AddPointsToClientObjective(int client, CEQuestObjectiveDefinition xObjective, int points, int source, bool silent)
{
	CEQuestDefinition xQuest;
	if(GetQuestByObjective(xObjective, xQuest))
	{		
		int iObjectiveIndex = xObjective.m_iIndex;
		
		// First, let's check if our current objective is not completed.
		// We can't do anything if out current objective is already completed.
		if (HasClientCompletedObjective(client, xObjective))return;
		
		// At this point, we are sure that some points will be added regardless.
		int iPointsToAdd = 0;
		int iLimit = xObjective.m_iLimit;
				
		// If we're adding points to a bonus objective, we add just one
		// point to the bonus objective and the rest goes to the primary one. 
		if(iObjectiveIndex > 0)
		{
			bool bShouldMutePrimary = true;
			
			// By default, if we're triggering a bonus objective, we are muting
			// primary points change because we don't want sounds to overlay each other.
			// However, if the limit of our objective is set to zero, that means we can't
			// possibly increase it, because we're always clamped to zero.
			// So in this case, let the primary objective handle the sound. It should always 
			// have a limit.
			if (iLimit == 0)bShouldMutePrimary = false;
			
			CEQuestObjectiveDefinition xPrimary;
			if(GetQuestObjectiveByIndex(xQuest, 0, xPrimary))
			{
				// True if something changed.
				AddPointsToClientObjective(client, xPrimary, points, source, bShouldMutePrimary);
			}
			iPointsToAdd = 1;
		} else {
			// Otherwise, we're already primary. 
			// Let's add the full amount.
			
			iPointsToAdd = points;
		}
		
		if(iPointsToAdd > 0 && iLimit > 0)
		{
		
			CEQuestClientProgress xProgress;
			GetClientQuestProgress(client, xQuest, xProgress);
			
			int iBefore = xProgress.m_iProgress[iObjectiveIndex];
			bool bChanged, bIsCompleted;
			int iDifference;
			
			// Increasing progress for current objective.
			
			xProgress.m_iProgress[iObjectiveIndex] = MIN(iLimit, iBefore + iPointsToAdd);
			int iAfter = xProgress.m_iProgress[iObjectiveIndex];
			iDifference = iAfter - iBefore;
			
			if(iDifference > 0)
			{
				bChanged = true;
				bIsCompleted = iBefore < iLimit && iAfter >= iLimit;
			}
			
			if(bChanged)
			{
				
				xProgress.m_iSource = source;
				UpdateClientQuestProgress(client, xProgress);
				
				// Queue backend update.
				AddQuestUpdateBatch(client, xQuest.m_iIndex, iObjectiveIndex, iAfter);
				
				bool bIsHalloween = StrEqual(xQuest.m_sPostfix, "MP");
				
				// ------------------------ //
				// SOUND					//
				
				if(!silent)
				{
					char sSound[128];
					Format(sSound, sizeof(sSound), "Quest.StatusTick");
			
					char sLevel[24];
					switch(iObjectiveIndex)
					{
						case 0:strcopy(sLevel, sizeof(sLevel), "Novice");
						case 1:strcopy(sLevel, sizeof(sLevel), "Advanced");
						default:strcopy(sLevel, sizeof(sLevel), "Expert");
					}
			
					// Only play "Compelted" music, if we've completed primary objective.
					if(bIsCompleted && iObjectiveIndex == 0)
					{
						if(bIsHalloween)
						{
							Format(sSound, sizeof(sSound), "%sCompleteHalloween", sSound);
						} else {
							Format(sSound, sizeof(sSound), "%s%sComplete", sSound, sLevel);
						}
					} else {
						Format(sSound, sizeof(sSound), "%s%s", sSound, sLevel);
			
						if(client != source)
						{
							Format(sSound, sizeof(sSound), "%sFriend", sSound);
						}
					}
			
					ClientCommand(client, "playgamesound %s", sSound);
				}
				
				// -------------------------------- //
				// MESSAGE							//
				
				// Sending message in chat if user completes objective.
				if(bIsCompleted)
				{
					if(iObjectiveIndex == 0)
					{
						if(bIsHalloween)
						{
				 			PrintToChatAll("\x03%N \x01has completed the primary objective for their \x03%s\x01 Merasmission!", client, xQuest.m_sName);
						} else {
				 			PrintToChatAll("\x03%N \x01has completed the primary objective for their \x03%s\x01 contract!", client, xQuest.m_sName);
						}
					} else {
						if(bIsHalloween)
						{
				  			PrintToChatAll("\x03%N \x01has completed an incredibly scary bonus objective for their \x03%s\x01 Merasmission!", client, xQuest.m_sName);
						} else {
				  			PrintToChatAll("\x03%N \x01has completed an incredibly difficult bonus objective for their \x03%s\x01 contract!", client, xQuest.m_sName);
						}
					}
				}
			}	
		}
		
	}
}

public bool AreClientsFriends(int client, int target)
{
	// Check if users are friends
	char szAuth[256];
	GetClientAuthId(target, AuthId_SteamID64, szAuth, sizeof(szAuth));

	bool bFriends = false;

	if(m_hFriends[client] != null)
	{
		if(m_hFriends[client].FindString(szAuth) != -1)
		{
			return true;
		}
	}

	if(!bFriends)
	{
		GetClientAuthId(client, AuthId_SteamID64, szAuth, sizeof(szAuth));
		if(m_hFriends[target] != null)
		{
			if(m_hFriends[target].FindString(szAuth) != -1)
			{
				return true;
			}
		}
	}

	return false;
}

/*

public Action cQuestActivate(int client, int args)
{
	char sArg1[MAX_NAME_LENGTH], sArg2[11];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	int iTarget = FindTargetBySteamID64(sArg1);
	if (!IsClientValid(iTarget))return Plugin_Handled;

	int iQuest = StringToInt(sArg2);

	CEQuest_SetPlayerQuest(iTarget, iQuest);
	return Plugin_Handled;
}

public Action cQuest(int client, int args)
{
	if(m_hQuest[client].m_iIndex == 0)
	{
		PrintToChat(client, "\x01Go to \x03Creators.TF\x01 website and select a contract you want to complete in \x03Contracker \x01tab.");
		return Plugin_Handled;
	}

	ClientShowQuestPanel(client);
	return Plugin_Handled;
}

public void ClientShowQuestPanel(int client)
{

	if(m_hQuest[client].m_iIndex == 0)
	{
		PrintToChat(client, "\x01Go to \x03Creators.TF\x01 website and select a contract you want to complete in \x03Contracker \x01tab.");
		return;
	}

	if (m_hQuest[client].m_hObjectives == null)return;

	Menu hMenu = new Menu(mQuestMenu);
	char sQuest[128];

	CEObjective hPrimary;
	m_hQuest[client].m_hObjectives.GetArray(QUEST_OBJECTIVE_PRIMARY, hPrimary);

	Format(sQuest, sizeof(sQuest), "%s [%d/%d]\n ", m_hQuest[client].m_sName, hPrimary.m_iProgress, hPrimary.m_iLimit);
	hMenu.SetTitle(sQuest);

	for (int i = 0; i < m_hQuest[client].m_hObjectives.Length; i++)
	{
		CEObjective hObjective;
		m_hQuest[client].m_hObjectives.GetArray(i, hObjective);

		char sItem[512];

		int iLimit = hObjective.m_iLimit;
		int iPoints = hObjective.m_iPoints;
		int iProgress = hObjective.m_iProgress;

		Format(sItem, sizeof(sItem), "%s: %d%s", hObjective.m_sName, iPoints, m_hQuest[client].m_sPostfix);

		if(i > QUEST_OBJECTIVE_PRIMARY && iLimit > 0)
		{
			Format(sItem, sizeof(sItem), "[%d/%d] %s", iProgress, iLimit, sItem);
		}

		if(i == QUEST_OBJECTIVE_PRIMARY)
		{
			char sProgress[128];
			int iFilled = RoundToCeil(float(iProgress) / float(iLimit) * QUEST_PANEL_MAX_CHARS);

			for (int j = 1; j <= QUEST_PANEL_MAX_CHARS; j++)
			{
				if (j <= iFilled)
				{
					StrCat(sProgress, sizeof(sProgress), CHAR_FULL);
				} else if(j == iFilled + 1 && iFilled > 0)
				{
					StrCat(sProgress, sizeof(sProgress), CHAR_PROGRESS);

				} else {
					StrCat(sProgress, sizeof(sProgress), CHAR_EMPTY);
				}
			}

			Format(sItem, sizeof(sItem), "%s\n%s\n ", sItem, sProgress, iProgress, iLimit);
		}

		hMenu.AddItem("", sItem);
	}

	hMenu.ExitButton = true;
	hMenu.Display(client, 60);

	delete hMenu;
}

public int mQuestMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void CEcon_OnClientEvent(int client, const char[] event, int add, int unique)
{
	CEQuest_TickleObjectives(client, client, event, add, unique);
}

public void CEQuest_TickleObjectives(int client, int source, const char[] event, int add, int unique)
{
	if (!CEQuest_CanUseQuest(client))return;

	// Event is new, unmark all events.
	if (m_hQuest[client].m_iLastIndex != unique)
	{
		for (int i = 0; i < m_hQuest[client].m_hObjectives.Length; i++)
		{
			CEObjective hObjective;
			m_hQuest[client].m_hObjectives.GetArray(i, hObjective);
			hObjective.m_bMarked = false;
			m_hQuest[client].m_hObjectives.SetArray(i, hObjective);
		}
	}
	m_hQuest[client].m_iLastIndex = unique;

	for (int i = 0; i < m_hQuest[client].m_hObjectives.Length; i++)
	{
		if (!IsObjectiveActive(client, i))continue;
		CEObjective hObjective;
		m_hQuest[client].m_hObjectives.GetArray(i, hObjective);
		if (hObjective.m_bMarked)continue;

		for (int j = 0; j < MAX_HOOKS; j++)
		{
			if (StrEqual(m_sQuestEvents[client][i][j], ""))continue;
			if(StrEqual(m_sQuestEvents[client][i][j], event))
			{
				if(client == source)
				{
					CEQuest_SendProgressToFriends(client, event, add, unique);
				}

				hObjective.m_bMarked = true;
				m_hQuest[client].m_hObjectives.SetArray(i, hObjective);

				if(IsObjectiveComplete(client, i)) continue;

				switch(hObjective.m_nActions[j])
				{
					case ACTION_SINGLEFIRE:
					{
						CEQuest_AddObjectiveProgress(client, source, i, add * hObjective.m_iPoints);
					}
					case ACTION_INCREMENT:
					{
						if(hObjective.m_iEnd > 0)
						{
							hObjective.m_iCounter += add;

							while(hObjective.m_iCounter >= hObjective.m_iEnd)
							{
								hObjective.m_iCounter -= hObjective.m_iEnd;
								m_hQuest[client].m_hObjectives.SetArray(i, hObjective);
								CEQuest_AddObjectiveProgress(client, source, i, hObjective.m_iPoints);
								m_hQuest[client].m_hObjectives.GetArray(i, hObjective);
							}
							m_hQuest[client].m_hObjectives.SetArray(i, hObjective);
						}
					}
					case ACTION_RESET:
					{
						hObjective.m_iCounter = 0;
						m_hQuest[client].m_hObjectives.SetArray(i, hObjective);
					}
					case ACTION_SUBSTRACT:
					{
						hObjective.m_iCounter -= add;
						if (hObjective.m_iCounter < 0)hObjective.m_iCounter = 0;
						m_hQuest[client].m_hObjectives.SetArray(i, hObjective);
					}
				}

			}
		}
	}
}

public void CEQuest_SendProgressToFriends(int client, const char[] event, int add, int unique)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientReady(i))
		{
			if(GetClientTeam(client) == GetClientTeam(i))
			{
				if(m_hQuest[client].m_iIndex == m_hQuest[i].m_iIndex)
				{
					if(ArePlayersFriends(client, i))
					{
						CEQuest_TickleObjectives(i, client, event, add, unique);
					}
				}
			}
		}
	}
}

public bool ArePlayersFriends(int client, int target)
{
	// Check if users are friends
	char szAuth[256];
	GetClientAuthId(target, AuthId_SteamID64, szAuth, sizeof(szAuth));

	bool bFriends = false;

	if(m_hFriends[client] != null)
	{
		if(m_hFriends[client].FindString(szAuth) != -1)
		{
			return true;
		}
	}

	if(!bFriends)
	{
		GetClientAuthId(client, AuthId_SteamID64, szAuth, sizeof(szAuth));
		if(m_hFriends[target] != null)
		{
			if(m_hFriends[target].FindString(szAuth) != -1)
			{
				return true;
			}
		}
	}

	return false;
}


public bool CEQuest_AddObjectiveProgress(int client, int source, int objective, int add)
{
	if (!CEQuest_CanUseQuest(client))return false;

	CEObjective hPrimaryOld, hObjectiveOld, hPrimary, hObjective;
	m_hQuest[client].m_hObjectives.GetArray(QUEST_OBJECTIVE_PRIMARY, hPrimaryOld);
	m_hQuest[client].m_hObjectives.GetArray(QUEST_OBJECTIVE_PRIMARY, hPrimary);
	m_hQuest[client].m_hObjectives.GetArray(objective, hObjectiveOld);
	m_hQuest[client].m_hObjectives.GetArray(objective, hObjective);

	bool bChanged, bCompleted, bIsBonusCompleted;
	int iPrimaryDiff, iBonusDiff;

	// Increasing progress for primary objective.
	int iLimit = hPrimary.m_iLimit;
	int iProgress = hPrimary.m_iProgress;
	hPrimary.m_iProgress = MIN(iLimit, iProgress + add);

	iPrimaryDiff = hPrimary.m_iProgress - hPrimaryOld.m_iProgress;

	if(iPrimaryDiff > 0)
	{
		bChanged = true;
		bCompleted = hPrimaryOld.m_iProgress < iLimit && hPrimary.m_iProgress >= iLimit;
	}
	hPrimary.m_bUpdated = true;
	m_hQuest[client].m_hObjectives.SetArray(QUEST_OBJECTIVE_PRIMARY, hPrimary);

	// Increasing progress for bonus objective.
	if(objective > QUEST_OBJECTIVE_PRIMARY)
	{
		iLimit = hObjective.m_iLimit;
		iProgress = hObjective.m_iProgress;
		hObjective.m_iProgress = MIN(iLimit, iProgress + 1);

		iBonusDiff = hObjective.m_iProgress - hObjectiveOld.m_iProgress;
		if(iBonusDiff > 0)
		{
			bChanged = true;
			bIsBonusCompleted = hObjectiveOld.m_iProgress < iLimit && hObjective.m_iProgress >= iLimit;
		}
		hObjective.m_bUpdated = true;
		m_hQuest[client].m_hObjectives.SetArray(objective, hObjective);
	}

	m_hQuest[client].m_iSource = source;
	bool bIsHalloween = StrEqual(m_hQuest[client].m_sPostfix, "MP");

	if(bChanged)
	{
		char sMessage[125];
		Format(sMessage, sizeof(sMessage), "quest_progress:client=%d,contract=%d", client, m_hQuest[client].m_iIndex);
		if(iPrimaryDiff > 0)
		{
			Format(sMessage, sizeof(sMessage), "%s,obj_0=%d", sMessage, hPrimary.m_iProgress);
		}
		if(iBonusDiff > 0)
		{
			Format(sMessage, sizeof(sMessage), "%s,obj_%d=%d", sMessage, objective, hObjective.m_iProgress);
		}
		
		// CESC_SendMessage(sMessage);

		char sSound[128];
		Format(sSound, sizeof(sSound), "Quest.StatusTick");

		char sLevel[24];
		switch(objective)
		{
			case QUEST_OBJECTIVE_PRIMARY:strcopy(sLevel, sizeof(sLevel), "Novice");
			case 1:strcopy(sLevel, sizeof(sLevel), "Advanced");
			default:strcopy(sLevel, sizeof(sLevel), "Expert");
		}

		// Sending message in chat is user completes primary objective.
		if(bCompleted)
		{
			if(bIsHalloween)
			{
	 			PrintToChatAll("\x03%N \x01has completed the primary objective for their \x03%s\x01 Merasmission!", client, m_hQuest[client].m_sName);
			} else {
	 			PrintToChatAll("\x03%N \x01has completed the primary objective for their \x03%s\x01 contract!", client, m_hQuest[client].m_sName);
			}
		}
		if(bIsBonusCompleted)
		{
			if(bIsHalloween)
			{
	  			PrintToChatAll("\x03%N \x01has completed an incredibly scary bonus objective for their \x03%s\x01 Merasmission!", client, m_hQuest[client].m_sName);
			} else {
	  			PrintToChatAll("\x03%N \x01has completed an incredibly difficult bonus objective for their \x03%s\x01 contract!", client, m_hQuest[client].m_sName);
			}
		}

		if(bCompleted)
		{
			if(bIsHalloween)
			{
				Format(sSound, sizeof(sSound), "%sCompleteHalloween", sSound);
			} else {
				Format(sSound, sizeof(sSound), "%s%sComplete", sSound, sLevel);
			}
		} else {
			Format(sSound, sizeof(sSound), "%s%s", sSound, sLevel);

			if(client != source)
			{
				Format(sSound, sizeof(sSound), "%sFriend", sSound);
			}
		}

		ClientCommand(client, "playgamesound %s", sSound);
	}

	return bChanged;
}

public bool IsObjectiveActive(int client, int objective)
{
	if(m_hQuest[client].m_iIndex == 0) return false;
	if (m_hQuest[client].m_hObjectives == null)return false;

	CEObjective hObjective;
	m_hQuest[client].m_hObjectives.GetArray(objective, hObjective);

	int iLastWeapon = CEcon_GetLastUsedWeapon(client);
	int iExpectCEEconItemDefIndex = hObjective.m_iCEWeaponIndex;
	if(iExpectCEEconItemDefIndex > 0)
	{
		if (!IsValidEntity(iLastWeapon))return false;
		if (!CEconItems_IsEntityCustomEconItem(iLastWeapon))return false;

		CEItem xItem;
		if(CEconItems_GetEntityItemStruct(iLastWeapon, xItem))
		{
			if (xItem.m_iItemDefinitionIndex != iExpectCEEconItemDefIndex)return false;
		} else {
			return false;
		}
	}
	return true;
}

public bool IsObjectiveComplete(int client, int objective)
{
	if(m_hQuest[client].m_iIndex == 0) return false;
	if (m_hQuest[client].m_hObjectives == null)return false;

	CEObjective hObjective;
	m_hQuest[client].m_hObjectives.GetArray(objective, hObjective);

	if(objective > QUEST_OBJECTIVE_PRIMARY)
	{
		CEObjective hPrimary;
		m_hQuest[client].m_hObjectives.GetArray(QUEST_OBJECTIVE_PRIMARY, hPrimary);

		int iLimit = hPrimary.m_iLimit;
		int iProgress = hPrimary.m_iProgress;
		if (iLimit > 0 && iProgress < iLimit)return false;
	}

	int iLimit = hObjective.m_iLimit;
	int iProgress = hObjective.m_iProgress;
	if (iLimit > 0 && iProgress < iLimit)return false;

	return true;
}

public any Native_CanObjectiveTrigger(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int objective = GetNativeCell(2);

	if (!IsObjectiveActive(client, objective))return false;
	if (IsObjectiveComplete(client, objective))return false;

	return true;
}

public any Native_GetObjectiveName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int objective = GetNativeCell(2);
	int size = GetNativeCell(4);

	if (m_hQuest[client].m_hObjectives == null)return;

	CEObjective hObj;
	m_hQuest[client].m_hObjectives.GetArray(objective, hObj);
	SetNativeString(3, hObj.m_sName, size);
}

public any Native_FindQuestByIndex(Handle plugin, int numParams)
{
	int iIndex = GetNativeCell(1);
	KeyValues kv = CEcon_GetEconomySchema();
	KeyValues hQuest;

	char sKey[32];
	Format(sKey, sizeof(sKey), "Contracker/Quests/%d", iIndex);
	if(kv.JumpToKey(sKey, false))
	{
		hQuest = new KeyValues("Quest");
		hQuest.Import(kv);
	}
	
	delete kv;
	return hQuest;
}

public bool CEQuest_IsQuestActive(int client)
{
	if (m_hQuest[client].m_iIndex == 0)return false;

	// Checking what is the current map.
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if (!StrEqual(m_hQuest[client].m_sRestrictionMap, "") && StrContains(sMap, m_hQuest[client].m_sRestrictionMap) == -1)return false;
	if (!StrEqual(m_hQuest[client].m_sRestrictionStrictMap, "") && !StrEqual(m_hQuest[client].m_sRestrictionStrictMap, sMap))return false;

	return true;
}

public bool CEQuest_CanUseQuest(int client)
{
	if (!CEQuest_IsQuestActive(client))return false;
	if (m_hQuest[client].m_iIndex == 0)return false;

	if (m_hQuest[client].m_nRestrictionClass != TFClass_Unknown && m_hQuest[client].m_nRestrictionClass != TF2_GetPlayerClass(client))return false;

	int iLastWeapon = CEcon_GetLastUsedWeapon(client);
	int iExpectCEEconItemDefIndex = m_hQuest[client].m_iCEWeaponIndex;
	if(iExpectCEEconItemDefIndex > 0)
	{
		if (!IsValidEntity(iLastWeapon))return false;
		if (!CEconItems_IsEntityCustomEconItem(iLastWeapon))return false;

		CEItem xItem;
		if(CEconItems_GetEntityItemStruct(iLastWeapon, xItem))
		{
			if (xItem.m_iItemDefinitionIndex != iExpectCEEconItemDefIndex)return false;
		} else {
			return false;
		}
	}

	return true;
}

*/

public int FindTargetBySteamID64(const char[] steamid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientAuthorized(i))
		{
			char szAuth[256];
			GetClientAuthId(i, AuthId_SteamID64, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, steamid))return i;
		}
	}
	return -1;
}

public int MAX(int iNum1, int iNum2)
{
	if (iNum1 > iNum2)return iNum1;
	if (iNum2 > iNum1)return iNum2;
	return iNum1;
}

public int MIN(int iNum1, int iNum2)
{
	if (iNum1 < iNum2)return iNum1;
	if (iNum2 < iNum1)return iNum2;
	return iNum1;
}



enum struct CEQuestUpdateBatch
{
	int m_iClient;
	int m_iQuest;
	
	int m_iObjective;
	int m_iPoints;
}

ArrayList m_QuestUpdateBatches;

public void AddQuestUpdateBatch(int client, int quest, int objective, int points)
{
	if(m_QuestUpdateBatches == null)
	{
		m_QuestUpdateBatches = new ArrayList(sizeof(CEQuestUpdateBatch));
	}
	
	for (int i = 0; i < m_QuestUpdateBatches.Length; i++)
	{
		CEQuestUpdateBatch xBatch;
		m_QuestUpdateBatches.GetArray(i, xBatch);
		
		if (xBatch.m_iClient != client)continue;
		if (xBatch.m_iQuest != quest)continue;
		if (xBatch.m_iObjective != objective)continue;
		
		m_QuestUpdateBatches.Erase(i);
		i--;
	}
	
	CEQuestUpdateBatch xBatch;
	xBatch.m_iClient 	= client;
	xBatch.m_iQuest 	= quest;
	xBatch.m_iObjective = objective;
	xBatch.m_iPoints 	= points;
	m_QuestUpdateBatches.PushArray(xBatch);
}

public Action Timer_QuestUpdateInterval(Handle timer, any data)
{
	if (m_QuestUpdateBatches == null)return;
	if (m_QuestUpdateBatches.Length == 0)return;
	
	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserQuests", HTTPMethod_POST);
	
	for (int i = 0; i < m_QuestUpdateBatches.Length; i++)
	{
		CEQuestUpdateBatch xBatch;
		m_QuestUpdateBatches.GetArray(i, xBatch);
		
		char sSteamID[64];
		GetClientAuthId(xBatch.m_iClient, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
		
		char sKey[128];
		Format(sKey, sizeof(sKey), "quests[%s][%d][%d]", sSteamID, xBatch.m_iQuest, xBatch.m_iObjective);
		
		char sValue[11];
		IntToString(xBatch.m_iPoints, sValue, sizeof(sValue));
		
		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sValue);
	}
	
	Steam_SendHTTPRequest(hRequest, QuestUpdate_Callback);
	delete m_QuestUpdateBatches;
}

public void QuestUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;
	
	// Cool, we've updated everything.	
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast)
{
	// Update progress immediately when round ends. 
	// Players usually will look up their progress after they've done playing the game.
	// And it'll be frustrating to see their progress not being updated immediately.
	CreateTimer(0.1, Timer_QuestUpdateInterval);
}