#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.00"

#include <sdktools>
#include <ce_util>
#include <ce_core>
#include <ce_manager_items>
#include <ce_manager_attributes>

#define Q_UNIQUE 6
#define TF_TEAM_DEFENDERS 2
#define TF_TEAM_INVADERS 3

public Plugin myinfo =
{
	name = "Creators.TF - Mann vs Machines",
	author = PLUGIN_AUTHOR,
	description = "Creators.TF - Mann vs Machines",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

ConVar ce_mvm_check_itemname_cvar;

int m_iCurrentWave;
int m_iLastPlayerCount;

float m_flWaveStartTime;
int m_iTotalTime;
int m_iSuccessTime;

bool m_bWaitForGameRestart;
bool m_bDefendersWon;

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
	int iTimeInMission = GetTotalMissionTime();
	if (iTimeInMission > -1)
	{
		char sTimeInMission[32];
		TimeToStopwatchTimer(iTimeInMission, sTimeInMission, sizeof(sTimeInMission));
		
		PrintToChatAll("\x01Total time spent in mission: \x03%s", sTimeInMission);
	}
	
	int iWaveTime = GetTotalWaveTime();
	if(iWaveTime > -1)
	{
		char sTimer[32];
		TimeToStopwatchTimer(iWaveTime, sTimer, sizeof(sTimer));
		
		PrintToChatAll("\x01Total time spent in Wave %d: \x03%s", m_iCurrentWave, sTimer	);
	}
}

public Action teamplay_round_start(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	m_bWaitForGameRestart = false;
	
	int iTimer = GetTotalWaveTime();
	if(iTimer > -1)
	{
		AddTimeToTotalTimer(iTimer);
		if(m_bDefendersWon)
		{
			m_bDefendersWon = false;
			AddTimeToSuccessTimer(iTimer);
		}
	}
	PrintGameStats();
}

public Action teamplay_round_win(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!TF2MvM_IsPlayingMvM())return Plugin_Continue;
	int iTeam = GetEventInt(hEvent, "team");
	
	// Clear mission time if we restart the game. 
	PrintToChatAll("teamplay_round_win");
	
	if(iTeam == TF_TEAM_DEFENDERS)
	{
		m_bDefendersWon = true;
	}
	
	switch(iTeam)
	{
		case TF_TEAM_DEFENDERS:
		{
			OnDefendersWon();
		}
		case TF_TEAM_INVADERS:
		{
			OnDefendersLost();
		}
	}
	
	return Plugin_Continue;
}

public void OnDefendersWon()
{
}

public void OnDefendersLost()
{
}

public void AddTimeToTotalTimer(int time)
{
	m_iTotalTime += time;
}

public void AddTimeToSuccessTimer(int time)
{
	m_iSuccessTime += time;
}

/*
* 	Purpose: 	Returns delta of current time and mission start time.
*				Or -1 if mission start time is not set.
*/
public int GetTotalMissionTime()
{
	return m_iTotalTime;
}

/*
* 	Purpose: 	Returns delta of current time and mission start time.
*				Or -1 if mission start time is not set.
*/
public int GetSuccessMissionTime()
{
	return m_iSuccessTime;
}

/*
* 	Purpose: 	Returns delta of current time and wave start time.
*				Or -1 if mission start time is not set.
*/
public int GetTotalWaveTime()
{
	if (m_flWaveStartTime == 0.0)return -1;
	return RoundToFloor(GetEngineTime() - m_flWaveStartTime);
}

/*
* 	Purpose: Forcefuly set wave start time to current time.
*/
public void SetWaveStartTime()
{
	PrintToChatAll("Wave Start Time Set");
	m_flWaveStartTime = GetEngineTime();
}

/*
* 	Purpose: Set wave start time to current value only if it is not already set.
*/
public void TrySetWaveStartTime()
{
	if (m_flWaveStartTime == 0.0)
	{
		PrintToChatAll("Setting Wave Time Start");
		SetWaveStartTime();
	}
}

public void ResetStats()
{
	PrintToChatAll("Game Restarted. Resetting stats...");
	m_iTotalTime = 0;
	m_iSuccessTime = 0;
	m_iCurrentWave = 0;
	ClearWaveStartTime();
}

/*
* 	Purpose: Clear wave time. This gives us possibility to set base time again.
*/
public void ClearWaveStartTime()
{
	m_flWaveStartTime = 0.0;
}

public Action mvm_begin_wave(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iWave = GetEventInt(hEvent, "wave_index");
	int iMaxWaves = GetEventInt(hEvent, "max_waves");
	int iAdvanced = GetEventInt(hEvent, "advanced");
	
	int iRealWave = iWave + 1;
	
	if(m_iCurrentWave != iRealWave)
	{
		TrySetWaveStartTime();
	}
	
	// Let's start with 1 and not zero.
	m_iCurrentWave = iRealWave;
	
	PrintGameStats();

	//PrintToChatAll("mvm_begin_wave (wave_index %d) (max_waves %d) (advanced %d)", iWave, iMaxWaves, iAdvanced);
}

public Action mvm_wave_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iAdvanced = GetEventInt(hEvent, "advanced");

	//PrintToChatAll("mvm_wave_complete (advanced %d)", iAdvanced);
	PrintGameStats();
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
		KeyValues hConf = CE_FindItemConfigByItemName(sArg2);
		if(UTIL_IsValidHandle(hConf))
		{
			if(IsClientValid(iClient))
			{
				ArrayList hAttribs = new ArrayList(sizeof(CEAttribute));

				int iIndex = hConf.GetNum("index");
				CE_EquipItem(iClient, -1, iIndex, Q_UNIQUE, hAttribs);
				delete hAttribs;
			}
			delete hConf;
			return Plugin_Handled;
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
		KeyValues hConf = CE_FindItemConfigByItemName(sArg1);
		if(hConf != null)
		{
			ce_mvm_check_itemname_cvar.SetInt(hConf.GetNum("item_index", -1));
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

	CE_SetAttributeFloat(iEntity, sName, flValue);

	return Plugin_Handled;
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