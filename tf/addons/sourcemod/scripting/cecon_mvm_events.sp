#pragma semicolon 1
#pragma newdecls required

//#include <cecon>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <cecon>

public Plugin myinfo =
{
	name = "Creators.TF Economy - TF2 Events",
	author = "Creators.TF Team",
	description = "Creators.TF TF2 Events",
	version = "1.0",
	url = "https://creators.tf"
}

bool uses_custom_upgrades = false;

ConVar buster_range_cvar;

#define TF_MAXPLAYERS 34 // 33 max players + 1 for offset



enum struct PlayerData
{
	int steam_id;
	int touched_cp_area;
	int tank_damage_wave;
	int tank_damage_last_second;

	bool was_whole_mission;

	int hit_tracker;

	int killer;

	int buster_save_sentry;

	float fire_weapon_time;
	int fire_weapon_gained_metal;
	int metal_pre_shoot;

	void Init(int client)
	{
		this.steam_id = GetSteamAccountID(client, true);
		this.touched_cp_area = -1;
		this.tank_damage_wave = 0;
		this.tank_damage_last_second = 0;
		this.was_whole_mission = false;
		this.killer = 0;
		this.hit_tracker = 0;
		this.buster_save_sentry = 0;
		this.fire_weapon_time = 0.0;
		this.fire_weapon_gained_metal = 0;
		this.metal_pre_shoot = 0;
	}
}

PlayerData player_data[TF_MAXPLAYERS];

Handle get_condition_provider_handle;
Handle attrib_float_handle;

int bonus_currency_counter = 0;
public void OnPluginStart()
{
	buster_range_cvar = FindConVar("tf_bot_suicide_bomb_range");

	HookEvent("upgrades_file_changed", upgrades_file_changed);

	HookEvent("mvm_mission_complete", mvm_mission_complete);

	HookEvent("mvm_tank_destroyed_by_players", mvm_tank_destroyed_by_players);
	
	HookEvent("mvm_begin_wave", mvm_begin_wave);
	HookEvent("mvm_wave_failed", mvm_wave_failed);
	HookEvent("mvm_wave_complete", mvm_wave_complete);

	HookEvent("controlpoint_starttouch", controlpoint_starttouch);
	HookEvent("controlpoint_endtouch", controlpoint_endtouch);
	
	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);
	HookEvent("player_hurt", player_hurt);
	HookEvent("damage_resisted", damage_resisted);
	HookEvent("player_ignited", player_ignited);
	HookEvent("player_healed", player_healed);
	HookEvent("medic_death", medic_death);

	HookEvent("mvm_pickup_currency", mvm_pickup_currency);
	HookEvent("mvm_creditbonus_wave", mvm_creditbonus_wave);

	HookEvent("player_carryobject", player_carryobject);
	HookEvent("player_dropobject", player_dropobject);
	
	HookEvent("player_stunned", player_stunned);

	Handle data_mvm = LoadGameConfigFile("tf2.cecon_mvm_events");
	StartPrepSDKCall(SDKCall_Raw);
	if (PrepSDKCall_SetFromConf(data_mvm,SDKConf_Signature,"CTFPlayerShared::GetConditionProvider")) 
	{
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Plain);
	}
	get_condition_provider_handle = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(data_mvm,SDKConf_Signature,"CAttributeManager::AttribHookValueFloat")) {
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	}
	attrib_float_handle = EndPrepSDKCall();

	AddNormalSoundHook(OnSound);
	CreateTimer(1.0, UpdateTimer, 0, TIMER_REPEAT);
}

// Update every second events
public Action UpdateTimer(Handle timer, any data)
{
	int player_resource = GetPlayerResourceEntity();
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		for (int i = 1; i <= TF_MAXPLAYERS; i++)
		{
			if (IsClientValid(i) && !IsFakeClient(i))
			{
				if (TF2_IsPlayerInCondition(i, TFCond_CritOnKill))
				{
					CEcon_SendEventToClientUnique(i, "TF_MVM_CRITBOOST_ON_KILL_SECOND", 1);
				}

				int tank_damage = GetEntProp(player_resource, Prop_Send, "m_iDamageBoss", 4, i);

				if (tank_damage > player_data[i].tank_damage_last_second)
				{
					CEcon_SendEventToClientUnique(i, "TF_MVM_DAMAGE_TANK", tank_damage - player_data[i].tank_damage_last_second);
				}

				player_data[i].tank_damage_last_second = tank_damage;
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!(buttons & IN_ATTACK) && player_data[client].fire_weapon_gained_metal > 0)
	{
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL_RESET", 1);
		player_data[client].fire_weapon_gained_metal = 0;
	}
	else if (weapon != 0 && player_data[client].fire_weapon_gained_metal > 0)
	{
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL_RESET", 1);
		player_data[client].fire_weapon_gained_metal = 0;
	}
}


public void OnClientPutInServer(int client)
{
	int steam_id = GetSteamAccountID(client);

	// Copy some properties that should stay if client disconnects temponairly;
	bool was_whole_mission = false;
	if (steam_id != 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (player_data[client].steam_id == steam_id)
			{
				was_whole_mission = player_data[client].was_whole_mission;
				break;
			}
		}
	}

	player_data[client].Init(client);
	player_data[client].was_whole_mission = was_whole_mission;


	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnPlayerDamagePost);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnPlayerDamage);
}

