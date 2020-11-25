#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ce_core>
#include <ce_coordinator>
#include <ce_util>
#include <system2>
#include <socket>

#define MAX_RESPONSE_LENGTH 8192
#define FRAGMENT_MAX_LENGTH 32768

public Plugin myinfo =
{
	name = "Creators.TF Economy - Server System",
	author = "Creators.TF Team, Peace-Maker",
	description = "Creators.TF Economy Server System",
	version = "1.00",
	url = "https://creators.tf"
};

bool m_bCoreEnabled;
bool m_bCoordinatorConnected;

ConVar ce_economy_coordinator_domain;
ConVar ce_economy_coordinator_port;
ConVar ce_economy_backend_domain;
ConVar ce_economy_backend_secure;
ConVar ce_economy_backend_auth;
ConVar ce_server_index;

Handle m_hSocket;
Handle m_hReconnectTimer;
ArrayList m_hFragmentedPayload;

public void OnPluginStart()
{
	ce_economy_coordinator_domain = CreateConVar("ce_economy_coordinator_domain", "sc.creators.tf", "Creators Economy coordinator domain.", FCVAR_PROTECTED);
	ce_economy_coordinator_port = CreateConVar("ce_economy_coordinator_port", "80", "Creators Economy coordinator port.", FCVAR_PROTECTED);

	ce_economy_backend_domain = CreateConVar("ce_economy_backend_domain", "creators.tf", "Creators Economy backend domain.", FCVAR_PROTECTED);
	ce_economy_backend_auth = CreateConVar("ce_economy_backend_auth", "", "", FCVAR_PROTECTED);
	ce_economy_backend_secure = CreateConVar("ce_economy_backend_secure", "1", "", FCVAR_PROTECTED);
	ce_server_index = CreateConVar("ce_server_index", "-1", "", FCVAR_PROTECTED);

	m_hFragmentedPayload = new ArrayList();

	StartCoordinatorReconnectTimer();
}

public void OnClientPostAdminCheck(int client)
{
	NotifyPlayerJoin(client);
}

public void OnClientDisconnect(int client)
{
	NotifyPlayerLeave(client);
}

public void NotifyMetaInfoChange()
{
	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	
	char sHostName[64];
	FindConVar("hostname").GetString(sHostName, sizeof(sHostName));
	
	int iPlayers = MaxClients;
	if (FindConVar("tv_enable").BoolValue)iPlayers--;

	char sMessage[125];
	Format(sMessage, sizeof(sMessage), "info:map=%s,host=%s,maxp=%d", sMap, sHostName, iPlayers);

	CESC_SendMessage(sMessage);
}

public void NotifyIndexChange()
{
	char sMessage[125];
	Format(sMessage, sizeof(sMessage), "index_update:index=%d", CESC_GetServerID());

	CESC_SendMessage(sMessage);
}

public void NotifyPlayerJoin(int client)
{
	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	if (StrEqual(sSteamID, "STEAM_ID_STOP_IGNORING_RETVALS"))return;

	char sMessage[125];
	Format(sMessage, sizeof(sMessage), "player_join:steamid=%s,id=%d,userid=%d", sSteamID, client, GetClientUserId(client));

	CESC_SendMessage(sMessage);
}

public void NotifyPlayerLeave(int client)
{
	char sMessage[125];
	Format(sMessage, sizeof(sMessage), "player_left:id=%d", client);

	CESC_SendMessage(sMessage);
}

public void OnSocketError(Handle socket, const int errorType, const int errorNum, any hFile)
{
}

public void OnSocketConnected(Handle socket, any arg)
{
	char sURL[64];
	ce_economy_coordinator_domain.GetString(sURL, sizeof(sURL));
	Format(sURL, sizeof(sURL), "%s:%d", sURL, ce_economy_coordinator_port.IntValue);

	// Access Header
	char sHeaderAuth[PLATFORM_MAX_PATH];
	CESC_GetServerAccessKey(sHeaderAuth, sizeof(sHeaderAuth));
	Format(sHeaderAuth, sizeof(sHeaderAuth), "server %s %d", sHeaderAuth, CESC_GetServerID());

	char sKey[16];
	GenerateWebSocketKey(sKey, sizeof(sKey));

	char sRequest[512];
	Format(sRequest, sizeof(sRequest), "GET / HTTP/1.0\r\n");
	Format(sRequest, sizeof(sRequest), "%sHost: %s\r\n", sRequest, sURL);
	Format(sRequest, sizeof(sRequest), "%sOrigin: SRCDS\r\n", sRequest);
	Format(sRequest, sizeof(sRequest), "%sConnection: Upgrade\r\n", sRequest);
	Format(sRequest, sizeof(sRequest), "%sUpgrade: websocket\r\n", sRequest);
	Format(sRequest, sizeof(sRequest), "%sSec-WebSocket-Key: %sCahJ+Ow==\r\n", sRequest, sKey);
	Format(sRequest, sizeof(sRequest), "%sSec-WebSocket-Version: 13\r\n", sRequest);
	Format(sRequest, sizeof(sRequest), "%sAccess: %s\r\n\r\n", sRequest, sHeaderAuth);

	SocketSend(socket, sRequest);
}

