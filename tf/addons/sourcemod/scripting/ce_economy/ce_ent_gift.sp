#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <ce_core>
#include <ce_manager_attributes>

public Plugin myinfo =
{
	name = "[CE Entity] ent_gift",
	author = "Creators.TF Team",
	description = "Holiday Gift Pickup",
	version = "1.00",
	url = "https://creators.tf"
}

public int Gift_Create(float pos[3])
{
	int iEnt = CreateEntityByName("prop_physics_override");
	
}