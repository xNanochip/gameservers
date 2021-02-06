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
#define QUEST_PROGRESS_INTERVAL 10.0

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

CEQuest m_hQuest[MAXPLAYERS + 1];
ArrayList m_hFriends[MAXPLAYERS + 1];
int m_iWaitingForQuest[MAXPLAYERS + 1];

char m_sQuestEvents[MAXPLAYERS + 1][16][MAX_HOOKS][128];

public void OnPluginStart()
{
	for (int i = 1; i <= MaxClients; i++) // just in case plugin late loads
	{
		if (!IsClientValid(i))continue;

		CEQuest_InitClient(i);
	}

	CreateTimer(QUEST_HUD_REFRESH_RATE, Timer_HudRefresh, _, TIMER_REPEAT);

	RegConsoleCmd("sm_quest", cQuest, "Check your Contract progress");
	RegConsoleCmd("sm_q", cQuest, "Check your Contract progress");
	RegConsoleCmd("sm_contract", cQuest, "Check your Contract progress");

	RegAdminCmd("ce_quest_activate", cQuestActivate, ADMFLAG_ROOT, "Check your Contract progress");

}

public void CEQuest_InitClient(int client)
{
	if (!IsClientReady(client))return;

	CEQuest_SetPlayerActiveQuest(client);
	CEQuest_PlayerLoadFriends(client);
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_contracts");

	CreateNative("CEQuest_SetPlayerQuest", Native_SetPlayerQuest);
	CreateNative("CEQuest_FindQuestByIndex", Native_FindQuestByIndex);
	CreateNative("CEQuest_GetObjectiveName", Native_GetObjectiveName);
	CreateNative("CEQuest_CanObjectiveTrigger", Native_CanObjectiveTrigger);

 	return APLRes_Success;
}

public void OnClientPostAdminCheck(int client)
{
	CEQuest_InitClient(client);
}

public void CEQuest_PlayerLoadFriends(int client)
{
	FlushFriendsCache(client);
	
	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	HTTPRequestHandle httpRequest = CEcon_CreateBaseHTTPRequest("/api/ISteamInterface/GUserFriends", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID);
	Steam_SendHTTPRequest(httpRequest, httpFetchFriends, client);
}

public void httpFetchFriends(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	if (!IsClientReady(client))return;

	if(code == HTTPStatusCode_OK)
	{
		// Getting response content length.
		int size = Steam_GetHTTPResponseBodySize(request);
		char[] content = new char[size + 1];
	
		// Getting actual response content body.
		Steam_GetHTTPResponseBodyData(request, content, size);
		Steam_ReleaseHTTPRequest(request);
	
		if (content[0] != '"')return;

		// Loading KeyValues of the project.
		KeyValues hFriends = new KeyValues("Friends");
		hFriends.ImportFromString(content);

		if(hFriends.JumpToKey("friends", false))
	    {
		    delete m_hFriends[client];
		    m_hFriends[client] = new ArrayList(ByteCountToCells(64));

		    if(hFriends.GotoFirstSubKey(false))
		    {
		   		do {
					char sSteamID[64];
					hFriends.GetString(NULL_STRING, sSteamID, sizeof(sSteamID), "");
					m_hFriends[client].PushString(sSteamID);

		   		} while (hFriends.GotoNextKey(false));
		   	}
			PrintToConsole(client, "[INFO] Steam Friends Found: %d", m_hFriends[client].Length);
	  	}
		delete hFriends;
	}
}

public void CEQuest_SetPlayerActiveQuest(int client)
{
	CEQuest_SetPlayerQuest(client, QUEST_INDEX_ACTIVE);
}

public Action Timer_HudRefresh(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		if (m_hQuest[i].m_iIndex == 0)continue;

		char sText[256];
		Format(sText, sizeof(sText), "%s: \n", m_hQuest[i].m_sName);

		if(CEQuest_IsQuestActive(i))
		{
			for (int j = 0; j < m_hQuest[i].m_hObjectives.Length; j++)
			{
				CEObjective hObj;
				m_hQuest[i].m_hObjectives.GetArray(j, hObj);

				int iLimit = hObj.m_iLimit;
				int iProgress = hObj.m_iProgress;

				if(j == QUEST_OBJECTIVE_PRIMARY)
				{
					Format(sText, sizeof(sText), "%s%d/%d%s \n", sText, iProgress, iLimit, m_hQuest[i].m_sPostfix);

				} else {

					if (iLimit == 0)continue;
					Format(sText, sizeof(sText), "%s[%d/%d] ", sText, iProgress, iLimit);
				}
			}
		} else {

			Format(sText, sizeof(sText), "%s- Inactive - ", sText);
		}

		bool bByMe = m_hQuest[i].m_iSource == i;
		bool bByFriend = !bByMe && IsClientValid(m_hQuest[i].m_iSource);

		if(bByFriend)
		{
			Format(sText, sizeof(sText), "%s\n%N ", sText, m_hQuest[i].m_iSource);
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
		if (m_hQuest[i].m_iSource > 0)m_hQuest[i].m_iSource = 0;
	}

}

