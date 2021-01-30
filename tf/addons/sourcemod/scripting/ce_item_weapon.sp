 //============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Handler for the Weapon custom item type.
// 
//=========================================================================//

#include <tf2items>

#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

#include <cecon>
#include <cecon_items>

#include <tf2wearables>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "Creators.TF (Weapon)", 
	author = "Creators.TF Team", 
	description = "Handler for the Weapon custom item type.", 
	version = "1.0", 
	url = "https://creators.tf"
};

enum struct CEItemDefinitionWeapon
{
	int m_iIndex;
	
    char m_sClassName[64];
	int m_iBaseIndex;
	
    int m_iClip;
    int m_iAmmo;
    
	char m_sWorldModel[256];
}

ArrayList m_hDefinitions;

char m_sWeaponModel[2049][256];
int m_hLastWeapon[MAXPLAYERS + 1];

//--------------------------------------------------------------------
// Purpose: Precaches all the items of a specific type on plugin
// startup.
//--------------------------------------------------------------------
public void OnAllPluginsLoaded()
{
	ProcessEconSchema(CEcon_GetEconomySchema());
	
	// Hook all players that are already in game.
	LateSDKHooks();
}

//--------------------------------------------------------------------
// Purpose: Fired when an entity is created. Used to SDK hook
// specific entities.
//--------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	strcopy(m_sWeaponModel[entity], PLATFORM_MAX_PATH, "");

	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		// Hook dropped weapon and remove them immediately.
		SDKHook(entity, SDKHook_SpawnPost, OnWeaponDropped);
	}

	if(StrEqual(classname, "player"))
	{
		// Hook player's weapon switch.
		SDKHook(entity, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	}
}

//--------------------------------------------------------------------
// Purpose: Used to hook entities if this plugin was late loaded.
//--------------------------------------------------------------------
public void LateSDKHooks()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		}
	}
}

//--------------------------------------------------------------------
// Purpose: If schema was late updated (by an update), reprecache
// everything again.
//--------------------------------------------------------------------
public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ProcessEconSchema(hSchema);
}

//--------------------------------------------------------------------
// Purpose: This is called upon item equipping process.
//--------------------------------------------------------------------
public int CEconItems_OnEquipItem(int client, CEItem item, const char[] type)
{
	if (!StrEqual(type, "weapon"))return -1;
	
	CEItemDefinitionWeapon hDef;
	if (FindWeaponDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))
	{
		if(StrEqual(hDef.m_sClassName, "tf_wearable"))
		{
			
		} else {
			int iWeapon = CreateWeapon(client, hDef.m_iBaseIndex, hDef.m_sClassName, item.m_nQuality);
			if(iWeapon > -1)
			{
				int item_slot = TF2Econ_GetItemSlot(hDef.m_iBaseIndex, TF2_GetPlayerClass(client));
				
				//----------------------------------------------//
				// Some weapons	have their slot index mismatched with the real value.
				// Here are some weapons that have a different slot index.
				
				// Hardcode revolvers to 0th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_revolver"))
				{
					item_slot = 0;
				}
				// Hardcode the sappers to 1th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_sapper"))
				{
					SetEntProp(iWeapon, Prop_Send, "m_iObjectType", 3, 4, 0);
					SetEntProp(iWeapon, Prop_Data, "m_iSubType", 3, 4, 0);
					item_slot = 1;
				}
				// Hardcode the PDAs to 3th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_pda_engineer_build"))
				{
					item_slot = 3;
				}
				// Hardcode the PDAs to 3th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_pda_engineer_build"))
				{
					item_slot = 3;
				}
				
				// Removing all wearables that take up the same slot as this weapon.
				// Some weapons are also considered to be wearables. For example Manntreads.
				// We need to get rid of them too.
				int iEdict;
				while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
				{
					if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client) continue;
	
					char sClass[32];
					GetEntityNetClass(iEdict, sClass, sizeof(sClass));
					if (!StrEqual(sClass, "CTFWearable")) continue;
	
					int iDefIndex = GetEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex");
					if (iDefIndex == 0xFFFF)continue;
					
					int iSlot = TF2Econ_GetItemSlot(iDefIndex, TF2_GetPlayerClass(client));
					if (iSlot == item_slot)
					{
						TF2Wear_RemoveWearable(client, iEdict);
						AcceptEntityInput(iEdict, "Kill");
					}
				}
	
				if(hDef.m_iClip > 0)
				{
					SetEntProp(iWeapon, Prop_Send, "m_iClip1", hDef.m_iClip);
				}
	
				if(hDef.m_iAmmo > 0)
				{
					SetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + (item_slot == 0 ? 4 : 8), hDef.m_iAmmo);
				}
	
				strcopy(m_sWeaponModel[iWeapon], sizeof(m_sWeaponModel[]), hDef.m_sWorldModel);
	
				// Making weapon visible.
				SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", 1);
	
				TF2_RemoveWeaponSlot(client, item_slot);
				EquipPlayerWeapon(client, iWeapon);
				
				DataPack hPack = new DataPack();
				hPack.WriteCell(client);
				hPack.WriteCell(iWeapon);
				hPack.Reset();
				
				RequestFrame(RF_OnWeaponDraw, hPack);
	
				return iWeapon;
			}
		}
	}
	return -1;
}

