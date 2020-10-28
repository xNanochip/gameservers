#!/bin/bash

cd /srv/daemon-data/
for d in ./*/ ; do
    pwd;
    echo "stashing git";
    git stash;
    echo "fetching git";
    git fetch origin master;
    echo "resetting git";
    git reset --hard origin/master;
    # checking out master
    git config pull.rebase false;
    git checkout master;
    echo "pulling git"
    git pull -f --progress;
    echo "chmodding";
    chmod 744 build.sh;
    chmod 744 start.sh;
    # leaving directory
    cd ../
done


echo "starting compile script";
bash build.sh