public Action OnSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	// Widowmaker shoot hook
	if (channel == 1 && strncmp(sample, ")weapons\\widow_maker_shot_", strlen(")weapons\\widow_maker_shot_")) == 0 
		&& IsClientValid(entity) && GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		PrintToChatAll("Attacker metal hurt pre %d", GetEntProp(entity, Prop_Data, "m_iAmmo", 4, 3));
		player_data[entity].metal_pre_shoot = GetEntProp(entity, Prop_Data, "m_iAmmo", 4, 3);
		RequestFrame(WidowmakerShootUpdate, entity);
	}
	// Short circuit deflect sound hook
	else if (entity > TF_MAXPLAYERS && strcmp(sample, ")weapons\\upgrade_explosive_headshot.wav") == 0)
	{
		char classname[36];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (strcmp(classname, "tf_projectile_mechanicalarmorb") == 0)
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

			CEcon_SendEventToClientUnique(owner, "TF_MVM_DEFLECT_SHORT_CIRCUIT", 1);
		}
	}
}

public void WidowmakerShootUpdate(int client)
{
	int metal_diff = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3) - player_data[client].metal_pre_shoot;
	if (metal_diff < 0)
	{
		player_data[client].fire_weapon_gained_metal=0;
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL_RESET", 1);
	}
	else
	{
		player_data[client].fire_weapon_gained_metal++;
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL", 1);
	}
}

public Action player_changeclass(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	int class = hEvent.GetInt("class");

	return Plugin_Continue;
}

public Action upgrades_file_changed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	char upgrade_path[256];

	GetEventString(hEvent, "path", upgrade_path, sizeof(upgrade_path), "");

	uses_custom_upgrades = strcmp(upgrade_path, "") != 0 && strcmp(upgrade_path, "scripts/items/mvm_upgrades.txt") != 0;

	return Plugin_Continue;
}

