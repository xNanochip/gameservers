#pragma semicolon 1

#include <sdktools>
#include <tf2wearables>
#include <tf2>

int g_iWearableOwner[2049];
int g_iWearableTiedToWeapon[2049];
bool g_bDestroyOnHolster[2049];

public Plugin myinfo =
{
	name = "TF2 Wearables",
	author = "Moonly Days",
	description = "Gives ability to equip visible wearables on players.",
	version = "1.0",
	url = "https://moonlydays.com"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2wearables");
	CreateNative("TF2Wear_CreateWearable", Native_CreateWearable);
	CreateNative("TF2Wear_EquipWearable", Native_EquipWearable);
	CreateNative("TF2Wear_SetModel", Native_SetModel);
	/*
	CreateNative("CEModels_SetModelIndex", Native_SetModelIndex);
	CreateNative("TF2_EquipWearable", Native_EquipWearable);
	CreateNative("CEModels_CreateTiedWearable", Native_CreateTiedWearable);
	CreateNative("CEModels_KillCustomAttachments", Native_KillCustomAttachments);
	CreateNative("CEModels_WearSetEntPropFloatOfWeapon", Native_WearSetEntPropFloatOfWeapon);*/
	return APLRes_Success;
}

Handle g_hSdkEquipWearable;
Handle g_hSdkRemoveWearable;

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("tf2.wearables");
	if (hGameConf != null)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::RemoveWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkRemoveWearable = EndPrepSDKCall();

		CloseHandle(hGameConf);
	}
}

// =============================================== //
// 	Native: TF2Wear_CreateWearable 
// =============================================== //
public int Native_CreateWearable(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	bool bIsViewModel = GetNativeCell(2);
	
	char sModel[256];
	GetNativeString(3, sModel, sizeof(sModel));

	int entity = CreateEntityByName(bIsViewModel ? "tf_wearable_vm" : "tf_wearable");
	if (!IsValidEntity(entity))
	{
		return -1;
	}
	
	// Effects
	SetEntProp(entity, Prop_Send, "m_fEffects", 129); // EF_BONEMERGE | EF_BONEMERGE_FASTCULL

	// Collision
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);	// FSOLID_NOT_SOLID
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 11); // COLLISION_GROUP_WEAPON
	
	// CBaseEntity
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
	
	// This makes it visible.
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);
	
	// CEconEntity
	SetEntProp(entity, Prop_Send, "m_iEntityLevel", -1);
	SetEntProp(entity, Prop_Send, "m_iItemIDLow", 2048);
	SetEntProp(entity, Prop_Send, "m_iItemIDHigh", 0);
	SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
	

	DispatchSpawn(entity);
	SetVariantString("!activator");
	ActivateEntity(entity);
	
	TF2Wear_SetModel(entity, sModel);
	
	TF2Wear_EquipWearable(client, entity);

	return entity;
}

// =============================================== //
// 	Native: TF2Wear_EquipWearable
// =============================================== //
public int Native_EquipWearable(Handle plugin, int numParams)
{
	if (g_hSdkEquipWearable == null)
	{
		LogMessage("Error: Can't call EquipWearable, SDK functions not loaded!");
		return;
	}
	
	int client = GetNativeCell(1);
	int entity = GetNativeCell(2);
	
	SDKCall(g_hSdkEquipWearable, client, entity);
}

