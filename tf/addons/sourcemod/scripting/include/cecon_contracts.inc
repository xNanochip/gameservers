#define MAX_OBJECTIVES 10
#define MAX_HOOKS 4

#define QUEST_OBJECTIVE_PRIMARY 0
#define QUEST_INDEX_ACTIVE -1

enum CEQuestActions
{
	CEQuestAction_Singlefire,
	CEQuestAction_Increment,
	CEQuestAction_Reset,
	CEQuestAction_Subtract,
	CEQuestAction_Set
}

enum struct CEObjective
{
	int m_iProgress;
	int m_iCounter;

	char m_sName[64];
	int m_iEnd;
	int m_iPoints;
	int m_iLimit;

	bool m_bMarked;
	bool m_bUpdated;

	CEQuestActions m_nActions[MAX_HOOKS];

	int m_iCEWeaponIndex;
}

enum struct CEQuest
{
	int m_iIndex;

	ArrayList m_hObjectives;

	char m_sPostfix[5];
	char m_sName[64];

	int m_iSource;
	int m_iLastIndex;

	// Restrictions
	char m_sRestrictionMap[64];
	char m_sRestrictionStrictMap[64];
	TFClassType m_nRestrictionClass;
	int m_iCEWeaponIndex;
}

native void CEQuest_SetPlayerQuest(int client, int contract);
native bool CEQuest_CanObjectiveTrigger(int client, int objective);
native KeyValues CEQuest_FindQuestByIndex(int index);
native void CEQuest_GetObjectiveName(int client, int objective, char[] buffer, int length);

enum struct CEQuestDefinition
{
	int m_iIndex;

	bool m_bBackground;

	int m_iObjectivesCount;
	int m_Objectives[MAX_OBJECTIVES];

	char m_sRestrictedToMap[64];
	char m_sStrictRestrictedToMap[64];
	TFClassType m_nRestrictedToClass;
	int m_iRestrictedToCEWeaponIndex;
}

enum struct CEQuestObjectiveDefinition
{
	int m_iIndex;
	int m_iQuestIndex;

	char m_sName[128];

	int m_iPoints; 	// Points multiplier for every event
	int m_iLimit; 	// Maximum amount of points
	int m_iEnd;		// Amount of points to trigger objective with non-singlefire event.

	int m_iHooksCount;
	int m_Hooks[MAX_HOOKS];

	int m_iRestrictedToCEWeaponIndex;
}

enum struct CEQuestObjectiveHookDefinition
{
	int m_iIndex;
	int m_iObjectiveIndex;
	int m_iQuestIndex;

	char m_sEvent[128];

	CEQuestActions m_Action;
}
