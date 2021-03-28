#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <morecolors>

public Plugin myinfo =
{
    name        = "Rough Sourcemod AimPlotter",
    author      = "MitchDizzle_, steph&nie",
    description = "",
    version     = "0.0.1",
    url         = "http://forums.alliedmods.net/showthread.php?t=189956"
}

float LastLaser[MAXPLAYERS+1][3];
bool LaserE[MAXPLAYERS+1];
new g_sprite;

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    RegAdminCmd("sm_laser", togglelaser, ADMFLAG_BAN);
    RegAdminCmd("sm_aimplot", togglelaser, ADMFLAG_BAN);
}

public void OnMapStart()
{
    g_sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public Action togglelaser(int client, int args)
{
    if (args < 1 || args > 2)
    {
        MC_ReplyToCommand(client, "{white}Usage: sm_laser {darkgray}<client> [on/off]\n{white}Toggles if \"on\" or \"off\" isn't specified.");
    }
    else
    {
        char arg1[32];
        GetCmdArg(1, arg1, sizeof(arg1));
        char arg2[32];
        GetCmdArg(2, arg2, sizeof(arg2));

        // -1 = toggle, 0 = turn off, 1 = turn on
        int offon = -1;
        if (StrContains(arg2, "off", false) != -1)
        {
            offon = 0;
        }
        else if ((StrContains(arg2, "on", false) != -1))
        {
            offon = 1;
        }
        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS];
        int target_count;
        bool tn_is_ml;

        if
        (
            (
                target_count = ProcessTargetString
                (
                    arg1,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_NO_IMMUNITY,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml
                )
            )
            <= 0
        )
        {
            ReplyToTargetError(client, target_count);
            return Plugin_Handled;
        }

        for (int i = 0; i < target_count; i++)
        {
            int targetclient = target_list[i];
            if (IsValidClientOrBot(targetclient))
            {
                if (offon == -1)
                {
                    LaserE[targetclient] = !LaserE[targetclient];
                }
                else if (offon == 0)
                {
                    LaserE[targetclient] = false;
                }
                else if (offon == 1)
                {
                    LaserE[targetclient] = true;
                }
            }
        }
    }

    return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
    LaserE[client] = false;
    LastLaser[client] = NULL_VECTOR;
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
    if (!LaserE[client])
    {
        LastLaser[client] = NULL_VECTOR;
        return Plugin_Continue;
    }

    float pos[3];
    if (IsClientInGame(client) && LaserE[client] && IsPlayerAlive(client))
    {
        TraceEye(client, pos);
        if (GetVectorDistance(pos, LastLaser[client]) > 1.1)
        {
            if (buttons & IN_ATTACK)
            {
                SetUpLaser(LastLaser[client], pos, {255,0,0,100});
            }
            else
            {
                SetUpLaser(LastLaser[client], pos, {255,255,255,100});
            }
            LastLaser[client] = pos;
        }
    }
    return Plugin_Continue;
}

void SetUpLaser(float start[3], float end[3], int color[4])
{
    TE_SetupBeamPoints
    (
        start,      // startpos
        end,        // endpos
        g_sprite,   // precached model index
        0,          // precached model index for halo
        0,          // startframe
        0,          // framerate
        1.0,        // lifetime
        1.0,        // starting width
        1.0,        // ending width
        0,          // fade time duration
        0.0,        // amplitude
        color,      // color
        0           // beam speed
    );
    TE_SendToAdmins();
}

void TraceEye(int client, float pos[3])
{
    float angles[3];
    float origin[3];
    float angvec[3];
    float newpos[3];

    GetClientEyePosition(client, origin);
    GetClientEyeAngles(client, angles);
    GetAngleVectors(angles, angvec, NULL_VECTOR, NULL_VECTOR);

    ScaleVector(angvec, 200.0);
    AddVectors(origin, angvec, newpos);
    TR_TraceRayFilter(origin, newpos, MASK_VISIBLE, RayType_EndPoint, TraceEntityFilterPlayer, client);
    if (TR_DidHit())
    {
        TR_GetEndPosition(pos);
    }
    else
    {
        pos = newpos;
    }
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, int client)
{
    if (entity == client)
    {
        return false;
    }

    if (IsValidClientOrBot(entity))
    {
        int clientTeam = GetClientTeam(client);
        int entTeam = GetClientTeam(entity);
        if (clientTeam == entTeam)
        {
            return false;
        }
    }
    return true;
}


bool IsValidClientOrBot(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        // don't bother with stv or replay bots lol
        && !IsClientSourceTV(client)
        && !IsClientReplay(client)
    );
}

void TE_SendToAdmins()
{
    int total = 0;
    int[] clients = new int[MaxClients];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && CheckCommandAccess(i, "sm_ban", ADMFLAG_GENERIC))
        {

            clients[total++] = i;
        }
    }
    TE_Send(clients, total);
}