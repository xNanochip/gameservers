#!/usr/bin/env bash

echo ${PWD}
export STEAM_GAMESERVER_RATE_LIMIT_200MS=25
export STEAM_GAMESERVER_PACKET_HANDLER_NO_IPC=1
./steamcmd/steamcmd.sh +login anonymous +force_install_dir ${PWD} +app_update 232250 +exit

./srcds_run $*
