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

//-------------------------------------------------------------------
// Economy Credentials
//-------------------------------------------------------------------
char m_sBaseEconomyURL[64];		// Stores the base url that is used for api link generation.
char m_sEconomyAccessKey[150];	// Creators.TF Backend API key, associated with the provider.
char m_sBranchName[32];			// Schema branch name.
char m_sBranchPassword[64];		// Secret keyword, used to retrieve schema from the branch.
char m_sAuthorizationKey[129];	// Value to put into "Authorization" header, when making a request.
								// In case if remote backend is passworded.

// True if all credentials have loaded succesfully.
bool m_bCredentialsLoaded = false;


//-------------------------------------------------------------------
// Schema
//-------------------------------------------------------------------
ConVar ce_schema_autoupdate;	// If true, plugins will autoupdate the item schema on every map change.
KeyValues m_Schema;				// Cached keyvalues handle of the schema, used for plugins that late load.

char m_sSchemaBuildVersion[64];	// Build version of the locally downloaded schema.
char m_sItemSchemaFilePath[96];	// File path to the items_config.cfg (Usually "addons/sourcemod/configs/items_config.cfg")

Handle g_CEcon_OnSchemaUpdated;	// Forward, that notifies the sub plugins, if the schema has changed.


//-------------------------------------------------------------------
// Events
//-------------------------------------------------------------------
// When we generate a random event index, this value is used as the
// maximum value.
#define MAX_EVENT_UNIQUE_INDEX_INT 10000

// Fired when a new client even is fired.
Handle g_hOnClientEvent;
// We store last weapon that client has interacted with.
int m_iLastWeapon[MAXPLAYERS + 1];

//-------------------------------------------------------------------
// Coordinator
//-------------------------------------------------------------------

// Stores all jobs indexes that we've already processed,
// and we need to mark as such on next coordiantor request.
char sProcessedJobs[256];
bool m_bCoordinatorActive = false;			// True if coordiantor is currently in process of making requests.
bool m_bIsBackendUnreachable = false;		// True if we can't reach backend for an extended period of time.

int m_iFailureCount = 0;					// Amount of failures that we have encountered in a row.

// Maximum amount of failures before we initiate a timeout.
#define COORDINATOR_MAX_FAILURES 5

// To prevent infinite spam to the backend,
// we timeout our requests if a certain amount of failures were made.
#define COORDINATOR_FAILURE_TIMEOUT 20.0

ConVar ce_coordinator_enabled;				// If true, coordinator will be online.