public Action mvm_mission_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	CEcon_SendEventToAll("TF_MVM_MISSION_COMPLETE", 1, GetRandomInt(0, 9999));

	int resource = GetPlayerResourceEntity();

	int highest_damage = 0;
	int highest_damage_player = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i) && player_data[i].was_whole_mission)
		{
			if (uses_custom_upgrades) {
				CEcon_SendEventToClientFromGameEvent(i, "TF_MVM_USE_CUSTOM_UPGRADES", 1, hEvent);
			}
			CEcon_SendEventToClientFromGameEvent(i, "TF_MVM_MISSION_COMPLETE_ALL_WAVES", 1, hEvent);
		}
		if (IsClientValid(i))
		{
			int damage = GetEntProp(resource, Prop_Send, "m_iDamageBoss", 4, i);
			if (damage > highest_damage) {
				highest_damage = damage;
				highest_damage_player = i;
			}
		}
	}

	if (highest_damage_player > 0) 
	{
		CEcon_SendEventToClientFromGameEvent(highest_damage_player, "TF_MVM_DAMAGE_TANK_MVP", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action player_spawn(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	player_data[client].hit_tracker = 0;
	player_data[client].killer = 0;
	player_data[client].touched_cp_area = -1;

	return Plugin_Continue;
}

int kill_counter_single;
int kill_counter_single_client;
int kill_counter_single_tick;

public Action player_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(hEvent, "assister"));

	int weapon_def = GetEventInt(hEvent, "weapon_def_index");
	int death_flags = GetEventInt(hEvent, "death_flags");
	int customkill = GetEventInt(hEvent, "customkill");
	int kill_streak_victim = GetEventInt(hEvent, "kill_streak_victim");
	int crit_type = GetEventInt(hEvent, "crit_type");
	
	if (IsClientValid(client))
	{
		//player_data[client].ResetStreak();
		if (IsClientValid(attacker))
		{
			if (client != attacker)
			{
				if (kill_counter_single_client != attacker || kill_counter_single_tick != GetGameTickCount())
				{
					kill_counter_single = 0;
				}
				kill_counter_single++;
				kill_counter_single_client = attacker;
				kill_counter_single_tick = GetGameTickCount();

				if (kill_counter_single >= 3)
				{
					
				}

				bool is_buster = IsSentryBuster(attacker);
				if (is_buster && GetClientTeam(client) == GetClientTeam(attacker))
				{
					int bomb = GetEntPropEnt(client, Prop_Send, "m_hItem");
					if (bomb != -1) 
						CEcon_SendEventToAll("TF_MVM_SENTRY_BUSTER_KILL_BOMB_CARRIER", 1, GetRandomInt(0, 9999));
				}

				if (IsFakeClient(client)) 
				{

					CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT", 1, hEvent);

					switch (crit_type)
					{
						case 0: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_NONE", 1, hEvent);
						case 1: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_MINI", 1, hEvent);
						case 2: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_FULL", 1, hEvent);
					}

					if (IsClientValid(assister))
					{
						player_data[client].hit_tracker |= 1 << (assister - 1);
						CEcon_SendEventToClientFromGameEvent(assister, "TF_MVM_KILL_ASSIST_ROBOT", 1, hEvent);
					}

					if (IsGiantNotBuster(client))
					{
						int hit_tracker = player_data[client].hit_tracker;
						// Players who assisted or dealt damage receive kill
						for (int i = 0; i < 32; i++)
						{
							if ((hit_tracker & (1 << i)) != 0) 
							{
								CEcon_SendEventToClientFromGameEvent(i + 1, "TF_MVM_KILL_ROBOT_GIANT", 1, hEvent);
							}
						}

						if (TF2_IsPlayerInCondition(client, TFCond_OnFire))
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_GIANT_BURNING", 1, hEvent);
						}

						if (TF2_GetPlayerClass(client) == TFClass_Scout && GetAttributeValue(client, "mult_player_movespeed", 1.0) >= 2.0)
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_SUPER_SCOUT", 1, hEvent);
						}
					}
					// All players receive boss kill events
					if (IsBoss(client))
					{
						CEcon_SendEventToAll("TF_MVM_KILL_ROBOT_BOSS", 1, GetRandomInt(0, 9999));
					}

					if (GetEntProp(client, Prop_Data, "m_iMaxHealth") >= 8000)
					{
						CEcon_SendEventToAll("TF_MVM_KILL_ROBOT_LARGE_HEALTH", 1, GetRandomInt(0, 9999));
					}

					if (GetEntPropEnt(client, Prop_Send, "m_hItem") != -1)
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BOMB_CARRIER", 1, hEvent);
					}

					// Gatebot filter
					int filter = CreateEntityByName("filter_tf_bot_has_tag");
					if (filter != -1) 
					{
						DispatchKeyValue(filter, "tags", "bot_gatebot");
						DispatchSpawn(filter);
						ActivateEntity(filter);

						player_data[client].killer = attacker;

						HookSingleEntityOutput(filter, "OnPass", OnGatebotFilterPass, true);
						HookSingleEntityOutput(filter, "OnFail", OnGatebotFilterFail, true);	
						AcceptEntityInput(filter, "TestActivator", client, attacker);
					}

					if (IsTauntKill(customkill))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_TAUNT", 1, hEvent);
					}

					// Razorback detection
					int child = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
					
					while (child != -1)
					{
						char classname[32];
						GetEntityClassname(child, classname, 32);

						if (strcmp(classname, "tf_wearable_razorback") == 0)
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_RAZORBACK", 1, hEvent);
							break;
						}
						child = GetEntPropEnt(child, Prop_Data, "m_hMovePeer");
					}

					// Half-zatoichi detection
					int active_weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

					if (active_weapon != -1)
					{
						char classname[32];
						GetEntityClassname(active_weapon, classname, 32);
						if (strcmp(classname, "tf_weapon_katana") == 0)
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_ZATOICHI", 1, hEvent);
						}
					}

					if (TF2_IsPlayerInCondition(attacker, TFCond_CritCola))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_COLA", 1, hEvent);
					}
					
					if (customkill == 1) // Headshot
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_HEADSHOT", 1, hEvent);
					}
					else
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_NOT_HEADSHOT", 1, hEvent);
					}

					if (customkill == 21) // Baseball hit
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BASEBALL", 1, hEvent);
					}

					if (customkill == 21) // Baseball hit
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BASEBALL", 1, hEvent);
					}
				}
			}
		}
	}
}

public Action controlpoint_starttouch(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");
	int area = GetEventInt(hEvent, "area");
	PrintToChatAll("starttouch %d", area);

	player_data[player].touched_cp_area = area;

	return Plugin_Continue;
}

public Action controlpoint_endtouch(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");
	int area = GetEventInt(hEvent, "area");
	PrintToChatAll("endtouch %d", area);
	if (player_data[player].touched_cp_area == area)
		player_data[player].touched_cp_area = -1;

	return Plugin_Continue;
}

