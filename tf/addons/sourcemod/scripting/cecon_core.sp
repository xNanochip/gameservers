//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Core plugin for Creators.TF Custom Economy plugin.
//
//=========================================================================//

#include <steamtools>

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define MAX_ENTITY_LIMIT 2048

#include <cecon>
#include <cecon_http>
#include <tf2>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <tf2attributes>

#define DEFAULT_ECONOMY_BASE_URL "https://creators.tf"

public Plugin myinfo =
{
	name = "Creators.TF Core",
	author = "Creators.TF Team",
	description = "Core plugin for Creators.TF Custom Economy plugin.",
	version = "1.0.1",
	url = "https://creators.tf"
}

char m_sBaseEconomyURL[64];
char m_sEconomyAccessKey[150];
char m_sBranchName[32];
char m_sBranchPassword[64];
char m_sAuthorizationKey[129];

bool m_bCredentialsLoaded = false;

ConVar ce_debug_mode;



ConVar ce_schema_autoupdate;
KeyValues m_Schema;

char m_sSchemaBuildVersion[64];
char m_sItemSchemaFilePath[96];

Handle g_CEcon_OnSchemaUpdated;



#define MAX_EVENT_UNIQUE_INDEX_INT 10000

Handle g_hOnClientEvent;
int m_iLastWeapon[MAXPLAYERS + 1];

public void OnPluginStart()
{
	ce_debug_mode = CreateConVar("ce_debug_mode", "0");

	if(Steam_IsConnected())
	{
		PrintToServer("Steam_IsConnected()");
		ReloadEconomyCredentials();
	}

	//============================//
	// Schema
	
	BuildPath(Path_SM, m_sItemSchemaFilePath, sizeof(m_sItemSchemaFilePath), "configs/item_schema.cfg");
	// ConVars
	ce_schema_autoupdate = CreateConVar("ce_schema_autoupdate", "1", "Should auto-update item schema on every map change.");
	// Commands
	RegServerCmd("ce_schema_update", cSchemaUpdate);

	//============================//
	// Events
	
	g_hOnClientEvent = CreateGlobalForward("CEcon_OnClientEvent", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
	RegAdminCmd("ce_events_test", cTestEvnt, ADMFLAG_ROOT, "");
	
	LateHooking();
}

public void OnMapStart()
{
	Schema_ProcessCachedItemSchema();
	Schema_CheckForUpdates(false);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("cecon_core");

	//========================//
	// Core

	CreateNative("CEcon_GetAccessKey", Native_GetAccessKey);
	CreateNative("CEcon_GetBaseBackendURL", Native_GetBaseBackendURL);
	CreateNative("CEcon_GetAuthorizationKey", Native_GetAuthorizationKey);

	//========================//
	// Schema
	
	g_CEcon_OnSchemaUpdated = CreateGlobalForward("CEcon_OnSchemaUpdated", ET_Ignore, Param_Cell);	
	CreateNative("CEcon_GetEconomySchema", Native_GetEconomySchema);

	//========================//
	// Events
	
	CreateNative("CEcon_SendEventToClient", Native_SendEventToClient);
	CreateNative("CEcon_SendEventToClientUnique", Native_SendEventToClientUnique);
	CreateNative("CEcon_SendEventToClientFromGameEvent", Native_SendEventToClientFromGameEvent);
	CreateNative("CEcon_SendEventToAll", Native_SendEventToAll);
	CreateNative("CEcon_GetLastUsedWeapon", Native_LastUsedWeapon);
	
	return APLRes_Success;
}

public int Steam_FullyLoaded()
{
	PrintToServer("Steam_FullyLoaded()");
	Steam_OnReady();
}

public void Steam_OnReady()
{
	ReloadEconomyCredentials();

	Schema_CheckForUpdates(false);
}

// Used to refresh economy credentials from economy.cfg file.
public void ReloadEconomyCredentials()
{
	m_bCredentialsLoaded = false;

	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/economy.cfg");

	KeyValues kv = new KeyValues("Economy");
	if (!kv.ImportFromFile(sLoc))return;

	kv.GetString("Key", m_sEconomyAccessKey, sizeof(m_sEconomyAccessKey));
	kv.GetString("Branch", m_sBranchName, sizeof(m_sBranchName));
	kv.GetString("Password", m_sBranchPassword, sizeof(m_sBranchPassword));
	kv.GetString("Domain", m_sBaseEconomyURL, sizeof(m_sBaseEconomyURL), DEFAULT_ECONOMY_BASE_URL);
	kv.GetString("Authorization", m_sAuthorizationKey, sizeof(m_sAuthorizationKey));
	delete kv;

	m_bCredentialsLoaded = true;

	SafeStartCoordinatorPolling();
	CreateTimer(5.0, Timer_CoordinatorWatchDog);
}

public void DebugLog(const char[] message, any ...)
{
	if(ce_debug_mode.BoolValue)
	{
		int length = strlen(message) + 255;
		char[] sOutput = new char[length];

		VFormat(sOutput, length, message, 2);
		LogMessage(sOutput);
	}
}

public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

public int FindTargetBySteamID(const char[] steamid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientAuthorized(i))
		{
			char szAuth[256];
			GetClientAuthId(i, AuthId_SteamID64, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, steamid))return i;
		}
	}
	return -1;
}

