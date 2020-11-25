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

Soundtrack_t m_hKits[OST_MAX_KITS];
Event_t m_hEvents[OST_MAX_KITS][OST_MAX_EVENTS];
Sample_t m_hSamples[OST_MAX_KITS][OST_MAX_EVENTS][OST_MAX_SAMPLES];

int m_iNextEvent[MAXPLAYERS + 1] =  { -1, ... };
int m_iCurrentEvent[MAXPLAYERS + 1] =  { -1, ... };
int m_iCurrentSample[MAXPLAYERS + 1];

int m_iMusicKit[MAXPLAYERS + 1];

bool m_bIsPlaying[MAXPLAYERS + 1];
bool m_bShouldStop[MAXPLAYERS + 1];
bool m_bForceNextEvent[MAXPLAYERS + 1];

Handle m_hTimer[MAXPLAYERS + 1];

ArrayList m_hSampleQueue[MAXPLAYERS + 1];

Sample_t m_hPreSample[MAXPLAYERS + 1];
Sample_t m_hPostSample[MAXPLAYERS + 1];

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
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_round_start", teamplay_round_start, EventHookMode_Pre);
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
	//FlushSoundtrackMemory();
	int iIndex = 0;
	if(hConf.JumpToKey("Items", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			// ===================
			// || Checking Item ||
			// ===================
			do {
				char sType[32];
				hConf.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "soundtrack"))continue;
				
				char sIndex[11];
				hConf.GetSectionName(sIndex, sizeof(sIndex));
				int iDefIndex = StringToInt(sIndex);

				m_hKits[iIndex].m_iDefIndex = iDefIndex;
				if(hConf.JumpToKey("logic", false))
				{
					hConf.GetString("broadcast/win", m_hKits[iIndex].m_sWinMusic, sizeof(m_hKits[].m_sWinMusic));
					hConf.GetString("broadcast/loss", m_hKits[iIndex].m_sLossMusic, sizeof(m_hKits[].m_sLossMusic));
					
					if(hConf.JumpToKey("events", false))
					{
						if(hConf.GotoFirstSubKey())
						{
							// ====================
							// || Checking Event ||
							// ====================
							do {
								char sEventIndex[11];
								hConf.GetSectionName(sEventIndex, sizeof(sEventIndex));
								int iEventIndex = StringToInt(sEventIndex);
								
								m_hEvents[iIndex][iEventIndex].m_bFireOnce = hConf.GetNum("fire_once") == 1;
								m_hEvents[iIndex][iEventIndex].m_bForceStart = hConf.GetNum("force_start") == 1;
								hConf.GetString("start_hook", m_hEvents[iIndex][iEventIndex].m_sStartHook, sizeof(m_hEvents[][].m_sStartHook));
								hConf.GetString("stop_hook", m_hEvents[iIndex][iEventIndex].m_sStopHook, sizeof(m_hEvents[][].m_sStopHook));
								hConf.GetString("id", m_hEvents[iIndex][iEventIndex].m_sID, sizeof(m_hEvents[][].m_sID));
								
								if(hConf.JumpToKey("samples", false))
								{
									if(hConf.GotoFirstSubKey())
									{
										// =====================
										// || Checking Sample ||
										// =====================
										do {
											char sSampleIndex[11];
											hConf.GetSectionName(sSampleIndex, sizeof(sSampleIndex));
											int iSampleIndex = StringToInt(sSampleIndex);
											
											m_hSamples[iIndex][iEventIndex][iSampleIndex].m_flDuration = hConf.GetFloat("duration");
											m_hSamples[iIndex][iEventIndex][iSampleIndex].m_flVolume = hConf.GetFloat("volume");
											
											hConf.GetString("move_to_event", m_hSamples[iIndex][iEventIndex][iSampleIndex].m_sMoveToEvent, sizeof(m_hSamples[][][].m_sMoveToEvent));
											hConf.GetString("sound", m_hSamples[iIndex][iEventIndex][iSampleIndex].m_sSound, sizeof(m_hSamples[][][].m_sSound));
											
											m_hSamples[iIndex][iEventIndex][iSampleIndex].m_nIterations = hConf.GetNum("iterations", 1);
											m_hSamples[iIndex][iEventIndex][iSampleIndex].m_nMoveToSample = hConf.GetNum("move_to_sample", -1);
											
											m_hSamples[iIndex][iEventIndex][iSampleIndex].m_bPreserveSample = hConf.GetNum("preserve_sample", 0) == 1;
											
										} while (hConf.GotoNextKey());
										hConf.GoBack();
									}
									hConf.GoBack();
								}
							} while (hConf.GotoNextKey());
							hConf.GoBack();
						}
						hConf.GoBack();
					}
					
					
					hConf.GoBack();
				}
				
				iIndex++;
			} while (hConf.GotoNextKey());
		}
	}
	hConf.Rewind();
}

