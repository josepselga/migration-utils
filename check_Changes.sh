#!/bin/bash

host=$1
hostPassword=$2

tmpPath=/tmp
SSH_KEY_SCRIPT="./set_up_ssh_keys.sh"

filesToCheckCore=("/etc/raddb/eap.conf"
            "/etc/raddb/modules/opennac"
            "/etc/raddb/sites-available/inner-tunnel"
            "/etc/postfix/main.cf"
            "/etc/postfix/generic"
            "/usr/share/opennac/api/application/configs/application.ini"
)

filesToCheckAnalytics=(
)

filesChanged=()

# OpenNAC 1.2.1 migration to 1.2.2

check_changes() {
    
    #for i in **; do [[ -f "$i" ]] && md5sum "$i" > "$i".md5; done

    #$confFile=$1
    #$local="/files/$2"
    #$file=$(basename $1)
    #$localFile=$local$file
    
    if  [ -f $1 ]; then
        
        #diff <(md5sum opennac) <(md5sum opennac.md5)
        #cat opennac | tr -d '[:space:]' > opennac_cut

        if diff <(cat $1 | tr -d '[:space:]' | md5sum) <(cat $2 | tr -d '[:space:]' | md5sum); then
            #echo "Changes detected on --> " $1
            filesChanged+=("$(basename $i)")
        fi
    
    else
        echo "File " $(basename $1) " not find on files folder"
    fi
}

## Comprovar modificaciones de la instalacion 

## If Core:
for i in "${filesToCheckCore[@]}" do

    $SSH_KEY_SCRIPT "$host $hostPassword"
    if scp root@$host:$i $tmpPath/$(basename $i) > 0; then
        check_changes "/files/$(basename $i)" "$tmpPath/$(basename $i)" "Core"
    else
        echo "Can't retrieve the file $i for host $host"
    fi
done

echo "The following files appear to be modified:"
for z in "${filesChanged[@]}" do
    echo "             $z"
done

##If Analytics:
