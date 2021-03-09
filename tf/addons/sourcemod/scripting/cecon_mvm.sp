#include <steamtools> 

#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <cecon>
#include <cecon_items>
#include <cecon_http>
#include <tf2_stocks>

#define Q_UNIQUE 6
#define TF_TEAM_DEFENDERS 2
#define TF_TEAM_INVADERS 3
#define TF_MVM_MAX_WAVES 12

public Plugin myinfo =
{
	name = "Creators.TF - Mann vs Machines",
	author = "Creators.TF Team",
	description = "Creators.TF - Mann vs Machines",
	version = "1.00",
	url = "https://creators.tf"
};

ConVar ce_mvm_check_itemname_cvar;
ConVar ce_mvm_show_game_time;

int m_iCurrentWave;
int m_iLastPlayerCount;

float m_flWaveStartTime;
int m_iTotalTime;
int m_iSuccessTime;
int m_iWaveTime;

bool m_bWaitForGameRestart;
bool m_bWeJustFailed;
bool m_bJustFinishedTheMission;

char m_sLastTourLootHash[128];

bool m_bIsMOTDOpen[MAXPLAYERS + 1];


enum struct CEItemBaseIndex 
{
	int m_iItemDefinitionIndex;
	int m_iBaseItemIndex;
}
ArrayList m_hItemIndexes;


public void OnPluginStart()
{
	RegServerCmd("ce_mvm_equip_itemname", cMvMEquipItemName, "");
	RegServerCmd("ce_mvm_get_itemdef_id", cMvMGetItemDefID, "");
	RegServerCmd("ce_mvm_set_attribute", cMvMSetEntityAttribute, "");
	ce_mvm_check_itemname_cvar = CreateConVar("ce_mvm_check_itemname_cvar", "-1", "", FCVAR_PROTECTED);
	ce_mvm_show_game_time = CreateConVar("ce_mvm_show_game_time", "0", "Enables game time summary to be shown in chat");

	HookEvent("mvm_begin_wave", mvm_begin_wave);
	HookEvent("mvm_wave_complete", mvm_wave_complete);
	HookEvent("mvm_wave_failed", mvm_wave_failed);
	HookEvent("mvm_mission_complete", mvm_mission_complete);
	
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_round_start", teamplay_round_start);
	
	RegConsoleCmd("sm_loot", cLoot, "Opens the latest Tour Loot page");
	
	RegAdminCmd("ce_mvm_force_loot", cForceLoot, ADMFLAG_ROOT);
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseEconomySchema(hSchema);
}

public void OnAllPluginsLoaded()
{
	ParseEconomySchema(CEcon_GetEconomySchema());
}

public void ParseEconomySchema(KeyValues hSchema)
{
	delete m_hItemIndexes;
	if (hSchema == null)return;
	m_hItemIndexes = new ArrayList(sizeof(CEItemBaseIndex));

	if(hSchema.JumpToKey("Items"))
	{
		if(hSchema.GotoFirstSubKey())
		{
			do {
				int iBaseIndex = hSchema.GetNum("item_index", -1);
				if(iBaseIndex > -1)
				{
					char sName[11];
					hSchema.GetSectionName(sName, sizeof(sName));
					
					CEItemBaseIndex xRecord;
					
					xRecord.m_iItemDefinitionIndex = StringToInt(sName);
					xRecord.m_iBaseItemIndex = iBaseIndex;
					
					m_hItemIndexes.PushArray(xRecord);
				}

			} while (hSchema.GotoNextKey());
		}
	}

    // Make sure we do that every time
	hSchema.Rewind();
	
}

public int GetDefinitionBaseIndex(int defid)
{
	if (m_hItemIndexes == null)return -1;
	
	for (int i = 0; i < m_hItemIndexes.Length; i++)
	{
		CEItemBaseIndex xRecord;
		m_hItemIndexes.GetArray(i, xRecord);
		if (xRecord.m_iItemDefinitionIndex != defid)continue;
		return xRecord.m_iBaseItemIndex;
	}
	
	return -1;
}

public void PrintGameStats()
{
	if (!ce_mvm_show_game_time.BoolValue)return;
	
	char sTimer[32];
	int iMissionTime = GetTotalMissionTime();
	TimeToStopwatchTimer(iMissionTime, sTimer, sizeof(sTimer));
	PrintToChatAll("\x01Total time spent in mission: \x03%s", sTimer);

	int iSuccessTime = GetTotalSuccessTime();
	int iPercentage = RoundToFloor(float(iSuccessTime) / float(iMissionTime) * 100.0);
	if (iPercentage < 0)iPercentage = 0;
	TimeToStopwatchTimer(iSuccessTime, sTimer, sizeof(sTimer));
	PrintToChatAll("\x01Total success time in mission: \x03%s (%d%%)", sTimer, iPercentage);

	int iWaveTime = GetTotalWaveTime();
	TimeToStopwatchTimer(iWaveTime, sTimer, sizeof(sTimer));
	PrintToChatAll("\x01Time spent on Wave %d: \x03%s", m_iCurrentWave, sTimer);
}