/**
*	Purpose: Stop all events if we start a new round.
*/
public Action teamplay_round_start(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	StopEventsForAll();
}

/**
*	Purpose: Stop all events if we end a round. (A tick after.);
*/
public Action teamplay_round_win(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	RequestFrame(RF_StopEventsForAll);
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
			m_bShouldStop[i] = true;
		}
		m_iNextEvent[i] = -1;
	}
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
			
			if(StrContains(sOldSound, "YourTeamWon") != -1)
			{
				strcopy(sSound, sizeof(sSound), m_hKits[iMusicKit].m_sWinMusic);
			}

			if(StrContains(sOldSound, "YourTeamLost") != -1)
			{
				strcopy(sSound, sizeof(sSound), m_hKits[iMusicKit].m_sLossMusic);
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

public void CEEvents_OnSendEvent(int client, const char[] event, int add, int unique)
{
	int iMusicKit = m_iMusicKit[client];
	if (iMusicKit == -1)return;
	
	for (int i = 0; i < OST_MAX_EVENTS; i++)
	{
		int iEvent = i;
		
		Event_t hEvent;
		hEvent = m_hEvents[iMusicKit][i];
		
		if(m_iCurrentEvent[client] != iEvent)
		{
			// Start Sample playing.
			if(StrEqual(m_hEvents[iMusicKit][i].m_sStartHook, event))
			{
				if (hEvent.m_bFireOnce && m_iCurrentEvent[client] == iEvent)continue;
	
				PrintToChatAll("%s said we need to start.", event);
				m_iNextEvent[client] = iEvent;
				m_bForceNextEvent[client] = hEvent.m_bForceStart;
			}
			
		} else {
			
			// Stop playing sample.
			if(StrEqual(m_hEvents[iMusicKit][i].m_sStartHook, event))
			{
				if(m_bIsPlaying[client] && !m_bShouldStop[client])
				{
					PrintToChatAll("%s said we need to stop.", event);
					m_bShouldStop[client] = true;
				}
			}
		}
	}
	
	PlayNextSample(client);
}

/*
public void CEEvents_OnBroadcastToAll(Handle event, bool isKV)
{
	for (int client = 1; client < MaxClients; client++)
	{
		if (!IsClientValid(client))continue;
		if (m_hKitLogic[client] == null)continue;

		// Getting event name.
		char sEventName[64];
		if(isKV) {
			KvGetSectionName(event, sEventName, sizeof(sEventName));
		} else {
			GetEventName(event, sEventName, sizeof(sEventName));
		}

		KeyValues kv = m_hKitLogic[client];

		// Loop through each event.
		if(kv.JumpToKey("events/0", false))
		{
			do {
				bool bFound = false;
				char sEvent[11];
				kv.GetSectionName(sEvent, sizeof(sEvent));
				int iEvent = StringToInt(sEvent);

				// Check if start_hooks has any hooks with events of this name.
				if(kv.JumpToKey("start_hooks/0", false))
				{
					do {

						if (kv.GetNum("fire_once", 0) == 1 && m_iCurrentEvent[client] == iEvent)continue;

						char sType[32], sName[64];
						kv.GetString("type", sType, sizeof(sType));
						kv.GetString("event_name", sName, sizeof(sName));

						if (!StrEqual(sType, "event_listener"))continue;
						if (!StrEqual(sName, sEventName))continue;

						if (kv.JumpToKey("logic", false))
						{
							if (!CECCS_ParseLogic(client, kv, event, null, isKV))
							{
								kv.GoBack();
								continue;
							}
							kv.GoBack();
						}

						m_iNextEvent[client] = iEvent;
						m_bForceNextEvent[client] = kv.GetNum("force_start", 0) == 1;
						bFound = true;

						break;

					} while (kv.GotoNextKey());
					kv.GoBack();
				}

				// See if we need to stop current event.
				if(m_iCurrentEvent[client] == iEvent)
				{
					if(kv.JumpToKey("stop_hooks/0", false))
					{
						do {
							char sType[32], sName[64];
							kv.GetString("type", sType, sizeof(sType));
							kv.GetString("event_name", sName, sizeof(sName));

							if (!StrEqual(sType, "event_listener"))continue;
							if (!StrEqual(sName, sEventName))continue;

							if (kv.JumpToKey("logic", false))
							{
								if (!CECCS_ParseLogic(client, kv, event, null, isKV))
								{
									kv.GoBack();
									continue;
								}
								kv.GoBack();
							}

							if(m_bIsPlaying[client] && !m_bShouldStop[client])
							{
								PrintToConsole(client, "%s said we need to stop.", sEventName);
								m_bShouldStop[client] = true;
							}

							break;

						} while (kv.GotoNextKey());
						kv.GoBack();
					}
				}

				if(bFound) break;
			} while (kv.GotoNextKey());
			kv.GoBack();
		}

		kv.Rewind();
		PlayNextSample(client);
	}
}*/

public void CE_OnPostEquip(int entity, int client, int index, int defid, int quality, KeyValues hAttributes, char[] type)
{
	if (!StrEqual(type, "soundtrack"))return;

	int iKitID = GetKitIndexByDefID(defid);
	m_iMusicKit[client] = iKitID;

	return;
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
		//BufferFlush(client);

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
			PrecacheSound(sSound);
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
			//BufferFlush(client);
			m_bShouldStop[client] = false;
			PrintToConsole(client, "m_bShouldStop, true");
		} else {
			hSample = m_hPostSample[client];
			strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			PrintToConsole(client, "m_bShouldStop, false");
			return;
		}
	}


	if(m_iNextEvent[client] > -1)
	{
		if(StrEqual(m_hPostSample[client].m_sSound, ""))
		{
			PrintToConsole(client, "m_iNextEvent, true");
			//BufferLoadEvent(client, m_iNextEvent[client]);
			m_iNextEvent[client] = -1;
		} else {
			PrintToConsole(client, "m_iNextEvent, false");
			hSample = m_hPostSample[client];
			strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			return;
		}
	}

	// Make sure queue handle exists.
	if (m_hSampleQueue[client] == null)return;

	if(!StrEqual(m_hPreSample[client].m_sSound, ""))
	{
		PrintToConsole(client, "m_hPreSample");
		hSample = m_hPreSample[client];
		strcopy(m_hPreSample[client].m_sSound, MAX_SOUND_NAME, "");
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

		PrintToConsole(client, "m_hSampleQueue, %d, (%d/%d)", m_iCurrentSample[client], sample.m_nCurrentIteration + 1, sample.m_nIterations);

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
			if(sample.m_nMoveToEvent > -1)
			{
				m_iNextEvent[client] = sample.m_nMoveToEvent;
			} else if(sample.m_nMoveToSample > -1 && sample.m_nMoveToSample < m_hSampleQueue[client].Length)
			{
				m_iCurrentSample[client] = sample.m_nMoveToSample;
			} else m_iCurrentSample[client]++;
		}

		hSample = sample;
		return;
	}

	if(!StrEqual(m_hPostSample[client].m_sSound, ""))
	{
		PrintToConsole(client, "m_hPostSample");
		hSample = m_hPostSample[client];
		strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
		return;
	}

	// If we are at this point - nothing is left to play, so we clean up everything.
	BufferFlush(client);
}

