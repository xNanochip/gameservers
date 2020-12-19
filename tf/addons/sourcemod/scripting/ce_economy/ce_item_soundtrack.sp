#pragma semicolon 1
#pragma newdecls required

#define MAX_SOUND_NAME 512
#define MAX_EVENT_NAME 32

#define PAYLOAD_STAGE_1_START 0.85
#define PAYLOAD_STAGE_2_START 0.93

#include <sdktools>
#include <ce_events>
#include <ce_manager_items>
#include <ce_item_soundtrack>
#include <ce_util>
#include <ce_core>

Soundtrack_t m_hKitDefs[OST_MAX_KITS];
int m_iKitDefsLength = 0;

Event_t m_hEventDefs[OST_MAX_EVENTS];
int m_iEventDefsLength = 0;

Sample_t m_hSampleDefs[OST_MAX_SAMPLES];
int m_iSampleDefsLength = 0;

int m_iMusicKit[MAXPLAYERS + 1] =  { -1, ... };

int m_iNextEvent[MAXPLAYERS + 1];

int m_iCurrentEvent[MAXPLAYERS + 1];

char m_sActiveSound[MAXPLAYERS + 1][MAX_SOUND_NAME];

bool m_bIsPlaying[MAXPLAYERS + 1];
bool m_bShouldStop[MAXPLAYERS + 1];
bool m_bForceNextEvent[MAXPLAYERS + 1];

Handle m_hTimer[MAXPLAYERS + 1];

int m_iQueueLength[MAXPLAYERS + 1];
int m_iQueuePointer[MAXPLAYERS + 1];
Sample_t m_hQueue[MAXPLAYERS + 1][OST_MAX_EVENTS];
Sample_t m_hPreSample[MAXPLAYERS + 1];
Sample_t m_hPostSample[MAXPLAYERS + 1];

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
	HookEvent("teamplay_broadcast_audio", teamplay_broadcast_audio, EventHookMode_Pre);
	HookEvent("teamplay_round_start", teamplay_round_start, EventHookMode_Pre);
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_point_captured", teamplay_point_captured);
	
	CreateTimer(0.5, Timer_EscordProgressUpdate, _, TIMER_REPEAT);
	RegServerCmd("ce_soundtrack_setkit", cSetKit, "");
	RegServerCmd("ce_soundtrack_dump", cDump, "");

	HookEntityOutput("team_round_timer", "On30SecRemain", OnEntityOutput);
	HookEntityOutput("team_round_timer", "On1MinRemain", OnEntityOutput);
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
			do {
				char sType[32];
				hConf.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "soundtrack"))continue;
				
				PrecacheSoundtrackKeyValues(hConf);
			} while (hConf.GotoNextKey());
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	m_iMusicKit[client] = -1;
	BufferFlush(client);
}

