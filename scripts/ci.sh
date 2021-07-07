#!/usr/bin/env bash

# Helper functions
source scripts/helpers.sh

usage()
{
    echo "Usage, assuming you are running this as a ci script, which you should be"
    echo "  ./scripts/ci.sh pull|build <arguments>"
    echo "    pull: Cleans and pulls the repo (if applicable)"
    echo "    build: Build unbuilt and updated plugins"
    echo "    <arguments>: All arguments are passed down to the command, for more info check"
    echo "      ./scripts/_1-pull.sh usage"
    echo "      ./scripts/_2-build.sh usage"
    exit 1
}

[[ ${CI} ]] || { error "This script is only to be executed in GitLab CI"; exit 1; }

# Input check
[[ "$#" == 0 ]] && usage

# Variable initialisation
COMMAND=${1}
shift
ARGS="$@"

# dirs to check for possible gameserver folders
TARGET_DIRS=(/srv/daemon-data /var/lib/pterodactyl/volumes)
# this is clever and infinitely smarter than what it was before, good job
WORK_DIR=$(du -s "${TARGET_DIRS[@]}" 2> /dev/null | sort -n | tail -n1 | cut -f2)
# go to our directory with (presumably) gameservers in it or die trying
debug "scripts dir: ${PWD}/scripts"
debug "working dir: ${WORK_DIR}"
SCRIPTS_DIR="${PWD}/scripts"
cd "${WORK_DIR}" || { error "can't cd to workdir ${WORK_DIR}!!!"; exit 1; }

# kill any git operations that are running and don't fail if we don't find any
# PROBABLY BAD PRACTICE LOL
killall -s SIGKILL -q git || true

# iterate thru directories in our work dir which we just cd'd to
for dir in ./*/ ; do
    # we didn't find a git folder
    if [ ! -d "${dir}/.git" ]; then
        warn "${dir} has no .git folder! skipping"
        # maybe remove these in the future
        continue
    fi
    # we did find a git folder! print out our current folder
    important "Operating on: ${dir}"

    # go to our server dir or die trying
    cd "${dir}" || { error "can't cd to ${dir}"; continue; }

    # branches and remotes
    CI_COMMIT_HEAD=$(git rev-parse --abbrev-ref HEAD)
    CI_LOCAL_REMOTE=$(git remote get-url origin)
    CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE##*@}"
    CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE/://}"
    CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE%.git}"
    CI_REMOTE_REMOTE="${CI_SERVER_HOST}/${CI_PROJECT_PATH}"

    info "Comparing branches ${CI_COMMIT_HEAD} and ${CI_COMMIT_REF_NAME}."
    info "Comparing local ${CI_LOCAL_REMOTE} and remote ${CI_REMOTE_REMOTE}."

    if [[ "${CI_LOCAL_REMOTE}" == "gitlab.com/creators_tf/servers" ]]; then
        git remote set-url origin ***REPLACED PRIVATE URL***
    fi
    
    if [[ "${CI_COMMIT_HEAD}" == "${CI_COMMIT_REF_NAME}" ]] && [[ "${CI_LOCAL_REMOTE}" == "${CI_REMOTE_REMOTE}" ]]; then
        debug "branches match"
        case "${COMMAND}" in
            pull)
                info "Pulling git repo"
                bash ${SCRIPTS_DIR}/_1-pull.sh "${ARGS}"
                ;;
            build)
                COMMIT_OLD=$(git rev-parse HEAD)
                info "Building updated and uncompiled .sp files"
                bash ${SCRIPTS_DIR}/_2-build.sh "${COMMIT_OLD}"
                ;;
            *)
                error "${COMMAND} is not supported"
                exit 1
                ;;
        esac
    else
        important "Branches do not match, doing nothing"
    fi
    cd ..
done
