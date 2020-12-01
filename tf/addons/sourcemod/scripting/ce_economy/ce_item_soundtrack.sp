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
	
Sample_t m_hPreSample[MAXPLAYERS + 1];
Sample_t m_hPostSample[MAXPLAYERS + 1];

Handle m_hTimer[MAXPLAYERS + 1];

ArrayList m_hSampleQueue[MAXPLAYERS + 1];

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
								Event_t hEvent;
								hEvent.m_bFireOnce = hConf.GetNum("fire_once") == 1;
								hEvent.m_bForceStart = hConf.GetNum("force_start") == 1;
								hConf.GetString("start_hook", hEvent.m_sStartHook, sizeof(hEvent.m_sStartHook));
								hConf.GetString("stop_hook", hEvent.m_sStopHook, sizeof(hEvent.m_sStopHook));
								hConf.GetString("id", hEvent.m_sID, sizeof(hEvent.m_sID));
								
								if(hConf.JumpToKey("pre_sample", false))
								{
									/*
									Sample_t hPreSample;
									KeyValuesToSample(hConf, hPreSample);
									hEvent.m_hPre = hPreSample;
									hConf.GoBack();*/
								}
								
								if(hConf.JumpToKey("post_sample", false))
								{
									/*
									Sample_t hPostSample;
									KeyValuesToSample(hConf, hPostSample);
									hEvent.m_hPost = hPostSample;
									hConf.GoBack();*/
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
				if (hEvent.m_bFireOnce && m_iCurrentEvent[client] == iEvent)continue;
	
				PrintToChatAll("%s said we need to start.", event);
				m_iNextEvent[client] = iEvent;
				m_bForceNextEvent[client] = hEvent.m_bForceStart;
			}
		} else {
			// Start Sample playing.
			if(StrContains(hEvent.m_sStopHook, event) != -1)
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
		if(StrEqual(m_hPostSample[client].m_sSound, ""))
		{
			BufferFlush(client);
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
			BufferLoadEvent(client, m_iNextEvent[client]);
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
			int iMoveToEvent = GetEventIndexByID(m_iMusicKit[client], sample.m_sMoveToEvent);
			PrintToChatAll("%d %s", iMoveToEvent, sample.m_sMoveToEvent);
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
	//m_hPreSample[client] = hEvent.m_hPre;
	//m_hPostSample[client] = hEvent.m_hPost;

	m_iCurrentEvent[client] = event;
	m_iCurrentSample[client] = 0;
}

public void BufferFlush(int client)
{
	if(UTIL_IsValidHandle(m_hSampleQueue[client]))
	{
		m_hSampleQueue[client].Clear();
	}
	strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
	strcopy(m_hPreSample[client].m_sSound, MAX_SOUND_NAME, "");

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

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, char[] type)
{
	if (!StrEqual(type, "soundtrack"))return;

	int iKitID = GetKitIndexByDefID(defid);
	m_iMusicKit[client] = iKitID;

	return;
}

public void CE_OnItemHoster(int client, int index, int defid, const char[] type)
{
	if (!StrEqual(type, "soundtrack"))return;
	m_iMusicKit[client] = -1;
}

public int GetEventIndexByID(int kit, const char[] sId)
{
	Soundtrack_t hKit;
	bool bFound = GetKitByIndex(kit, hKit);
	if (!bFound)return -1;
	
	for (int i = 0; i < hKit.m_hEvents.Length; i++)
	{
		Event_t hEvent;
		hKit.m_hEvents.GetArray(kit, hEvent);
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