#!/usr/bin/env bash

# by invaderctf and sappho.io

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Helper functions
source ${SCRIPT_DIR}/discord_helpers.sh


# check if we are in a terminal, if not, set our term var to screen so tput doesn't whine
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

error()
{
    echo "${RED}[ERROR] ${1} ${RESET}"
}

warn()
{
    echo "${YELLOW}[WARN] ${1} ${RESET}"
}

important()
{
    echo "${PURPLE}[IMPORTANT] ${1} ${RESET}"
}

ok()
{
    echo "${GREEN}[OK] ${1} ${RESET}"
}

info()
{
    echo "${BLU}[INFO] ${1} ${RESET}"
}

debug()
{
    if ${ctf_show_debug}; then
        echo "${CYAN}[DEBUG] ${1} ${RESET}"
    fi
}

# sets ${thisbranch} to this dir's current git branch

getThisBranch()
{
    # this is so long in case we have a detached head:
    # https://stackoverflow.com/questions/6059336/how-to-find-the-current-git-branch-in-detached-head-state
    # Cuts the "HEAD\n" off as well
    thisbranch=$(git branch --remote --verbose --no-abbrev --contains | sed -rne 's/^[^\/]*\/([^\ ]+).*$/\1/p' | sed -z 's/HEAD\n//g')
    if [[ "${thisbranch}" == "" ]]; then
        hook  "Something has gone horribly wrong, git branch is BLANK. Falling back to default branch!!!"
        error "Something has gone horribly wrong, git branch is BLANK. Falling back to default branch!!!"
        thisbranch="${CI_DEFAULT_BRANCH}"
    fi
    export thisbranch
}

