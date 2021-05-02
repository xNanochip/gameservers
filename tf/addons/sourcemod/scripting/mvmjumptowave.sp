#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0.0"
#define UNDEFINED_VALUE -1

public Plugin:myinfo =  
{
  name = "TF2 MvM Wave Restart",
  author = "kimoto",
  description = "TF2 MvM Wave Restart",
  version = PLUGIN_VERSION,
  url = "http://kymt.me/"
};

new oldFlags = -1;

public OnPluginStart()
{
  RegAdminCmd("sm_mvm_wave_restart", ADMFLAG_SLAY, Command_MvMWaveRestart, "Restarts the current wave");
  RegAdminCmd("sm_mvm_wave", ADMFLAG_SLAY, Command_MvMJumpToNextWave, "Jumps to a specific wave number");
  RegAdminCmd("sm_wave_restart", ADMFLAG_SLAY, Command_MvMWaveRestart); // Alias
}

public OnPluginEnd()
{
}

public JumpToWave(number)
{
  oldFlags = GetCommandFlags("tf_mvm_jump_to_wave");
  SetCommandFlags("tf_mvm_jump_to_wave", oldFlags & ~FCVAR_CHEAT);
  ServerCommand("tf_mvm_jump_to_wave %s", number);
  ServerExecute();
  // CreateTimer(0.25, Timer_ResetFlag, INVALID_HANDLE, 0);
}

public Action:Command_MvMWaveRestart(client, args)
{
    	if (!GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		return Plugin_Handled;
	}
	
  new ent = FindEntityByClassname(-1, "tf_objective_resource");
  if(ent == -1){
    LogMessage("tf_objective_resource not found");
    return;
  }
  JumpToWave(GetEntData(ent, FindSendPropInfo("CTFObjectiveResource", "m_nMannVsMachineWaveCount")));
}

public Action:Command_MvMJumpToNextWave(client, args)
{
    if (!GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		PrintToConsole(client, "Usage: sm_mvm_wave <number>");
		return Plugin_Handled;
	}

    new String:number[10];
	GetCmdArg(1, number, sizeof(number));

  new ent = FindEntityByClassname(-1, "tf_objective_resource");
  if(ent == -1){
    LogMessage("tf_objective_resource not found");
    return;
  }

  JumpToWave(number);
}

public Action:Timer_ResetFlag(Handle:timer, any:data)
{
  SetCommandFlags("tf_mvm_jump_to_wave", oldFlags);
}