//-------------------------------------------------------------------
// Purpose: Fired when plugin starts.
//-------------------------------------------------------------------
public void OnPluginStart()
{
	// If SteamTools is already connected, load
	// credentials right away.
	if(Steam_IsConnected())
	{
		Steam_OnReady();
	}
	// ----------- COORD ------------ //

	ce_coordinator_enabled = CreateConVar("ce_coordinator_enabled", "1", "If true, coordinator will be online.");

	// ----------- SCHEMA ----------- //

	// Preload the schema file location path for later usage.
	BuildPath(Path_SM, m_sItemSchemaFilePath, sizeof(m_sItemSchemaFilePath), "configs/item_schema.cfg");
	// ConVars
	ce_schema_autoupdate = CreateConVar("ce_schema_autoupdate", "1", "Should auto-update item schema on every map change.");
	// Commands
	RegServerCmd("ce_schema_update", cSchemaUpdate);

	// ----------- EVENTS ----------- //

	g_hOnClientEvent = CreateGlobalForward("CEcon_OnClientEvent", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
	RegAdminCmd("ce_events_test", cTestEvnt, ADMFLAG_ROOT, "Tests a CEcon event.");

	// Hook all needed entities when plugin late loads.
	LateHooking();

	// We check every 5 seconds if coordinator is running, if it is not
	// but it should, restart it.
	CreateTimer(5.0, Timer_CoordinatorWatchDog);
}

//-------------------------------------------------------------------
// Purpose: Fired when map changes.
//-------------------------------------------------------------------
public void OnMapStart()
{
	// Process economy precached schema.
	Schema_ProcessCachedItemSchema();
	// But we also try to see if there are any updates.
	Schema_CheckForUpdates(false);
}

//-------------------------------------------------------------------
// Purpose: Native initialization.
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Purpose: Fired when SteamTools is late loaded.
//-------------------------------------------------------------------
public int Steam_FullyLoaded()
{
	Steam_OnReady();
}

//-------------------------------------------------------------------
// Purpose: This is fired on every plugin lifecycle
// when SteamTools is available.
//-------------------------------------------------------------------
public void Steam_OnReady()
{
	ReloadEconomyCredentials();
	Schema_CheckForUpdates(false);
}

//-------------------------------------------------------------------
// Purpose: Used to refresh economy credentials from economy.cfg
// file.
//-------------------------------------------------------------------
public void ReloadEconomyCredentials()
{
	// Before we reload everything, let's mark this flag as false
	// in case if something fails and this function is returned.
	m_bCredentialsLoaded = false;

	// Format the economy.cfg location.
	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/economy.cfg");

	// Create a new KeyValues to store the credentials in.
	KeyValues kv = new KeyValues("Economy");
	if (!kv.ImportFromFile(sLoc))return;

	// Load everything from the file.
	kv.GetString("Key", m_sEconomyAccessKey, sizeof(m_sEconomyAccessKey));
	kv.GetString("Branch", m_sBranchName, sizeof(m_sBranchName));
	kv.GetString("Password", m_sBranchPassword, sizeof(m_sBranchPassword));
	kv.GetString("Domain", m_sBaseEconomyURL, sizeof(m_sBaseEconomyURL), DEFAULT_ECONOMY_BASE_URL);
	kv.GetString("Authorization", m_sAuthorizationKey, sizeof(m_sAuthorizationKey));

	// We don't need this handle anymore, remove it.
	delete kv;

	// Everything was succesful, mark it as true again.
	m_bCredentialsLoaded = true;

	// Start coordinator request, if it's not started already.
	SafeStartCoordinatorPolling();
}

//-------------------------------------------------------------------
// Purpose: Returns true if client is a real player that
// is ready for backend interactions.
//-------------------------------------------------------------------
public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

//-------------------------------------------------------------------
// Purpose: Returns true if client exists.
//-------------------------------------------------------------------
public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

//-------------------------------------------------------------------
// Purpose: Finds client by their SteamID.
//-------------------------------------------------------------------
// Purpose: Used to refresh economy credentials from economy.cfg
// file.
//-------------------------------------------------------------------
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Purpose: Wrapper for IsValidEntity that also checks if entity
// index is between 0 and MAX_ENTITY_LIMIT.
//-------------------------------------------------------------------
public bool IsEntityValid(int entity)
{
	return entity > 0 && entity < MAX_ENTITY_LIMIT && IsValidEntity(entity);
}

//-------------------------------------------------------------------
// Native: CEcon_GetBaseBackendURL
//-------------------------------------------------------------------
public any Native_GetBaseBackendURL(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sBaseEconomyURL, size);
}

//-------------------------------------------------------------------
// Native: CEcon_GetAccessKey
//-------------------------------------------------------------------
public any Native_GetAccessKey(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sEconomyAccessKey, size);
}

//-------------------------------------------------------------------
// Native: CEcon_GetAuthorizationKey
//-------------------------------------------------------------------
public any Native_GetAuthorizationKey(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sAuthorizationKey, size);
}

//============= Copyright Amper Software, All rights reserved. ============//
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
*/
//===============================//

//-------------------------------------------------------------------
// Purpose: Timer that reenables coordinator queue if it's offline,
// but it should be online.
//-------------------------------------------------------------------
public Action Timer_CoordinatorWatchDog(Handle timer, any data)
{
	SafeStartCoordinatorPolling();
}

//-------------------------------------------------------------------
// Purpose: Used to start coordinator request, but it only does
// that if there are no active requests right now.
//-------------------------------------------------------------------
public void SafeStartCoordinatorPolling()
{
	if (m_bCoordinatorActive)return;

	StartCoordinatorLongPolling();
}

