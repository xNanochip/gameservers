//============= Copyright Amper Software , All rights reserved. ============//
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
	PrintToChatAll("StartCoordinatorLongPolling()");
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

	Steam_SendHTTPRequest(httpRequest, Coordinator_Request_Callback);
}

public void Coordinator_Request_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	PrintToChatAll("Coordinator_Request_Callback()");
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
