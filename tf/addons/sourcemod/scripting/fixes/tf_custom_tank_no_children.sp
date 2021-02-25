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
	if(StrEqual(classname, "prop_dynamic"))
	{
		RequestFrame(RF_OnPropDynamicSpawn, entity);
	}
}

public void RF_OnPropDynamicSpawn(any entity)
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