#!/bin/bash

#Screen colour constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHT_BLUE='\033[0;34m'
NC='\033[0m'

tmpPath=/tmp
SSH_KEY_SCRIPT="$(dirname "$0")/set_up_ssh_keys.sh"

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

noRetrievedFiles=()

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

        if diff <(cat $1 | tr -d '[:space:]' | md5sum) <(cat $2 | tr -d '[:space:]' | md5sum) | grep '.*' > /dev/null; then
            #echo "Changes detected on --> " $1
            filesChanged+=($i)
        fi
    
    else
        echo "File " $(basename $1) " not find on files folder"
    fi
}


post_install_noMove() {
      
    for sample in $(find /usr/share/opennac/ -name *.ini.sample)
    do
            oldini=$(echo ${sample} | sed 's_.sample__')
            diff=$(diff ${sample} ${oldini} 1>/dev/null; echo $?)
            if [ "${diff}" -eq 1 ] && [[ "${oldini}" != *"otp/config.ini" ]]
            then
                    echo -e "\n${oldini}"
            fi
    done
}

node='NO-TARGET'
type="core"
password="opennac"

while getopts n:t:p: flag
do
    case "${flag}" in
        n) node=${OPTARG};;
        t) type=${OPTARG};;
        p) password=${OPTARG};;
    esac
done

## Comprovar modificaciones de la instalacion 

case $type in

  ## If Core:
  core)
    type="Core"
    filesToCheck=("${filesToCheckCore[@]}")  
    ;;

  ##If Analytics:
  analytics)
    type="Analytics"
    filesToCheck=("${filesToCheckAnalytics[@]}")  
    ;;
esac

$SSH_KEY_SCRIPT "$node" "$password"



echo -e "\n${YELLOW}Checking installation files...${NC}\n"

for i in "${filesToCheck[@]}"; do
    if scp root@$node:$i $tmpPath/$(basename $i)&> /dev/null; then
        check_changes "./files/$type/$(basename $i)" "$tmpPath/$(basename $i)"
        rm -rf "$tmpPath/$(basename $i)"
        echo "$tmpPath/$(basename $i)"
    else
        #echo -e "${RED}Can't retrieve the file $i for host $node${NC}"
        noRetrievedFiles+=("$i")
    fi
done



echo -e "\n${YELLOW}Checking opennac .sample files...${NC}\n"
echo -e "${RED}The following files appear to be modified based on .sample:${NC}"

ssh root@$node "$(typeset -f post_install_noMove); post_install_noMove" 


if (( ${#noRetrievedFiles[@]} )); then
    echo -e "\n${RED}The following files can't be retrieved:${NC}"
    for z in "${noRetrievedFiles[@]}"; do
        echo "$z"
    done
fi

if [ ${#filesChanged[@]} -eq 0 ]; then
    echo -e "\n${GREEN}No files appear to be modified based on OVA.${NC}\n"
else
    echo -e "\n${RED}The following files appear to be modified based on OVA:${NC}"
    for z in "${filesChanged[@]}"; do
        echo "$z"
    done
    echo -e "\n"
fi