public void OnGatebotFilterFail(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
}

public void OnGatebotFilterPass(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
	int killer = player_data[activator].killer;

	CEcon_SendEventToClientUnique(killer, "TF_MVM_KILL_GATEBOT", 1);

	int cp_area = player_data[activator].touched_cp_area;
	if (cp_area != -1 ) 
	{
		if (IsGiant(activator))
			CEcon_SendEventToClientUnique(killer, "TF_MVM_KILL_GATEBOT_GIANT_CAPTURE", 1);

		// count all players if they touch same cp, if its the last one, activate event
		bool found = false;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (i != activator && IsClientValid(i) && IsPlayerAlive(i) && player_data[i].touched_cp_area == cp_area)
			{
				found = true;
				break;
			}
		}

		if (!found)
		{
			int objective_resource = FindEntityByClassname(-1, "tf_objective_resource");
			// If one of the cps have more than 75% progress, activate event
			if (GetEntPropFloat(objective_resource, Prop_Send, "m_flLazyCapPerc", cp_area) < 0.25) {
				CEcon_SendEventToClientUnique(killer, "TF_MVM_CLEAR_POINT_GATEBOT", 1);
			}
		}

		player_data[activator].touched_cp_area = -1;
	}
}


public Action mvm_begin_wave(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int objective_resource = FindEntityByClassname(-1,"tf_objective_resource");
	int wave_number = GetEntProp(objective_resource, Prop_Send,"m_nMannVsMachineWaveCount");


	if (wave_number == 1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			player_data[i].was_whole_mission = IsClientValid(i) && !IsFakeClient(i);
		}
		CEcon_SendEventToAll("TF_MVM_MISSION_BEGIN", 1, GetRandomInt(0, 9999));
	}
	
	CEcon_SendEventToAll("TF_MVM_WAVE_BEGIN", 1, GetRandomInt(0, 9999));

	bonus_currency_counter = 0;

	int resource = GetPlayerResourceEntity();
	for (int i = 1; i <= MaxClients; i++)
	{
		player_data[i].tank_damage_wave = GetEntProp(resource, Prop_Send, "m_iDamageBoss", 4, i);
	}

	return Plugin_Continue;
}

public void OnWaveEnd(Handle hEvent)
{
	int resource = GetPlayerResourceEntity();
	for (int i = 1; i <= MaxClients; i++)
	{
		player_data[i].tank_damage_wave = 0;
	}
}

public Action mvm_wave_failed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	OnWaveEnd(hEvent);

	int objective_resource = FindEntityByClassname(-1,"tf_objective_resource");
	int wave_number = GetEntProp(objective_resource, Prop_Send,"m_nMannVsMachineWaveCount");

	CEcon_SendEventToAll("TF_MVM_WAVE_FAIL", 1, GetRandomInt(0, 9999));

	if (wave_number == 1)
	{
		CEcon_SendEventToAll("TF_MVM_MISSION_RESET", 1, GetRandomInt(0, 9999));
	}

	return Plugin_Continue;
}

public Action mvm_wave_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		player_data[i].was_whole_mission &= IsClientValid(i) && !IsFakeClient(i);
	}
	CEcon_SendEventToAll("TF_MVM_WAVE_COMPLETE", 1, GetRandomInt(0, 9999));

	OnWaveEnd(hEvent);

	return Plugin_Continue;
}

public Action mvm_tank_destroyed_by_players(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	//Check if one of tanks is a blimp
	bool is_blimp = false;
	for (int i = -1; i != -1; FindEntityByClassname(i, "tank_boss"))
	{
		if (!(GetEntityFlags(i) & FL_ONGROUND))
		{
			int model = GetEntProp(i, Prop_Send, "m_nModelIndexOverrides", 4, 0);

			// If a custom model is being used while being airborne, it assumes its a blimp
			if (model != 0 && model != GetEntProp(i, Prop_Send, "m_nModelIndex"))
			{
				is_blimp = true;
			}
		}
	}

	int resource = GetPlayerResourceEntity();
	for (int i = 1; i <= MaxClients; i++)
	{
		int damage = 0;
		if (IsClientValid(i))
		{
			damage = GetEntProp(resource, Prop_Send, "m_iDamageBoss", 4, i) - player_data[i].tank_damage_wave;
			if (damage > 0) {
				CEcon_SendEventToClientFromGameEvent(i, "TF_MVM_DESTROY_TANK", 1, hEvent);

				if (is_blimp)
				{
					CEcon_SendEventToClientFromGameEvent(i, "TF_MVM_DESTROY_TANK_BLIMP", 1, hEvent);
				}
			}
			
		}
		player_data[i].tank_damage_wave += damage;
	}

	return Plugin_Continue;
}

