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

char m_sAutoloadPopfile[64];

public void OnPluginStart()
{
	RegServerCmd("ce_mm_change_map_if_empty", cChangeMapIfEmpty);
	RegServerCmd("ce_mm_autoload_popfile", cAutoloadPopfile);
}

public void OnMapStart()
{
	PrintToServer(m_sAutoloadPopfile);
	ServerCommand("tf_mvm_popfile %s", m_sAutoloadPopfile);
}

public Action cChangeMapIfEmpty(int args)
{
	if (GetConnectedPlayersCount() > 0)return Plugin_Handled;
	
	char sMap[64];
	GetCmdArg(1, sMap, sizeof(sMap));
	
	ServerCommand("changelevel %s", sMap);
	
	return Plugin_Handled;
}

public Action cAutoloadPopfile(int args)
{
	GetCmdArg(1, m_sAutoloadPopfile, sizeof(m_sAutoloadPopfile));
	return Plugin_Handled;
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