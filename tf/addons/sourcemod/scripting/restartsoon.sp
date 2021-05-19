#include <sourcemod>

public Plugin myinfo =
{
    name             =  "Restart Soon:tm:",
    author           =  "steph&nie",
    description      =  "Restart map at end of map timer, if requested",
    version          =  "0.0.4",
    url              =  "https://sappho.io"
}

bool b_restart;
bool b_kill;

public void OnPluginStart()
{
    RegAdminCmd("sm_restartsoon", restart, ADMFLAG_ROOT, "Restart server at end of map");
    RegAdminCmd("sm_unrestart", unrestart, ADMFLAG_ROOT, "Cancel pending restart at end of map");
    RegAdminCmd("sm_killsoon", kill, ADMFLAG_ROOT, "Killserver at end of map");
    RegAdminCmd("sm_unkill", unkill, ADMFLAG_ROOT, "Cancel pending killserver at end of map");
}

public Action restart(int Cl, int args)
{
    if (b_restart)
    {
        ReplyToCommand(Cl, "A restart is already pending on map change.");
    }
    else
    {
        b_restart = true;
        ReplyToCommand(Cl, "Server will restart on map change.");
    }
}

public Action unrestart(int Cl, int args)
{
    if (!b_restart)
    {
        ReplyToCommand(Cl, "A restart is not pending.");
    }
    else
    {
        b_restart = false;
        ReplyToCommand(Cl, "Restart cancelled.");
    }
}


public Action kill(int Cl, int args)
{
    if (b_kill)
    {
        ReplyToCommand(Cl, "A killserver is already pending on map change.");
    }
    else
    {
        b_kill = true;
        ReplyToCommand(Cl, "Server will die on map change.");
    }
}

public Action unkill(int Cl, int args)
{
    if (!b_kill)
    {
        ReplyToCommand(Cl, "A killserver is not pending.");
    }
    else
    {
        b_kill = false;
        ReplyToCommand(Cl, "Killserver cancelled.");
    }
}

void RestartNow() 
{
    ServerCommand("sm_kick @humans This server is restarting. Please rejoin in about 30 seconds");
    ServerCommand("_restart");
}

void KillNow() 
{
    ServerCommand("sm_kick @humans This server is closing");
    ServerCommand("killserver");
}

// Need to use RequestFrame or otherwise it may not always work
public void OnMapStart()
{
    if (b_kill)
    {
        RequestFrame(KillNow);
    }

    if (b_restart)
    {
        RequestFrame(RestartNow);
    }
}