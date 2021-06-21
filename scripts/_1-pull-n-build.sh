#!/usr/bin/env bash

# Helper functions
source scripts/helpers.sh

# Variable initialisation
gitclean=false
gitshallow=false
gitgc=false
gitgc_aggressive=false

usage()
{
    echo "Usage, assuming you are running this as a ci script, which you should be"
    echo "  -c removes all plugins and compiles them from scratch and recursively removes all untracked files in the sourcemod folder"
    echo "  -s culls ('shallowifies') all repositories to only have the last 25 commits, implies -h"
    echo "  -a runs aggressive git housekeeping on all repositories (THIS WILL TAKE A VERY LONG TIME)"
    echo "  -h runs normal git housekeeping on all repositories (git gc always gets run with --auto, this will force it to run)"
    echo "  -v enables debug printing"
    exit 1
}

[[ ${CI} ]] || { error "This script is only to be executed in GitLab CI"; exit 1; }

while getopts 'csahv' flag; do
    case "${flag}" in
        c) gitclean=true ;;
        s) gitshallow=true ;;
        a) gitgc_aggressive=true ;;
        h) gitgc=true ;;
        v) export ctf_show_debug=true ;;
        ?) usage ;;
    esac
done

# dirs to check for possible gameserver folders
TARGET_DIRS=(/srv/daemon-data /var/lib/pterodactyl/volumes)
# this is clever and infinitely smarter than what it was before, good job
WORK_DIR=$(du -s "${TARGET_DIRS[@]}" 2> /dev/null | sort -n | tail -n1 | cut -f2)
# go to our directory with (presumably) gameservers in it or die trying
debug "current dir: ${PWD}"
debug "working dir: ${WORK_DIR}"
cd "${WORK_DIR}" || { error "can't cd to workdir ${WORK_DIR}!!!"; exit 1; }

# kill any git operations that are running and don't fail if we don't find any
# PROBABLY BAD PRACTICE LOL
killall -s SIGKILL -q git || true

# iterate thru directories in our work dir which we just cd'd to
for dir in ./*/ ; do
    # we didn't find a git folder
    if [  ! -d "${dir}/.git" ]; then
        warn "${dir} has no .git folder! skipping"
        # maybe remove these in the future
        continue
    fi
    # we did find a git folder! print out our current folder
    important "Operating on: ${dir}"

    # go to our server dir or die trying
    cd "${dir}" || { error "can't cd to ${dir}"; continue; }

    info "Finding empty objects"
    numemptyobjs=$(find .git/objects/ -type f -empty | wc -l)
    if (( numemptyobjs > 0 )); then
        error "FOUND EMPTY GIT OBJECTS, RUNNING GIT FSCK ON THIS REPOSITORY!"
        find .git/objects/ -type f -empty -delete
        warn "fetching before git fscking"
        git fetch -p
        warn "fscking!!!"
        git fsck --full
        cd ..
        continue
    fi

    CI_COMMIT_HEAD=$(git rev-parse --abbrev-ref HEAD)
    # i figured out what this is for, it's for checking that we're not in the events servers, which have their own repository

    CI_LOCAL_REMOTE=$(git remote get-url origin)
    CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE##*@}"
    CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE/://}"
    CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE%.git}"

    CI_REMOTE_REMOTE="${CI_SERVER_HOST}/${CI_PROJECT_PATH}"

    # branches and remotes
    info "Comparing branches ${CI_COMMIT_HEAD} and ${CI_COMMIT_REF_NAME}."
    info "Comparing local ${CI_LOCAL_REMOTE} and remote ${CI_REMOTE_REMOTE}."
    if [[ "${CI_COMMIT_HEAD}" == "${CI_COMMIT_REF_NAME}" ]] && [[ "$CI_LOCAL_REMOTE" == "$CI_REMOTE_REMOTE" ]]; then
        debug "branches match"
        debug "cleaning any old git locks..."
        rm -fv .git/index.lock

        debug "setting git config..."
        git config --global user.email "support@creators.tf"
        git config --global user.name "Creators.TF Production"

        COMMIT_OLD=$(git rev-parse HEAD)

        if ${gitshallow}; then
            warn "shallowifying repo on user request"
            info "clearing stash..."
            git stash clear
            info "expiring reflog..."
            git reflog expire --expire=all --all
            info "deleting tags..."
            git tag -l | xargs git tag -d
            info "setting git gc to automatically run..."
            gitgc=true
        fi

        info "fetching..."
        git fetch origin "${CI_COMMIT_REF_NAME}" --depth 25

        info "resetting..."
        git reset --hard "origin/${CI_COMMIT_REF_NAME}"

        info "cleaning cfg folder..."
        git clean -d -f -x tf/cfg/

        info "cleaning maps folder..."
        git clean -d -f tf/maps

        if ${gitclean}; then
            warn "recursively cleaning sourcemod folder on user request"
            git clean -d -f -x tf/addons/sourcemod/plugins/
            git clean -d -f -x tf/addons/sourcemod/plugins/external
            git clean -d -f -x tf/addons/sourcemod/data/
            git clean -d -f -x tf/addons/sourcemod/gamedata/
        fi

        # ignore the output if it already scrubbed it
        debug "running str0 to scrub steamclient spam"
        python3 ./scripts/str0.py ./bin/steamclient.so -c ./scripts/str0.ini | grep -v "Failed to locate string"

        info "git pruning"
        git prune

        # don't run this often
        info "garbage collecting"
        if ${gitgc_aggressive}; then
            debug "running aggressive git gc!!!"
            git gc --aggressive --prune=all
        elif ${gitgc}; then
            debug "running git gc on user request"
            git gc
        else
            debug "auto running git gc"
            git gc --auto
        fi

        ok "git repo updated on this server (${dir})"

        info "building updated and uncompiled .sp files"
        debug "comparing against ${COMMIT_OLD}"
        ./scripts/spbuild.sh "${COMMIT_OLD}"
    else
        important "Branches do not match, doing nothing"
    fi
    cd ..
done