int resist_client_last;
int resist_tick_last;

int player_hurt_client_last;
int player_hurt_attacker_last;
int player_hurt_tick_last;
int player_hurt_madmilk_last;
public Action player_hurt(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int custom = GetEventInt(hEvent, "custom");
	int damage = GetEventInt(hEvent, "damageamount");
	bool crit = GetEventBool(hEvent, "crit");
	bool minicrit = GetEventBool(hEvent, "minicrit");

	player_hurt_client_last = client;
	player_hurt_attacker_last = attacker;
	player_hurt_tick_last = GetGameTickCount();

	if (IsClientValid(attacker) && attacker != client && IsFakeClient(client))
	{
		// Add to hit tracker;
		player_data[client].hit_tracker |= 1 << (attacker - 1);

		// Don't include overkill damage
		if (GetEntProp(client, Prop_Data, "m_iHealth") < 0)
			damage += GetEntProp(client, Prop_Data, "m_iHealth");

		CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT", damage, hEvent);

		if (custom == 30) // Sentry damage
		{
			CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_SENTRY", damage, hEvent);
		}

		if (custom == 45) // Boot / Jetpack Stomp
		{
			if (IsGiantNotBuster(client))
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_STOMP_ROBOT_GIANT", 1, hEvent);
			}
		}

		if (TF2_IsPlayerInCondition(client, TFCond_Milked))
		{
			player_hurt_madmilk_last = GetConditionProvider(client, TFCond_Milked);
		}

		if (minicrit && TF2_IsPlayerInCondition(attacker, TFCond_Buffed))
		{
			int buff_provider = GetConditionProvider(attacker, TFCond_Buffed);
			if (IsClientValid(buff_provider))
			{
				CEcon_SendEventToClientFromGameEvent(buff_provider, "TF_MVM_DAMAGE_ASSIST_BUFF", damage, hEvent);
			}
		}
	}

	

	// Battalions backup check
	if (IsClientValid(attacker) && IsFakeClient(attacker) && !IsFakeClient(client))
	{
		// Vac resist
		if (attacker != client && resist_client_last == client && resist_tick_last == GetGameTickCount())
		{
			float dmg_resisted = 0.0;
			int healer = 0;
			bool has_vac_uber = TF2_IsPlayerInCondition(client, TFCond_UberBulletResist) || TF2_IsPlayerInCondition(client, TFCond_UberBlastResist) || TF2_IsPlayerInCondition(client, TFCond_UberFireResist);
			bool has_vac_heal = TF2_IsPlayerInCondition(client, TFCond_SmallBulletResist) || TF2_IsPlayerInCondition(client, TFCond_SmallBlastResist) || TF2_IsPlayerInCondition(client, TFCond_SmallFireResist);
			
			// Assume regular resist rate
			if (has_vac_uber)
			{
				healer = GetConditionProvider(client, TFCond_UberBulletResist);
				if (!IsClientValid(healer))
				{
					healer = GetConditionProvider(client, TFCond_UberBlastResist);
				}
				if (!IsClientValid(healer))
				{
					healer = GetConditionProvider(client, TFCond_UberFireResist);
				}

				dmg_resisted = damage * 3.0;
				if (crit)
				{
					dmg_resisted += damage * 4.0 * 2.0;
				}
			}
			else if (has_vac_heal)
			{
				healer = GetConditionProvider(client, TFCond_SmallBulletResist);
				if (!IsClientValid(healer))
				{
					healer = GetConditionProvider(client, TFCond_SmallBlastResist);
				}
				if (!IsClientValid(healer))
				{
					healer = GetConditionProvider(client, TFCond_SmallFireResist);
				}

				dmg_resisted = damage * 0.18;
			}

			// Find vac resist medics
			if (healer > 0)
			{
				CEcon_SendEventToClientUnique(healer, "TF_MVM_VAC_BLOCK_DAMAGE", RoundFloat(dmg_resisted));
			}
		}

		if (TF2_IsPlayerInCondition(client, TFCond_DefenseBuffed))
		{
			// Find buff provider
			int buff_provider = GetConditionProvider(client, TFCond_DefenseBuffed);

			if (IsClientValid(buff_provider))
			{
				CEcon_SendEventToClientUnique(buff_provider, "TF_MVM_BATTALION_BACKUP_BLOCK_DAMAGE", damage);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action damage_resisted(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	resist_client_last = GetEventInt(hEvent, "entindex");
	resist_tick_last = GetGameTickCount();
	PrintToChatAll("Resist");	
}

int damagecustom_last;
public Action OnPlayerDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	damagecustom_last = damagecustom;
}

public void OnPlayerDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	PrintToChatAll("Receive damage post %f", damage);	
	if (attacker > 0)
	PrintToChatAll("Attacker metal hurt post %d", GetEntProp(attacker, Prop_Data, "m_iAmmo", 4, 3));
	if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && damagecustom_last != 2) // backstab
	{
		// Multiply crit damage
		if ((damagetype & DMG_CRIT) == DMG_CRIT)
		{
			damage *= 3.0;
		}

		// Find ubercharged medic

		int healer = GetConditionProvider(victim, TFCond_Ubercharged);

		bool valid = healer != victim;

		// Count damage absorbed by medic if he is healing someone
		if (!valid)
		{
			int medigun = GetPlayerWeaponSlot(healer, 1);
			if (medigun != -1)
			{
				char classname[32];
				GetEntityClassname(medigun, classname, sizeof(classname));
				if (strcmp(classname, "tf_weapon_medigun") == 0)
				{
					int target = GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
					valid = target > 0;
				}
			}
		}

		if (valid)
		{
			CEcon_SendEventToClientUnique(healer, "TF_MVM_UBER_BLOCK_DAMAGE", RoundFloat(damage));
		}
	}

	
}

