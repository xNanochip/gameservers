#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

bool didstartup;

enum
{
    UNKNOWN = 0,
    QP,
    VPLUS,
    DD
}

// set in base cfg
// ConVar ce_environment;
// dynamically set
//ConVar ce_server_index;
ConVar ce_region;
ConVar ce_type;

bool econ;
bool pubs;
//bool mvm;

//TODO: make it pull all this info from a kv file pls

public void OnPluginStart()
{
    RegServerCmd("ctf_regen_info", RegenInfo, "Regen CTF Info");

    CreateConVar("ce_environment", " ", "Creators.TF Environment");
    ce_region = CreateConVar("ce_region", " ", "Creators.TF Server Region");
    CreateConVar("ce_server_index", "-1", "Creators.TF Server Index");
    ce_type = CreateConVar("ce_type", " ", "Creators.TF Server Type");

    LogMessage("\n\n[CTF-INFO] -> CREATED CTF CONVARS\n");
}

Action RegenInfo(int args)
{
    SetHostnameEtc();   
}

char url[32] = "Creators.TF";

void SetHostnameEtc()
{
    int sid = GetConVarInt(FindConVar("ce_server_index"));

    char region[64];
    char c_region[24];
    int type;

    econ = false;
    pubs = false;

    // unknown region
    // todo: events servers
    if (sid > 0 && sid < 100)
    {
        region = "?";
    }
    // 100 block
    else if (sid >= 101 && sid <= 199) 
    {
        region = "West EU";

        /***********
            EU 1
        ***********/
        if (sid <= 110)
        {
            c_region = "EU 1";
            if (sid <= 104)
            {
                type = QP;
            }
            else
            {
                type = VPLUS;
            }
        }

        /**********
            EU 2
        **********/
        else
        {
            c_region = "EU 2";
            type = DD;
        }
    }

    /**********
        VIN
    **********/
    else if (sid >= 201 && sid <= 299)
    {
        region = "East US";
        c_region = "VIN";
        if (sid <= 204)
        {
            type = QP;
        }
        else if (sid <= 210)
        {
            type = VPLUS;
        }
    }

    /**********
        LA
    **********/
    else if (sid >= 301 && sid <= 399)
    {
        region = "West US";
        c_region = "LA";
        if (sid == 301)
        {
            type = QP;
        }
        else if (sid == 302)
        {
            type = VPLUS;
        }
        else
        {
            type = DD;
        }
    }

    /**********
        CHI
    **********/
    else if (sid >= 401 && sid <= 499)
    {
        region = "East US";
        c_region = "CHI";
        type = DD;
    }

// here's where i'd put my brazil server....
// https://i.imgur.com/PpL0EQa.png

    /**********
        AUS
    **********/
    else if (sid >= 601 && sid <= 699)
    {
        region = "Australia";
        c_region = "AUS";
        if (sid == 601)
        {
            type = QP;
        }
        else if (sid == 602)
        {
            type = VPLUS;
        }
        else
        {
            type = DD;
        }
    }

    /**********
        SGP
    **********/
    else if (sid >= 700 && sid < 800)
    {
        region = "Singapore";
        c_region = "SGP";
        if (sid == 701)
        {
            type = QP;
        }
        else if (sid == 702)
        {
            type = VPLUS;
        }
        else
        {
            type = DD;
        }
    }

    /**********
    US POTATO MARYLAND
    **********/
    else if (sid >= 800 && sid <= 849)
    {
        region = "East US";
        c_region = "US_POT";
        type = DD;
    }

    /**********
     EU POTATO
    **********/

    else if (sid >= 850 && sid <= 899)
    {
        region = "West EU";
        c_region = "EU_POT";
        type = DD;
    }

    /**********
      UNKNOWN
    **********/
    else
    {
        region = "Unknown region";
        c_region = "UNKNOWN";
        type = UNKNOWN;
    }

    // set ce_region
    SetConVarString(ce_region, c_region);

    // Pretty obvious.
    char ctype[64];
    if (type == UNKNOWN)
    {
        ctype = "Unknown";
    }
    else if (type == QP)
    {
        ctype = "Quickplay";
        econ = true;
        pubs = true;
        //mvm = false;
    }
    else if (type == VPLUS)
    {
        ctype = "Vanilla+ | NO DL";
        econ = false;
        pubs = true;
        //mvm = false;
    }
    else if (type == DD)
    {
        ctype = "Digital Directive MvM";
        econ = true;
        pubs = false;
        //mvm = true;
    }

    // set ce_type
    SetConVarString(ce_type, ctype);
    
    LogMessage("\n\n[CTF-INFO] SETTING HOSTNAME\n\n");
    // set our hostname here    
    char hostname[128];
    Format(hostname, sizeof(hostname), "%s | %s | %s | #%i", url, region, ctype, sid);

    // can i use SetConVarString here? lol -steph
    // yes, FindConVar, then .SetString it. Methodmaps pls. -nano
    // i will do it later -steph
    //ServerCommand("hostname %s", hostname);
    SetConVarString(FindConVar("hostname"), hostname);
    CreateTimer(0.25, ExecBase);
}

Action ExecBase(Handle timer)
{
    LogMessage("\n\n[CTF-INFO] EXECING BASE.CFG\n\n");
    // always exec our base
    ServerCommand("exec quickplay/base");

    CreateTimer(0.25, ExecMapcycle);
}

Action ExecMapcycle(Handle timer)
{
    LogMessage("\n\n[CTF-INFO] SETTING MAPCYCLE\n\n");
    // set pub or mvm mapcycle depending on the server type
    if (pubs)
    {
        ServerCommand("mapcyclefile quickplay/mapcycle.txt");
    }
    else
    {
        ServerCommand("mapcyclefile quickplay/mapcycle_mvm.txt");
    }
    CreateTimer(0.25, ExecEconVanilla);
}


Action ExecEconVanilla(Handle timer)
{
    LogMessage("\n\n[CTF-INFO] EXECING TYPE CFG\n\n");
    // exec econ or vanilla depending on the server type
    if (econ)
    {
        ServerCommand("exec quickplay/econ");
    }
    else
    {
        ServerCommand("exec quickplay/vanilla");
    }
    CreateTimer(0.25, ExecGamemode);
}

Action ExecGamemode(Handle timer)
{
    LogMessage("\n\n[CTF-INFO] EXECING GAMEMODE CFG\n\n");
    if (pubs)
    {
        ServerCommand("exec quickplay/pubs");
    }
    else
    {
        ServerCommand("exec quickplay/mvm");
    }

    if (!didstartup)
    {
        CreateTimer(1.0, DoStartup);
    }
}

Action DoStartup(Handle timer)
{
    didstartup = true;
    LogMessage("\n\n[CTF-INFO] BATON PASSING TO STARTUP PLUGIN\n\n");
    ServerCommand("_startup");
}
