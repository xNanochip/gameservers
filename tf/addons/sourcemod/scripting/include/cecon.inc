//============= Copyright Amper Software , All rights reserved. ============//
//
// Purpose: Include file for plugins that use Creators.TF Custom Economy features.
//
//=========================================================================//

//======================================//
// SCHEMA
//======================================//
native KeyValues CEcon_GetEconomySchema();
forward void CEcon_OnSchemaUpdated(KeyValues hSchema);
