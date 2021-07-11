// this forces server settings to get properly set up after the server first reboots
// on boot there's a bunch of fucking race conditions with plugins and cfgs and this just
// fixes that.


int mapchanges = -1;

public void OnMapStart()
{
    mapchanges++;
}

float timetowait = 0.5;

public void OnAllPluginsLoaded()
{
    if (mapchanges == 0)
    {
        CreateTimer(timetowait, StartDaisyChain);
    }
}

Action StartDaisyChain(Handle timer)
{
    CreateTimer(timetowait, LoadCleaner);
}

// load cleaner ext
// TODO: is this needed??
Action LoadCleaner(Handle timer)
{
    ServerCommand("sm exts load cleaner");
    CreateTimer(timetowait, CopyIdxToSbId);
}

// copy ce_server_index to sb_id for sourcebans
Action CopyIdxToSbId(Handle timer)
{
    int ctf_serverindex = GetConVarInt(FindConVar("ce_server_index"));
    SetConVarInt(FindConVar("sb_id"), ctf_serverindex);
    CreateTimer(timetowait, ReloadSBPP);
}

// reload sourcebans
Action ReloadSBPP(Handle timer)
{
    ServerCommand("sm plugins reload sbpp_main");
    CreateTimer(timetowait, changelevelNext);
}

// finally reload our map
Action changelevelNext(Handle timer)
{
    ServerCommand("changelevel_next");
}
