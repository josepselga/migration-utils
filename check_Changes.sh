#!/bin/bash

onprincipal = $arg1
ddbbName = opennac121_$(date +%d-%m-%Y).sql
dbbPath = /tmp

filesToCheck=( "/etc/raddb/eap.conf"
            "/etc/raddb/modules/opennac"
            "/etc/raddb/sites-available/inner-tunnel"
            "/etc/postfix/main.cf"
            "/etc/postfix/generic"
            "/usr/share/opennac/api/application/configs/application.ini"
)



# OpenNAC 1.2.1 migration to 1.2.2

check_changes() {
    
    #for i in **; do [[ -f "$i" ]] && md5sum "$i" > "$i".md5; done

    $confFile = $arg1
    $local = "/files/"
    $file = $(basename $arg1)
    $localFile = $local$file
    
    if  [ -f $localFile ]; then
        
        #diff <(md5sum opennac) <(md5sum opennac.md5)
        #cat opennac | tr -d '[:space:]' > opennac_cut

        if diff <(cat $localFile | tr -d '[:space:]' | md5sum) <(cat $confFile | tr -d '[:space:]' | md5sum); then
            echo "Changes detected on --> " $confFile
        fi
    
    else
        echo "File " $confFile " not find on files folder"
    fi
}

## Comprovar modificaciones de la instalacion 

for i in "${filesToCheck[@]}"
do
    check_changes $i
done