public any Native_SetPlayerQuest(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int quest = GetNativeCell(2);
	if (m_hQuest[client].m_iIndex == quest)return;

	FlushClientCache(client);

	char sUrl[128];
	Format(sUrl, sizeof(sUrl), "/api/IUsers/GContracker?get=contract&contract=%d", quest);

	m_iWaitingForQuest[client] = quest;
	
	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	char sQuest[11];
	IntToString(quest, sQuest, sizeof(sQuest));
	
	HTTPRequestHandle httpRequest = CEcon_CreateBaseHTTPRequest("/api/IEconomySDK/UserQuests", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "contract", sQuest);
	Steam_SendHTTPRequest(httpRequest, httpFetchFriends, client);
}

public void httpFetchContracker(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	if(code == HTTPStatusCode_OK)
	{
		// Getting response content length.
		int size = Steam_GetHTTPResponseBodySize(request);
		char[] content = new char[size + 1];
	
		// Getting actual response content body.
		Steam_GetHTTPResponseBodyData(request, content, size);
		Steam_ReleaseHTTPRequest(request);
		
		if (content[0] != '"')return;

		// Loading KeyValues of the project.
		KeyValues hProgress = new KeyValues("Progress");
		hProgress.ImportFromString(content);

		// Checking if result was succesful.
		char sResult[32];
		hProgress.GetString("result", sResult, sizeof(sResult));
		if(!StrEqual(sResult, "SUCCESS"))
		{
			// Nvm, we've failed. Flush everything.
			m_hQuest[client].m_iIndex = 0;
			delete hProgress;
			return;
		}

		if(hProgress.JumpToKey("contract", false))
		{
			// Getting the Index of the quest.
			int iIndex = hProgress.GetNum("id");

			if(m_iWaitingForQuest[client] > -1 && m_iWaitingForQuest[client] != iIndex)
			{
				m_hQuest[client].m_iIndex = 0;
				delete hProgress;
				return;
			}

			// Let's check if this quest even exists.
			KeyValues hQuest = CEQuest_FindQuestByIndex(iIndex);

			FlushClientCache(client);
			if (hQuest != null)
			{
				// Saving the index of the quest and the definition config.
				m_hQuest[client].m_iIndex = hProgress.GetNum("id");

				//PrintToChat(client, "Loading quest: %d", m_hQuest[client].m_iIndex);

				// Getting static contract info.
				hQuest.GetString("name", m_hQuest[client].m_sName, 64);
				hQuest.GetString("postfix", m_hQuest[client].m_sPostfix, 64, "CP");

				//PrintToChat(client, "∟ Name: %s", m_hQuest[client].m_sName);
				//PrintToChat(client, "∟ Postfix: %s", m_hQuest[client].m_sPostfix);

				char sClass[16];
				// Getting restrictions.
				hQuest.GetString("restrictions/map", m_hQuest[client].m_sRestrictionMap, 64);
				hQuest.GetString("restrictions/map_s", m_hQuest[client].m_sRestrictionStrictMap, 64);
				hQuest.GetString("restrictions/class", sClass, sizeof(sClass));
				m_hQuest[client].m_nRestrictionClass = TF2_GetClass(sClass);

				char sCEWeapon[128];
				hQuest.GetString("restrictions/ce_weapon", sCEWeapon, sizeof(sCEWeapon));

				if(!StrEqual(sCEWeapon, ""))
				{
					CEItemDefinition xDef;
					if(CEconItems_GetItemDefinitionByName(sCEWeapon, xDef))
					{
						m_hQuest[client].m_iCEWeaponIndex = xDef.m_iIndex;
					} else {
						m_hQuest[client].m_iCEWeaponIndex = hQuest.GetNum("restrictions/ce_weapon", -1);
					}
				}

				if(hQuest.JumpToKey("objectives/0", false))
				{
					do {
						char sIndex[11];
						hQuest.GetSectionName(sIndex, sizeof(sIndex));
						int iObjective = StringToInt(sIndex);

						CEObjective hObjective;
						hQuest.GetString("name", hObjective.m_sName, 64);
						hObjective.m_iEnd = hQuest.GetNum("end", 0);
						hObjective.m_iPoints = hQuest.GetNum("points", 0);
						hObjective.m_iLimit = hQuest.GetNum("limit", 100);

						hQuest.GetString("restrictions/ce_weapon", sCEWeapon, sizeof(sCEWeapon));

						if(!StrEqual(sCEWeapon, ""))
						{
							CEItemDefinition xDef;
							if(CEconItems_GetItemDefinitionByName(sCEWeapon, xDef))
							{
								m_hQuest[client].m_iCEWeaponIndex = xDef.m_iIndex;
							} else {
								m_hQuest[client].m_iCEWeaponIndex = hQuest.GetNum("restrictions/ce_weapon", -1);
							}
						}

						for (int i = 0; i < MAX_HOOKS; i++)
						{
							char sKey[32];
							Format(sKey, sizeof(sKey), "hooks/%d", i);
							if(hQuest.JumpToKey(sKey, false))
							{
								//PrintToChat(client, "	∟ Reading hook %d", i);
								char sAction[32], sEvent[128];
								hQuest.GetString("action", sAction, sizeof(sAction), "singlefire");
								hQuest.GetString("event", sEvent, sizeof(sEvent));

								if (StrEqual(sAction, "increment"))hObjective.m_nActions[i] = ACTION_INCREMENT;
								else if (StrEqual(sAction, "reset"))hObjective.m_nActions[i] = ACTION_RESET;
								else if (StrEqual(sAction, "substract"))hObjective.m_nActions[i] = ACTION_SUBSTRACT;
								else if (StrEqual(sAction, "set"))hObjective.m_nActions[i] = ACTION_SET;
								else hObjective.m_nActions[i] = ACTION_SINGLEFIRE;

								strcopy(m_sQuestEvents[client][iObjective][i], sizeof(m_sQuestEvents[][][]), sEvent);

								hQuest.GoBack();
							} else {
								break;
							}
						}

						char sKey[32];
						Format(sKey, sizeof(sKey), "objectives/%s", sIndex);
						if(hProgress.JumpToKey(sKey, false))
						{
							hObjective.m_iProgress = hProgress.GetNum("progress", 0);
							//PrintToChat(client, "	∟ Progress: %d", hObjective.m_iProgress);
							hProgress.GoBack();
						}

						if (m_hQuest[client].m_hObjectives == null)m_hQuest[client].m_hObjectives = new ArrayList(sizeof(CEObjective));
						m_hQuest[client].m_hObjectives.PushArray(hObjective);

					} while (hQuest.GotoNextKey());
				}

				PrintToChat(client, "\x03You have activated '\x05%s\x03' contract. Type \x05!quest \x03or \x05!contract \x03to view current completion progress.", m_hQuest[client].m_sName);
				PrintToChat(client, "\x03You can change your contract on \x05creators.tf \x03in \x05ConTracker \x03tab.");

				char sDecodeSound[64];
				strcopy(sDecodeSound, sizeof(sDecodeSound), "Quest.Decode");
				if(StrEqual(m_hQuest[client].m_sPostfix, "MP"))
				{
					Format(sDecodeSound, sizeof(sDecodeSound), "%sHalloween", sDecodeSound);
				}

				ClientCommand(client, "playgamesound %s", sDecodeSound);
			}
			delete hQuest;
		}
		delete hProgress;
	}
}

public void FlushClientCache(int client)
{
	m_iWaitingForQuest[client] = 0;
	m_hQuest[client].m_iIndex = 0;

	strcopy(m_hQuest[client].m_sName, 64, "");
	strcopy(m_hQuest[client].m_sPostfix, 5, "");

	m_hQuest[client].m_iSource = 0;
	m_hQuest[client].m_iLastIndex = 0;

	strcopy(m_hQuest[client].m_sRestrictionMap, 64, "");
	strcopy(m_hQuest[client].m_sRestrictionStrictMap, 64, "");
	m_hQuest[client].m_nRestrictionClass = TFClass_Unknown;
	m_hQuest[client].m_iCEWeaponIndex = 0;

	delete m_hQuest[client].m_hObjectives;
	
	for (int i = 0; i < sizeof(m_sQuestEvents[]); i++)
	{
		for (int j = 0; j < sizeof(m_sQuestEvents[][]); j++)
		{
			strcopy(m_sQuestEvents[client][i][j], sizeof(m_sQuestEvents[][][]), "");
		}
	}
}

public void FlushFriendsCache(int client)
{
	delete m_hFriends[client];
}

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