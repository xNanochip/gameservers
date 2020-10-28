#/bin/bash
shopt -s globstar

SPCOMP_PATH=$(realpath "tf/addons/sourcemod/scripting/spcomp")
COMPILED_DIR=$(realpath 'tf/addons/sourcemod/plugins/')
SCRIPTS_DIR=$(realpath 'tf/addons/sourcemod/scripting/')

chmod 744 $SPCOMP_PATH


touch ./00

find . -iname '*.sp' -mmin -5 -print0 | while read -d $'\0' file
do
    echo $file>> ./00
done

# ==========================
# Compile all scripts that don't have any smxes
# ==========================

echo "Seeking for .sp in $SCRIPTS_DIR/**/*"

for p in $SCRIPTS_DIR/**/*
do
    if [ ${p##*.} == 'sp' ]; then
        if [[ $p =~ "disabled/" ]] || [[ $p =~ "external/" ]]; then
            continue
        fi
        PLUGIN_NAME=`realpath --relative-to $SCRIPTS_DIR $p`
        PLUGIN_NAME=${PLUGIN_NAME%.*}
        PLUGIN_SCRIPT_PATH="$SCRIPTS_DIR/$PLUGIN_NAME.sp"
        PLUGIN_COMPILED_PATH="$COMPILED_DIR/$(basename $PLUGIN_NAME).smx"

        if [[ ! -f "$PLUGIN_COMPILED_PATH" ]]; then
            echo $PLUGIN_SCRIPT_PATH >> ./00
        fi
    fi
done

echo "[INFO] Full compile list:"
echo "========================="
cat ./00
echo "========================="


echo "[INFO] Starting processing of plugin files."
while read p; do
    PLUGIN_NAME=`realpath --relative-to $SCRIPTS_DIR $p`
    PLUGIN_NAME=${PLUGIN_NAME%.*}
    PLUGIN_SCRIPT_PATH="$SCRIPTS_DIR/$PLUGIN_NAME.sp"
    PLUGIN_COMPILED_PATH="$COMPILED_DIR/$(basename $PLUGIN_NAME).smx"


    if [[ ! -f "$PLUGIN_SCRIPT_PATH" ]]; then
        if [[ -f "$PLUGIN_COMPILED_PATH" ]]; then
            rm $PLUGIN_COMPILED_PATH;
        fi
    fi

    if [[ $p =~ "disabled/" ]] || [[ $p =~ "external/" ]] || [[ ! -f "$PLUGIN_SCRIPT_PATH" ]]; then
        continue
    fi

    echo $PLUGIN_SCRIPT_PATH;
    if [[ -f "$PLUGIN_SCRIPT_PATH" ]]; then
        $SPCOMP_PATH -D$SCRIPTS_DIR `realpath --relative-to $SCRIPTS_DIR $PLUGIN_SCRIPT_PATH` -o$PLUGIN_COMPILED_PATH -v0
    fi
done < ./00
rm ./00

echo "[INFO] All plugin files are recompiled."

exit;