public Action player_ignited(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "victim_entindex");
	int attacker = GetEventInt(hEvent, "pyro_entindex");

	if (IsClientValid(attacker) && attacker != client && IsFakeClient(client))
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_IGNITE_ROBOT", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action player_healed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int patient = GetClientOfUserId(GetEventInt(hEvent, "patient"));
	int healer = GetClientOfUserId(GetEventInt(hEvent, "healer"));
	int amount = GetEventInt(hEvent, "amount");

	if (IsClientValid(healer) && healer != patient)
	{
		if (!IsFakeClient(healer))
		{
			if (IsFakeClient(patient))
			{
				CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_ROBOTS", amount, hEvent);
			}
			else
			{
				CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_TEAMMATES", amount, hEvent);
			}

			if (player_hurt_attacker_last == patient && player_hurt_madmilk_last == healer && player_hurt_tick_last == GetGameTickCount())
			{
				CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_MADMILK", amount, hEvent);
			}

			if (TF2_IsPlayerInCondition(patient, TFCond_RegenBuffed) && GetConditionProvider(patient, TFCond_RegenBuffed) == healer)
			{
				CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_CONCHEROR", amount, hEvent);
			}
		}
	}

	return Plugin_Continue;
}

public Action mvm_medic_powerup_shared(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "player");

	int medigun = GetPlayerWeaponSlot(client, 1);

	if (medigun != -1)
	{
		int target = GetEntPropEnt(client, Prop_Send, "m_hHealingTarget");
		if (IsClientValid(target) && IsFakeClient(target))
		{
			CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_CANTEEN_SHARE_ROBOT", 1, hEvent);
		}
	}
	
}

public Action player_chargedeployed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int patient = GetClientOfUserId(GetEventInt(hEvent, "targetid"));
	int healer = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (IsClientValid(patient) && IsFakeClient(patient))
	{
		CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_UBER_DEPLOY_ROBOT", 1, hEvent);
	}
}

public Action medic_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int healer = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	bool charged = GetEventBool(hEvent, "charged");

	// Only count regular uber
	bool charged_uber = charged && GetAttributeValue(healer, "set_charge_type", 0.0) == 0.0;
	if (charged_uber && IsClientValid(healer) && IsFakeClient(healer))
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_UBER_MEDIC", 1, hEvent);

		if (IsGiant(healer))
			CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_GIANT_UBER_MEDIC", 1, hEvent);
		
	}

	return Plugin_Continue;
}


public Action mvm_pickup_currency(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "player");
	int currency = GetEventInt(hEvent, "currency");

	CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_COLLECT_CURRENCY", currency, hEvent);
	CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_ALL_PLAYERS", currency, GetRandomInt(0, 9999));
	return Plugin_Continue;
}

public Action mvm_creditbonus_wave(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	bonus_currency_counter++;

	if (bonus_currency_counter == 1)
	{
		CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_BONUS", 1, GetRandomInt(0, 9999));
	}
	else if (bonus_currency_counter == 2)
	{
		CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_BONUS_ALL", 1, GetRandomInt(0, 9999));
	}

	return Plugin_Continue;
}