public Action teamplay_round_start(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	// This is usually fired after we lost a round.
	if(m_bWeJustFailed)
	{
		OnDefendersLost();
		m_bWeJustFailed = false;
	}

	m_bWaitForGameRestart = false;
}

public void ProcessTime(int time, bool success)
{
	AddTimeToTotalWaveTime(time);
	AddTimeToTotalTime(time);
	if(success)
	{
		AddTimeToSuccessTime(time);
	}
}

public Action teamplay_round_win(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	// This is usually fired when we lose.
	if (!TF2MvM_IsPlayingMvM())return Plugin_Continue;
	int iTeam = GetEventInt(hEvent, "team");

	if(iTeam == TF_TEAM_INVADERS)
	{
		m_bWeJustFailed = true;
	}

	return Plugin_Continue;
}

public bool IsValidWave(int index)
{
	return index > 0 && index < TF_MVM_MAX_WAVES;
}

public void OnDefendersWon()
{
	int time = GetCurrentWaveTime();
	ProcessTime(time, true);
	PrintGameStats();
	ClearWaveStartTime();
}

public void OnDefendersLost()
{
	int time = GetCurrentWaveTime();
	ProcessTime(time, false);
	PrintGameStats();
	ClearWaveStartTime();
}

public void SetWaveStartTime()
{
	m_flWaveStartTime = GetEngineTime();
}

public void ClearWaveStartTime()
{
	m_flWaveStartTime = 0.0;
}

public int GetCurrentWaveTime()
{
	if (m_flWaveStartTime == 0.0)return 0;
	return RoundToFloor(GetEngineTime() - m_flWaveStartTime);
}

public void AddTimeToTotalWaveTime(int time)
{
	m_iWaveTime += time;
}

public void AddTimeToTotalTime(int time)
{
	m_iTotalTime += time;
}

public void AddTimeToSuccessTime(int time)
{
	m_iSuccessTime += time;
}

public int GetTotalSuccessTime()
{
	return m_iSuccessTime;
}

public int GetTotalWaveTime()
{
	return m_iWaveTime;
}

public int GetTotalMissionTime()
{
	return m_iTotalTime;
}

public void ResetStats()
{
	PrintToChatAll("Game Restarted. Resetting stats...");
	m_iSuccessTime = 0;
	m_iWaveTime = 0;
	m_iTotalTime = 0;
	ClearWaveStartTime();
	
	m_bJustFinishedTheMission = false;
	
	strcopy(m_sLastTourLootHash, sizeof(m_sLastTourLootHash), "");
}

public Action mvm_begin_wave(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iWave = GetEventInt(hEvent, "wave_index");
	int iRealWave = iWave + 1;

	if(iRealWave != m_iCurrentWave)
	{
		m_iWaveTime = 0;
	}

	// Let's start with 1 and not zero.
	m_iCurrentWave = iRealWave;
	SetWaveStartTime();
}

public Action mvm_mission_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	m_bJustFinishedTheMission = true;
}

public Action mvm_wave_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	// int iAdvanced = GetEventInt(hEvent, "advanced");
	// PrintToChatAll("mvm_wave_complete (advanced %d)", iAdvanced);
	
	OnDefendersWon();
	
	int iWave = m_iCurrentWave;
	int iTime = GetTotalWaveTime();
	SendWaveCompletionTime(iWave, iTime);
}

public Action mvm_wave_failed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if(m_bWaitForGameRestart)
	{
		m_bWaitForGameRestart = false;
		ResetStats();
	} else {
		m_bWaitForGameRestart = true;
	}
}

public void OnMvMGameStart()
{
	// Someone joined the game.
	ResetStats();
}

public void OnMvMGameEnd()
{
	// Everyone left the game.
	ResetStats();
}

public void OnMapStart()
{
	if(TF2MvM_IsPlayingMvM())
	{
		RequestFrame(RF_RecalculatePlayerCount);
	}
}

public bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}