//-------------------------------------------------------------------
// Purpose: Used to force start a coordinator request.
//-------------------------------------------------------------------
public void StartCoordinatorLongPolling()
{
	// Before we make anoher request, let's make sure that nothing tells us
	// not to. Before we are sure that nothing stops us from making a request, let's
	// set this flag to false.

	m_bCoordinatorActive = false;

	// If there are any conditons that tell us not to make a request, we return this function.
	// m_bCoordinatorActive will be false at this point, and this will mean that plugin stopped
	// making requests in queue. And it will not do any until this function is called again
	// and all these conditions are met.

	// If we decided not to have coordiantor feature, don't do it.
	if (!ce_coordinator_enabled.BoolValue)return;

	// If we failed to read economy credentials (Backend Domain, API Key, etc..).
	if (!m_bCredentialsLoaded)return;

	// All conditions were met, mark this flag as true and start the request.
	m_bCoordinatorActive = true;

	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/coordiantor", m_sBaseEconomyURL);

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

//-------------------------------------------------------------------
// Purpose: Callback to the coordinator request.
//-------------------------------------------------------------------
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
			// body is in invalid format (i.e. not KeyValues).
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

		// We increase this variable if an error happened.
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

		// If there was no error, and last time backend was marked as unreachable,
		// that means we've connected to it again.
		// Send a message in chat to notify everyone that economy is up again.
		if(m_bIsBackendUnreachable)
		{
			m_bIsBackendUnreachable = false;
			CoordinatorOnBackendReachable();
		}

		// If everything was succesfully, make another request in the next frame.
		RequestFrame(RF_DelayerCoordinatorRequest);
	}
}

//-------------------------------------------------------------------
// Purpose: Fired when backend is marked as unreachable.
//-------------------------------------------------------------------
public void CoordinatorOnBackendUnreachable()
{
	// TODO: Make a forward.
	PrintToChatAll("\x01Economy Backend is \x03down.");
	PrintToServer("[WARNING] Economy Backend is down.");
}

//-------------------------------------------------------------------
// Purpose: Fired when backend is back available.
//-------------------------------------------------------------------
public void CoordinatorOnBackendReachable()
{
	// TODO: Make a forward.
	PrintToChatAll("\x01Economy Backend is \x03up.");
	PrintToServer("[WARNING] Economy Backend is up.");
}

//-------------------------------------------------------------------
// Purpose: Used to start a coordiantor request with a
// delay using RequestFrame.
//-------------------------------------------------------------------
public void RF_DelayerCoordinatorRequest(any data)
{
	StartCoordinatorLongPolling();
}

//-------------------------------------------------------------------
// Used to start a coordiantor request with a delay using CreateTimer.
//-------------------------------------------------------------------
public Action Timer_DelayedCoordinatorRequest(Handle timer, any data)
{
	StartCoordinatorLongPolling();
}

//-------------------------------------------------------------------
// Processes response of the coordinator request. Returns true if
// there are any errors.
//-------------------------------------------------------------------
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

//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Manages Economy Schema auto-update.
//
//=========================================================================//

//-------------------------------------------------------------------
// Purpose: Command callback to check for schema updates.
//-------------------------------------------------------------------
public Action cSchemaUpdate(int args)
{
	Schema_CheckForUpdates(true);
	return Plugin_Handled;
}

//-------------------------------------------------------------------
// Purpose: Processes cached item schema and notifies plugins about
// it being updated.
//-------------------------------------------------------------------
public void Schema_ProcessCachedItemSchema()
{
	KeyValues kv = new KeyValues("Schema");
	if (!kv.ImportFromFile(m_sItemSchemaFilePath))return;

	// Print build version in chat.
	kv.GetString("Version/build", m_sSchemaBuildVersion, sizeof(m_sSchemaBuildVersion), "");
	LogMessage("Current Item Schema version: %s", m_sSchemaBuildVersion);

	// Make a forward call to notify other plugins about the change.
	Call_StartForward(g_CEcon_OnSchemaUpdated);
	Call_PushCell(kv);
	Call_Finish();

	// Clearing old schema if exists.
	delete m_Schema;
	m_Schema = kv;
}

//-------------------------------------------------------------------
// Purpose: Used to make a backend request to check for updates.
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Purpose: Check for updates request callback.
//-------------------------------------------------------------------
public void Schema_CheckForUpdates_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
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