public Action cDump(int args)
{
	LogMessage("Dumping precached data");
	for (int i = 0; i < m_iKitDefsLength; i++)
	{
		Soundtrack_t hKit;
		GetKitByIndex(i, hKit);
		
		LogMessage("Soundtrack_t");
		LogMessage("{");
		LogMessage("  m_iDefIndex = %d", hKit.m_iDefIndex);
		LogMessage("  m_sWinMusic = \"%s\"", hKit.m_sWinMusic);
		LogMessage("  m_sLossMusic = \"%s\"", hKit.m_sLossMusic);
		LogMessage("  m_iEventsCount = %d", hKit.m_iEventsCount);
		LogMessage("  m_iEvents =");
		LogMessage("  [");
		
		for (int j = 0; j < hKit.m_iEventsCount; j++)
		{
			int iEventIndex = hKit.m_iEvents[j];
			
			Event_t hEvent;
			GetEventByIndex(iEventIndex, hEvent);
			LogMessage("    %d => Event_t (%d)", j, iEventIndex);
			LogMessage("    {");
			LogMessage("      m_sStartHook = \"%s\"", hEvent.m_sStartHook);
			LogMessage("      m_sStopHook = \"%s\"", hEvent.m_sStopHook);
			LogMessage("      m_sID = \"%s\"", hEvent.m_sID);
			
			LogMessage("      m_bForceStart = %s", hEvent.m_bForceStart ? "true" : "false");
			LogMessage("      m_bFireOnce = %s", hEvent.m_bFireOnce ? "true" : "false");
			LogMessage("      m_bSkipPost = %s", hEvent.m_bSkipPost ? "true" : "false");
			
			LogMessage("      m_iPriority = %d", hEvent.m_iPriority);
			LogMessage("      m_iSamplesCount = %d", hEvent.m_iSamplesCount);
			LogMessage("      m_iSamples =");
			LogMessage("      [");
			
			for (int k = 0; k < hEvent.m_iSamplesCount; k++)
			{
				int iSampleIndex = hEvent.m_iSamples[k];
				
				Sample_t hSample;
				GetSampleByIndex(iSampleIndex, hSample);
				LogMessage("        %d => Sample_t (%d)", k, iSampleIndex);
				LogMessage("        {");
				LogMessage("          m_sSound = \"%s\"", hSample.m_sSound);
				LogMessage("          m_nIterations = %d", hSample.m_nIterations);
				LogMessage("          m_nCurrentIteration = %d", hSample.m_nCurrentIteration);
				LogMessage("          m_nMoveToSample = %d", hSample.m_nMoveToSample);
				LogMessage("          m_sMoveToEvent = \"%d\"", hSample.m_sMoveToEvent);
				LogMessage("          m_flDuration = %f", hSample.m_flDuration);
				LogMessage("          m_flVolume = %f", hSample.m_flVolume);
				LogMessage("          m_bPreserveSample = %s", hSample.m_bPreserveSample ? "true" : "false");
				LogMessage("        }");
			}
			
			LogMessage("      ]");
			LogMessage("    }");
		}
		
		LogMessage("  ]");
		LogMessage("}");
		
	}
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
	m_iCurrentEvent[client] = -1;
	m_iNextEvent[client] = -1;
	BufferFlush(client);
}

public int PrecacheSoundtrackKeyValues(KeyValues hConf)
{
	// Getting Definition Index of the kit.
	char sIndex[11];
	hConf.GetSectionName(sIndex, sizeof(sIndex));
	int iDefIndex = StringToInt(sIndex);
	
	char sName[128];
	hConf.GetString("name", sName, sizeof(sName));

	int iIndex = m_iKitDefsLength;
	Soundtrack_t hKit;
	hKit.m_iDefIndex = iDefIndex;

	if(hConf.JumpToKey("logic", false))
	{
		// Setting Win and Lose music.
		hConf.GetString("broadcast/win", hKit.m_sWinMusic, sizeof(hKit.m_sWinMusic));
		hConf.GetString("broadcast/loss", hKit.m_sLossMusic, sizeof(hKit.m_sLossMusic));

		if(hConf.JumpToKey("events", false))
		{
			if(hConf.GotoFirstSubKey())
			{
				do {
					int iEvent = PrecacheEventKeyValues(hConf);
					// Add to array.

					hKit.m_iEvents[hKit.m_iEventsCount] = iEvent;
					hKit.m_iEventsCount++;

				} while (hConf.GotoNextKey());
				hConf.GoBack();
			}
			hConf.GoBack();
		}
		hConf.GoBack();
	}

	m_hKitDefs[iIndex] = hKit;
	m_iKitDefsLength++;

	return iIndex;
}

public int PrecacheEventKeyValues(KeyValues hConf)
{
	int iIndex = m_iEventDefsLength;
	Event_t hEvent;

	hEvent.m_iPriority = hConf.GetNum("priority", 0);

	hEvent.m_bFireOnce = hConf.GetNum("fire_once") >= 1;
	hEvent.m_bForceStart = hConf.GetNum("force_start") >= 1;
	hEvent.m_bSkipPost = hConf.GetNum("skip_post") >= 1;

	hConf.GetString("start_hook", hEvent.m_sStartHook, sizeof(hEvent.m_sStartHook));
	hConf.GetString("stop_hook", hEvent.m_sStopHook, sizeof(hEvent.m_sStopHook));
	hConf.GetString("id", hEvent.m_sID, sizeof(hEvent.m_sID));
	
	hEvent.m_iPreSample = -1;
	hEvent.m_iPostSample = -1;

	if(hConf.JumpToKey("pre_sample", false))
	{
		hEvent.m_iPreSample = PrecacheSampleKeyValues(hConf);
		hConf.GoBack();
	}

	if(hConf.JumpToKey("post_sample", false))
	{
		hEvent.m_iPostSample = PrecacheSampleKeyValues(hConf);
		hConf.GoBack();
	}

	if(hConf.JumpToKey("samples", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			do {
				int iSample = PrecacheSampleKeyValues(hConf);

				hEvent.m_iSamples[hEvent.m_iSamplesCount] = iSample;
				hEvent.m_iSamplesCount++;

			} while (hConf.GotoNextKey());
			hConf.GoBack();
		}
		hConf.GoBack();
	}

	m_hEventDefs[iIndex] = hEvent;
	m_iEventDefsLength++;

	return iIndex;
}

