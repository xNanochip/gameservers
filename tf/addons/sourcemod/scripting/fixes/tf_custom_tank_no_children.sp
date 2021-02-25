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
		// CreateTimer(1.0, RF_OnPropDynamicSpawn, entity);
	}
}

public Action RF_OnPropDynamicSpawn(Handle timer, any entity)
{
	// Make sure this entity still exists.
	if (!IsValidEntity(entity))return;
	
	char sClassname[32];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	// Make sure we are still prop_dynamic.
	if (!StrEqual(sClassname, "prop_dynamic"))return;
	
	// Get owner entity.
	int iTank = GetEntPropEnt(entity, Prop_Send, "moveparent");
	if(IsValidEntity(iTank))
	{
		// Make sure our parent is tank_boss.
		GetEntityClassname(iTank, sClassname, sizeof(sClassname));
		if (!StrEqual(sClassname, "tank_boss"))return;
		
		char sModel[PLATFORM_MAX_PATH];
		GetEntPropString(iTank, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
		
		PrintToChatAll("Tank Models: %d %d", PrecacheModel(sModel), GetEntProp(iTank, Prop_Send, "m_nModelIndex"));
	}
}