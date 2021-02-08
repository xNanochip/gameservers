#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>

int user;

public Plugin myinfo =
{
    name        = "Client Cvar Grabber",
    author      = "lugui, steph&nie",
    description = "Allows admins to query cvars on clients by cvar name",
    version     = "2.0",
};

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    RegAdminCmd("sm_getcvar", Command_GetCvar, ADMFLAG_GENERIC, "Get a client's cvar");
    RegAdminCmd("sm_query", Command_GetCvar, ADMFLAG_GENERIC, "Get a client's cvar");
}

public Action Command_GetCvar(int client, int args)
{
    user = client;
    if (args < 2)
    {
        MC_ReplyToCommand(client, "{white}Usage: sm_query {darkgray}<client>{white} {springgreen}<cvar>");
    }
    else
    {
        char arg1[32];
        char arg2[256];
        GetCmdArg(1, arg1, sizeof(arg1));
        GetCmdArg(2, arg2, sizeof(arg2));

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
                    COMMAND_FILTER_NO_BOTS,
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
            if (IsValidClient(target_list[i]))
            {
                QueryClientConVar(target_list[i], arg2, CheckCvar);
            }
        }
    }

    return Plugin_Handled;
}

public void CheckCvar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    if (result == ConVarQuery_NotFound)
    {
        MC_PrintToChatEx(user, client, "{white}Cvar '{springgreen}%s{white}' was not found on {teamcolor}%N", cvarName, client);
    }
    else if (result == ConVarQuery_NotValid)
    {
        MC_PrintToChatEx(user, client, "{white}Cvar '{springgreen}%s{white}' was not valid on {teamcolor}%N{white} - '{springgreen}%s{white}' is probably a concommand!", cvarName, client, cvarName);
    }
    else if (result == ConVarQuery_Protected)
    {
        MC_PrintToChat(user, "{white}Cvar '{springgreen}%s{white}' is protected - {red}Cannot query!", cvarName);
    }
    else
    {
        MC_PrintToChatEx(user, client, "{white}Value of cvar '{springgreen}%s{white}' on {teamcolor}%N{white} is '{springgreen}%s{white}'", cvarName, client, cvarValue);
    }
}

bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsFakeClient(client)
    );
}