public Action player_carryobject(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	int builder = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int type = GetEventInt(hEvent, "object");
	int entity = GetEventInt(hEvent, "index");
	if (type == 2) //OBJ_SENTRYGUN
	{
		player_data[builder].buster_save_sentry = 0;

		float vecobj[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecobj);

		float vecbuilder[3];
		GetEntPropVector(builder, Prop_Send, "m_vecOrigin", vecbuilder);

		float buster_range_sq = buster_range_cvar.FloatValue * buster_range_cvar.FloatValue;

		// Only count long range grabs, exclude wrench grabs
		if (GetVectorDistance(vecobj, vecbuilder, true) > 125.0 * 125.0)
		{
			// Search for sentry busters
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientValid(i) && IsFakeClient(i) && GetClientTeam(i) != GetClientTeam(builder) && IsSentryBuster(i))
				{
					float vecbuster[3];
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecbuster);

					float vecvelbuster[3];
					GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", vecvelbuster);

					PrintToChatAll("buster %f", GetVectorLength(vecvelbuster, true));
					if (GetVectorDistance(vecobj, vecbuster, true) < buster_range_sq)
					{
						player_data[builder].buster_save_sentry = i;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action player_dropobject(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int builder = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int type = GetEventInt(hEvent, "object");
	int entity = GetEventInt(hEvent, "index");
	if (type == 2) //OBJ_SENTRYGUN
	{
		int buster = player_data[builder].buster_save_sentry;
		if (IsClientValid(buster) && IsPlayerAlive(buster))
		{
			float vecobj[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecobj);

			float vecbuster[3];
			GetEntPropVector(buster, Prop_Send, "m_vecOrigin", vecbuster);

			float buster_range_sq = buster_range_cvar.FloatValue * buster_range_cvar.FloatValue;

			if (GetVectorDistance(vecobj, vecbuster, true) > buster_range_sq)
			{
				CEcon_SendEventToClientFromGameEvent(builder, "TF_MVM_SAVE_SENTRY_RESCUE", 1, hEvent);
			}
		}
		else if (buster > 0)
		{
			CEcon_SendEventToClientFromGameEvent(builder, "TF_MVM_SAVE_SENTRY_RESCUE", 1, hEvent);
		}
	}

	return Plugin_Continue;
}

public Action player_stunned(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int stunner = GetClientOfUserId(GetEventInt(hEvent, "stunner"));
	int victim = GetClientOfUserId(GetEventInt(hEvent, "victim"));
	bool capping = GetEventBool(hEvent, "victim_capping");
	bool big_stun = GetEventBool(hEvent, "big_stun");
	PrintToChatAll("stun %d %d", stunner, victim);


	if (stunner == 0)
	{
		float vecvictim[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vecvictim);


		// Search for rocket pack pyros nearbly
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientValid(i) && !IsFakeClient(i) && GetClientTeam(i) != GetClientTeam(victim) && TF2_IsPlayerInCondition(i, TFCond_RocketPack))
			{
				
				float vecpyro[3];
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecpyro);
				
				if (GetVectorDistance(vecvictim, vecpyro, true) < 500.0 * 500.0)
				{
					stunner = i;
					CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_WITH_JETPACK", 1, hEvent);

					if (TF2_GetPlayerClass(victim) == TFClass_Medic)
					{
						CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_MEDIC_WITH_JETPACK", 1, hEvent);
					}
				}
				break;
			}
		}
	}

	if (IsClientValid(stunner) && IsFakeClient(victim) && !IsFakeClient(stunner))
	{
		CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT", 1, hEvent);

		if (IsGiantNotBuster(victim))
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_GIANT", 1, hEvent);
		}

		if (capping)
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_CAPPING", 1, hEvent);
		}

		if (big_stun)
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_MOONSHOT", 1, hEvent);
		}

		if (GetEntPropEnt(victim, Prop_Send, "m_hItem") != -1)
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_BOMB_CARRIER", 1, hEvent);
		}
	}
	
	return Plugin_Continue;
}