/**
*	Purpose: 	ce_mvm_force_loot command.
*/
public Action cForceLoot(int client, int args)
{
	RequestTourLoot();

	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_equip_itemname command.
*/
public Action cMvMEquipItemName(int args)
{
	char sArg1[11], sArg2[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int iClient = StringToInt(sArg1);

	if (!StrEqual(sArg2, ""))
	{
		if (IsClientValid(iClient))
		{
			CEItem xItem;
			if(CEconItems_CreateNamedItem(xItem, sArg2, 6, null))
			{
				CEconItems_GiveItemToClient(iClient, xItem);
			}
		}
	}

	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_get_itemdef_id command.
*/
public Action cMvMGetItemDefID(int args)
{
	char sArg1[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));

	if (!StrEqual(sArg1, ""))
	{
		CEItemDefinition xDef;
		if(CEconItems_GetItemDefinitionByName(sArg1, xDef))
		{
			ce_mvm_check_itemname_cvar.SetInt(GetDefinitionBaseIndex(xDef.m_iIndex));
			return Plugin_Handled;
		}
	}
	ce_mvm_check_itemname_cvar.SetInt(-1);

	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_set_attribute command.
*/
public Action cMvMSetEntityAttribute(int args)
{
	char sName[128], sEntity[11], sValue[11];
	GetCmdArg(1, sEntity, sizeof(sEntity));
	int iEntity = StringToInt(sEntity);
	
	GetCmdArg(2, sName, sizeof(sName));
	GetCmdArg(3, sValue, sizeof(sValue));
	
	if (!IsValidEntity(iEntity))return Plugin_Handled;

	CEconItems_SetEntityAttributeString(iEntity, sName, sValue);

	return Plugin_Handled;
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

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		RequestFrame(RF_RecalculatePlayerCount);
	}
}


public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
	{
		RequestFrame(RF_RecalculatePlayerCount);
	}
}

public void RF_RecalculatePlayerCount(any data)
{
	RecalculatePlayerCount();
}

public void RecalculatePlayerCount()
{
	if (!TF2MvM_IsPlayingMvM())return;

	int count = GetRealClientCount();
	int old = m_iLastPlayerCount;
	m_iLastPlayerCount = count;

	if(old == 0 && count > 0)
	{
		OnMvMGameStart();
	} else if(count == 0 && old > 0)
	{
		OnMvMGameEnd();
	}
}

public int GetRealClientCount()
{
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            count++;
        }
    }

    return count;
}

public void TimeToStopwatchTimer(int time, char[] buffer, int size)
{
	char[] timer = new char[size + 1];

	int iForHours = time;
	int iSecsInHour = 60 * 60;
	int iHours = iForHours / iSecsInHour;
	if(iHours > 0)
	{
		Format(timer, size, "%d hr ", iHours);
	}

	int iSecInMins = 60;
	int iForMins = iForHours % iSecsInHour;
	int iMinutes = iForMins / iSecInMins;
	if(iMinutes > 0)
	{
		Format(timer, size, "%s%d min ", timer, iMinutes);
	}

	int iSeconds = iForMins % iSecInMins;
	Format(timer, size, "%s%d sec", timer, iSeconds);

	strcopy(buffer, size, timer);
}

public void GetPopFileName(char[] buffer, int length)
{
	char filename[256];
	
	int ObjectiveEntity = FindEntityByClassname(-1, "tf_objective_resource");
	GetEntPropString(ObjectiveEntity, Prop_Send, "m_iszMvMPopfileName", filename, sizeof(filename));
	
	char explode[6][256];
	int count = ExplodeString(filename, "/", explode, sizeof(explode), sizeof(explode[]));
	
	char name[256];
	strcopy(name, sizeof(name), explode[count - 1]);
	ReplaceString(name, sizeof(name), ".pop", "");
	
	strcopy(buffer, length, name);
}

public void SendWaveCompletionTime(int wave, int seconds)
{
	char sPopFile[256];
	GetPopFileName(sPopFile, sizeof(sPopFile));
	
	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserMvMWaveProgress", HTTPMethod_POST);
	
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		
		char sSteamID[64];
		GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
		
		char sKey[32];
		Format(sKey, sizeof(sKey), "steamids[%d]", iCount);
		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sSteamID);
		
		iCount++;
	}
	
	// Setting wave number.
	char sValue[64];
	IntToString(wave, sValue, sizeof(sValue));
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "wave", sValue);
	
	// Setting time number.
	IntToString(seconds, sValue, sizeof(sValue));
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "time", sValue);
	
	// Setting mission name.
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "mission", sPopFile);
	
	Steam_SendHTTPRequest(hRequest, SendWaveCompletionTime_Callback);
}