public bool IsEntityValid(int entity)
{
	return entity > 0 && entity < MAX_ENTITY_LIMIT && IsValidEntity(entity);
}

public any Native_GetBaseBackendURL(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sBaseEconomyURL, size);
}

public any Native_GetAccessKey(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sEconomyAccessKey, size);
}

public any Native_GetAuthorizationKey(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sAuthorizationKey, size);
}

//============= Copyright Amper Software 2021, All rights reserved. =======//
//
// Purpose: Creates the connection between website and servers. Allows two-way
// messaging between servers and website using long-polling technique.
//
//=========================================================================//


//===============================//
// DOCUMENTATION

/* HOW DOES COORDINATOR WORK?
*
*	Coordinator is a module that is made to provide two-way communuication
*	brigde between servers and backend. For requests directed from servers
*	to website, we simply use HTTP requests to API.
*
*	For requests fron website to server we can't use direct HTTP requests,
*	so we need to do some trickery here. We're using Long-Polling technique
*	that allows us to send events from backend to game server in real time.
*
*	If you want to learn more about how Long-Polling works, google it. But
*	in short: When coordinator is initialized, we send a request to backend
*	which, unlike all other typical requests, is kept open for an extended
*	period of time. If something happens on the backend, that we need to
*	alert this plugin about, backend responds with event's content and closes
*	connection in this request. Plugin reads contents of the event, does
*	whatever it needs with it, opens another similar request and loop goes on.
*
*
*/
//===============================//

char sProcessedJobs[256];
bool m_bCoordinatorActive = false;
bool m_bIsBackendUnreachable = false;

int m_iFailureCount = 0;

#define COORDINATOR_MAX_FAILURES 5
#define COORDINATOR_FAILURE_TIMEOUT 20.0

// Timer that reenables coordinator queue in case if something breaks.
public Action Timer_CoordinatorWatchDog(Handle timer, any data)
{
	SafeStartCoordinatorPolling();
}

// Used to start coordinator request, but it only does
// that if there are no active requests right now.
public void SafeStartCoordinatorPolling()
{
	if (m_bCoordinatorActive)return;

	StartCoordinatorLongPolling();
}

// Used to force start a coordinator request.
public void StartCoordinatorLongPolling()
{
	// PrintToServer("StartCoordinatorLongPolling()");
	// Before we make anoher request, let's make sure that nothing tells us
	// not to. Before we are sure that nothing stops us from making a request, let's
	// set this flag to false.

	m_bCoordinatorActive = false;

	// If there are any conditons that tell us not to make a request, we return this function.
	// m_bCoordinatorActive will be false at this point, and this will mean that plugin stopped
	// making requests in queue. And it will not do any until this function is called again
	// and all these conditions are met.

	// If we failed to read economy credentials (Backend Domain, API Key, etc..).
	if (!m_bCredentialsLoaded)return;

	// All conditions were met, mark this flag as true and start the request.
	m_bCoordinatorActive = true;
	
	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/IServers/GServerCoordinator", m_sBaseEconomyURL);

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "processed_jobs", sProcessedJobs);
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 40);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", m_sAuthorizationKey);
	
	char sAccessHeader[256];
	Format(sAccessHeader, sizeof(sAccessHeader), "Provider %s", m_sEconomyAccessKey);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sAccessHeader);

	Steam_SendHTTPRequest(httpRequest, Coordinator_Request_Callback);
}

