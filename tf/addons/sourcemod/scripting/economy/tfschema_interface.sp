//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Functions to operate with some parts of base TF schema in SourceMod.
// 
//=========================================================================//

Handle 	g_SDKCallGetEconItemSchema,
		g_SDKCallSchemaGetAttributeDefinitionByName;

public void TFSchema_OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("tf2.creators");
	if (!hGameConf)
	{
		SetFailState("Failed to load gamedata (tf2.creators).");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetEconItemSchema = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_SDKCallSchemaGetAttributeDefinitionByName = EndPrepSDKCall();
}

public Address TFSchema_GetEconItemSchema()
{
	return SDKCall(g_SDKCallGetEconItemSchema);
}

public bool TFSchema_IsAttributeNameValid(const char[] name)
{
	Address pSchema = TFSchema_GetEconItemSchema();
	if(pSchema)
	{
		return SDKCall(g_SDKCallSchemaGetAttributeDefinitionByName, pSchema, name) != Address_Null;
	}
	return false;
}