#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

// HACK: Disable newdecls for steamtools ext.
#pragma newdecls optional
#include <steamtools>
#pragma newdecls required 

#define DEBUG

public Plugin myinfo =
{
	name = "Creators.TF Economy - Server System",
	author = "Creators.TF Team, Peace-Maker",
	description = "Creators.TF Economy Server System",
	version = "1.00",
	url = "https://creators.tf"
};

char sProcessedJobs[256];

public void OnPluginStart()
{
	StartCoordinatorRequest();
}

public void StartCoordinatorRequest()
{
	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, "http://local.creators.tf/api/IServers/GServerCoordinator");
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "processed_jobs", sProcessedJobs);
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 40);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	
	// PrintToServer("Sending...");
	Steam_SendHTTPRequest(httpRequest, CoordinatorCallback);
	
}

public void CoordinatorCallback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	if(success)
	{
		if(code == HTTPStatusCode_OK)
		{
			
			int size = Steam_GetHTTPResponseBodySize(request);
			char[] content = new char[size + 1];
			
			Steam_GetHTTPResponseBodyData(request, content, size);
			Steam_ReleaseHTTPRequest(request);
			
			if(StrEqual(content, "TIMEOUT"))
			{
				// PrintToServer("Response: TIMEOUT");
				StartCoordinatorRequest();
				return;
			}
			
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
			
			// PrintToServer("%s", sProcessedJobs);
		}
	}
	
	StartCoordinatorRequest();
}