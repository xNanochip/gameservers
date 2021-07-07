// this forces server settings to get properly set up after the server first reboots
// on boot there's a bunch of fucking race conditions with plugins and cfgs and this just
// fixes that.

bool firstmap = true;

public void OnMapStart()
{
    CreateTimer(5.0, GoToNextMap);
}

Action GoToNextMap(Handle timer)
{
    if (firstmap)
    {
        firstmap = false;
        // load cleaner
        ServerCommand("sm exts load cleaner");

        // copy ce_server_index to sb_id
        int ctf_serverindex = GetConVarInt(FindConVar("ce_server_index"));
        SetConVarInt(FindConVar("sb_id"), ctf_serverindex);
        ServerCommand("sm plugins reload sbpp_main");

        // change the level
        ServerCommand("changelevel_next");
    }
}

