#include <tf2_stocks>

public void OnMapStart()
{
	if(TF2MvM_IsPlayingMvM())
	{
		ServerCommand("sm exts load sigsegv.ext.2.tf2");
	} else {
		// Unload the ext somehow
	}
}

public bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}