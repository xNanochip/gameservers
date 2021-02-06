//======================================//
// Coordinator
//======================================//


// Creates a full absolute url to the backend.
native void 				CEconHTTP_CreateAbsoluteBackendURL(const char[] url, char[] buffer, int size);
native HTTPRequestHandle 	CEconHTTP_CreateBaseHTTPRequest(const char[] url, HTTPMethod method);