public Action deploy_buff_banner(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int buff_type = GetEventInt(hEvent, "buff_type");
	int buff_owner = GetClientOfUserId(GetEventInt(hEvent, "buff_owner"));
	
	CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_BUFF_ACTIVATE", 1, hEvent);

	switch (buff_type)
	{
		case 1: CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_BUFF_BANNER_ACTIVATE", 1, hEvent);
		case 2: CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_BATTALION_BACKUP_ACTIVATE", 1, hEvent);
		case 3: CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_CONCHEROR_ACTIVATE", 1, hEvent);
	}
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	
	switch(cond)
	{
		case TFCond_Milked:
		{
			int entity = GetConditionProvider(client, cond);
			if (IsClientValid(entity) && !IsFakeClient(entity) && IsFakeClient(client))
			{
				CEcon_SendEventToClientUnique(entity, "TF_MVM_MADMILK_ROBOT", 1);

				if (IsGiantNotBuster(client))
				{
					CEcon_SendEventToClientUnique(entity, "TF_MVM_MILK_ROBOT_GIANT", 1);

					if (TF2_IsPlayerInCondition(client, TFCond_MarkedForDeath))
					{
						CEcon_SendEventToClientUnique(entity, "TF_MVM_MILK_MARK_ROBOT_GIANT", 1);
					}
				}

				// Snare upgrade detection
				if (GetAttributeValue(entity, "applies_snare_effect", 0.0) != 0.0)
				{
					CEcon_SendEventToClientUnique(entity, "TF_MVM_STUN_MILK_ROBOT", 1);
					if (IsGiantNotBuster(client) && TF2_GetPlayerClass(client) == TFClass_Scout)
					{
						CEcon_SendEventToClientUnique(entity, "TF_MVM_STUN_MILK_ROBOT_GIANT_SCOUT", 1);
					}
				} 
			}
		}
		case TFCond_MarkedForDeath:
		{
			int entity = GetConditionProvider(client, cond);
			if (IsClientValid(entity) && !IsFakeClient(entity) && IsFakeClient(client))
			{
				CEcon_SendEventToClientUnique(entity, "TF_MVM_MARK_FOR_DEATH_ROBOT", 1);

				if (IsGiantNotBuster(client))
				{
					CEcon_SendEventToClientUnique(entity, "TF_MVM_MARK_FOR_DEATH_ROBOT_GIANT", 1);

					if (TF2_IsPlayerInCondition(client, TFCond_Milked))
					{
						CEcon_SendEventToClientUnique(entity, "TF_MVM_MILK_MARK_ROBOT_GIANT", 1);
					}
				}
			}
		}
		case TFCond_CritOnKill:
		{
			//player_data[client].critboost_time = GetEngineTime();
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	switch(cond)
	{
		case TFCond_CritOnKill:
		{
			CEcon_SendEventToClientUnique(client, "TF_MVM_CRITBOOST_ON_KILL_STOP", 1);
		}
	}
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

public bool IsSentryBuster(int client)
{

	char model[256];
	GetEntPropString(client, Prop_Send, "m_iszCustomModel", model, sizeof(model));

	bool buster_model = strcmp(model, "models/bots/demo/bot_sentry_buster.mdl") == 0;

	return buster_model;
}

public bool IsGiant(int client)
{
	return GetEntProp(client, Prop_Send, "m_bIsMiniBoss") != 0;
}

public bool IsGiantNotBuster(int client)
{
	return IsGiant(client) && !IsSentryBuster(client);
}

public bool IsBoss(int client)
{
	return GetEntProp(client, Prop_Send, "m_bUseBossHealthBar") != 0;
}

public void GetTFClassName(TFClassType class, char[] buf, int len)
{
	switch (class)
	{
		case TFClass_Scout: strcopy(buf, len, "SCOUT");
		case TFClass_Soldier: strcopy(buf, len, "SOLDIER");
		case TFClass_Pyro: strcopy(buf, len, "PYRO");
		case TFClass_DemoMan: strcopy(buf, len, "DEMOMAN");
		case TFClass_Heavy: strcopy(buf, len, "HEAVY");
		case TFClass_Engineer: strcopy(buf, len, "ENGINEER");
		case TFClass_Medic: strcopy(buf, len, "MEDIC");
		case TFClass_Sniper: strcopy(buf, len, "SNIPER");
		case TFClass_Spy: strcopy(buf, len, "SPY");
	}
}

public bool IsTauntKill(int damageTypeCustom)
{
	switch (damageTypeCustom)
	{
		case 7: return true;
		case 9: return true;
		case 10: return true;
		case 13: return true;
		case 15: return true;
		case 21: return true;
		case 24: return true;
		case 29: return true;
		case 33: return true;
		case 53: return true;
		case 63: return true;
		case 82: return true;
	}
	return false;
}

public int GetConditionProvider(int client, TFCond cond)
{
	if (!IsClientValid(client) || get_condition_provider_handle == null)
	{
		return -1;
	}

	int shared = FindSendPropInfo("CTFPlayer", "m_Shared");
	int entity = SDKCall(get_condition_provider_handle, GetEntityAddress(client) + view_as<Address>(shared), view_as<int>(cond));
	return entity;
	
}

public float GetAttributeValue(int entity, char[] attribute, float inValue)
{
	if (attrib_float_handle == null)
	{
		return inValue;
	}

	return SDKCall(attrib_float_handle, inValue, attribute, entity, 0, false);
	
}

public bool HasFullUberOfType(int client, int type)
{
	int medigun = GetPlayerWeaponSlot(client, 1);
	if (medigun != -1)
	{
		char classname[32];
		GetEntityClassname(medigun, classname, sizeof(classname));
		if (strcmp(classname, "tf_weapon_medigun") == 0 && GetEntProp(medigun, Prop_Send, "m_flChargeLevel") >= 1.0)
		{
			return type == -1 || RoundFloat(GetAttributeValue(medigun, "set_charge_type", 0.0)) == type;
		}
	}	
	return false;
}