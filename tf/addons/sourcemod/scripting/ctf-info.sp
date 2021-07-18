#pragma semicolon 1

#include <sourcemod>

// set in base cfg
// ConVar ce_environment;
// dynamically set
ConVar ce_region;

public void OnPluginStart()
{
    HookConVarChange(FindConVar("ce_server_index"), IndexChanged);
    RegServerCmd("ctf_regen_info", RegenInfo, "Regen CTF Info");
    CreateConVar
    (
       "ce_environment",          // name
       " ",                       // default value
       "Creators.TF Environment", // description
       FCVAR_NONE                 // flags
    );
    ce_region = CreateConVar
    (
       "ce_region",               // name
       " ",                       // default value
       "Creators.TF Region",      // description
       FCVAR_NONE                 // flags
    );
}

Action RegenInfo(int args)
{
    SetHostnameEtc();   
}

void IndexChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    SetHostnameEtc();
}

enum
{
    UNKNOWN = 0,
    QP,
    VPLUS,
    DD
}

char url[32] = "Creators.TF";

void SetHostnameEtc()
{
    int sid = GetConVarInt(FindConVar("ce_server_index"));

    char region[64];
    char c_region[24];
    int type;
    bool econ;
    bool pubs;

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
        region = "Midwest US";
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

    SetConVarString(ce_region, c_region);

    // Pretty obvious.
    char ctype[64];
    if (type == UNKNOWN)
    {
        ctype = "Unknown";
    }
    else if (type == QP)
    {
        ctype = "Custom Pubs";
        econ = true;
        pubs = true;
    }
    else if (type == VPLUS)
    {
        ctype = "Vanilla+ Pubs | NoDL";
        econ = false;
        pubs = true;
    }
    else if (type == DD)
    {
        ctype = "Digital Directive MvM";
        econ = true;
        pubs = false;
    }
    
    // Here's the meat of our execing

    // always exec our base
    ServerCommand("exec quickplay/base");


    // exec econ or vanilla depending on the server type
    if (econ)
    {
        ServerCommand("exec quickplay/econ");
    }
    else
    {
        ServerCommand("exec quickplay/vanilla");
    }

    // set pub or mvm mapcycle depending on the server type
    if (pubs)
    {
        ServerCommand("mapcyclefile quickplay/mapcycle.txt");
    }
    else
    {
        ServerCommand("mapcyclefile quickplay/mapcycle-mvm.txt");
    }
    
    // set our hostname here    
    char hostname[128];
    Format(hostname, sizeof(hostname), "%s | %s | %s | #%i", url, region, ctype, sid);
    ServerCommand("hostname %s", hostname);
}
