#!/bin/bash
    cd /srv/daemon-data
    for d in ./*/ ; do
        cd "$d";
        pwd;
        echo "stashing git"
        git stash;
        echo "fetching git"
        git fetch origin master;
        echo "resetting git"
        git reset --hard origin/master;
        echo "pulling git"
        git pull
        echo "chmodding"
        chmod 744 build.sh;
        chmod 744 start.sh;
        echo "starting compile script"
        bash ./build.sh;
        echo "leaving directory"
        cd ../;
    done
