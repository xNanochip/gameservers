//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Include file for plugins that use Creators.TF Custom Economy features.
//
//=========================================================================//

//======================================//
// SCHEMA
//======================================//

// Returns KeyValues with economy schema.
native KeyValues CEcon_GetEconomySchema();
forward void CEcon_OnSchemaUpdated(KeyValues hSchema);

native void CEcon_SendEventToClient(int client, const char[] name, int add, int unique_id);
native void CEcon_SendEventToClientUnique(int client, const char[] name, int add);
native void CEcon_SendEventToClientFromGameEvent(int client, const char[] name, int add, Handle event);

native void CEcon_SendEventToAll(const char[] name, int add, int unique_id);
native int CEcon_GetLastUsedWeapon(int client);

forward void CEcon_OnClientEvent(int client, const char[] name, int add, int unique_id);
