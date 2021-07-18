// this forces server settings to get properly set up after the server first reboots
// on boot there's a bunch of fucking race conditions with plugins and cfgs and this just
// fixes that.
#pragma semicolon 1

ConVar ce_server_index;

bool booted;

int changelevelNum;

float timetowait = 2.5;

public void OnPluginStart()
{
    ce_server_index = CreateConVar("ce_server_index", "-1", "C.TF Server Index");
    LogMessage("\n\n[STARTUP] -> CREATED CTF CONVARS\n");
}

// OnConfigsExecuted -> changelevelRand -> OnConfigsExecuted -> StartDaisyChain -> LoadCleaner -> CopyIdxToSbId -> ReloadSBPP -> changelevelRand -> OnConfigsExecuted

public void OnConfigsExecuted()
{
    if (!booted)
    {
        if (changelevelNum == 0)
        {
            // force a changelevel
            CreateTimer(timetowait, changelevelRand);
        }

        if (changelevelNum == 1)
        {
            CreateTimer(timetowait, StartDaisyChain);
        }

        LogMessage("\n\n[STARTUP] -> OnConfigsExecuted\n");

        if (changelevelNum >= 2)
        {
            booted = true;
            LogMessage("\n\n[STARTUP] -> Fully booted! Have fun!\n");
        }
    }
}

// reload our map
Action changelevelRand(Handle timer)
{
    changelevelNum++;
    LogMessage("\n\n[STARTUP] -> FORCE CHANGING LEVEL (time %i)\n", changelevelNum);
    // shake it up a lil
    ServerCommand("randommap");
}

Action StartDaisyChain(Handle timer)
{
    LogMessage("\n\n[STARTUP] -> STARTING DAISY CHAIN\n");
    CreateTimer(timetowait, LoadCleaner);
}

// load cleaner ext
// TODO: is this needed??
Action LoadCleaner(Handle timer)
{
    LogMessage("\n\n[STARTUP] -> LOADING CLEANER\n");
    ServerCommand("sm exts load cleaner");
    CreateTimer(timetowait, CopyIdxToSbId);
}

// copy ce_server_index to sb_id for sourcebans
Action CopyIdxToSbId(Handle timer)
{
    LogMessage("\n\n[STARTUP] -> COPYING SERVER ID TO SB_ID\n");
    int ctf_serverindex = GetConVarInt(ce_server_index);
    SetConVarInt(FindConVar("sb_id"), ctf_serverindex);
    CreateTimer(timetowait, ReloadSBPP);
}

// reload sourcebans
Action ReloadSBPP(Handle timer)
{
    LogMessage("\n\n[STARTUP] -> RELOADING SOURCEBANS\n");
    ServerCommand("sb_reload");
    CreateTimer(timetowait, changelevelRand);
}
