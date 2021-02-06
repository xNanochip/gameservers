//============= Copyright Amper Software 2021, All rights reserved. =======//
//
// Purpose: Used for tracking different events happening in game, and connect
// them with economy features, like quests or achievements.
//
//=========================================================================//

#define MAX_EVENT_UNIQUE_INDEX_INT 10000

Handle g_hOnClientEvent;
int m_iLastWeapon[MAXPLAYERS + 1];

public void Events_OnPluginStart()
{
	g_hOnClientEvent = CreateGlobalForward("CEcon_OnClientEvent", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);

	RegAdminCmd("ce_events_test", cTestEvnt, ADMFLAG_ROOT, "");
	
	Events_LateHooking();
}

public APLRes Events_AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CEcon_SendEventToClient", Native_SendEventToClient);
	CreateNative("CEcon_SendEventToClientUnique", Native_SendEventToClientUnique);
	CreateNative("CEcon_SendEventToClientFromGameEvent", Native_SendEventToClientFromGameEvent);
	CreateNative("CEcon_SendEventToAll", Native_SendEventToAll);
	CreateNative("CEcon_GetLastUsedWeapon", Native_LastUsedWeapon);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "obj_") != -1)
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	if(StrEqual(classname, "player"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	if(StrContains(classname, "item_healthkit") != -1)
	{
		SDKHook(entity, SDKHook_Touch, OnTouch);
	}
}
public void Events_LateHooking()
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_*")) != -1)
	{
		SDKHook(ent, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	ent = -1;
	while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
	{
		SDKHook(ent, SDKHook_Touch, OnTouch);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public Action OnTouch(int entity, int toucher)
{
	if (!IsClientValid(toucher))return Plugin_Continue;

	int hOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (hOwner == toucher)return Plugin_Continue;

	// If someone touched a sandvich, mark heavy's secondary weapon as last used.
	if(IsClientValid(hOwner))
	{
		if(TF2_GetPlayerClass(hOwner) == TFClass_Heavy)
		{
			int iLunchBox = GetPlayerWeaponSlot(hOwner, 1);
			if(IsValidEntity(iLunchBox))
			{
				m_iLastWeapon[hOwner] = iLunchBox;
			}
		}
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if(IsClientValid(attacker))
	{
		if(IsValidEntity(inflictor))
		{
			// If inflictor entity has a "m_hBuilder" prop, that means we've killed with a building.
			// Setting our wrench as last weapon.
			if(HasEntProp(inflictor, Prop_Send, "m_hBuilder"))
			{
				if(TF2_GetPlayerClass(attacker) == TFClass_Engineer)
				{
					int iWrench = GetPlayerWeaponSlot(attacker, 2);
					if(IsValidEntity(iWrench))
					{
						m_iLastWeapon[attacker] = iWrench;
					}
				}
			} else {
				// Player killed someone with a hitscan weapon. Saving the one.
				m_iLastWeapon[attacker] = weapon;
			}
		}
	}
}

public Action cTestEvnt(int client, int args)
{
	if(IsClientValid(client))
	{
		char sArg1[128], sArg2[11];
		GetCmdArg(1, sArg1, sizeof(sArg1));
		GetCmdArg(2, sArg2, sizeof(sArg2));

		CEcon_SendEventToClientUnique(client, sArg1, MAX(StringToInt(sArg2), 1));
	}

	return Plugin_Handled;
}

public void LateHooking()
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_*")) != -1)
	{
		SDKHook(ent, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	ent = -1;
	while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
	{
		SDKHook(ent, SDKHook_Touch, OnTouch);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public any Native_LastUsedWeapon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return m_iLastWeapon[client];
}

public any Native_SendEventToClientFromGameEvent(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	char event[128];
	GetNativeString(2, event, sizeof(event));
	
	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);
	
	CEcon_SendEventToClient(client, event, add, unique_id);
}

public any Native_SendEventToClientUnique(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	char event[128];
	GetNativeString(2, event, sizeof(event));
	
	int add = GetNativeCell(3);
	int unique_id = GetRandomInt(0, MAX_EVENT_UNIQUE_INDEX_INT);
	
	CEcon_SendEventToClient(client, event, add, unique_id);
}

public any Native_SendEventToAll(Handle plugin, int numParams)
{
	char event[128];
	GetNativeString(1, event, sizeof(event));
	
	int add = GetNativeCell(2);
	int unique_id = GetNativeCell(3);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientValid(i))continue;
		
		CEcon_SendEventToClient(i, event, add, unique_id);
	}
}

public any Native_SendEventToClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	char event[128];
	GetNativeString(2, event, sizeof(event));
	
	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);

	Call_StartForward(g_hOnClientEvent);
	Call_PushCell(client);
	Call_PushString(event);
	Call_PushCell(add);
	Call_PushCell(unique_id);
	Call_Finish();
}