// =============================================== //
// 	Native: TF2Wear_SetModel
// =============================================== //
public int Native_SetModel(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	
	char sModel[512];
	GetNativeString(2, sModel, sizeof(sModel));
	
	if (StrEqual(sModel, ""))return;
	
	if(IsValidEntity(iEntity))
	{
		int iModel = PrecacheModel(sModel, false);
		
		SetEntProp(iEntity, Prop_Send, "m_nModelIndex", iModel);
		for (int i = 0; i < 4; i++)
		{
			SetEntProp(iEntity, Prop_Send, "m_nModelIndexOverrides", iModel, 4, i);
		}
	}
}
/*

bool g_bModelsHidden[MAXPLAYERS + 1];

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	if(cond == TFCond_Taunting)
	{
		int iTaunt = GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex");
		if(iTaunt > -1)
		{
			g_bModelsHidden[client] = true;
			CE_OnWeaponSwitch(client, 0);
		}
	}
}


public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	if(cond == TFCond_Taunting)
	{
		if(g_bModelsHidden[client])
		{
			CE_OnWeaponSwitch(client, GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"));
		}
	}
}

public void CE_OnWeaponSwitch(int client, int weapon)
{
	if (0 <= weapon < MAX_ENTITY_LIMIT)
	{
		int iWearable = -1;
		while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
		{
			if (g_bDestroyOnHolster[iWearable])
			{
				if (g_iWearableOwner[iWearable] == client)
				{
					if (g_iWearableTiedToWeapon[iWearable] != weapon) {
						SDKCall(g_hSdkRemoveWearable, client, iWearable);
						AcceptEntityInput(iWearable, "Kill");
					}
				}
			}
		}
	}
}

stock void AddEntityFlags(int iEntity, int iEffects)
{
	SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects | GetEntProp(iEntity, Prop_Send, "m_fEffects"));
}

stock void RemoveEntityFlags(int iEntity, int iEffects)
{
	SetEntProp(iEntity, Prop_Send, "m_fEffects", ~iEffects & GetEntProp(iEntity, Prop_Send, "m_fEffects"));
}

public void OnEntityCreated(int entity, const char[] class)
{
	if (!IsValidEntity(entity) || !(0 < entity <= MAX_ENTITY_LIMIT))return;
	g_bDestroyOnHolster[entity] = false;
	g_iWearableOwner[entity] = 0;
	g_iWearableTiedToWeapon[entity] = 0;
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntity(entity) || !(0 < entity <= MAX_ENTITY_LIMIT))return;
	g_bDestroyOnHolster[entity] = false;
	g_iWearableOwner[entity] = 0;
	g_iWearableTiedToWeapon[entity] = 0;

	int edict;
	while((edict = FindEntityByClassname(edict, "tf_wearable*")) != -1)
	{
		if (g_iWearableTiedToWeapon[edict] == entity) {
			AcceptEntityInput(edict, "Kill");
		}
	}
}

public int Native_KillCustomAttachments(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int iWearable = -1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
	{
		if (g_iWearableOwner[iWearable] == client)
		{
			SDKCall(g_hSdkRemoveWearable, client, iWearable);
			AcceptEntityInput(iWearable, "Kill");
		}
	}
}

public int Native_SetModelIndex(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	char szModel[500];
	GetNativeString(2, szModel, sizeof(szModel));
	int iModel = PrecacheModel(szModel, false);
	SetEntProp(iEntity, Prop_Send, "m_nModelIndex", iModel);
	for (int i = 0; i <= 3; i++)
	{
		SetEntProp(iEntity, Prop_Send, "m_nModelIndexOverrides", iModel, 4, i);
	}
}
public int Native_CreateTiedWearable(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char model[512];
	GetNativeString(2, model, sizeof(model));
	bool vm = view_as<bool>(GetNativeCell(3));
	int weapon = GetNativeCell(4);
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)return -1;

	int entity = CEModels_CreateWearable(client, model, vm, 1);

	g_bDestroyOnHolster[entity] = true;
	g_iWearableOwner[entity] = client;
	g_iWearableTiedToWeapon[entity] = weapon;

	if(HasEntProp(weapon, Prop_Send, "m_flPoseParameter"))
	{
		SetEntPropFloat(entity, Prop_Send, "m_flPoseParameter", GetEntPropFloat(weapon, Prop_Send, "m_flPoseParameter"));
	}

	return entity;
}

public int Native_WearSetEntPropFloatOfWeapon(Handle plugin, int numParams)
{
	int weapon = GetNativeCell(1);
	PropType type = GetNativeCell(2);
	char sProp[PLATFORM_MAX_PATH];
	GetNativeString(3, sProp, sizeof(sProp));
	float value = GetNativeCell(4);
	int children = GetNativeCell(5);

	SetEntPropFloat(weapon, type, sProp, value);

	int edict;
	while((edict = FindEntityByClassname(edict, "tf_wearable*")) != -1)
	{
		if (g_iWearableTiedToWeapon[edict] == weapon) {
			if(HasEntProp(edict, type, sProp))
			{
				SetEntPropFloat(edict, type, sProp, value, children);
			}
		}
	}

}

public int Native_CreateWearable(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int quality = GetNativeCell(4);

	char model[512];
	GetNativeString(2, model, sizeof(model));
	bool vm = view_as<bool>(GetNativeCell(3));

	int entity = CreateEntityByName(vm ? "tf_wearable_vm" : "tf_wearable");
	if (!IsValidEntity(entity))
	{
		return -1;
	}

	if(!StrEqual(model, "")) {
		SetEntProp(entity, Prop_Send, "m_nModelIndex", PrecacheModel(model, false));
	}
	SetEntProp(entity, Prop_Send, "m_fEffects", 129);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 11);
	SetEntProp(entity, Prop_Send, "m_iEntityQuality", quality);
	SetEntProp(entity, Prop_Send, "m_iEntityLevel", -1);
	SetEntProp(entity, Prop_Send, "m_iItemIDLow", 2048);
	SetEntProp(entity, Prop_Send, "m_iItemIDHigh", 0);
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);
	SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
	SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	DispatchSpawn(entity);
	SetVariantString("!activator");
	ActivateEntity(entity);
	TF2_EquipWearable(client, entity);

	return entity;
}

public int CE_AttachmentsCount(int client)
{
	int a = 0;
	int iWearable = -1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
	{
		if(client == GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity"))
		{
			a++;
		}
	}
	return a;
}*/