public void GenerateWebSocketKey(char[] buffer, int size)
{
	char[] string = new char[size + 1];

	char TOKEN_CHARACTERS[128];
	Format(TOKEN_CHARACTERS, sizeof(TOKEN_CHARACTERS), "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");

	for (int i = 0; i < size; i++)
	{
	    int iRandom = GetRandomInt(0, strlen(TOKEN_CHARACTERS) - 1);
	    char sChar = TOKEN_CHARACTERS[iRandom];

	    Format(string, size, "%s%c", string, sChar);
	}
	strcopy(buffer, size, string);
}

public void NotifyHeaderInfo()
{
	NotifyIndexChange();
	NotifyMetaInfoChange();
	NotifyAllConnectedPlayers();
}

public void OnSocketReceive(Handle socket, char[] data, const int dataSize, any hFile)
{
	if (StrContains(data, "HTTP/1.1 101 Switching Protocols", true) == 0)
	{
		char sKey[29];
		Format(sKey, 29, "%s", data[StrContains(data, "Sec-WebSocket-Accept: ", true) + 22]);
		LogMessage("Socket connected.");
		LogMessage("Accept Key: %s", sKey);
		
		m_bCoordinatorConnected = true;
		NotifyHeaderInfo();
	} else {

		int vFrame[WebsocketFrame];
		char[] sPayLoad = new char[dataSize - 1];
		ParseFrame(vFrame, data, dataSize, sPayLoad);
		ReplaceString(sPayLoad, dataSize, "&quot;", "\"");
		if (sPayLoad[0] == '/')return;
		
		ServerCommand(sPayLoad);
	}
}

public void OnMapStart()
{
	if(m_bCoordinatorConnected)
	{
		NotifyHeaderInfo();
	}
}

public void NotifyAllConnectedPlayers()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientValid(i))continue;

		NotifyPlayerJoin(i);
	}
}

public void StartCoordinatorReconnectTimer()
{
	if(m_hReconnectTimer == null)
	{
		ConnectCoordinator();
		m_hReconnectTimer = CreateTimer(2.0, Timer_SocketReconnect, _, TIMER_REPEAT);
	}
}

public void ConnectCoordinator()
{
	char sURL[64];
	ce_economy_coordinator_domain.GetString(sURL, sizeof(sURL));
	int iPort = ce_economy_coordinator_port.IntValue;

	m_hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketConnect(m_hSocket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, sURL, iPort);
}

public Action Timer_SocketReconnect(Handle timer, any data)
{
	if(m_bCoordinatorConnected)
	{
		KillTimer(timer);
		m_hReconnectTimer = null;
		return Plugin_Stop;
	}

	ConnectCoordinator();

	return Plugin_Continue;
}

