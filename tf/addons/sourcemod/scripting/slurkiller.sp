#pragma semicolon 1
#pragma newdecls optional

// don't care if includes arent in newdecls
#include <sourcemod>
#include <regex>
#include <sourcebanspp>
#include <sourcecomms>
// more colors double prints ????
#include <color_literals>

// do care about the plugin though
#pragma newdecls required

public Plugin myinfo =
{
    name             = "Slur Killer",
    author           = "steph&nie",
    description      = ".",
    version          = "1.1.3",
    url              = "https://sappho.io/"
};

// REGEX
Regex nword;
Regex fslur;
Regex tslur;
Regex cslur;

bool hasClientBeenWarned[MAXPLAYERS+1];

public void OnPluginStart()
{
    // set up regex
    // regex modified from: https://github.com/Blank-Cheque/Slurs
    nword  = new Regex("n([i!\\|1l][gq]{2}|[a@4o0][gq]{2}er)",                      PCRE_CASELESS | PCRE_MULTILINE);
    fslur  = new Regex("f+[a@4]+(g+|q{2,}|qg+|gq+)",                                PCRE_CASELESS | PCRE_MULTILINE);
    tslur  = new Regex("(tr([ao0]+){2}n)|t+r+[a4o0@]+n+([il1][e3]+|y+|[e3]r+)s?",   PCRE_CASELESS | PCRE_MULTILINE);
    cslur  = new Regex("\\bc[o0]{2}ns?\\b",                                         PCRE_CASELESS | PCRE_MULTILINE);
}

public Action OnClientSayCommand(int Cl, const char[] command, const char[] sArgs)
{
    // don't touch fake clients
    if (!IsValidClient(Cl))
    {
        return Plugin_Continue;
    }

    if
    (
            MatchRegex(nword,  sArgs) > 0
         || MatchRegex(fslur,  sArgs) > 0
         || MatchRegex(tslur,  sArgs) > 0
         || MatchRegex(cslur,  sArgs) > 0
    )
    {
        if (!hasClientBeenWarned[Cl])
        {
            PrintColoredChat(Cl, COLOR_WHITE ... "Hate speech is not tolerated here. " ... COLOR_RED ... "This is your only warning.");
            hasClientBeenWarned[Cl] = true;
        }
        else if (hasClientBeenWarned[Cl])
        {
            char reason[512];
            Format(reason, sizeof(reason), "Auto Silenced for hate speech, user said: %s", sArgs);
            SourceComms_SetClientGag (Cl, true, 10080, true, reason);
            SourceComms_SetClientMute(Cl, true, 10080, true, reason);
        }
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

// player join (includes rejoins at map changes)
public void OnClientPutInServer(int Cl)
{
    if (IsValidClient(Cl))
    {
        clearWarning(GetClientUserId(Cl));
    }
}

// clear warning (clears on player join, map change and player leave)
void clearWarning(int userid)
{
    hasClientBeenWarned[GetClientOfUserId(userid)] = false;
}

// IsValidClient Stock
bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsFakeClient(client)
    );
}
