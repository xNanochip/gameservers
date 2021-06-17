#!/usr/bin/env bash

# Helper functions
source scripts/helpers.sh

# Variable initialisation
WORKING_DIR="tf/addons/sourcemod"
SPCOMP_PATH="scripting/spcomp64"
SCRIPTS_DIR="scripting"
COMPILED_DIR="plugins"
# Exclusion list, use /dir/ for directories and /file_ for file_*.sp
EXCLUDED="/stac/ /include/ /disabled/ /external/ /economy/ /attributes/ /discord_"
EXCLUDED="grep -v -e ${EXCLUDED// / -e }"

# Temporary files
UNCOMPILED_LIST=$(mktemp)
UPDATED_LIST=$(mktemp)

# TODO: I am pretty sure this needs to be single quoted with double quotes around the vars
trap "rm -f ${UNCOMPILED_LIST} ${UPDATED_LIST}; popd >/dev/null" EXIT

usage() {
    echo "This script looks for all uncompiled .sp files"
    echo "and if a reference is given, those that were updated"
    echo "Then it compiles everything"
    echo "Usage: ./build.sh <reference>"
    exit 1
}

# Just checking the git refernece is valid
reference_validation()
{
    GIT_REF="${1}"
    if git rev-parse --verify --quiet "${GIT_REF}" > /dev/null; then
        info "Comparing against ${GIT_REF}"
    else
        error "Reference ${GIT_REF} does not exist"
        exit 2
    fi
}

# Find all changed *.sp files inside ${WORKING_DIR}
# Write the full list to a file
# Remove all the *.smx counterparts that exist
list_updated()
{
    UPDATED=$(git diff --name-only HEAD "${GIT_REF}" . | grep "\.sp$" | ${EXCLUDED})
    if [[ -z $UPDATED ]]; then
        ok "No updated files in diff";
        return 1;
    fi
    info "Generating list of updated scripts"
    while IFS= read -r line; do
        # git diff reports the full path, we need it relative to ${WORKING_DIR}
        echo "${line/${WORKING_DIR}\//}" >> "${UPDATED_LIST}"
        rm -f "${COMPILED_DIR}/$(basename "${line/.sp/.smx}")"
    done <<< "${UPDATED}"
    return 0;
}

# Find all *.sp files inside ${WORKING_DIR}
# Select those that do not have a *.smx counterpart
# And write resulting list to a file
list_uncompiled()
{
    # this may need to be quoted
    UNCOMPILED=$(find "${SCRIPTS_DIR}" -iname "*.sp" | ${EXCLUDED})
    info "Generating list of uncompiled scripts"
    # please for the love of god comment this
    while IFS= read -r line; do
        [[ ! -f "${COMPILED_DIR}/$(basename "${line/.sp/.smx}")" ]] \
        && echo "${line}" >> "${UNCOMPILED_LIST}"
    done <<< "${UNCOMPILED}"
    warn "$UNCOMPILED_LIST";
    if [[ -z $UNCOMPILED_LIST ]]; then
        ok "No uncompiled .sp files";
        return 1;
    fi

    return 0;
}

# Iterate over a list files and compile all the *.sp files
# Output will be ${COMPILED_DIR}/plugin_name.smx
# If an error is found the function dies and report the failing file
compile()
{
    info "Compiling $(wc -l < "${1}") files"
    while read -r plugin; do
        info "Compiling ${plugin}"
        ./${SPCOMP_PATH} "${plugin}" -o "${COMPILED_DIR}/$(basename "${plugin/.sp/.smx}")" -v0 #-E
        [[ $? -ne 0 ]] && compile_error "${plugin}"
    done < "${1}"
    return 0;
}

# Auxiliary function to catch errors on spcomp64
compile_error(){
    error "spcomp64 error while compiling ${1}"
    exit 255
}

###
# Script begins here ↓
pushd ${WORKING_DIR} >/dev/null || exit
[[ ! -x ${SPCOMP_PATH} ]] && chmod u+x ${SPCOMP_PATH}

# Compile all scripts that have been updated
if [[ -n ${1} ]]; then
    reference_validation "${1}"
    info "Looking for all .sp files that have been updated"
    list_updated
    if [[ $? -eq 0 ]]; then
        info "Compiling updated plugins"
        compile "${UPDATED_LIST}"
    fi
fi

# Compile all scripts that have not been compiled
info "Looking for all .sp files in ${WORKING_DIR}/${SCRIPTS_DIR}"
list_uncompiled
if [[ $? -eq 0 ]]; then
    info "Compiling uncompiled plugins"
    compile "${UNCOMPILED_LIST}"
fi

ok "All plugins compiled successfully !"
exit 0