public void OnSocketDisconnected(Handle socket, any arg)
{
	if(m_bCoordinatorConnected)
	{
		LogMessage("Socket disconnect");
	}
	m_bCoordinatorConnected = false;
	StartCoordinatorReconnectTimer();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_coordinator");
	CreateNative("CESC_SendMessage", Native_SendMessage);
	CreateNative("CESC_SendAPIRequest", Native_SendAPIRequest);
	CreateNative("CESC_GetServerID", Native_GetServerID);
	CreateNative("CESC_GetServerAccessKey", Native_GetServerAccessKey);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ce_core"))
	{
		m_bCoreEnabled = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ce_core"))
	{
		m_bCoreEnabled = false;
	}
}

public any Native_SendAPIRequest(Handle plugin, int numParams)
{
	char sBaseUrl[128], sOutput[256], sData[4096];
	// Getting URL that we have to send req to.
	GetNativeString(1, sBaseUrl, sizeof(sBaseUrl));

	// Request type of the request.
	RequestTypes nType = GetNativeCell(2);

	// Request callback.
	Function callback = GetNativeFunction(3);

	// Send a request as a client.
	int client = GetNativeCell(4);

	// Getting data that we need to provide.
	GetNativeString(5, sData, sizeof(sData));

	// Local file path we should save output to.
	GetNativeString(6, sOutput, sizeof(sOutput));

	// Custom value.
	any value = GetNativeCell(7);

	// Make sure we have a valid server id set.
	int iServerID = CESC_GetServerID();
	if(iServerID == -1) return;

	// Preparing url of the request.
	char sURL[128];

	// If we don't have :// in the URL that means this is
	// not the full URL. We add base domain name
	// in the beginning.
	if(StrContains(sBaseUrl, "://") == -1)
	{
		if(sBaseUrl[0] != '/')
		{
			// We need to make sure we have a slash before URL, so we
			// can form a proper link in the end.
			Format(sBaseUrl, sizeof(sBaseUrl), "/%s", sBaseUrl);
		}
		ce_economy_backend_domain.GetString(sURL, sizeof(sURL));

		if(ce_economy_backend_secure.BoolValue)
		{
			Format(sURL, sizeof(sURL), "https://%s%s", sURL, sBaseUrl);
		} else {
			Format(sURL, sizeof(sURL), "http://%s%s", sURL, sBaseUrl);
		}
	}

	System2HTTPRequest httpMessage = new System2HTTPRequest(httpRequestCallback, sURL);

	// Access Header
	char sHeaderAuth[PLATFORM_MAX_PATH];
	CESC_GetServerAccessKey(sHeaderAuth, sizeof(sHeaderAuth));
	Format(sHeaderAuth, sizeof(sHeaderAuth), "server %s %d", sHeaderAuth, iServerID);

	if(IsClientReady(client))
	{
		char sSteamID[64];
		GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
		Format(sHeaderAuth, sizeof(sHeaderAuth), "%s %s", sHeaderAuth, sSteamID);
	}

	httpMessage.SetHeader("Access", sHeaderAuth);

	// Authorization Header
	ce_economy_backend_auth.GetString(sHeaderAuth, sizeof(sHeaderAuth));
	httpMessage.SetHeader("Authorization", sHeaderAuth);

	// Accept Header
	httpMessage.SetHeader("Content-Type", "text/keyvalues");
	httpMessage.SetHeader("Accept", "text/keyvalues");

	Format(sHeaderAuth, sizeof(sHeaderAuth), "Creators.TF Server/1.0 (Server #%d)", iServerID);
	httpMessage.SetHeader("User-Agent", sHeaderAuth);

	// Setting data of the request.
	if(!StrEqual(sData, ""))
	{
		httpMessage.SetData(sData);
	}

	// Setting output file of the request.
	if(!StrEqual(sOutput, ""))
	{
		httpMessage.SetOutputFile(sOutput);
	}

	DataPack hPack = new DataPack();
	hPack.WriteFunction(callback);
	hPack.WriteCell(plugin);
	hPack.WriteCell(value);
	hPack.Reset();

	// Saving callback.
	httpMessage.Any = hPack;

	// Making proper request type.
	if (nType == RequestType_GET)
	{
		httpMessage.GET();
	}else if (nType == RequestType_POST)
	{
		httpMessage.POST();
	}

	delete httpMessage;
}

public void httpRequestCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!UTIL_IsValidHandle(response))return;

	char content[MAX_RESPONSE_LENGTH];
	if(response.ContentLength <= MAX_RESPONSE_LENGTH)
	{
		response.GetContent(content, response.ContentLength + 1);
	}

	DataPack hPack = request.Any;
	if (!UTIL_IsValidHandle(hPack))return;
	Function fnCallback = hPack.ReadFunction();
	Handle plugin = hPack.ReadCell();

	any value = hPack.ReadCell();
	delete hPack;

	Call_StartFunction(plugin, fnCallback);
	Call_PushString(content);
	Call_PushCell(response.ContentLength);
	Call_PushCell(response.StatusCode);
	Call_PushCell(value);
	Call_Finish();
}

/**
*	Native: CESC_SendMessage
*	Purpose: 	Sends message to coordinator.
*/
public any Native_SendMessage(Handle plugin, int numParams)
{
	if (!m_bCoreEnabled)return;

	// Name of the message.
	char sContent[125];
	GetNativeString(1, sContent, sizeof(sContent));

	WebSocketSend(m_hSocket, sContent, sizeof(sContent));
}

