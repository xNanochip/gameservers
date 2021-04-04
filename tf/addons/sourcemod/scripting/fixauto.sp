#pragma semicolon 1;
#pragma newdecls required;

#include <sourcemod>
#include <sdktools>
#include <tf2>

public Plugin myinfo =
{
    name             = "Disable Autobalance during bad times",
    author           = "stephanie",
    description      = "Don't autobalance people during these times",
    version          = "0.0.1",
    url              = "https://sappho.io"
}

/*
    Don't autobalance people during these times:
    -   1 minute left in server time            - done !
    -   30 sec or less in round time            - done !
    -   one team owns 4 out of 5 cap points     - done !
    -   cart is before the last point           - done !
        this only includes the LAST last point on multistage pl maps

    TODO - if one team has 2 intel captures and the 3rd intel is picked up
*/

// enable autobalance
void EnableAuto()
{
    SetConVarInt(FindConVar("mp_autoteambalance"), 1);
}

// disable autobalance
void DisableAuto()
{
    SetConVarInt(FindConVar("mp_autoteambalance"), 0);
}

bool FIVECP;
bool PL;
//bool KOTH;
//bool CTF;

int uncappedpoints;
int redpoints;
int blupoints;

public void OnPluginStart()
{
    CreateTimer(1.0, CheckMapTimeLeft, _, TIMER_REPEAT);
    HookEvent("teamplay_round_start", OnRoundStart);
    HookEvent("teamplay_point_captured", ControlPointCapped);
    HookEntityOutput("team_round_timer", "On30SecRemain", NearEndOfRound);
}

public void OnMapStart()
{
    LogMessage("Map started. Enabling autobalance!");
    EnableAuto();
    CheckGamemode();
}

Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    LogMessage("A round started. Enabling autobalance!");
    EnableAuto();
    CheckGamemode();
}

void CheckGamemode()
{
    FIVECP  = false;
    PL      = false;

    char curMap[64];
    GetCurrentMap(curMap, sizeof(curMap));
    // 5CP
    if (StrContains(curMap, "cp_", false) != -1)
    {
        int iEnt = -1;
        while ((iEnt = FindEntityByClassname(iEnt, "team_control_point")) > 0)
        {
            // If there is a blu CP or a neutral CP, then it's not an attack/defend map
            if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Red))
            {
                FIVECP = true;
                LogMessage(">>>5CP detected<<<");
                checkPoints();
                break;
            }
        }
        LogMessage("A/D detected");
    }
    // PL
    else if (StrContains(curMap, "pl_", false) != -1)
    {
        LogMessage(">>>PAYLOAD detected<<<");
        PL = true;
    }
    else if (StrContains(curMap, "koth_", false) != -1)
    {
        LogMessage(">>>KOTH detected<<<");
        //KOTH = true;
    }
    else if (StrContains(curMap, "ctf_", false) != -1)
    {
        LogMessage(">>>CTF detected<<<");
        //CTF = true;
    }
}

void checkPoints()
{
    // clear these
    uncappedpoints  = 0;
    redpoints       = 0;
    blupoints       = 0;

    // init to -1 to search from first ent
    int iEnt = -1;
    // search thru ents to find all the control points and check their teams
    while ((iEnt = FindEntityByClassname(iEnt, "team_control_point")) > 0)
    {
        // uncapped
        if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Unassigned))
        {
            uncappedpoints++;
            continue;
        }
        // red
        if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Red))
        {
            redpoints++;
            continue;
        }
        // blu
        if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Blue))
        {
            blupoints++;
            continue;
        }
    }
    LogMessage("uncapped %i blue %i red %i", uncappedpoints, blupoints, redpoints);
}

// whenever any point gets capped
Action ControlPointCapped(Event event, const char[] name, bool dontBroadcast)
{
    // only do this on 5cp or payload duh
    if (FIVECP || PL)
    {
        // recheck our points
        checkPoints();

        if (FIVECP)
        {
            // it should only ever be 4 vs 1 if someones pushing last
            if
            (
                (redpoints == 4 && blupoints == 1)
                ||
                (blupoints == 4 && redpoints == 1)
            )
            {
                LogMessage("Someone is pushing last. Disabling autobalance!");
                DisableAuto();
            }
            else
            {
                LogMessage("Nobody is pushing last. Enabling autobalance!");
                EnableAuto();
            }
        }
        else if (PL)
        {
            // this means red only has one point left
            if (redpoints == 1)
            {
                LogMessage("Someone is pushing last. Disabling autobalance!");
                DisableAuto();
            }
            else
            {
                LogMessage("Nobody is pushing last. Enabling autobalance!");
                EnableAuto();
            }
        }
    }
}

// fired on 30 seconds left, including setup time!
void NearEndOfRound(const char[] output, int caller, int activator, float delay)
{
    if
    (
        // only bother if we're running
        GameRules_GetRoundState() == RoundState_RoundRunning
        &&
        // make sure we're not in stinky setup time
        GameRules_GetProp("m_bInSetup") == 0
    )
    {
        LogMessage("Near the end of the round, disabling autobalance!");
        DisableAuto();
    }
}

// check server time - runs every second
public Action CheckMapTimeLeft(Handle timer)
{
    int timelimit;
    GetMapTimeLimit(timelimit);

    int totalsecs;
    GetMapTimeLeft(totalsecs);

    // don't bother if no timelimit or server time is expired
    if (timelimit == 0 || totalsecs <= 0)
    {
        return Plugin_Handled;
    }

    // 1 minute left!
    if (totalsecs == 60)
    {
        LogMessage("server time at 1 minute left, disabling autobalance");
        DisableAuto();
    }

    return Plugin_Handled;
}