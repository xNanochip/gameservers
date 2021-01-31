//======================================//
// Coordinator
//======================================//


// Creates a full absolute url to the backend.
native void CEcon_CreateAbsoluteBackendURL(const char[] url, char[] buffer, int size);
// Returns access key in the buffer.
native void CEcon_GetBackendAccessKey(const char[] buffer);

//
native HTTPRequestHandle CEcon_CreateBaseHTTPRequest(const char[] url, HTTPMethod method);