/**
*	Native: CESC_GetServerID
*	Purpose: Returns this server id.
*/
public any Native_GetServerID(Handle plugin, int numParams)
{
	return ce_server_index.IntValue;
}

public any Native_GetServerAccessKey(Handle plugin, int numParams)
{
	int length = GetNativeCell(2);
	char[] buffer = new char[length + 1];

	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/creators.cfg");
	KeyValues kv = new KeyValues("Creators");
	if (kv.ImportFromFile(sLoc))
	{
		kv.GetString("key", buffer, length, "");
	}
	delete kv;

	SetNativeString(1, buffer, length);
}

public bool WebSocketSend(Handle socket, char[] payload, int length)
{
	int vFrame[WebsocketFrame];
	vFrame[OPCODE] = FrameType_Text;

	vFrame[PAYLOAD_LEN] = length;

	vFrame[FIN] = 1;
	vFrame[CLOSE_REASON] = -1;
	vFrame[MASK] = 1;

	if(SendWebsocketFrame(socket, payload, vFrame))
	{
		return true;
	}
	return false;
}

public bool SendWebsocketFrame(Handle socket, char[] payload, vFrame[WebsocketFrame])
{
	int length = vFrame[PAYLOAD_LEN];

	// Force RSV bits to 0
	vFrame[RSV1] = 0;
	vFrame[RSV2] = 0;
	vFrame[RSV3] = 0;

	char[] sFrame = new char[length + 18];
	if(CreateFrame(payload, sFrame, vFrame))
	{

		if(length > 65535)
		{
			length += 10;
		} else if(length > 125)
		{
			length += 4;
		} else
		{
			length += 2;
		}

		if(vFrame[CLOSE_REASON] != -1)
		{
			length += 2;
		}

		SocketSend(socket, sFrame);
		return true;
	}

	return false;
}

public void ParseFrame(int vFrame[WebsocketFrame], const char[] receiveDataLong, const int dataSize, char[] sPayLoad)
{
	int[] receiveData = new int[dataSize];
	for (int i = 0; i < dataSize; i++)
	{
		receiveData[i] = receiveDataLong[i] & 0xff;
	}

	char sByte[9];
	Format(sByte, sizeof(sByte), "%08b", receiveData[0]);

	vFrame[FIN] = sByte[0] == '1' ? 1:0;
	vFrame[RSV1] = sByte[1] == '1' ? 1:0;
	vFrame[RSV2] = sByte[2] == '1' ? 1:0;
	vFrame[RSV3] = sByte[3] == '1' ? 1:0;
	vFrame[OPCODE] = view_as<WebsocketFrameType>(bindec(sByte[4]));

	Format(sByte, sizeof(sByte), "%08b", receiveData[1]);

	vFrame[MASK] = sByte[0] == '1' ? 1:0;
	vFrame[PAYLOAD_LEN] = bindec(sByte[1]);

	int iOffset = 2;

	vFrame[MASKINGKEY][0] = '\0';
	if(vFrame[PAYLOAD_LEN] > 126)
	{
		char sLoongLength[49];
		for (int i = 2; i < 8; i++)
		{
			Format(sLoongLength, sizeof(sLoongLength), "%s%08b", sLoongLength, receiveData[i]);
		}

		vFrame[PAYLOAD_LEN] = bindec(sLoongLength);
		iOffset += 6;
	} else if(vFrame[PAYLOAD_LEN] > 125)
	{
		char sLongLength[17];
		for (int i = 2; i < 4; i++)
		{
			Format(sLongLength, sizeof(sLongLength), "%s%08b", sLongLength, receiveData[i]);
		}

		vFrame[PAYLOAD_LEN] = bindec(sLongLength);
		iOffset += 2;
	}

	if(vFrame[MASK])
	{
		for (int i = iOffset, j = 0; j < 4; i++, j++)
		{
			vFrame[MASKINGKEY][j] = receiveData[i];
		}

		vFrame[MASKINGKEY][4] = '\0';
		iOffset += 4;

		int[] iPayLoad = new int[vFrame[PAYLOAD_LEN]];
		for (int i = iOffset, j = 0; j < vFrame[PAYLOAD_LEN]; i++, j++)
		{
			iPayLoad[j] = receiveData[i];
		}

		for (int i = 0; i < vFrame[PAYLOAD_LEN]; i++)
		{
			Format(sPayLoad, vFrame[PAYLOAD_LEN] + 1, "%s%c", sPayLoad, iPayLoad[i] ^ vFrame[MASKINGKEY][i % 4]);
		}
	}

	strcopy(sPayLoad, vFrame[PAYLOAD_LEN] + 1, receiveDataLong[iOffset]);

	if(vFrame[OPCODE] == FrameType_Close)
	{
		char sCloseReason[65];
		for (int i = 0; i < 2; i++)
		{
			Format(sCloseReason, sizeof(sCloseReason), "%s%08b", sCloseReason, sPayLoad[i] & 0xff);
		}

		vFrame[CLOSE_REASON] = bindec(sCloseReason);

		strcopy(sPayLoad, dataSize - 1, sPayLoad[2]);
		vFrame[PAYLOAD_LEN] -= 2;
	} else {
		vFrame[CLOSE_REASON] = -1;
	}
}

