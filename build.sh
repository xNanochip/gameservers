#!/usr/bin/env bash

# shopt -s globstar

SPCOMP_PATH="./tf/addons/sourcemod/scripting/spcomp64"
SCRIPTS_DIR="tf/addons/sourcemod/scripting/"
COMPILED_DIR="tf/addons/sourcemod/plugins/"
UNCOMPILED_LIST=$(mktemp)
UPDATED_LIST=$(mktemp)
trap "rm -f ${UNCOMPILED_LIST} ${UPDATED_LIST}" EXIT

usage() {
    echo "This script looks for all the uncompiled .sp files, and those that changed against a reference commit"
    echo "Then it compiles it somehow"
    echo "Usage: ./build.sh <reference>"
    exit 1
}

input_validation() {
    GIT_REF=${1}
    if git rev-parse --verify --quiet ${GIT_REF} > /dev/null; then
        info "Comparing against ${GIT_REF}"
    else
        echo "Reference ${GIT_REF} does not exists"
        exit 2
    fi
}

compile() {
    while read -r plugin; do
        echo ${SPCOMP_PATH} -D "${SCRIPTS_DIR}" "${plugin/${SCRIPTS_DIR}/}" -o "${COMPILED_DIR}$(basename "${plugin/.sp/}").smx" -v0
    done < ${1}
}

[[ -x ${SPCOMP_PATH} ]] || chmod u+x ${SPCOMP_PATH}
[[ -z ${1} ]] && usage || input_validation ${1}


# ==========================
# Compile all scripts that have been updated
# ==========================

echo "[INFO] Looking for all .sp files that have been updated"
UPDATED=$(git diff --name-only HEAD "${GIT_REF}" | grep "\.sp$" | grep -v "*/stac/*" | grep -v "*/include/*" | grep -v "*/disabled/*" | grep -v "*/external/*" | grep -v "*/economy/*")

echo "[INFO] Generating list of updated scripts:"
echo "========================="
# double check that the logic is correct here
while IFS= read -r line; do
    echo rm -f "${COMPILED_DIR}/$(basename ${line/.sp/.smx})"
    echo ${line} >> ${UPDATED_LIST}
done <<< "${UPDATED}"
echo "========================="

echo "[INFO] Compiling updated plugins"
compile ${UPDATED_LIST}
exit 0

# ==========================
# Compile all scripts that don't have any smxes
# ==========================

echo "[INFO] Looking for all .sp files in ${SCRIPTS_DIR}"
# double check that the logic is correct here
UNCOMPILED=$(find ${SCRIPTS_DIR} -iname "*.sp" ! -path "*/stac/*" ! -path "*/include/*" ! -path "*/disabled/*" ! -path "*/external/*" ! -path "*/economy/*")

echo "[INFO] Generating list of uncompiled scripts:"
echo "========================="
while IFS= read -r line; do
    [[ ! -f "${COMPILED_DIR}/$(basename ${line/.sp/.smx})" ]] && echo ${line} | tee -a ${UNCOMPILED_LIST}
done <<< "${UNCOMPILED}"
echo "========================="

echo "[INFO] Compiling uncompiled plugins"
compile ${UNCOMPILED_LIST}


echo "[INFO] All plugin files are recompiled."

exit 0