public void Coordinator_Request_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	bool bError = true;

	// If response was succesful...
	if (success)
	{
		// And response code is 200...
		if (code == HTTPStatusCode_OK)
		{
			// Let's try to process the request response.
			// --------------------------------------------- //
			// NOTE: Notice that it may still return an error, if for some reason response
			// body is in invalid format (not KeyValues).
			// --------------------------------------------- //
			// NOTE: Also keep in mind that long-polling timeout is not considered to be an error.
			// If response content is "TIMEOUT", that means that backend has decided to close
			// the connection. We do not consider that as an error and just make another request
			// right away.

			bError = CoordinatorProcessRequestContent(request);
		}
	}

	// If we ended up with an error, that means that something went wrong.
	// Let's try a few more times (defined in COORDINATOR_MAX_FAILURES) and then
	// make a timeout for COORDINATOR_FAILURE_TIMEOUT seconds.
	if(bError)
	{

		if(!m_bIsBackendUnreachable)
		{
			// If last time backend was reachable, mark it as unreachable
			// and throw a message in chat to notify everyone about downtime.
			m_bIsBackendUnreachable = true;
			CoordinatorOnBackendUnreachable();
		}

		// We increase this variable if error happened.
		m_iFailureCount++;

		// If this variable reached the limit, we make a timeout.
		if(m_iFailureCount >= COORDINATOR_MAX_FAILURES)
		{

			// Throw a message in console.
			LogError("Connection to Economy Coordinator failed after %d retries. Making another attempts in %f seconds", COORDINATOR_MAX_FAILURES, COORDINATOR_FAILURE_TIMEOUT);
			// Reset the variable so that we start with zero upon next request.
			m_iFailureCount = 0;

			// Create a delay with timer.
			CreateTimer(COORDINATOR_FAILURE_TIMEOUT, Timer_DelayedCoordinatorRequest);
			return;

		} else {

			// If we didn't reach the timeout limit yet, wait for one second and
			// try to make another attempt.
			CreateTimer(1.0, Timer_DelayedCoordinatorRequest);
		}
	} else {

		if(m_bIsBackendUnreachable)
		{
			m_bIsBackendUnreachable = false;
			CoordinatorOnBackendReachable();
		}

		// If everything was succesfully, make another request in the next frame.
		RequestFrame(RF_DelayerCoordinatorRequest);
	}
}

public void CoordinatorOnBackendUnreachable()
{
	// TODO: Make a forward.
	PrintToChatAll("\x01Economy Backend is \x03down.");
	PrintToServer("[WARNING] Economy Backend is down.");
}

public void CoordinatorOnBackendReachable()
{
	// TODO: Make a forward.
	PrintToChatAll("\x01Economy Backend is \x03up.");
	PrintToServer("[WARNING] Economy Backend is up.");
}

// Used to start a coordiantor request with a delay using RequestFrame.
public void RF_DelayerCoordinatorRequest(any data)
{
	StartCoordinatorLongPolling();
}

// Used to start a coordiantor request with a delay using CreateTimer.
public Action Timer_DelayedCoordinatorRequest(Handle timer, any data)
{
	StartCoordinatorLongPolling();
}

// Processes response of the coordinator request.
// Returns true if there are any errors.
public bool CoordinatorProcessRequestContent(HTTPRequestHandle request)
{
	// Getting response content length.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];

	// Getting actual response content body.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	// If response content is "TIMEOUT", that means that backend has decided to close
	// the connection. We do not count that as an error, but we still return, because
	// there is nothing to parse.
	if (StrEqual(content, "TIMEOUT"))return false;

	// We can't really check if content in response is in KeyValues or not,
	// but what we can do is check if it starts with a quote mark. KV1 (which is
	// the format, that backend gives us a response in) always has this symbol
	// in the beginning.
	if (content[0] != '"')return true;

	// Do I have to explain you what this is?
	KeyValues kv = new KeyValues("Response");

	// KeyValues.ImportFromString() returns false if it failed to process string into a KV handle.
	// If this happens we return true because some error has occured.
	if (!kv.ImportFromString(content))return true;

	// Flush the string that contains list of jobs that we've processed.
	// We are going to send this list in the next coordinator request to let it know
	// that these jobs are already processed by us.
	strcopy(sProcessedJobs, sizeof(sProcessedJobs), "");

	// Assuming that at this point KV handle is valid. Processing it.
	if(kv.JumpToKey("jobs", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				// Getting index of the job and appending it to the list of processed jobs.
				char sIndex[64];
				kv.GetString("index", sIndex, sizeof(sIndex));
				Format(sProcessedJobs, sizeof(sProcessedJobs), "%s%s,", sProcessedJobs, sIndex);

				// Getting the actual job command that we need to excetute. And execute it.
				char sCommand[256];
				kv.GetString("command", sCommand, sizeof(sCommand));

				PrintToServer(sCommand);
				ServerCommand(sCommand);

			} while (kv.GotoNextKey());

			kv.GoBack();
		}
		kv.GoBack();
	}

	// Deleting this handle as we don't need it anymore.
	delete kv;

	// Return false as there were no errors in this execution.
	return false;
}
//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Manages Economy Schema auto-update.
//
//=========================================================================//

