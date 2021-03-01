#include <tf2_stocks>

public Extension __ext_tf2items = 
{
	name = "SigSegv MvM",
	file = "sigsegv.ext.2.tf2",
	autoload = 0,
	#if defined REQUIRE_EXTENSIONS
		required = 1,
	#else
		required = 0,
	#endif
}

public void OnPluginStart()
{
	if(TF2MvM_IsPlayingMvM())
	{
		// Unload this plugin without throwing errors.
		ServerCommand("sm plugins unload sigsegv");
	}
}

public bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}