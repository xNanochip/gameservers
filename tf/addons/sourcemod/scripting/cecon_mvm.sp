#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <cecon_items>

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

int m_iCurrentWave;
int m_iLastPlayerCount;

float m_flWaveStartTime;
int m_iTotalTime;
int m_iSuccessTime;
int m_iWaveTime;

bool m_bWaitForGameRestart;
bool m_bWeJustFailed;

public void OnPluginStart()
{
	RegServerCmd("ce_mvm_equip_itemname", cMvMEquipItemName, "");
	RegServerCmd("ce_mvm_get_itemdef_id", cMvMGetItemDefID, "");
	RegServerCmd("ce_mvm_set_attribute", cMvMSetEntityAttribute, "");
	ce_mvm_check_itemname_cvar = CreateConVar("ce_mvm_check_itemname_cvar", "-1", "", FCVAR_PROTECTED);

	HookEvent("mvm_begin_wave", mvm_begin_wave);
	HookEvent("mvm_wave_complete", mvm_wave_complete);
	HookEvent("mvm_wave_failed", mvm_wave_failed);
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_round_start", teamplay_round_start);
}

public void PrintGameStats()
{
	char sTimer[32];
	int iMissionTime = GetTotalMissionTime();
	TimeToStopwatchTimer(iMissionTime, sTimer, sizeof(sTimer));
	PrintToChatAll("\x01Total time spent in mission: \x03%s", sTimer);

	int iSuccessTime = GetTotalSuccessTime();
	int iPercentage = RoundToFloor(float(iSuccessTime) / float(iMissionTime) * 100.0);
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

public Action mvm_wave_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iAdvanced = GetEventInt(hEvent, "advanced");

	PrintToChatAll("mvm_wave_complete (advanced %d)", iAdvanced);
	OnDefendersWon();
}

public Action mvm_wave_failed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	PrintToChatAll("mvm_wave_failed");
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
			ce_mvm_check_itemname_cvar.SetInt(xDef.m_iIndex);
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
	if (!IsValidEntity(iEntity))return Plugin_Handled;

	GetCmdArg(2, sName, sizeof(sName));
	GetCmdArg(3, sValue, sizeof(sValue));
	float flValue = StringToFloat(sValue);

	CEconItems_SetEntityAttributeFloat(iEntity, sName, flValue);

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
