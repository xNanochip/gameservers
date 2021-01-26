#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#pragma newdecls optional
#include <steamtools>
#pragma newdecls required

#define RECONNECT_INTERVAL 5.0

public Plugin myinfo =
{
	name = "Creators.TF Economy - Server System",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Server System",
	version = "1.00",
	url = "https://creators.tf"
};

char sProcessedJobs[256];

public void OnPluginStart()
{
	StartCoordinatorLongPolling();
}

public void StartCoordinatorLongPolling()
{
	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, "http://local.creators.tf/api/IServers/GServerCoordinator");
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "processed_jobs", sProcessedJobs);
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 40);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");

	Steam_SendHTTPRequest(httpRequest, Coordiantor_Request_Callback);

}

public void Coordiantor_Request_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	bool bError = true;

	// If response was not succesful.
	if (success)
	{
		// If response code was not OK.
		if (code != HTTPStatusCode_OK)
		{
			bError = ProcessContent(request);
		}
	}

	if(bError)
	{
	} else {
	}
}

public bool ProcessContent(HTTPRequestHandle request)
{
	// Getting content length.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];

	// Getting content.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	// If response is a timeout.
	if (StrEqual(content, "TIMEOUT"))return false;

	// If content does not start with a " (not KeyValues)
	if (content[0] != '"')return false;

	KeyValues kv = new KeyValues("Response");
	kv.ImportFromString(content);

	strcopy(sProcessedJobs, sizeof(sProcessedJobs), "");

	if(kv.JumpToKey("jobs", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				char sIndex[64];
				kv.GetString("index", sIndex, sizeof(sIndex));
				Format(sProcessedJobs, sizeof(sProcessedJobs), "%s%s,", sProcessedJobs, sIndex);

				char sCommand[256];
				kv.GetString("command", sCommand, sizeof(sCommand));
				PrintToServer(sCommand);

			} while (kv.GotoNextKey());

			kv.GoBack();
		}
		kv.GoBack();
	}
	delete kv;
	return true;
}
