#pragma semicolon 1;
#pragma newdecls required;

#include <sourcemod>
#include <sdktools>
#include <tf2>

public Plugin myinfo =
{
    name             = "fix a/d timelimit",
    author           = "stephanie",
    description      = "",
    version          = "0.0.1",
    url              = "https://sappho.io"
}

public void OnMapStart()
{
    CreateTimer(5.0, CheckGamemode);
}

public Action CheckGamemode(Handle timer)
{
    char curMap[64];
    GetCurrentMap(curMap, sizeof(curMap));
    if (StrContains(curMap, "cp_", false) != -1)
    {
        int ent = -1;
        while ((ent = FindEntityByClassname(ent, "team_control_point")) != -1)
        {
            // If there is a blu CP or a neutral CP, then it's not an attack/defend map
            if (GetEntProp(ent, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Red))
            {
                break;
            }
        }
        ent = -1;
        while ((ent = FindEntityByClassname(ent, "tf_gamerules")) != -1)
        {
            SetVariantBool(false);
            AcceptEntityInput(ent, "SetStalemateOnTimelimit");
            LogMessage("fixed a/d map timelimit");
            continue;
        }
    }
}