public bool PreprocessFrame(int iIndex, int vFrame[WebsocketFrame], char[] sPayLoad)
{
	// This is a fragmented frame
	if(vFrame[FIN] == 0)
	{
		// This is a control frame. Those cannot be fragmented!
		if(vFrame[OPCODE] >= FrameType_Close)
		{
			LogError("Received fragmented control frame. %d", vFrame[OPCODE]);
			return true;
		}

		int iPayloadLength = m_hFragmentedPayload.Get(0);

		// This is the first frame of a serie of fragmented ones.
		if(iPayloadLength == 0)
		{
			if(vFrame[OPCODE] == FrameType_Continuation)
			{
				LogError("Received first fragmented frame with opcode 0. The first fragment MUST have a different opcode set.");
				return true;
			}

			// Remember which type of message this fragmented one is.
			SetArrayCell(m_hFragmentedPayload, 1, vFrame[OPCODE]);
		} else
		{
			if(vFrame[OPCODE] != FrameType_Continuation)
			{
				LogError("Received second or later frame of fragmented message with opcode %d. opcode must be 0.", vFrame[OPCODE]);
				return true;
			}
		}

		// Keep track of the overall payload length of the fragmented message.
		// This is used to create the buffer of the right size when passing it to the listening plugin.
		iPayloadLength += vFrame[PAYLOAD_LEN];
		SetArrayCell(m_hFragmentedPayload, 0, iPayloadLength);

		// This doesn't fit inside one array cell? Split it up.
		if(vFrame[PAYLOAD_LEN] > FRAGMENT_MAX_LENGTH)
		{
			for (int i = 0; i < vFrame[PAYLOAD_LEN]; i += FRAGMENT_MAX_LENGTH)
			{
				PushArrayString(m_hFragmentedPayload, sPayLoad[i]);
			}
		}
		else
		{
			PushArrayString(m_hFragmentedPayload, sPayLoad);
		}

		return true;
	}

	// The FIN bit is set if we reach here.
	switch(vFrame[OPCODE])
	{
		case FrameType_Continuation:
		{
			int iPayloadLength = m_hFragmentedPayload.Get(0);
			WebsocketFrameType iOpcode = m_hFragmentedPayload.Get(1);

			// We don't know what type of data that is.
			if(iOpcode == FrameType_Continuation)
			{
				LogError("Received last frame of a series of fragmented ones without any fragments with payload first.");
				return true;
			}

			// Add the payload of the last frame to the buffer too.

			// Keep track of the overall payload length of the fragmented message.
			// This is used to create the buffer of the right size when passing it to the listening plugin.
			iPayloadLength += vFrame[PAYLOAD_LEN];
			m_hFragmentedPayload.Set(0, iPayloadLength);

			// This doesn't fit inside one array cell? Split it up.
			if(vFrame[PAYLOAD_LEN] > FRAGMENT_MAX_LENGTH)
			{
				for (int i = 0; i < vFrame[PAYLOAD_LEN]; i += FRAGMENT_MAX_LENGTH)
				{
					PushArrayString(m_hFragmentedPayload, sPayLoad[i]);
				}
			}
			else
			{
				PushArrayString(m_hFragmentedPayload, sPayLoad);
			}

			return false;
		}
		case FrameType_Text:
		{
			return false;
		}
		case FrameType_Binary:
		{
			return false;
		}
		case FrameType_Close:
		{
			// TODO
		}
		case FrameType_Ping:
		{
			vFrame[OPCODE] = FrameType_Pong;
			return true;
		}
		case FrameType_Pong:
		{
			return true;
		}
	}

	LogError("Received invalid opcode = %d", vFrame[OPCODE]);
	return true;
}

