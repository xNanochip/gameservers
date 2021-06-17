#!/usr/bin/env bash
export TERM=screen

# Colours
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLU=$(tput setaf 4)
PURPLE=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
RESET=$(tput sgr0)

important()
{
    printf "${PURPLE}[IMPORTANT] ${1} ${RESET}\n"
}

ok()
{
    printf "${GREEN}[OK] ${1} ${RESET}\n"
}

info()
{
    printf "${BLU}[INFO] ${1} ${RESET}\n"
}

warn()
{
    printf "${YELLOW}[WARN] ${1} ${RESET}\n"
}

error()
{
    printf "${RED}[ERROR] ${1} ${RESET}\n"
}
