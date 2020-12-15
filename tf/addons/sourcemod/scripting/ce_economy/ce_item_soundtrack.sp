#pragma semicolon 1
#pragma newdecls required

#define MAX_SOUND_NAME 512
#define MAX_EVENT_NAME 32

#include <sdktools>
#include <ce_events>
#include <ce_manager_items>
#include <ce_item_soundtrack>
#include <ce_util>
#include <ce_core>

ArrayList m_hKits;

int m_iMusicKit[MAXPLAYERS + 1] =  { -1, ... };

int m_iNextEvent[MAXPLAYERS + 1] =  { -1, ... };
int m_iCurrentEvent[MAXPLAYERS + 1] =  { -1, ... };
int m_iCurrentSample[MAXPLAYERS + 1];

bool m_bIsPlaying[MAXPLAYERS + 1];
bool m_bShouldStop[MAXPLAYERS + 1];
bool m_bForceNextEvent[MAXPLAYERS + 1];
	
Sample_t m_hClientPreSample[MAXPLAYERS + 1];
Sample_t m_hClientPostSample[MAXPLAYERS + 1];

Sample_t m_hPreSamples[OST_MAX_KITS][OST_MAX_EVENTS];
Sample_t m_hPostSamples[OST_MAX_KITS][OST_MAX_EVENTS];

Handle m_hTimer[MAXPLAYERS + 1];

ArrayList m_hSampleQueue[MAXPLAYERS + 1];

int m_nPayloadStage = 0;
int m_iRoundTime = 0;

public Plugin myinfo =
{
	name = "Creators.TF Economy - Music Kits Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Music Kits Handler",
	version = "1.00",
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	HookEvent("teamplay_broadcast_audio", evBroadcast, EventHookMode_Pre);
	HookEvent("teamplay_round_start", teamplay_round_start, EventHookMode_Pre);
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_point_captured", teamplay_point_captured);
	CreateTimer(0.5, Timer_EscordProgressUpdate, _, TIMER_REPEAT);
	RegServerCmd("ce_quest_setkit", cSetKit, "");
	
	HookEntityOutput("team_round_timer", "On30SecRemain", OnEntityOutput);
	HookEntityOutput("team_round_timer", "On1MinRemain", OnEntityOutput);
}

public bool TF2_IsWaitingForPlayers()
{
	return GameRules_GetProp("m_bInWaitingForPlayers") == 1;
}

public bool TF2_IsSetup()
{
	return GameRules_GetProp("m_bInSetup") == 1;
}

public void OnEntityOutput(const char[] output, int caller, int activator, float delay)
{
	if (TF2_IsWaitingForPlayers())return;
	
	// Round almost over.
	if (strcmp(output, "On30SecRemain") == 0)
	{
		if (TF2_IsSetup())return;
		
		m_iRoundTime = 29;
		CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	
	// Setup
	if (strcmp(output, "On1MinRemain") == 0)
	{
		if (!TF2_IsSetup())return;
		
		m_iRoundTime = 59;
		CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Countdown(Handle timer, any data)
{
	if (m_iRoundTime < 1) return Plugin_Stop;
	
	if(TF2_IsSetup() && m_iRoundTime == 45)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEEvents_SendEventToClient(i, "OST_ROUND_SETUP", 1, GetRandomInt(1, 10000));
			}
		}
	}
		
	if(!TF2_IsSetup() && m_iRoundTime == 20)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEEvents_SendEventToClient(i, "OST_ROUND_ALMOST_END", 1, GetRandomInt(1, 10000));
			}
		}
	}
	
	m_iRoundTime--;
	return Plugin_Continue;
}

public Action cSetKit(int args)
{
	char sArg1[MAX_NAME_LENGTH], sArg2[11], sArg3[256];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	GetCmdArg(3, sArg3, sizeof(sArg3));

	int iTarget = FindTargetBySteamID(sArg1);
	if (!IsClientValid(iTarget))return Plugin_Handled;

	int iKit = StringToInt(sArg2);

	MusicKit_SetKit(iTarget, iKit, sArg3);
	return Plugin_Handled;
}

public void CE_OnSchemaUpdated(KeyValues hSchema)
{
	LogMessage("Schema updated");
	ParseEconomySchema(hSchema);
}