public void SendWaveCompletionTime_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];
	
	Steam_GetHTTPResponseBodyData(request, content, size);
	
	Steam_ReleaseHTTPRequest(request);
	PrintToServer(content);
	
	if(m_bJustFinishedTheMission)
	{
		RequestTourLoot();
		m_bJustFinishedTheMission = false;
	}

	// Getting response size.
}

public void RequestTourLoot()
{
	char sPopFile[256];
	GetPopFileName(sPopFile, sizeof(sPopFile));
	
	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserMvMTourLoot", HTTPMethod_POST);
	
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		
		char sSteamID[64];
		GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
		
		char sKey[32];
		Format(sKey, sizeof(sKey), "steamids[%d]", iCount);
		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sSteamID);
		
		Format(sKey, sizeof(sKey), "classes[%d]", iCount);
		char sClass[32];
		switch(TF2_GetPlayerClass(i))
		{
			case TFClass_Scout:strcopy(sClass, sizeof(sClass), "scout");
			case TFClass_Soldier:strcopy(sClass, sizeof(sClass), "soldier");
			case TFClass_Pyro:strcopy(sClass, sizeof(sClass), "pyro");
			case TFClass_DemoMan:strcopy(sClass, sizeof(sClass), "demo");
			case TFClass_Heavy:strcopy(sClass, sizeof(sClass), "heavy");
			case TFClass_Engineer:strcopy(sClass, sizeof(sClass), "engineer");
			case TFClass_Medic:strcopy(sClass, sizeof(sClass), "medic");
			case TFClass_Sniper:strcopy(sClass, sizeof(sClass), "sniper");
			case TFClass_Spy:strcopy(sClass, sizeof(sClass), "spy");
		}
		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sClass);
		
		iCount++;
	}
	
	// Setting mission name.
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "mission", sPopFile);
	Steam_SendHTTPRequest(hRequest, RequestTourLoot_Callback);
}

public void RequestTourLoot_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	PrintToChatAll("RequestTourLoot_Callback %d", code);
	
	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;

	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];
	
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);
	
	PrintToServer(content);

	KeyValues Response = new KeyValues("Response");

	// ======================== //
	// Parsing loadout response.

	// If we fail to import content return.
	if (!Response.ImportFromString(content))return;
	Response.GetString("hash", m_sLastTourLootHash, sizeof(m_sLastTourLootHash));
	delete Response;
	
	CreateTimer(2.0, Timer_OpenTourLootPageToAll);
}

public Action Timer_OpenTourLootPageToAll(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		
		OpenLastTourLootPage(i);
	}
}

public void OpenLastTourLootPage(int client)
{
	QueryClientConVar(client, "cl_disablehtmlmotd", QueryConVar_Motd);
}

public void QueryConVar_Motd(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, DataPack dPack)
{
	if (result == ConVarQuery_Okay)
	{
		if (StringToInt(cvarValue) != 0)
		{
			PrintToChat(client, "\x01* Please set \x03cl_disablehtmlmotd 0 \x01in your console and type \x03!loot \x01in chat to see the loot.");
			return;
		}
		else
		{
			if (StrEqual(m_sLastTourLootHash, ""))return;
			
			char url[PLATFORM_MAX_PATH];
			Format(url, sizeof(url), "/tourloot?hash=%s", m_sLastTourLootHash);
			
			CEconHTTP_CreateAbsoluteBackendURL(url, url, sizeof(url));
			
			KeyValues hConf = new KeyValues("data");
			hConf.SetNum("type", 2);
			hConf.SetString("msg", url);
			hConf.SetNum("customsvr", 1);
			ShowVGUIPanel(client, "info", hConf);
			delete hConf;
			m_bIsMOTDOpen[client] = true;
		}
	}
}

public Action cLoot(int client, int args)
{
	OpenLastTourLootPage(client);
	return Plugin_Handled;
}

public void CloseMOTD(int client)
{
	m_bIsMOTDOpen[client] = false;

	KeyValues hConf = new KeyValues("data");
	hConf.SetNum("type", 2);
	hConf.SetString("msg", "about:blank");
	hConf.SetNum("customsvr", 1);

	ShowVGUIPanel(client, "info", hConf, false);
	delete hConf;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	// Since TF2 no longer allows us to check when a MOTD is closed, we'll have to detect player's movements (indicating that motd is no longer open).
	if (m_bIsMOTDOpen[client])
	{
		if (buttons & (IN_ATTACK | IN_JUMP | IN_DUCK | IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK2))
		{
			CloseMOTD(client);
		}
	}
}