#define OST_MAX_KITS 24
#define OST_MAX_EVENTS 16
#define OST_MAX_SAMPLES 16

enum struct Sample_t
{
	char m_sSound[MAX_SOUND_NAME];

	int m_nIterations;
	int m_nCurrentIteration;

	int m_nMoveToSample;
	char m_sMoveToEvent[32];

	float m_flDuration;
	float m_flVolume;

	bool m_bPreserveSample;
}

enum struct Soundtrack_t
{
	int m_iDefIndex;

	char m_sWinMusic[512];
	char m_sLossMusic[512];
}

enum struct Event_t
{
	char m_sStartHook[128];
	char m_sStopHook[128];

    char m_sID[32];

	bool m_bForceStart;
    bool m_bFireOnce;
}