public bool CreateFrame(char[] sPayLoad, char[] sFrame, vFrame[WebsocketFrame])
{
	int length = vFrame[PAYLOAD_LEN];

	switch(vFrame[OPCODE])
	{
		case FrameType_Text:
		{
			sFrame[0] = (1<<0)|(1<<7); //  - Text-Frame (1000 0001):
		}
		case FrameType_Close:
		{
			sFrame[0] = (1<<3)|(1<<7); //  -  Close-Frame (1000 1000):
			length += 2; // Remember the 2byte close reason
		}
		case FrameType_Ping:
		{
			sFrame[0] = (1<<0)|(1<<3)|(1<<7); //  -  Ping-Frame (1000 1001):
		}
		case FrameType_Pong:
		{
			sFrame[0] = (1<<1)|(1<<3)|(1<<7); //  -  Pong-Frame (1000 1010):
		}
		default:
		{
			LogError("Trying to send frame with unknown opcode = %d", view_as<int>(vFrame[OPCODE]));
			return false;
		}
	}

	int iOffset;

	if (length > 65535)
	{
		sFrame[1] = 128;
		char sLengthBin[65], sByte[9];
		Format(sLengthBin, 65, "%064b", length);
		for (int i = 0, j = 2; j <= 10; i++)
		{
			if (i && !(i % 8))
			{
				sFrame[j] = bindec(sByte);
				Format(sByte, 9, "");
				j++;
			}
			Format(sByte, 9, "%s%s", sByte, sLengthBin[i]);
		}

		// the most significant bit MUST be 0
		if (sFrame[2] > 127)
		{
			LogError("Can't send frame. Too much data.");
			return false;
		}
		iOffset = 9;
	} else if (length > 125)
	{
		LogMessage("2");
		sFrame[1] = 254;
		if (length < 256)
		{
			sFrame[2] = 0;
			sFrame[3] = length;
		} else {
			char sLengthBin[17], sByte[9];
			Format(sLengthBin, 17, "%016b", length);
			for (int i = 0, j = 2; i <= 16; i++)
			{
				if (i && !(i % 8))
				{
					sFrame[j] = bindec(sByte);
					Format(sByte, 9, "");
					j++;
				}
				Format(sByte, 9, "%s%s", sByte, sLengthBin[i]);
			}
		}
		iOffset = 4;
	} else {
		sFrame[1] = length;
		iOffset = 2;
	}

	sFrame[1] |= (1 << 7);

	int iMaskingKey[4];
	iMaskingKey[0] = 255; //GetRandomInt(0, 255);
	iMaskingKey[1] = 254; //GetRandomInt(0, 255);
	iMaskingKey[2] = 253; //GetRandomInt(0, 255);
	iMaskingKey[3] = 252; //GetRandomInt(0, 255);

	sFrame[iOffset] = iMaskingKey[0];
	sFrame[iOffset+1] = iMaskingKey[1];
	sFrame[iOffset+2] = iMaskingKey[2];
	sFrame[iOffset+3] = iMaskingKey[3];
	iOffset += 4;
	length += 4;

	// We got a closing reason. Add it right in front of the payload.
	if(vFrame[OPCODE] == FrameType_Close && vFrame[CLOSE_REASON] != -1)
	{
		char sCloseReasonBin[17], sByte[9];
		Format(sCloseReasonBin, 17, "%016b", vFrame[CLOSE_REASON]);
		for (int i = 0, j = iOffset; i <= 16; i++)
		{
			if (i && !(i % 8))
			{
				sFrame[j] = bindec(sByte);
				Format(sByte, 9, "");
				j++;
			}
			Format(sByte, 9, "%s%s", sByte, sCloseReasonBin[i]);
		}
		iOffset += 2;
	}

	char[] masked = new char[vFrame[PAYLOAD_LEN] + 1];
	for (int i = 0; i < vFrame[PAYLOAD_LEN]; i++)
	{
		Format(masked, vFrame[PAYLOAD_LEN] + 1, "%s%c", masked, (sPayLoad[i] & 0xff) ^ iMaskingKey[i % 4]);
	}
	Format(sFrame, length + iOffset, "%s%s", sFrame, masked);

	return true;
}

public int bindec(const char[] sBinary)
{
	int ret, len = strlen(sBinary);
	for (int i = 0; i < len; i++)
	{
		ret = ret << 1;
		if (sBinary[i] == '1')
		{
			ret |= 1;
		}
	}
	return ret;
}