public int GetKitIndexByDefID(int defid)
{
	for (int i = 0; i < OST_MAX_KITS; i++)
	{
		if (m_hKits[i].m_iDefIndex == defid)return i;
	}
	return -1;
}

public int GetEventIndexByID(int kit, const char[] id)
{
	for (int i = 0; i < OST_MAX_EVENTS; i++)
	{
		if (StrEqual(m_hEvents[kit][i].m_sID, id))return i;
	}
	return -1;
}
/*
public void BufferFlush(int client)
{
	if(IsHandleValid(m_hSampleQueue[client]))
	{
		m_hSampleQueue[client].Clear();
	}
	strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
	strcopy(m_hPreSample[client].m_sSound, MAX_SOUND_NAME, "");

	m_iCurrentEvent[client] = -1;
}*/

	/*
public void BufferLoadEvent(int client, int event)
{
	if (!IsClientValid(client))return;
	if (m_hKitLogic[client] == null)return;

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

	KeyValues kv = new KeyValues("Logic");
	kv.Import(m_hKitLogic[client]);

	char sKey[32];
	Sample_t hPost, hPre;

	// Load Post Sample.
	Format(sKey, sizeof(sKey), "events/%d/samples/post", event);
	if(kv.JumpToKey(sKey, false))
	{
		kv.GetString("sound", hPost.m_sSound, MAX_SOUND_NAME);
		hPost.m_flDuration = kv.GetFloat("duration", 0.0);
		kv.GoBack();
	}
	m_hPostSample[client] = hPost;

	// Load Pre Sample.
	Format(sKey, sizeof(sKey), "events/%d/samples/pre", event);
	if(kv.JumpToKey(sKey, false))
	{
		kv.GetString("sound", hPre.m_sSound, MAX_SOUND_NAME);
		hPre.m_flDuration = kv.GetFloat("duration", 0.0);
		kv.GoBack();
	}
	m_hPreSample[client] = hPre;

	Format(sKey, sizeof(sKey), "events/%d/samples/0", event);

	// Load other samples.
	if(kv.JumpToKey(sKey, false))
	{
		do {
			char sName[6];
			kv.GetSectionName(sName, sizeof(sName));
			if (StrEqual(sName, "post") || StrEqual(sName, "pre"))continue;

			Sample_t hSample;

			kv.GetString("sound", hSample.m_sSound, MAX_SOUND_NAME);
			hSample.m_flDuration = kv.GetFloat("duration", 0.0);
			hSample.m_nIterations = kv.GetNum("iterations", 1);
			hSample.m_nMoveToSample = kv.GetNum("move_to_sample", -1);
			hSample.m_bPreserveSample = kv.GetNum("preserve_sample", -1) == 1;

			char sIndex[MAX_EVENT_NAME];
			kv.GetString("move_to_event", sIndex, sizeof(sIndex));

			hSample.m_nMoveToEvent = GetClientEventIndexByID(client, event, sIndex);

			m_hSampleQueue[client].PushArray(hSample);

		} while (kv.GotoNextKey());
		kv.GoBack();
	}

	delete kv;

	m_iCurrentEvent[client] = event;
	m_iCurrentSample[client] = 0;
}*/

public float GetClientSoundInterp(int client)
{
	return float(TF2_GetNativePing(client)) / 2000.0;
}

public int TF2_GetNativePing(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, client);
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

	m_iNextEvent[client] = -1;
	m_iCurrentEvent[client] = -1;
	m_iCurrentSample[client] = 0;

	Format(m_hPreSample[client].m_sSound, MAX_SOUND_NAME, "");
	Format(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");

	m_bIsPlaying[client] = false;
	m_bShouldStop[client] = false;
	m_bForceNextEvent[client] = false;

	delete m_hTimer[client];
}

public bool IsHandleValid(Handle hHandle)
{
	return hHandle != null && hHandle != INVALID_HANDLE;
}
