#pragma semicolon 1
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#define PLUGIN_VERSION "1.0.0-creators"
#define UNDEF -1

public Plugin:myinfo = {
	name = "TF2 MvM Wave Controls",
	author = "Potatofactory, kimoto",
	description = "Provides interface in wave jumping and restarting for admin use.", 
	version = PLUGIN_VERSION, 
	url = "https://creators.tf/"
};
 

public ResetCmdFlags()
{
	decl flags;
	flags = GetCommandFlags ("tf_mvm_jump_to_wave");
	SetCommandFlags ("tf_mvm_jump_to_wave", flags & ~FCVAR_CHEAT);
}

public OnPluginStart() {
	RegAdminCmd ("sm_wave_restart", Command_MvMWaveRestart, ADMFLAG_SLAY, "Restarts the current wave");
	RegAdminCmd ("sm_wave_jump", Command_MvMJumpToNextWave, ADMFLAG_SLAY, "Jumps to a specific wave number");

	ResetCmdFlags ();
}

public JumpToWave(waveRequested) {
	ServerCommand ("tf_mvm_jump_to_wave %s", waveRequested);
	ServerExecute ();
}

public Action:Command_MvMWaveRestart(client, args) {
	if (! GameRules_GetProp("m_bPlayingMannVsMachine")) {
		return Plugin_Handled;
	}

	new ent = FindEntityByClassname (0, "tf_objective_resource");
	if (ent == UNDEF) {
		ReplyToCommand (client, "Cannot change wave, entity tf_objective_resource not found.");
		return Plugin_Handled;
	}

	JumpToWave (
		GetEntData (ent, FindSendPropInfo("CTF ObjectiveResource", "m_nMannVsMachineWaveCount"))
	);
	return Plugin_Handled;
}

public Action:Command_MvMJumpToNextWave (int iClient, int argc) {
	if (! GameRules_GetProp("m_bPlayingMannVsMachine")) {
		return Plugin_Handled;
	}

	if (argc < 1) {
		PrintToConsole (iClient, "Usage: sm_mvm_wave <number>");
		return Plugin_Handled;
	}

	char waveRequest[2];
	GetCmdArg (1, waveRequest, sizeof(waveRequest));

	decl iEntObjective;
	iEntObjective = FindEntityByClassname (0, "tf_objective_resource");
	if (iEntObjective == UNDEF) {
		ReplyToCommand (iClient, "Cannot change wave, entity tf_objective_resource not found.");
		return Plugin_Handled;
	}

	JumpToWave (StringToInt(waveRequest));

	return Plugin_Handled;
}