public int PrecacheSampleKeyValues(KeyValues hConf)
{
	int iIndex = m_iSampleDefsLength;
	Sample_t hSample;

	hSample.m_flDuration = hConf.GetFloat("duration");
	hSample.m_flVolume = hConf.GetFloat("volume");

	hConf.GetString("move_to_event", hSample.m_sMoveToEvent, sizeof(hSample.m_sMoveToEvent));
	hConf.GetString("sound", hSample.m_sSound, sizeof(hSample.m_sSound));

	hSample.m_nIterations = hConf.GetNum("iterations", 1);
	hSample.m_nMoveToSample = hConf.GetNum("move_to_sample", -1);

	hSample.m_bPreserveSample = hConf.GetNum("preserve_sample", 0) == 1;

	m_hSampleDefs[iIndex] = hSample;
	m_iSampleDefsLength++;

	return iIndex;
}

public Action teamplay_broadcast_audio(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int iTeam = hEvent.GetInt("team");
	char sOldSound[MAX_SOUND_NAME];
	hEvent.GetString("sound", sOldSound, sizeof(sOldSound));

	for (int i = 1; i < MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		if (GetClientTeam(i) != iTeam)continue;

		char sSound[MAX_SOUND_NAME];
		
		Soundtrack_t hKit;
		if(GetClientKit(i, hKit))
		{
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
			hNewEvent.SetInt("override", 1);
			hNewEvent.SetString("sound", sSound);
			hNewEvent.FireToClient(i);
		}
	}

	return Plugin_Handled;
}

public int GetKitIndexByDefID(int defid)
{
	for (int i = 0; i < m_iKitDefsLength; i++)
	{
		if (m_hKitDefs[i].m_iDefIndex == defid)return i;
	}
	return -1;
}

public bool GetKitByIndex(int id, Soundtrack_t hKit)
{
	if(id >= m_iKitDefsLength || id < 0) return false;
	hKit = m_hKitDefs[id];
	return true;
}

public bool GetEventByIndex(int id, Event_t hEvent)
{
	if(id >= m_iEventDefsLength || id < 0) return false;
	hEvent = m_hEventDefs[id];
	return true;
}

public bool GetSampleByIndex(int id, Sample_t hSample)
{
	if(id >= m_iSampleDefsLength || id < 0) return false;
	hSample = m_hSampleDefs[id];
	return true;
}

public int GetEventIndexByKitAndID(int kit, char[] id)
{
	Soundtrack_t hKit;
	GetKitByIndex(kit, hKit);
	
	for (int i = 0; i < hKit.m_iEventsCount; i++)
	{
		int iEventIndex = hKit.m_iEvents[i];
		
		Event_t hEvent;
		if(GetEventByIndex(iEventIndex, hEvent))
		{
			if (StrEqual(hEvent.m_sID, ""))continue;
			if (StrEqual(hEvent.m_sID, id))return iEventIndex;
		}
	}
	
	return -1;
}

public bool GetClientKit(int client, Soundtrack_t hKit)
{
	if (m_iMusicKit[client] < 0)return false;

	if (!GetKitByIndex(m_iMusicKit[client], hKit))return false;
	return true;
}