public void OnAllPluginsLoaded()
{
	KeyValues hSchema = CE_GetEconomyConfig();
	if(hSchema == INVALID_HANDLE) return;
	ParseEconomySchema(hSchema);
	delete hSchema;
}

public void ParseEconomySchema(KeyValues hConf)
{
	if(hConf.JumpToKey("Items", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			// ===================
			// || Checking Item ||
			// ===================
			
			m_hKits = new ArrayList(sizeof(Soundtrack_t));
			do {
				char sType[32];
				hConf.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "soundtrack"))continue;
				
				char sIndex[11];
				hConf.GetSectionName(sIndex, sizeof(sIndex));
				int iDefIndex = StringToInt(sIndex);
				
				int iKitIndex = m_hKits.Length;
				
				Soundtrack_t hKit;
				hKit.m_iDefIndex = iDefIndex;
				if(hConf.JumpToKey("logic", false))
				{
					hConf.GetString("broadcast/win", hKit.m_sWinMusic, sizeof(hKit.m_sWinMusic));
					hConf.GetString("broadcast/loss", hKit.m_sLossMusic, sizeof(hKit.m_sLossMusic));
					
					if(hConf.JumpToKey("events", false))
					{
						if(hConf.GotoFirstSubKey())
						{
							// ====================
							// || Checking Event ||
							// ====================
							
							hKit.m_hEvents = new ArrayList(sizeof(Event_t));
							do {
								int iEventIndex = hKit.m_hEvents.Length;
								
								Event_t hEvent;
								hEvent.m_iPriority = hConf.GetNum("priority", 0);
								
								hEvent.m_bFireOnce = hConf.GetNum("fire_once") >= 1;
								hEvent.m_bForceStart = hConf.GetNum("force_start") >= 1;
								hEvent.m_bSkipPost = hConf.GetNum("skip_post") >= 1;
								hConf.GetString("start_hook", hEvent.m_sStartHook, sizeof(hEvent.m_sStartHook));
								hConf.GetString("stop_hook", hEvent.m_sStopHook, sizeof(hEvent.m_sStopHook));
								hConf.GetString("id", hEvent.m_sID, sizeof(hEvent.m_sID));
								
								if(hConf.JumpToKey("pre_sample", false))
								{
									KeyValuesToSample(hConf, m_hPreSamples[iKitIndex][iEventIndex]);
									hConf.GoBack();
								}
								
								if(hConf.JumpToKey("post_sample", false))
								{
									KeyValuesToSample(hConf, m_hPostSamples[iKitIndex][iEventIndex]);
									hConf.GoBack();
								}
								
								if(hConf.JumpToKey("samples", false))
								{
									if(hConf.GotoFirstSubKey())
									{
										// =====================
										// || Checking Sample ||
										// =====================
										
										hEvent.m_hSamples = new ArrayList(sizeof(Sample_t));
										do {
											
											Sample_t hSample;
											KeyValuesToSample(hConf, hSample);
											
											hEvent.m_hSamples.PushArray(hSample);
											
										} while (hConf.GotoNextKey());
										hConf.GoBack();
									}
									hConf.GoBack();
								}
								hKit.m_hEvents.PushArray(hEvent);
							} while (hConf.GotoNextKey());
							hConf.GoBack();
						}
						hConf.GoBack();
					}
					hConf.GoBack();
				}
				m_hKits.PushArray(hKit);
			} while (hConf.GotoNextKey());
		}
	}
	hConf.Rewind();
}

public void KeyValuesToSample(KeyValues hConf, Sample_t hSample)
{							
	hSample.m_flDuration = hConf.GetFloat("duration");
	hSample.m_flVolume = hConf.GetFloat("volume");
	
	hConf.GetString("move_to_event", hSample.m_sMoveToEvent, sizeof(hSample.m_sMoveToEvent));
	hConf.GetString("sound", hSample.m_sSound, sizeof(hSample.m_sSound));
	
	hSample.m_nIterations = hConf.GetNum("iterations", 1);
	hSample.m_nMoveToSample = hConf.GetNum("move_to_sample", -1);
	
	hSample.m_bPreserveSample = hConf.GetNum("preserve_sample", 0) == 1;
}

