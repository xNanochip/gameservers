//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Manages Economy Schema auto-update.
//
//=========================================================================//

ConVar ce_schema_autoupdate;
KeyValues m_Schema;

char m_sSchemaBuildVersion[64];
bool m_bSchemaLoadedSuccesfully = false;
char m_sItemSchemaFilePath[96];

Handle g_CEcon_OnSchemaUpdated;

public void Schema_OnPluginStart()
{
	BuildPath(Path_SM, m_sItemSchemaFilePath, sizeof(m_sItemSchemaFilePath), "configs/item_schema.cfg");

	// ConVars
	ce_schema_autoupdate = CreateConVar("ce_schema_autoupdate", "1", "Should auto-update item schema on every map change.");

	// Commands
	RegServerCmd("ce_schema_update", cSchemaUpdate);
}

public void Schema_AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_CEcon_OnSchemaUpdated = CreateGlobalForward("CEcon_OnSchemaUpdated", ET_Ignore, Param_Cell);
	
	CreateNative("CEcon_GetEconomySchema", Native_GetEconomySchema);
}

public void Schema_OnMapStart()
{
	Schema_ProcessCachedItemSchema();
	Schema_CheckForUpdates(false);
}

public Action cSchemaUpdate(int args)
{
	Schema_CheckForUpdates(true);
	return Plugin_Handled;
}

public void Schema_ProcessCachedItemSchema()
{
	m_bSchemaLoadedSuccesfully = false;

	KeyValues kv = new KeyValues("Schema");
	if (!kv.ImportFromFile(m_sItemSchemaFilePath))return;

	kv.GetString("Version/build", m_sSchemaBuildVersion, sizeof(m_sSchemaBuildVersion), "");
	LogMessage("Current Item Schema version: %s", m_sSchemaBuildVersion);

	Items_PrecacheItems(kv);

	Call_StartForward(g_CEcon_OnSchemaUpdated);
	Call_PushCell(kv);
	Call_Finish();

	// Clearing old schema if exists.
	delete m_Schema;
	m_Schema = kv;

	m_bSchemaLoadedSuccesfully = true;
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