public Action cSchemaUpdate(int args)
{
	Schema_CheckForUpdates(true);
	return Plugin_Handled;
}

public void Schema_ProcessCachedItemSchema()
{
	KeyValues kv = new KeyValues("Schema");
	if (!kv.ImportFromFile(m_sItemSchemaFilePath))return;

	kv.GetString("Version/build", m_sSchemaBuildVersion, sizeof(m_sSchemaBuildVersion), "");
	LogMessage("Current Item Schema version: %s", m_sSchemaBuildVersion);

	Call_StartForward(g_CEcon_OnSchemaUpdated);
	Call_PushCell(kv);
	Call_Finish();

	// Clearing old schema if exists.
	delete m_Schema;
	m_Schema = kv;
}

// Used to update schema on the servers.
public void Schema_CheckForUpdates(bool bIsForced)
{
	// If we're not forcing autoupdate.
	if(!bIsForced)
	{
		// And autoupdate is not enabled...
		if (!ce_schema_autoupdate.BoolValue)
		{
			// Dont do anything.
			return;
		}
	}

	LogMessage("Checking for Item Schema updates...");

	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/IEconomyItems/GScheme", m_sBaseEconomyURL);

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "field", "Version");
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 10);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", m_sAuthorizationKey);
	
	char sAccessHeader[256];
	Format(sAccessHeader, sizeof(sAccessHeader), "Provider %s", m_sEconomyAccessKey);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sAccessHeader);

	PrintToChatAll("Schema_CheckForUpdates()");
	Steam_SendHTTPRequest(httpRequest, Schema_CheckForUpdates_Callback);
}

public void Schema_CheckForUpdates_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	PrintToChatAll("Schema_CheckForUpdates_Callback()");
	// If request is succesful...
	if (success)
	{
		// And response code is 200...
		if (code == HTTPStatusCode_OK)
		{
			// Getting response content length.
			int size = Steam_GetHTTPResponseBodySize(request);
			char[] content = new char[size + 1];

			// Getting actual response content body.
			Steam_GetHTTPResponseBodyData(request, content, size);
			Steam_ReleaseHTTPRequest(request);

			// We can't really check if content in response is in KeyValues or not,
			// but what we can do is check if it starts with a quote mark. KV1 (which is
			// the format, that backend gives us a response in) always has this symbol
			// in the beginning.
			if (content[0] != '"')return;

			KeyValues kv = new KeyValues("Response");

			// KeyValues.ImportFromString() returns false if it failed to process string into a KV handle.
			// If this happens we return because some error has occured.
			if (!kv.ImportFromString(content))return;

			// Assuming that at this point KV handle is valid. Processing it.
			char sNewBuild[64];
			kv.GetString("build", sNewBuild, sizeof(sNewBuild));

			if(StrEqual(m_sSchemaBuildVersion, sNewBuild))
			{
				LogMessage("No new updates found.");
			} else {
				LogMessage("A new version detected. Updating...");
				Schema_ForceUpdate();
			}
			
			delete kv;

			return;
		}
	}

	return;
}

// Used to update schema on the servers.
public void Schema_ForceUpdate()
{
	PrintToChatAll("Schema_ForceUpdate()");
	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/IEconomyItems/GScheme", m_sBaseEconomyURL);

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 10);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", m_sAuthorizationKey);
	
	char sAccessHeader[256];
	Format(sAccessHeader, sizeof(sAccessHeader), "Provider %s", m_sEconomyAccessKey);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sAccessHeader);

	PrintToChatAll("Schema Update Send");
	Steam_SendHTTPRequest(httpRequest, Schema_ForceUpdate_Callback);
}

