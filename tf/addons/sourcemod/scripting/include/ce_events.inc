#define MAX_HOOKS 10



/**
* Called when an event is fired for a participating user
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
* @param client 		Client who refers to this event.
*
* @return					Does nothing.
*/
forward void CEEvents_OnBroadcast(Handle event, bool isCustom, int client);

native int CEEvents_SendEventToClient(int client, const char[] event, int add, int unique);

native int CEEvents_LastUsedWeapon(int client);

/**
* Called when an event is fired
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
*
* @return					Does nothing.
*/
forward void CEEvents_OnBroadcastToAll(Handle event, bool isCustom);

/**
* Called when an event is fired
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
* @param client 		Client who refers to this event.
*
* @return				Does nothing.
*/
native void CEEvents_BroadcastEvent(Handle event, bool isCustom, int ...);

/**
* Called when an event is fired
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
*
* @return					Does nothing.
*/
native void CEEvents_BroadcastEventToAll(Handle event, bool isCustom);
