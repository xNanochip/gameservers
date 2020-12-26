#include <sourcemod>

public Plugin myinfo =
{
    name             =  "Restart Soon:tm:",
    author           =  "steph&nie",
    description      =  "Restart map at end of map timer, if requested",
    version          =  "0.0.1",
    url              =  "https://sappho.io"
}

bool b_restart;

public void OnPluginStart()
{
    RegAdminCmd("sm_restartsoon", restart, ADMFLAG_ROOT, "Restart server at end of round");
    RegAdminCmd("sm_unrestart", unrestart, ADMFLAG_ROOT, "Cancel pending restart at end of round");
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

public void OnMapEnd()
{
    if (b_restart)
    {
        ServerCommand("_restart");
    }
}