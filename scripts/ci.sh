#!/usr/bin/env bash

# Helper functions
source scripts/helpers.sh

# dirs to check for possible gameserver folders
TARGET_DIRS=(/srv/daemon-data /var/lib/pterodactyl/volumes)
# this is clever and infinitely smarter than what it was before, good job
WORK_DIR=$(du -s "${TARGET_DIRS[@]}" 2> /dev/null | sort -n | tail -n1 | cut -f2)
# go to our directory with (presumably) gameservers in it or die trying
cd "${WORK_DIR}" || exit
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
    info "Operating on: $dir"
    # go to our server dir or die trying
    cd "$dir" || exit

    # todo: fix this for git fscking
    info "finding empty objects"
    find .git/objects/ -type f -empty -exec ls {} +;
    #echo "fetching"
    #git fetch -p
    #echo "fscking"
    #git fsck --full
    #cd ../

    # no idea lol
    CI_LOCAL_REMOTE=$(git remote get-url origin);
    CI_LOCAL_REMOTE="${CI_LOCAL_REMOTE##*@}";
    CI_LOCAL_REMOTE=$(echo "$CI_LOCAL_REMOTE" | tr : /)
    CI_LOCAL_REMOTE=${CI_LOCAL_REMOTE%.git}

    # pretty sure these are cicd vars? dunno
    CI_REMOTE_REMOTE="$CI_SERVER_HOST/$CI_PROJECT_PATH.git"
    CI_REMOTE_REMOTE=$(echo "$CI_REMOTE_REMOTE" | tr : /)
    CI_REMOTE_REMOTE=${CI_REMOTE_REMOTE%.git}

    # why do we need to check this?
    info "Comparing remotes $CI_LOCAL_REMOTE and $CI_REMOTE_REMOTE."
    if [ "$CI_LOCAL_REMOTE" == "$CI_REMOTE_REMOTE" ]; then

        info "Comparing branches $(git rev-parse --abbrev-ref HEAD) and $CI_COMMIT_REF_NAME."
        if [ "$(git rev-parse --abbrev-ref HEAD)" == "$CI_COMMIT_REF_NAME" ]; then
            info "cleaning any old git locks..."
            # don't fail if there are none
            rm .git/index.lock -v || true
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

            # TODO: make this a flag
            # UNCOMMENT THESE LINES TO FORCE CLEANUP OF EXTRA BULLSHIT THAT MIGHT BE ON SERVERS
            # echo "git clean"
            # git clean -d -f -x tf/addons/sourcemod/plugins/
            # git clean -d -f -x tf/addons/sourcemod/plugins/external
            # git clean -d -f -x tf/addons/sourcemod/data/
            # git clean -d -f -x tf/addons/sourcemod/gamedata/

            info "chmodding"
            # start script for servers is always at the root of our server dir
            chmod 744 ./start.sh;
            # everything else not so much
            chmod 744 ./scripts/build.sh;
            chmod 744 ./scripts/str0.py;
            chmod 744 ./scripts/str0.ini;

            info "running str0 to scrub steamclient spam"
            python3 ./scripts/str0.py ./bin/steamclient.so -c ./scripts/str0.ini | grep -v "Failed to locate string"

            # don't run this often
            info "garbage collecting"
            git gc --auto ;


            info "building"
            ./scripts/build.sh "$COMMIT_OLD";

        fi;
    fi;
    cd ../;
done
