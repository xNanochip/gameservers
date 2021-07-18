#!/usr/bin/env bash

echo ${PWD}
export STEAM_GAMESERVER_RATE_LIMIT_200MS=25
export STEAM_GAMESERVER_PACKET_HANDLER_NO_IPC=1
./steamcmd/steamcmd.sh +login anonymous +force_install_dir ${PWD} +app_update 232250 +exit

echo "ce_server_index ${SERVER_ID}" > ./tf/cfg/quickplay/_id.cfg
echo "ctf_regen_info" >> ./tf/cfg/quickplay/_id.cfg
./srcds_run $*
