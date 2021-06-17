#!/usr/bin/env bash

# Helper functions
source scripts/helpers.sh

gitclean=''
gitgc=''
debug=''

debug()
{
    if [[ "$debug" == "true" ]]; then
        echo "${CYAN}[DEBUG] ${1} ${RESET}"
    fi
}

usage()
{
    echo "Usage, assuming you are running this as a ci script, which you should be"
    echo "  -c cleans all plugins and compiles them from scratch as well as cleaning all untracked files in the sourcemod folder"
    echo "  -g runs aggressive git housekeeping on all repositories ( THIS WILL TAKE A VERY LONG TIME )"
    echo "  -v enables debug printing"
}

while getopts 'cgv' flag; do
    case "${flag}" in
        c) gitclean='true'  ;;
        g) gitgc='true'     ;;
        v) debug='true'     ;;
        *) usage && exit 1  ;;
    esac
done

# dirs to check for possible gameserver folders
TARGET_DIRS=(/srv/daemon-data /var/lib/pterodactyl/volumes)
# this is clever and infinitely smarter than what it was before, good job
WORK_DIR=$(du -s "${TARGET_DIRS[@]}" 2> /dev/null | sort -n | tail -n1 | cut -f2)
# go to our directory with (presumably) gameservers in it or die trying
debug "pwd: $(pwd)";
cd "${WORK_DIR}" || error "couldn't cd to $dir ???"; exit
# kill any git operations that are running and don't fail if we don't find any
# PROBABLY BAD PRACTICE LOL
killall -s SIGKILL -q git || true
# iterate thru directories in our work dir which we just cd'd to
for dir in ./*/ ; do
    # we didn't find a git folder
    if [  ! -d "$dir".git ]; then
        # shouldn't this be better quoted or does bash handle that? idr
        warn "$dir has no .git folder!";
        # go to the next folder (i think?? should be)
        continue;
    fi
    # we did find a git folder!
    # print out our cur folder
    important "Operating on: $dir"
    
    debug "pwd: $(pwd)";
    # go to our server dir or die trying
    cd "$dir" || error "couldn't cd to $dir ???"; exit

    info "finding empty objects"
    numemptyobjs=$(find .git/objects/ -type f -empty | wc -l)
    # you do not need the $ apparently
    # https://github.com/koalaman/shellcheck/wiki/SC2004
    if (( numemptyobjs > 0 )); then
        error "FOUND EMPTY GIT OBJECTS, RUNNING GIT FSCK ON THIS REPOSITORY!";
        # i'll optimize this later
        find .git/objects/ -type f -empty -exec rm {} +;
        warn "fetching before git fscking"
        #git fetch -p
        warn "fscking!!!"
        #git fsck --full
        continue;
    fi

    # no idea lol
    #CI_LOCAL_REMOTE=$(git remote get-url origin);
    #CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE##*@}";
    #CI_LOCAL_REMOTE=$(echo "$CI_LOCAL_REMOTE" | tr : /)
    #CI_LOCAL_REMOTE=${CI_LOCAL_REMOTE%.git}
    #
    ## pretty sure these are cicd vars? dunno
    #CI_REMOTE_REMOTE="$CI_SERVER_HOST/$CI_PROJECT_PATH.git"
    #CI_REMOTE_REMOTE=$(echo "$CI_REMOTE_REMOTE" | tr : /)
    #CI_REMOTE_REMOTE=${CI_REMOTE_REMOTE%.git}

    # why do we need to check this?
    #info "Comparing remotes $CI_LOCAL_REMOTE and $CI_REMOTE_REMOTE."
    #if [ "$CI_LOCAL_REMOTE" == "$CI_REMOTE_REMOTE" ]; then

    info "Comparing branches $(git rev-parse --abbrev-ref HEAD) and $CI_COMMIT_REF_NAME."
    if [ "$(git rev-parse --abbrev-ref HEAD)" == "$CI_COMMIT_REF_NAME" ]; then
        debug "branches match"
        info "cleaning any old git locks..."
        # don't fail if there are none
        # and suppress the stderror if its just telling us there are none
        rm .git/index.lock -v &> >(grep -v "No such") || true
        info "setting git config"

        git config --global user.email "support@creators.tf"
        git config --global user.name "Creators.TF Production"

        COMMIT_OLD=$(git rev-parse HEAD);

        info "clearing stash"
        git stash clear;

        info "fetching"
        git fetch origin "$CI_COMMIT_REF_NAME";

        info "resetting"
        git reset --hard origin/"$CI_COMMIT_REF_NAME";

        info "cleaning cfg folder"
        git clean -d -f -x tf/cfg/

        info "cleaning maps folder"
        git clean -d -f tf/maps

        if [[ "$gitclean" == "true" ]]; then
            git clean -d -f -x tf/addons/sourcemod/plugins/
            git clean -d -f -x tf/addons/sourcemod/plugins/external
            git clean -d -f -x tf/addons/sourcemod/data/
            git clean -d -f -x tf/addons/sourcemod/gamedata/
        fi

        info "chmodding"
        # start script for servers is always at the root of our server dir
        chmod 744 ./start.sh;
        # everything else not so much
        chmod 744 ./scripts/build.sh;
        chmod 744 ./scripts/str0.py;
        chmod 744 ./scripts/str0.ini;

        info "running str0 to scrub steamclient spam"
        # ignore the output if it already scrubbed it
        python3 ./scripts/str0.py ./bin/steamclient.so -c ./scripts/str0.ini | grep -v "Failed to locate string"

        # don't run this often
        info "garbage collecting"
        if [[ "$gitgc" == "true" ]]; then
            info "running git gc!!!"
            git gc --aggressive
        else
            git gc --auto ;
        fi
        info "building"
        ./scripts/build.sh "$COMMIT_OLD";

    fi;
    cd ../;
done