public Action evBroadcast(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int iTeam = hEvent.GetInt("team");
	char sOldSound[MAX_SOUND_NAME];
	hEvent.GetString("sound", sOldSound, sizeof(sOldSound));

	for (int i = 1; i < MaxClients; i++)
	{
		if (!IsClientValid(i))continue;
		if (GetClientTeam(i) != iTeam)continue;

		char sSound[MAX_SOUND_NAME];
		
		if(m_iMusicKit[i] > -1)
		{
			int iMusicKit = m_iMusicKit[i];
			Soundtrack_t hKit;
			m_hKits.GetArray(iMusicKit, hKit);
			
			if(StrContains(sOldSound, "YourTeamWon") != -1)
			{
				strcopy(sSound, sizeof(sSound), hKit.m_sWinMusic);
			}

			if(StrContains(sOldSound, "YourTeamLost") != -1)
			{
				strcopy(sSound, sizeof(sSound), hKit.m_sLossMusic);
			}
		}
		
		if(StrEqual(sSound, ""))
		{
			hEvent.FireToClient(i);
			
		} else {
			Event hNewEvent = CreateEvent("teamplay_broadcast_audio");
			if (hNewEvent == null)continue;

			hNewEvent.SetInt("team", iTeam);
			hNewEvent.SetString("sound", sSound);
			hNewEvent.FireToClient(i);
		}
	}

	return Plugin_Handled;
}

public Action teamplay_round_start(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	StopEventsForAll();
	
	if(!TF2_IsSetup() && !TF2_IsWaitingForPlayers())
	{
		RequestFrame(PlayRoundStartMusic, hEvent);
	}
}

public void PlayRoundStartMusic(any hEvent)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientReady(i))
		{
			CEEvents_SendEventToClient(i, "OST_ROUND_START", 1, view_as<int>(hEvent));
		}
	}
}

public Action teamplay_round_win(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int iWinReason = GetEventInt(hEvent, "winreason");
	if(m_nPayloadStage == 2 && iWinReason == 1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEEvents_SendEventToClient(i, "OST_PAYLOAD_CLIMAX", 1, view_as<int>(hEvent));
			}
		}
	}
}

public void RF_StopEventsForAll(any forced)
{
	StopEventsForAll();
}

public void StopEventsForAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientValid(i))continue;
		if(m_bIsPlaying[i])
		{
			// Otherwise, queue a stop.
			
			// Play null sound to stop current sample.
			ClientCommand(i, "play misc/null.wav");
			
			// Stop everything if we have Force tag set.
			if(m_hTimer[i] != null)
			{
				KillTimer(m_hTimer[i]);
				m_hTimer[i] = null;
			}
			BufferFlush(i);
	
			m_bForceNextEvent[i] = false;
			m_bIsPlaying[i] = false;
			m_bShouldStop[i] = false;
		}
		m_iNextEvent[i] = -1;
	}
}

public void CEEvents_OnSendEvent(int client, const char[] event, int add, int unique)
{
	Soundtrack_t hKit;
	bool bFound = GetClientKit(client, hKit);
	if (!bFound)return;
	
	for (int i = 0; i < hKit.m_hEvents.Length; i++)
	{
		int iEvent = i;
		
		Event_t hEvent;
		hKit.m_hEvents.GetArray(i, hEvent);
		
		if(m_iCurrentEvent[client] != iEvent)
		{
			// Start Sample playing.
			if(StrContains(hEvent.m_sStartHook, event) != -1)
			{
				if(m_iCurrentEvent[client] > -1)
				{
					Event_t hOldEvent;
					if(GetKitEventByIndex(m_iMusicKit[client], m_iCurrentEvent[client], hOldEvent))
					{
						if(hOldEvent.m_iPriority > hEvent.m_iPriority)
						{
							continue;
						}
					}
				}
				
				if (hEvent.m_bFireOnce && m_iCurrentEvent[client] == iEvent)continue;
	
				m_iNextEvent[client] = iEvent;
				m_bForceNextEvent[client] = hEvent.m_bForceStart;
				m_bShouldStop[client] = false;
			}
		} else {
			// Start Sample playing.
			if(StrContains(hEvent.m_sStopHook, event) != -1)
			{
				if(m_bIsPlaying[client] && !m_bShouldStop[client])
				{
					m_bShouldStop[client] = true;
				}
			}
		}
	}
	
	PlayNextSample(client);
}

