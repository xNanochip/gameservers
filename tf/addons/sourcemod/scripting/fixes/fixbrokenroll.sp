public Plugin myinfo =
{
    name             =  "Fix roll while dead",
    author           =  "steph&nie",
    description      =  "Fixes https://github.com/ValveSoftware/Source-1-Games/issues/3338",
    version          =  "0.0.2",
    url              =  "https://sappho.io"
}

public Action OnPlayerRunCmd
(
    int client,
    int& buttons,
    int& impulse,
    float vel[3],
    float angles[3],
    int& weapon,
    int& subtype,
    int& cmdnum,
    int& tickcount,
    int& seed,
    int mouse[2]
)
{
    if (IsValidClient(client))
    {
        if (!IsPlayerAlive(client))
        {
            // fix https://github.com/ValveSoftware/Source-1-Games/issues/3338
            angles[2] = 0.0;
        }
    }
}

stock bool IsValidClient(int client)
{
    return ((0 < client <= MaxClients) && IsClientInGame(client));
}


