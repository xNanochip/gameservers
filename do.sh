#!/bin/bash
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
git pull master;
echo "chmodding";
chmod 744 build.sh;
chmod 744 start.sh;
echo "starting compile script";
bash ./build.sh;
