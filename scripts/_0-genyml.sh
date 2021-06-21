#!/usr/bin/env bash

# job names
jobnames=(
    pull-n-build
)

# scripts to execute for each job
jobs=(
    "bash ./scripts/_1-pull-n-build.sh -c -s -h -v"
)

#    echo "  -c removes all plugins and compiles them from scratch and recursively removes all untracked files in the sourcemod folder"
#    echo "  -s culls ('shallowifies') all repositories to only have the last 25 commits, implies -h"
#    echo "  -a runs aggressive git housekeeping on all repositories (THIS WILL TAKE A VERY LONG TIME)"
#    echo "  -h runs normal git housekeeping on all repositories (git gc always gets run with --auto, this will force it to run)"
#    echo "  -v enables debug printing"


# all servers tags
allservers=(
    eupub
    virginiapub
    lapub
    chicago3
    auspub
    sgppub
    eupotato1
    eu2pub
)

# staging servers tags
stagingservers=(
    eupub
    virginiapub
)


# use staging by default
tagstouse=("${stagingservers[@]}")
# don't use master and make sure these vars are actually defined if [ -z "$CI_COMMIT_BRANCH" ];
if [[ "$CI_COMMIT_BRANCH" == "$CI_DEFAULT_BRANCH" ]] && [ -n "$CI_COMMIT_BRANCH" ] && [ -n "${CI_DEFAULT_BRANCH}" ]; then
    tagstouse=("${allservers[@]}")
fi


# stages
echo "stages:"

# for loop for our job names list
for jobname in "${jobnames[@]}"
do
    echo "  - ${jobname}"
done

echo ""

i=0
# for loop for our job names list
for jobname in "${jobnames[@]}"
do
    # for loop for all the servers
    for tag in "${tagstouse[@]}"
    do
        # Job definition
        # I rather use a Here Document, but I can't be arsed with the whitepaces in YAML
        echo "${jobname}-${tag}:"
        echo "  stage: ${jobname}"
        echo "  script: ${jobs[i]}"
        #if [[ ! "${stagingservers[@]}" =~ "${tag}" ]]; then
        #    echo "  only:"
        #    echo "    - master"
        #fi

        # Needs
        # only do the needs stuff if we're not on the first stage
        if (( i > 0 )); then
        # get the previous str of the jobnames array
        echo "  needs:"
        echo "  - job: ${jobnames[i-1]}-${tag}"
        fi
        # Tags
        echo "  tags:"
        echo "    - ${tag}"
    done
    echo ""
    ((i=i+1))
done
