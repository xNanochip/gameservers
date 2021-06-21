#!/usr/bin/env bash

# job names
jobnames=(
    pull-n-build
)

# scripts to execute for each job
jobs=(
    "./scripts/_1-pull-n-build.sh"
)

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
    for tag in "${allservers[@]}"
    do
        # Job definition
        # I rather use a Here Document, but I can't be arsed with the whitepaces in YAML
        echo "${jobname}-${tag}:"
        echo "  stage: ${jobname}"
        echo "  script: ${jobs[i]}"
        if [[ ! "${stagingservers[@]}" =~ "${tag}" ]]; then
            echo "  only:"
            echo "    - master"
        fi

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
