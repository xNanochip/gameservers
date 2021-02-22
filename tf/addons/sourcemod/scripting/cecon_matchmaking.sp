#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

public Plugin myinfo =
{
	name = "Creators.TF Matchmaking",
	author = "Creators.TF Team",
	description = "Matchmaking.",
	version = "1.0",
	url = "https://creators.tf"
}

char m_sAutoloadPopfile[PLATFORM_MAX_PATH];
ArrayList m_hMapList;
int m_iMapListSerial;

public void OnPluginStart()
{
	RegServerCmd("ce_mm_empty_change_map", cChangeMapIfEmpty);
	RegServerCmd("ce_mm_empty_change_popfile", cAutoloadPopfile);
	
	m_hMapList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
}

public void OnConfigsExecuted()
{
	LoadRememberedPopFile();
	
	if(ReadMapList(m_hMapList, m_iMapListSerial, "quickplay", MAPLIST_FLAG_CLEARARRAY | MAPLIST_FLAG_MAPSFOLDER) == INVALID_HANDLE)
	{
		if(m_iMapListSerial == -1)
		{
			LogError("Error loading quickplay map rotation.");
		}
	}
}

public Action cChangeMapIfEmpty(int args)
{
	if (!CanQuickplaySwitchMaps())return Plugin_Handled;
	
	char sMap[64];
	GetCmdArg(1, sMap, sizeof(sMap));
	
	// We dont need to load a map if we're already on it.
	char sCurrMap[64];
	GetCurrentMap(sCurrMap, sizeof(sCurrMap));
	if (StrEqual(sMap, sCurrMap))return Plugin_Handled;
	
	// 
	if(m_hMapList.FindString(sMap) > -1)
	{
		ServerCommand("changelevel %s", sMap);
	}
	
	return Plugin_Handled;
}

//------------------------------------------------------------------------
// Purpose: Command to switch empty 
//------------------------------------------------------------------------
public Action cAutoloadPopfile(int args)
{
	if (!CanQuickplaySwitchMaps())return Plugin_Handled;
	
	// Getting popfile name.
	char sPopFile[PLATFORM_MAX_PATH];
	GetCmdArg(1, sPopFile, sizeof(sPopFile));
	
	char sMap[PLATFORM_MAX_PATH];
	
	// Trying to find a map with this popfile.
	for (int i = 0; i < m_hMapList.Length; i++)
	{
		char buffer[PLATFORM_MAX_PATH];
		m_hMapList.GetString(i, buffer, sizeof(buffer));
		int len = strlen(buffer);
		
		if (strncmp(sPopFile, buffer, len) == 0)
		{
			strcopy(sMap, sizeof(sMap), buffer);
		}
	}
	
	if(!StrEqual(sMap, ""))
	{
		strcopy(m_sAutoloadPopfile, sizeof(m_sAutoloadPopfile), sPopFile);
		
		char sCurr[PLATFORM_MAX_PATH];
		GetCurrentMap(sCurr, sizeof(sCurr));
		
		if(StrEqual(sCurr, sMap))
		{
			LoadRememberedPopFile();
		} else {
			ServerCommand("changelevel %s", sMap);
		}
	}
	return Plugin_Handled;
}

public void LoadRememberedPopFile()
{
	if (!StrEqual(m_sAutoloadPopfile, ""))
	{
		LogMessage("Setting mission: %s", m_sAutoloadPopfile);
		ServerCommand("tf_mvm_popfile %s", m_sAutoloadPopfile);
	}
}

public bool CanQuickplaySwitchMaps()
{
	return IsServerEmpty();
}

public bool IsServerEmpty()
{
	return GetConnectedPlayersCount() == 0;
}

public int GetConnectedPlayersCount()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))continue;
		if (IsClientSourceTV(i))continue;
		if (IsFakeClient(i))continue;
		
		count++;
	}
	return count;
}