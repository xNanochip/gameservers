#pragma semicolon 1
#pragma newdecls required

#include <cecon_items>
#include <sdktools>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "[CE Attribute] ammo sandwich",
	author = "Creators.TF Team",
	description = "ammo sandwich",
	version = "1.00",
	url = "https://creators.tf"
};

public void OnMapStart()
{
	PrecacheModel("models/items/ammo_plate.mdl");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "item_healthammokit"))
	{
		RequestFrame(RF_SetGearWichPlate, entity);
	}
}

public void RF_SetGearWichPlate(any plate)
{
	SetEntProp(plate, Prop_Send, "m_nModelIndex", PrecacheModel("models/items/ammo_plate.mdl"));
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{/*
	if(TF2_GetPlayerClass(client) == TFClass_Heavy)
	{
		int iLunchBox = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if (CEconItems_IsEntityCustomEconItem(iLunchBox))
		{
			bool bIsAmmoLunchbox = CEconItems_GetEntityAttributeInteger(iLunchBox, "lunchbox adds minicrits") == 5;
			if(bIsAmmoLunchbox)
			{
				// Heavy is eating ammo sandwich.
				
				bool bConsume = false;
				
				
				int iMinigun = GetPlayerWeaponSlot(client, 0);
				int iMaxAmmo = GetEntProp(iMinigun, Prop_Data, "m_iPrimaryAmmoCount");
				int iAmmo;
				if(IsValidEntity(iMinigun))
				{
					iAmmo = GetEntProp(iMinigun, Prop_Send, "m_iClip1", 1);
				}
				
				PrintToChatAll("%d/%d", iAmmo, iMaxAmmo);
			}
		}
	}*/
}