public void Schema_ForceUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	PrintToChatAll("Schema_ForceUpdate_Callback()");
	// If request is succesful...
	if (success)
	{
		// And response code is 200...
		if (code == HTTPStatusCode_OK)
		{
			Steam_WriteHTTPResponseBody(request, m_sItemSchemaFilePath);
			Schema_ProcessCachedItemSchema();
		}
	}

	return;
}

public any Native_GetEconomySchema(Handle plugin, int numParams)
{
	return m_Schema;
}

//============= Copyright Amper Software 2021, All rights reserved. =======//
//
// Purpose: Used for tracking different events happening in game, and connect
// them with economy features, like quests or achievements.
//
//=========================================================================//

public void Events_OnPluginStart()
{
}

public APLRes Events_AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "obj_") != -1)
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	if(StrEqual(classname, "player"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	if(StrContains(classname, "item_healthkit") != -1)
	{
		SDKHook(entity, SDKHook_Touch, OnTouch);
	}
}

public Action OnTouch(int entity, int toucher)
{
	if (!IsClientValid(toucher))return Plugin_Continue;

	int hOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (hOwner == toucher)return Plugin_Continue;

	// If someone touched a sandvich, mark heavy's secondary weapon as last used.
	if(IsClientValid(hOwner))
	{
		if(TF2_GetPlayerClass(hOwner) == TFClass_Heavy)
		{
			int iLunchBox = GetPlayerWeaponSlot(hOwner, 1);
			if(IsValidEntity(iLunchBox))
			{
				m_iLastWeapon[hOwner] = iLunchBox;
			}
		}
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if(IsClientValid(attacker))
	{
		if(IsValidEntity(inflictor))
		{
			// If inflictor entity has a "m_hBuilder" prop, that means we've killed with a building.
			// Setting our wrench as last weapon.
			if(HasEntProp(inflictor, Prop_Send, "m_hBuilder"))
			{
				if(TF2_GetPlayerClass(attacker) == TFClass_Engineer)
				{
					int iWrench = GetPlayerWeaponSlot(attacker, 2);
					if(IsValidEntity(iWrench))
					{
						m_iLastWeapon[attacker] = iWrench;
					}
				}
			} else {
				// Player killed someone with a hitscan weapon. Saving the one.
				m_iLastWeapon[attacker] = weapon;
			}
		}
	}
}

public Action cTestEvnt(int client, int args)
{
	if(IsClientValid(client))
	{
		char sArg1[128], sArg2[11];
		GetCmdArg(1, sArg1, sizeof(sArg1));
		GetCmdArg(2, sArg2, sizeof(sArg2));

		CEcon_SendEventToClientUnique(client, sArg1, MAX(StringToInt(sArg2), 1));
	}

	return Plugin_Handled;
}

public void LateHooking()
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_*")) != -1)
	{
		SDKHook(ent, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	ent = -1;
	while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
	{
		SDKHook(ent, SDKHook_Touch, OnTouch);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public any Native_LastUsedWeapon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return m_iLastWeapon[client];
}

public any Native_SendEventToClientFromGameEvent(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	char event[128];
	GetNativeString(2, event, sizeof(event));
	
	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);
	
	CEcon_SendEventToClient(client, event, add, unique_id);
}

public any Native_SendEventToClientUnique(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	char event[128];
	GetNativeString(2, event, sizeof(event));
	
	int add = GetNativeCell(3);
	int unique_id = GetRandomInt(0, MAX_EVENT_UNIQUE_INDEX_INT);
	
	CEcon_SendEventToClient(client, event, add, unique_id);
}

public any Native_SendEventToAll(Handle plugin, int numParams)
{
	char event[128];
	GetNativeString(1, event, sizeof(event));
	
	int add = GetNativeCell(2);
	int unique_id = GetNativeCell(3);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientValid(i))continue;
		
		CEcon_SendEventToClient(i, event, add, unique_id);
	}
}

public any Native_SendEventToClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	char event[128];
	GetNativeString(2, event, sizeof(event));
	
	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);

	Call_StartForward(g_hOnClientEvent);
	Call_PushCell(client);
	Call_PushString(event);
	Call_PushCell(add);
	Call_PushCell(unique_id);
	Call_Finish();
}
public int MAX(int iNum1, int iNum2)
{
	if (iNum1 > iNum2)return iNum1;
	if (iNum2 > iNum1)return iNum2;
	return iNum1;
}

public int MIN(int iNum1, int iNum2)
{
	if (iNum1 < iNum2)return iNum1;
	if (iNum2 < iNum1)return iNum2;
	return iNum1;
}