//-------------------------------------------------------------------
// Purpose: Used to make a backend request to force update the
// schema.
//-------------------------------------------------------------------
public void Schema_ForceUpdate()
{
	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/IEconomyItems/GScheme", m_sBaseEconomyURL);

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 10);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");

	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", m_sAuthorizationKey);

	char sAccessHeader[256];
	Format(sAccessHeader, sizeof(sAccessHeader), "Provider %s", m_sEconomyAccessKey);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sAccessHeader);

	Steam_SendHTTPRequest(httpRequest, Schema_ForceUpdate_Callback);
}

//-------------------------------------------------------------------
// Purpose: Force update request callback.
//-------------------------------------------------------------------
public void Schema_ForceUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
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

//-------------------------------------------------------------------
// Native: CEcon_GetEconomySchema
//-------------------------------------------------------------------
public any Native_GetEconomySchema(Handle plugin, int numParams)
{
	return m_Schema;
}

//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Used for tracking different events happening in game, and connect
// them with economy features, like quests or achievements.
//
//=========================================================================//

//-------------------------------------------------------------------
// Purpose: Fired when a new entity is created.
//-------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook objects (Buildings) with OnTakeDamage SDKHook
	if(StrContains(classname, "obj_") != -1)
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	// Hook players with OnTakeDamage SDKHook
	if(StrEqual(classname, "player"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	// Hook players with OnTouch SDKHook
	if(StrContains(classname, "item_healthkit") != -1)
	{
		SDKHook(entity, SDKHook_Touch, OnTouch);
	}
}

//-------------------------------------------------------------------
// Purpose: Fired when something touches an entity.
//-------------------------------------------------------------------
public Action OnTouch(int entity, int toucher)
{
	// This is only hooked with healthkits right now.
	// Health hit is considered to be a sandvich if it has an owner.

	if (!IsClientValid(toucher))return Plugin_Continue;

	// See if we have an owner.
	int hOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	// Don't do anything if our owner touched us.
	if (hOwner == toucher)return Plugin_Continue;

	// If someone else touched a sandvich, mark heavy's secondary weapon as last used.
	if(IsClientValid(hOwner))
	{
		// Only do this if owner class is heavy.
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

//-------------------------------------------------------------------
// Purpose: Fired when something deals damage to an entity.
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Purpose: Command callback to test an event on a client.
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Purpose: Late hook specific entities.
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Native: CEcon_GetLastUsedWeapon
//-------------------------------------------------------------------
public any Native_LastUsedWeapon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return m_iLastWeapon[client];
}

//-------------------------------------------------------------------
// Native: CEcon_SendEventToClientFromGameEvent
//-------------------------------------------------------------------
public any Native_SendEventToClientFromGameEvent(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	char event[128];
	GetNativeString(2, event, sizeof(event));

	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);

	CEcon_SendEventToClient(client, event, add, unique_id);
}

//-------------------------------------------------------------------
// Native: CEcon_SendEventToClientUnique
//-------------------------------------------------------------------
public any Native_SendEventToClientUnique(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	char event[128];
	GetNativeString(2, event, sizeof(event));

	int add = GetNativeCell(3);
	int unique_id = GetRandomInt(0, MAX_EVENT_UNIQUE_INDEX_INT);

	CEcon_SendEventToClient(client, event, add, unique_id);
}

//-------------------------------------------------------------------
// Native: CEcon_SendEventToAll
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Native: CEcon_SendEventToClient
//-------------------------------------------------------------------
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

//-------------------------------------------------------------------
// Purpose: Returns maximum of two.
//-------------------------------------------------------------------
public int MAX(int iNum1, int iNum2)
{
	if (iNum1 > iNum2)return iNum1;
	if (iNum2 > iNum1)return iNum2;
	return iNum1;
}

//-------------------------------------------------------------------
// Purpose: Returns minimum of two.
//-------------------------------------------------------------------
public int MIN(int iNum1, int iNum2)
{
	if (iNum1 < iNum2)return iNum1;
	if (iNum2 < iNum1)return iNum2;
	return iNum1;
}
