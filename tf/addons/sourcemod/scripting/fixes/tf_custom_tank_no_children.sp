#pragma semicolon 1

#include <sdkhooks>

public Plugin myinfo =
{
	name = "[MvM] Custom Tanks Attachables Remover.",
	author = "Moonly Days",
	description = "Removes attachables on tanks with custom models.",
	version = "1.0",
	url = "https://moonlydays.com"
};

public void OnEntityCreated(int entity, const char[] classname)
{
	PrintToChatAll("Spawned: %s", classname);
	if(StrEqual(classname, "prop_dynamic"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnPropDynamicSpawn);
	}
}

public Action OnPropDynamicSpawn(int entity)
{
	// Get owner entity.
	int iTank = GetEntPropEnt(entity, Prop_Send, "moveparent");
	PrintToChatAll("%d %d", iTank, entity);
	
	if(IsValidEntity(iTank))
	{
		char sClassname[32];
		GetEntityClassname(iTank, sClassname, sizeof(sClassname));
		PrintToChatAll(sClassname);
	}
}