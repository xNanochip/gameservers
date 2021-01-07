public void OnMapStart()
{
    CreateTimer(5.0, fixCtfVotes);
}

Action fixCtfVotes(Handle timer)
{
    char mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
    if (StrContains(mapname, "ctf_") != -1)
    {
        SetConVarInt(FindConVar("mce_exclude"), 0);
        SetConVarInt(FindConVar("sm_nominate_excludecurrent"), 0);
        SetConVarInt(FindConVar("sm_nominate_excludeold"), 0);
    }
}