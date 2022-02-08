#!/bin/bash

#Screen colour constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHT_BLUE='\033[0;34m'
NC='\033[0m'


ddbbName = opennac121_$(date +%d-%m-%Y).sql
ddbbPath = "/tmp"
SSH_KEY_SCRIPT="$(dirname "$0")/set_up_ssh_keys.sh"

# POST ANSIBLE DEPLOYMENT

## executar script al nou principal , fer mysql dump al slave (indicar manualment ip)

while getopts p:pp:s:sp: flag
do
    case "${flag}" in
        p) principal=${OPTARG};;
        pp) principalPassword=${OPTARG};;
        s) slave=${OPTARG};;
        sp) slavePassword=${OPTARG};;
        *)
            echo 'Error in line parse' >&2
            exit 1
    esac
done
shift "$(( OPTIND - 1 ))"

if [ -z "$principal" ] || [ -z "$slave" ]; then
    echo -e "${RED}Missing -p (Principal Target) or -s (Slave Target)${NC}"
    exit 1
fi
if [ -z "$principalPassword" ]; then
    echo -e "${YELLOW}Missing -pp (Principal Pasword), using default \"opennac\"${NC}"
    principalPassword='opennac'
fi
if [ -z "$slavePassword" ]; then
    echo -e "${YELLOW}Missing -sp (Slave Pasword), using default \"opennac\"${NC}"
    slavePassword='opennac'
fi


#set up ssh keys
if $SSH_KEY_SCRIPT "$principal" "$principalPassword" ; then
    echo -e "${GREEN}Connection with Principal success${NC}\n"
else
    echo -e "${RED}Connection with Principal fails${NC}"
    exit 0
fi
if $SSH_KEY_SCRIPT "$slave" "$slavePassword" ; then
    echo -e "${GREEN}Connection with Slave success${NC}\n"
else
    echo -e "${RED}Connection with Slave fails${NC}"
    exit 0
fi

exit 0