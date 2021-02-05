#define MAX_OBJECTIVES 10
#define MAX_HOOKS 4

enum CEQuestActions
{
	CEQuestAction_Singlefire,
	CEQuestAction_Increment,
	CEQuestAction_Reset,
	CEQuestAction_Subtract,
	CEQuestAction_Set
}

enum struct CEQuestDefinition
{
	int m_iIndex;

	char m_sName[128];
	char m_sPostfix[5];

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

enum struct CEQuestClientProgress
{
	int m_iClient;
	int m_iQuest;

	int m_iProgress[MAX_OBJECTIVES];
	int m_iVariable[MAX_OBJECTIVES];

	int m_iSource;
}