public void CEEvents_OnSendEvent(int client, const char[] event, int add, int unique)
{
	Soundtrack_t hKit;
	if(!GetClientKit(client, hKit)) return;

	for (int i = 0; i < hKit.m_iEventsCount; i++)
	{
		int iEvent = hKit.m_iEvents[i];

		Event_t hEvent;
		GetEventByIndex(iEvent, hEvent);

		// Check if we need to start an event.
		if(StrContains(hEvent.m_sStartHook, event) != -1)
		{
			// If this event is played only once, we skip this.
			if (hEvent.m_bFireOnce && m_iCurrentEvent[client] == iEvent)continue;

			if(m_iCurrentEvent[client] > -1)
			{
				Event_t hOldEvent;
				if(GetEventByIndex(m_iCurrentEvent[client], hOldEvent))
				{
					if(hOldEvent.m_iPriority > hEvent.m_iPriority) continue;
				}
			}

			m_iNextEvent[client] = iEvent;
			m_bForceNextEvent[client] = hEvent.m_bForceStart;
			m_bShouldStop[client] = false;
		}

		// Start Sample playing.
		if(StrContains(hEvent.m_sStopHook, event) != -1)
		{
			if(m_bIsPlaying[client] && !m_bShouldStop[client])
			{
				m_bShouldStop[client] = true;
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
		m_bIsPlaying[client] = true;

		if(!StrEqual(hSample.m_sSound, ""))
		{
			if(!StrEqual(m_sActiveSound[client], ""))
			{
				StopSound(client, SNDCHAN_AUTO, m_sActiveSound[client]);
			}

			strcopy(m_sActiveSound[client], sizeof(m_sActiveSound[]), hSample.m_sSound);
			PrecacheSound(hSample.m_sSound);
			EmitSoundToClient(client, hSample.m_sSound);
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

public void BufferFlush(int client)
{
	m_iQueueLength[client] = 0;
	m_iQueuePointer[client] = 0;
	m_iCurrentEvent[client] = -1;
	
	strcopy(m_hPreSample[client].m_sSound, sizeof(m_hPreSample[].m_sSound), "");
	strcopy(m_hPostSample[client].m_sSound, sizeof(m_hPostSample[].m_sSound), "");
}

public void GetNextSample(int client, Sample_t hSample)
{
	// Make sure client exists.
	if (!IsClientValid(client))return;

	// First, we check if we need to switch to next sample.
	// We only do that if post and pre are not set and queue is empty.
	if(m_bShouldStop[client])
	{
		if(StrEqual(m_hPostSample[client].m_sSound, ""))
		{
			BufferFlush(client);
			m_bShouldStop[client] = false;
		} else {
			hSample = m_hPostSample[client];
			strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			return;
		}
	}

	if(m_iNextEvent[client] > -1)
	{
		bool bSkipPost = false;
		
		Event_t CurrentEvent;
		if(GetEventByIndex(m_iNextEvent[client], CurrentEvent))
		{
			bSkipPost = CurrentEvent.m_bSkipPost;
		}

		if(StrEqual(m_hPostSample[client].m_sSound, "") || bSkipPost)
		{
			PrintToConsole(client, "m_iNextEvent, true");
			BufferLoadEvent(client, m_iNextEvent[client]);
			m_iNextEvent[client] = -1;
		} else {
			PrintToConsole(client, "m_iNextEvent, false");
			hSample = m_hPostSample[client];
			strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			return;
		}
	}

	if(!StrEqual(m_hPreSample[client].m_sSound, ""))
	{
		PrintToConsole(client, "m_hPreSample");
		hSample = m_hPreSample[client];
		strcopy(m_hPreSample[client].m_sSound, MAX_SOUND_NAME, "");
		return;
	}

	int iPointer = m_iQueuePointer[client];
	
	// If we have more things to play in the main queue.
	if(m_iQueueLength[client] > iPointer)
	{
		
		// Get currently active sample.
		Sample_t CurrentSample;
		CurrentSample = m_hQueue[client][iPointer];

		// If we run this sample and amount of iterations has exceeded the max amount,
		// we reset the value and run it again.
		if(CurrentSample.m_nCurrentIteration >= CurrentSample.m_nIterations)
		{
			CurrentSample.m_nCurrentIteration = 0;
		}

		//PrintToConsole(client, "m_hSampleQueue, %d, (%d/%d)", m_iCurrentSample[client], sample.m_nCurrentIteration + 1, sample.m_nIterations);

		// Increase current iteration every time we run through it.
		if(CurrentSample.m_nCurrentIteration < CurrentSample.m_nIterations)
		{
			CurrentSample.m_nCurrentIteration++;
		}

		// Update all changed data in the queue.
		m_hQueue[client][iPointer] = CurrentSample;

		// Move to next sample if we reached our limit.
		if(CurrentSample.m_nCurrentIteration == CurrentSample.m_nIterations)
		{
			int iMoveToEvent = GetEventIndexByKitAndID(m_iMusicKit[client], CurrentSample.m_sMoveToEvent);
			if(iMoveToEvent > -1)
			{
				// Check if we need to move to a specific event now.
				m_iNextEvent[client] = iMoveToEvent;
			} else if(CurrentSample.m_nMoveToSample > -1 && CurrentSample.m_nMoveToSample < m_iQueueLength[client])
			{
				// Otherwise check if we need to go to a specific sample.
				// m_iCurrentSample[client] = sample.m_nMoveToSample;
				m_iQueuePointer[client] = CurrentSample.m_nMoveToSample;
			} else {
				// Otherwise, move to next sample.
				m_iQueuePointer[client]++;
			}
		}

		hSample = CurrentSample;
		return;
	}

	if(!StrEqual(m_hPostSample[client].m_sSound, ""))
	{
		hSample = m_hPostSample[client];
		strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
		return;
	}

	// If we are at this point - nothing is left to play, so we clean up everything.
	BufferFlush(client);
}

public void BufferLoadEvent(int client, int event)
{
	
	if (!IsClientValid(client))return;

	Event_t hEvent;
	if (!GetEventByIndex(event, hEvent))return;

	for (int i = 0; i < hEvent.m_iSamplesCount; i++)
	{
		int iEventIndex = hEvent.m_iSamples[i];
		
		Sample_t hSample;
		GetSampleByIndex(iEventIndex, hSample);
		
		m_hQueue[client][i] = hSample;
	}
	m_iQueueLength[client] = hEvent.m_iSamplesCount;
	m_iQueuePointer[client] = 0;
	
	// Loading Pre
	if(!GetSampleByIndex(hEvent.m_iPreSample, m_hPreSample[client]))
	{
		strcopy(m_hPreSample[client].m_sSound, sizeof(m_hPreSample[].m_sSound), "");
	}
	
	// Loading Post
	if(!GetSampleByIndex(hEvent.m_iPostSample, m_hPostSample[client]))
	{
		strcopy(m_hPostSample[client].m_sSound, sizeof(m_hPostSample[].m_sSound), "");
	}
}

public Action teamplay_round_start(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	//StopEventsForAll();

	if(!TF2_IsSetup() && !TF2_IsWaitingForPlayers())
	{
		//RequestFrame(PlayRoundStartMusic, hEvent);
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

public Action Timer_EscordProgressUpdate(Handle timer, any data)
{
	static float flOld = 0.0;
	float flNew = Payload_GetProgress();

	if(flOld != flNew)
	{
		switch(m_nPayloadStage)
		{
			case 0:
			{
				if(flNew >= PAYLOAD_STAGE_1_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEEvents_SendEventToClient(i, "OST_PAYLOAD_S1_START", 1, GetRandomInt(1, 10000));
						}
					}
					m_nPayloadStage = 1;
				}
			}
			case 1:
			{
				if(flNew >= PAYLOAD_STAGE_2_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEEvents_SendEventToClient(i, "OST_PAYLOAD_S2_START", 1, GetRandomInt(1, 10000));
						}
					}
					m_nPayloadStage = 2;
				}

				if(flNew < PAYLOAD_STAGE_1_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEEvents_SendEventToClient(i, "OST_PAYLOAD_S1_CANCEL", 1, GetRandomInt(1, 10000));
						}
					}
					m_nPayloadStage = 0;
				}
			}
			case 2:
			{
				if(flNew < PAYLOAD_STAGE_1_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEEvents_SendEventToClient(i, "OST_PAYLOAD_S2_CANCEL", 1, GetRandomInt(1, 10000));
						}
					}
					m_nPayloadStage = 0;
				}
			}
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

public bool TF2_IsWaitingForPlayers()
{
	return GameRules_GetProp("m_bInWaitingForPlayers") == 1;
}

public bool TF2_IsSetup()
{
	return GameRules_GetProp("m_bInSetup") == 1;
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