//--------------------------------------------------------------------
// Purpose: Finds a weapon's definition by the definition index.
// Returns true if found, false otherwise. 
//--------------------------------------------------------------------
public bool FindWeaponDefinitionByIndex(int defid, CEItemDefinitionWeapon output)
{
	if (m_hDefinitions == null)return false;
	
	for (int i = 0; i < m_hDefinitions.Length; i++)
	{
		CEItemDefinitionWeapon hDef;
		m_hDefinitions.GetArray(i, hDef);
		
		if (hDef.m_iIndex == defid)
		{
			output = hDef;
			return true;
		}
	}
	
	return false;
}

//--------------------------------------------------------------------
// Purpose: Parses the schema and reads precaches all the items.
//--------------------------------------------------------------------
public void ProcessEconSchema(KeyValues kv)
{
	if (kv == null)return;
	
	delete m_hDefinitions;
	m_hDefinitions = new ArrayList(sizeof(CEItemDefinitionWeapon));
	
	if (kv.JumpToKey("Items"))
	{
		if (kv.GotoFirstSubKey())
		{
			do {
				char sType[16];
				kv.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "weapon"))continue;
				
				char sIndex[11];
				kv.GetSectionName(sIndex, sizeof(sIndex));
				
				CEItemDefinitionWeapon hDef;
				hDef.m_iIndex = StringToInt(sIndex);
				hDef.m_iBaseIndex = kv.GetNum("item_index");
				
				hDef.m_iClip = kv.GetNum("weapon_clip");
				hDef.m_iAmmo = kv.GetNum("weapon_ammo");
				
				kv.GetString("world_model", hDef.m_sWorldModel, sizeof(hDef.m_sWorldModel));
				kv.GetString("item_class", hDef.m_sClassName, sizeof(hDef.m_sClassName));
				
				m_hDefinitions.PushArray(hDef);
			} while (kv.GotoNextKey());
		}
	}
	
	kv.Rewind();
}

//--------------------------------------------------------------------
// Purpose: Creates a TF2 weapon, using TF2Items extension.
//--------------------------------------------------------------------
public int CreateWeapon(int client, int index, const char[] classname, int quality)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);

	char class[128];
	strcopy(class, sizeof(class), classname);

	if (TF2_GetPlayerClass(client) == TFClass_Unknown)return -1;

	if(StrEqual(class, "tf_weapon_saxxy"))
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: Format(class, sizeof(class), "tf_weapon_bat");
			case TFClass_Sniper: Format(class, sizeof(class), "tf_weapon_club");
			case TFClass_Soldier: Format(class, sizeof(class), "tf_weapon_shovel");
			case TFClass_DemoMan: Format(class, sizeof(class), "tf_weapon_bottle");
			case TFClass_Medic: Format(class, sizeof(class), "tf_weapon_bonesaw");
			case TFClass_Spy: Format(class, sizeof(class), "tf_weapon_knife");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_wrench");
			case TFClass_Pyro: Format(class, sizeof(class), "tf_weapon_fireaxe");
			case TFClass_Heavy: Format(class, sizeof(class), "tf_weapon_fireaxe");
		}
	} else if(StrEqual(class, "tf_weapon_shotgun"))
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier: Format(class, sizeof(class), "tf_weapon_shotgun_soldier");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_shotgun_primary");
			case TFClass_Pyro: Format(class, sizeof(class), "tf_weapon_shotgun_pyro");
			case TFClass_Heavy: Format(class, sizeof(class), "tf_weapon_shotgun_hwg");
		}
	} else if(StrEqual(class, "tf_weapon_pistol"))
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: Format(class, sizeof(class), "tf_weapon_pistol_scout");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_pistol");
		}
	}

	TF2Items_SetClassname(hWeapon, class);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetQuality(hWeapon, quality);

	int iWep = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
	
	SetEntProp(iWep, Prop_Send, "m_iEntityLevel", -1);
	return iWep;
}

//--------------------------------------------------------------------
// Purpose: Returns true if weapon's world model is supposed
// to be visible.
//--------------------------------------------------------------------
public bool ShouldDrawWeaponWorldModel(int client, int weapon)
{
	if (!ShouldDrawWeaponModel(client, weapon))return false;
	return true;
}

//--------------------------------------------------------------------
// Purpose: Returns true if weapon's view model is supposed
// to be visible.
//--------------------------------------------------------------------
public bool ShouldDrawWeaponViewModel(int client, int weapon)
{
	if(IsFakeClient(client))return false;
	if (!ShouldDrawWeaponModel(client, weapon))return false;
	return true;
}