public void PlayNextSample(int client)
{
	if(m_bForceNextEvent[client])
	{
		// Stop everything if we have Force tag set.
		if(m_hTimer[client] != null)
		{
			KillTimer(m_hTimer[client]);
			m_hTimer[client] = null;
		}
		BufferFlush(client);

		m_bForceNextEvent[client] = false;
		m_bIsPlaying[client] = false;
		m_bShouldStop[client] = false;

	} else {
		// Otherwise, return if we're playing something.
		if (m_bIsPlaying[client])
		{
			return;
		}
	}

	Sample_t hSample;
	GetNextSample(client, hSample);

	if(!StrEqual(hSample.m_sSound, "") || hSample.m_bPreserveSample)
	{
		char sSound[MAX_SOUND_NAME];
		Format(sSound, sizeof(sSound), "#%s", hSample.m_sSound);
		m_bIsPlaying[client] = true;

		if(!StrEqual(hSample.m_sSound, ""))
		{
			ClientCommand(client, "play misc/null.wav");
			ClientCommand(client, "play %s", sSound);
		}

		float flInterp = GetClientSoundInterp(client);
		float flDelay = hSample.m_flDuration - flInterp;

		m_hTimer[client] = CreateTimer(flDelay, Timer_PlayNextSample, client);
	}
}

public Action Timer_PlayNextSample(Handle timer, any client)
{
	// Play next sample from here only if this timer is the active one.
	if(m_hTimer[client] == timer)
	{
		m_hTimer[client] = INVALID_HANDLE;
		m_bIsPlaying[client] = false;
		PlayNextSample(client);
	}

}

public float GetClientSoundInterp(int client)
{
	return float(TF2_GetNativePing(client)) / 2000.0;
}

public int TF2_GetNativePing(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, client);
}

