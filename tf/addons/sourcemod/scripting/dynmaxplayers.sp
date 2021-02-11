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

ConVar sm_maxplayers;

//-------------------------------------------------------------------
// Purpose: Fired when plugin starts
//-------------------------------------------------------------------
public void OnPluginStart()
{
	sm_maxplayers = CreateConVar("sm_maxplayers", "24", "Amount of clients allowed on a server.", _, true, 1.0);
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