//--------------------------------------------------------------------
// Purpose: Returns true if weapon is supposed to be visible.
//--------------------------------------------------------------------
public bool ShouldDrawWeaponModel(int client, int weapon)
{
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)return false;
	if (!CEconItems_IsEntityCustomEconItem(weapon))return false;
	if (StrEqual(m_sWeaponModel[weapon], ""))return false;
	return true;
}

//--------------------------------------------------------------------
// Purpose: This function handles weapons custom models appearance.
//--------------------------------------------------------------------
public void OnDrawWeapon(int client, int iWeapon)
{
	// Make sure to remove all tied wearables before we do anything else.
	TF2Wear_RemoveAllTiedWearables(iWeapon);
	
	// Draw models only if we're supposed to be drawing them in the first place.
	if(ShouldDrawWeaponModel(client, iWeapon))
	{
		// If client is a bot, don't bother with Wearables bs and just change the model of the weapon.
		// However, this breaks animations in first person, so we can't really do that with real players.
		if(IsFakeClient(client))
		{
			for (int i = 0; i <= 3; i++)
			{
				SetEntProp(iWeapon, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(m_sWeaponModel[iWeapon]), 4, i);
			}
		} else {
	
			SetEntityRenderMode(iWeapon, RENDER_TRANSALPHA);
			SetEntityRenderColor(iWeapon, 0, 0, 0, 0);
	
			SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 1);
			
			TF2Wear_CreateWeaponTiedWearable(iWeapon, false, m_sWeaponModel[iWeapon]);
			TF2Wear_CreateWeaponTiedWearable(iWeapon, true, m_sWeaponModel[iWeapon]);
		}
	}
}


public void OnWeaponSwitch(int client, int weapon)
{
	if (m_hLastWeapon[client] == weapon)return; // Nothing has changed.
	int iLastWeapon = m_hLastWeapon[client];

	if(iLastWeapon > 0)
	{
		TF2Wear_RemoveAllTiedWearables(iLastWeapon);
	}

	m_hLastWeapon[client] = weapon;
	float flHolsterTime;

	// HACK: The only weapon that has "holster_anim_time" attribute is Thermal Thruster.
	// We can check the "m_flHolsterAnimTime" netprop of the player that is always >0 when we're
	// holstering the rocketpack. However I can't understand what defines its value.
	//
	// We need to find a way to detect exact amount of time needed for the animation to play, so that
	// this doesn't break when Valve push new weapons using that attrib. (Which is probably never, so we're fine for now.)
	//
	// P.S. Inb4 this doesn't age well.

	if(GetEntPropFloat(client, Prop_Send, "m_flHolsterAnimTime") > 0)
	{
		// HACK: Sets the holster time to 0.8 as that's the time rocketpack uses to holster.
		flHolsterTime = 0.8;
	}

	if(CEconItems_IsEntityCustomEconItem(weapon))
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(client);
		hPack.WriteCell(weapon);
		hPack.Reset();

		if(flHolsterTime > 0.0)
		{
			CreateTimer(flHolsterTime, Timer_OnWeaponDraw, hPack);
		} else {
			RequestFrame(RF_OnWeaponDraw, hPack);
		}
	}
}

public Action Timer_OnWeaponDraw(Handle timer, DataPack hPack)
{
	RequestFrame(RF_OnWeaponDraw, hPack);
}

public void RF_OnWeaponDraw(DataPack hPack)
{
	int client = hPack.ReadCell();
	int weapon = hPack.ReadCell();
	hPack.Reset();
	delete hPack;

	OnDrawWeapon(client, weapon);
}

public void OnWeaponDropped(int weapon)
{
	if(IsValidEntity(weapon) && GetEntProp(weapon, Prop_Send, "m_iEntityLevel") == -1)
	{
		AcceptEntityInput(weapon, "Kill");
	}
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	if (cond == TFCond_Taunting)
	{
		bool bShouldHideWeapon = false;
		
		int iTaunt = GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex");
		if(iTaunt > 0)
		{
			bShouldHideWeapon = true;
		} else {
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			
			if(IsValidEntity(iActiveWeapon))
			{
				char sClassName[32];
				GetEntityClassname(iActiveWeapon, sClassName, sizeof(sClassName));
				
				if (StrEqual("tf_weapon_rocketlauncher", sClassName))bShouldHideWeapon = true;
			}
		}
		
		if(bShouldHideWeapon)
		{
			for (int i = 0; i < 5; i++)
			{
				int iWeapon = GetPlayerWeaponSlot(client, i);
				if (!IsValidEntity(iWeapon))continue;
	
				SetEntityRenderMode(iWeapon, RENDER_NORMAL);
				SetEntityRenderColor(iWeapon, 255, 255, 255, 255);
				
				TF2Wear_RemoveAllTiedWearables(iWeapon);
				SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 0);
			}
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	if (cond == TFCond_Taunting)
	{
		for (int i = 0; i < 5; i++)
		{
			int iWeapon = GetPlayerWeaponSlot(client, i);
			if (!IsValidEntity(iWeapon))continue;
			if (!CEconItems_IsEntityCustomEconItem(iWeapon))continue;

			OnDrawWeapon(client, iWeapon);
		}
	}
}