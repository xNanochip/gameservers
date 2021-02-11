#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

public Plugin myinfo =
{
	name = "Dynamic Max Players Limit",
	author = "Moonly Days",
	description = "Limits the amount of clients allowed on the server.",
	version = "1.0",
	url = "https://moonlydays.com"
};

ConVar 	sm_maxplayers,
		sm_maxplayers_mirror_visiblemaxplayers;

//-------------------------------------------------------------------
// Purpose: Fired when plugin starts
//-------------------------------------------------------------------
public void OnPluginStart()
{
	sm_maxplayers = 
		CreateConVar("sm_maxplayers", "24", "Amount of clients allowed on a server.", _, true, 1.0);
	sm_maxplayers_mirror_visiblemaxplayers = 
		CreateConVar("sm_maxplayers_mirror_visiblemaxplayers", "1", "Setting this cvar to true will make `sv_visiblemaxplayers` convar to also change when sm_maxplayers changes.");
	
	// We could probably wrap these two hooks under one callback, but maybe
	// we'll want to change something somewhere so, i'll keep them separate.
	HookConVarChange(sm_maxplayers, sm_maxplayers__CHANGED);
	HookConVarChange(FindConVar("sv_visiblemaxplayers"), sv_visiblemaxplayers__CHANGED);
}

//-------------------------------------------------------------------
// Purpose: Fired when sm_maxplayers cvar changes its value.
//-------------------------------------------------------------------
public void sm_maxplayers__CHANGED(ConVar convar, const char[] oldval, const char[] newval)
{
	UpdateVisibleMaxPlayers();
}

//-------------------------------------------------------------------
// Purpose: Fired when sv_visiblemaxplayers cvar changes its value.
//-------------------------------------------------------------------
public void sv_visiblemaxplayers__CHANGED(ConVar convar, const char[] oldval, const char[] newval)
{
	UpdateVisibleMaxPlayers();
}

//-------------------------------------------------------------------
// Purpose: If we return false here, client will not be able to 
// connect.
//-------------------------------------------------------------------
public bool OnClientConnect(int client, char[] msg, int length)
{
	if(CanLastConnectedClientConnect())
	{
		return true;
	} else {
		strcopy(msg, length, "Server is full");
		return false;
	}
}

//-------------------------------------------------------------------
// Purpose: Returns true if a new potential client can join the 
// server.
//-------------------------------------------------------------------
public bool CanLastConnectedClientConnect()
{
	return GetRealClientCount() <= sm_maxplayers.IntValue;
}

//-------------------------------------------------------------------
// Purpose: Returns the amount of clients currently connected 
// to the game.
//-------------------------------------------------------------------
public int GetRealClientCount()
{
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i))
        {
        	// Only exception is SourceTV, we don't count SourceTV as a player.
    		if (IsClientSourceTV(i))continue;
            count++;
        }
    }

    return count;
}

public void UpdateVisibleMaxPlayers()
{
	if(sm_maxplayers_mirror_visiblemaxplayers.BoolValue)
	{
		FindConVar("sv_visiblemaxplayers").IntValue = sm_maxplayers.IntValue;	
	}
}