public void GetNextSample(int client, Sample_t hSample)
{
	// Make sure client exists.
	if (!IsClientValid(client))return;
	
	// First, we check if we need to switch to next sample.
	// We only do that if post and pre are not set and queue is empty.
	if(m_bShouldStop[client])
	{
		if(StrEqual(m_hClientPostSample[client].m_sSound, ""))
		{
			BufferFlush(client);
			m_bShouldStop[client] = false;
			//PrintToConsole(client, "m_bShouldStop, true");
		} else {
			hSample = m_hClientPostSample[client];
			strcopy(m_hClientPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			//PrintToConsole(client, "m_bShouldStop, false");
			return;
		}
	}

	if(m_iNextEvent[client] > -1)
	{
		bool bSkipPost = false;
		Soundtrack_t hKit;
		if(GetClientKit(client, hKit))
		{
			Event_t hEvent;
			hKit.m_hEvents.GetArray(m_iNextEvent[client], hEvent);
			bSkipPost = hEvent.m_bSkipPost;
		}
		
		if(StrEqual(m_hClientPostSample[client].m_sSound, "") || bSkipPost)
		{
			//PrintToConsole(client, "m_iNextEvent, true");
			BufferLoadEvent(client, m_iNextEvent[client]);
			m_iNextEvent[client] = -1;
		} else {
			//PrintToConsole(client, "m_iNextEvent, false");
			hSample = m_hClientPostSample[client];
			strcopy(m_hClientPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			return;
		}
	}

	// Make sure queue handle exists.
	if (m_hSampleQueue[client] == null)return;

	if(!StrEqual(m_hClientPreSample[client].m_sSound, ""))
	{
		//PrintToConsole(client, "m_hClientPreSample");
		hSample = m_hClientPreSample[client];
		strcopy(m_hClientPreSample[client].m_sSound, MAX_SOUND_NAME, "");
		return;
	}

	if(m_hSampleQueue[client].Length > m_iCurrentSample[client])
	{
		Sample_t sample;
		m_hSampleQueue[client].GetArray(m_iCurrentSample[client], sample);

		// If we run this sample and amount of iterations has exceeded the max amount,
		// we reset the value and run it again.
		if(sample.m_nCurrentIteration >= sample.m_nIterations)
		{
			sample.m_nCurrentIteration = 0;
		}

		//PrintToConsole(client, "m_hSampleQueue, %d, (%d/%d)", m_iCurrentSample[client], sample.m_nCurrentIteration + 1, sample.m_nIterations);

		// Increase current iteration every time we run through it.
		if(sample.m_nCurrentIteration < sample.m_nIterations)
		{
			sample.m_nCurrentIteration++;
		}

		// Update all changed data in the queue.
		m_hSampleQueue[client].SetArray(m_iCurrentSample[client], sample);

		// Move to next sample if we reached our limit.
		if(sample.m_nCurrentIteration == sample.m_nIterations)
		{
			int iMoveToEvent = GetEventIndexByID(m_iMusicKit[client], sample.m_sMoveToEvent);
			if(iMoveToEvent > -1)
			{
				m_iNextEvent[client] = iMoveToEvent;
			} else if(sample.m_nMoveToSample > -1 && sample.m_nMoveToSample < m_hSampleQueue[client].Length)
			{
				m_iCurrentSample[client] = sample.m_nMoveToSample;
			} else m_iCurrentSample[client]++;
		}

		hSample = sample;
		return;
	}

	if(!StrEqual(m_hClientPostSample[client].m_sSound, ""))
	{
		//PrintToConsole(client, "m_hClientPostSample");
		hSample = m_hClientPostSample[client];
		strcopy(m_hClientPostSample[client].m_sSound, MAX_SOUND_NAME, "");
		return;
	}

	// If we are at this point - nothing is left to play, so we clean up everything.
	BufferFlush(client);
}

public void BufferLoadEvent(int client, int event)
{
	if (!IsClientValid(client))return;
	
	Soundtrack_t hKit;
	if (!GetClientKit(client, hKit))return;

	// Set up an array list if not exists.
	if (m_hSampleQueue[client] == null)
	{
		m_hSampleQueue[client] = new ArrayList(sizeof(Sample_t));
	}

	// Clear the arraylist from old samples if exist.
	if (m_hSampleQueue[client].Length > 0)
	{
		m_hSampleQueue[client].Clear();
	}
	
	Event_t hEvent;
	hKit.m_hEvents.GetArray(event, hEvent);

	m_hSampleQueue[client] = hEvent.m_hSamples.Clone();
	m_hClientPreSample[client] = m_hPreSamples[m_iMusicKit[client]][event];
	m_hClientPostSample[client] = m_hPostSamples[m_iMusicKit[client]][event];

	m_iCurrentEvent[client] = event;
	m_iCurrentSample[client] = 0;
}

public void BufferFlush(int client)
{
	if(UTIL_IsValidHandle(m_hSampleQueue[client]))
	{
		m_hSampleQueue[client].Clear();
	}
	strcopy(m_hClientPostSample[client].m_sSound, MAX_SOUND_NAME, "");
	strcopy(m_hClientPreSample[client].m_sSound, MAX_SOUND_NAME, "");

	m_iCurrentEvent[client] = -1;
}

public void OnClientConnected(int client)
{
	ClearData(client);
}

public void OnClientDisconnect(int client)
{
	ClearData(client);
}

public void ClearData(int client)
{
	delete m_hSampleQueue[client];
	
	m_iMusicKit[client] = -1;
	m_iNextEvent[client] = -1;
	m_iCurrentEvent[client] = -1;
	m_iCurrentSample[client] = -1;

	m_bIsPlaying[client] = false;
	m_bShouldStop[client] = false;
	m_bForceNextEvent[client] = false;
	
	if(m_hTimer[client] != null)
	{
		KillTimer(m_hTimer[client]);
		m_hTimer[client] = null;
	}
}

public void MusicKit_SetKit(int client, int defid, char[] name)
{
	int iKitID = GetKitIndexByDefID(defid);
	
	if(iKitID != m_iMusicKit[client])
	{
		if(iKitID == -1)
		{
			PrintToChat(client, "\x01* Game soundtrack removed.", name);	
		} else {
			PrintToChat(client, "\x01* Game soundtrack set to: %s", name);	
		}
	}
	
	m_iMusicKit[client] = iKitID;
}

public int GetEventIndexByID(int kit, const char[] sId)
{
	Soundtrack_t hKit;
	bool bFound = GetKitByIndex(kit, hKit);
	if (!bFound)return -1;
	
	for (int i = 0; i < hKit.m_hEvents.Length; i++)
	{
		Event_t hEvent;
		hKit.m_hEvents.GetArray(i, hEvent);
		if (StrEqual(hEvent.m_sID, ""))continue;
		if (StrEqual(hEvent.m_sID, sId))
		{
			return i;
		}
	}
	return -1;
}

public bool GetKitByIndex(int index, Soundtrack_t kit)
{
	if (!UTIL_IsValidHandle(m_hKits))return false;
	if (index >= m_hKits.Length)return false;
	
	m_hKits.GetArray(index, kit);
	
	return true;
}

public bool GetKitEventByIndex(int kit, int index, Event_t event)
{
	Soundtrack_t hKit;
	if (!GetKitByIndex(kit, hKit))return false;
	
	hKit.m_hEvents.GetArray(index, event);
	
	return true;
}

public int GetKitIndexByDefID(int defid)
{
	if (!UTIL_IsValidHandle(m_hKits))return -1;
	
	for (int i = 0; i < m_hKits.Length; i++)
	{
		Soundtrack_t hKit;
		m_hKits.GetArray(i, hKit);
		
		if (hKit.m_iDefIndex == defid)return i;
	}
	return -1;
}

public bool GetClientKit(int client, Soundtrack_t hKit)
{
	if (m_iMusicKit[client] == -1)return false;
	int iMusicKit = m_iMusicKit[client];
	
	if (!GetKitByIndex(iMusicKit, hKit))return false;
	return true;
}

public Action Timer_EscordProgressUpdate(Handle timer, any data)
{
	static float flOld = 0.0;
	float flNew = Payload_GetProgress();
	
	const float flStage1 = 0.85;
	const float flStage2 = 0.93;
	const float flFinish = 0.99;
	
	if(flOld != flNew)
	{
		// It has changed.
		if(flNew >= flFinish && flOld < flFinish)
		{
			//PrintToChatAll("Climax");
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientReady(i))
				{
					//CEEvents_SendEventToClient(i, "OST_PAYLOAD_CLIMAX", 1, GetRandomInt(1, 10000));
				}
			}
		
		}else if(flNew >= flStage2 && flOld < flStage2)
		{
			//PrintToChatAll("Stage 2 just started");
			// Stage 2 just started.
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientReady(i))
				{
					//CEEvents_SendEventToClient(i, "OST_PAYLOAD_S2_START", 1, GetRandomInt(1, 10000));
				}
			}
			m_nPayloadStage = 2;
			
		} else if (flNew < flStage2 && flOld >= flStage2)
		{
			//PrintToChatAll("Stage 2 just cancelled");
			// Stage 2 just cancelled.
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientReady(i))
				{
					//CEEvents_SendEventToClient(i, "OST_PAYLOAD_S2_CANCEL", 1, GetRandomInt(1, 10000));
				}
			}
			m_nPayloadStage = 0;
		} else if(flNew >= flStage1 && flOld < flStage1)
		{
			//PrintToChatAll("Stage 1 just started");
			// Stage 1 just started.
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientReady(i))
				{
					//CEEvents_SendEventToClient(i, "OST_PAYLOAD_S1_START", 1, GetRandomInt(1, 10000));
				}
			}
			m_nPayloadStage = 1;
		} else if(flNew < flStage1 && flOld >= flStage1)
		{
			//PrintToChatAll("Stage 1 just cancelled");
			// Stage 1 just cancelled.
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientReady(i))
				{
					//CEEvents_SendEventToClient(i, "OST_PAYLOAD_S1_CANCEL", 1, GetRandomInt(1, 10000));
				}
			}
			m_nPayloadStage = 0;
		}
		
		flOld = flNew;
	}
}

public float Payload_GetProgress()
{
	int iEnt = -1;
	float flProgress = 0.0;
	while((iEnt = FindEntityByClassname(iEnt, "team_train_watcher")) != -1 )
	{
		if (IsValidEntity(iEnt))
		{
			// If cart is of appropriate team.
			float flProgress2 = GetEntPropFloat(iEnt, Prop_Send, "m_flTotalProgress");
			if (flProgress < flProgress2)flProgress = flProgress2;
		}
	}
	return flProgress;
}

public Action teamplay_point_captured(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		
		CEEvents_SendEventToClient(i, "OST_POINT_CAPTURE", 1, view_as<int>(hEvent));
	}
}