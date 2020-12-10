enum RequestTypes
{
	RequestType_GET,
	RequestType_POST
}

enum WebsocketFrameType
{
	FrameType_Continuation = 0,
	FrameType_Text = 1,
	FrameType_Binary = 2,
	FrameType_Close = 8,
	FrameType_Ping = 9,
	FrameType_Pong = 10
}

enum struct WebsocketFrame
{
	int FIN;
	int RSV1;
	int RSV2;
	int RSV3;
	WebsocketFrameType OPCODE;
	int MASK;
	int PAYLOAD_LEN;
	char MASKINGKEY[5];
	int CLOSE_REASON;
}

#define StatusCode_Success 200

typeset APIRequestCallback
{
	function void(const char[] content, int size, int status, any value);
}

/**
* Returns the server index.
*
* @return					Index.
*/
native int CESC_GetServerID();

/**
* Changes the style of a cosmetic.
*
* @param hHandle			Contents of the message.
* @param sName				Name of the message.
*
* @return					Nothing.
*/
native void CESC_SendMessage(char[] sName);

/**
* Sends an API request.
*
* @param url				Url of the gateway.
* @param type				Type of the request.
* @param callback			Callback with data
* @param client				Client to perform request as.
* @param data				Data to provide this request with.
* @param output				Output of the file.
* @param value				Any value.
*
* @return					Nothing.
*/
native void CESC_SendAPIRequest(const char[] url, RequestTypes type, APIRequestCallback callback, int client = -1, const char[] data = "", const char[] output = "", any value = -1);

/**
* Returns server access key from creators.cfg
*
* @param buffer				Buffer to store.
* @param length				Length of buffer.
*
* @return					Nothing.
*/
native void CESC_GetServerAccessKey(char[] buffer, int length);
