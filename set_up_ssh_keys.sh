#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

key=""
errors=0
PASSWORD_FILE="/tmp/password.txt"

# genera key en el master i copia en los slaves

sendSSHKeys(){

    echo "Verifying if keys exists in destination..."
    #ssh -q -o StrictHostKeyChecking=accept-new root@"$1" exit
    res=$(ssh -q -o BatchMode=yes -o ConnectTimeout=2 root@"$1" echo ok 2>&1)
    if [ "$res" = "ok" ]; then
        echo -e "SSH key exists in destination and the connection is ${GREEN}OK: $1 ${NC}\n"
        return 1
    else
        echo "No SSH keys found in: $1"
        echo "Sending ssh key"
        sshpass -f "$PASSWORD_FILE" ssh-copy-id -i /root/.ssh/id_rsa.pub root@"$1"
        #add the ssh fingerprint
        ssh-keyscan -H $1 >> /root/.ssh/known_hosts
        echo "Testing ssh connection.."
        res=$(ssh -q -o BatchMode=yes -o ConnectTimeout=2 root@"$1" echo ok 2>&1)
        if [ "$res" = "ok" ]; then
            echo -e "SSH Connection ${GREEN}OK${NC} with node:${GREEN} $1 ${NC}\n"
        else
            echo -e "${RED}SSH Connection ${RED}KO${NC} with node:${RED} $1\n ${NC}"
            errors=$((errors+1))
        fi
    fi
}

sshKeys(){
    #Check if the master has a ssh KEY
    echo "Checking if there is a key"

    if test -f /root/.ssh/id_rsa; then
        echo "Key found"
    else
        echo "No key was found in /root/.ssh"
        echo "Generating keys"
        ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
    fi

    echo "$2" > $PASSWORD_FILE
    echo "StrictHostKeyChecking no" >> /root/.ssh/config
    echo "UserKnownHostsFile=/dev/null" >> /root/.ssh/config

    if test -f "$1"; then #check if IPs is a file or a single IP
        for ip in $(cat $1)
        do
            sendSSHKeys $ip
        done
    else
        sendSSHKeys $1
    fi
    rm $PASSWORD_FILE #clean the file
    rm /root/.ssh/config #clean the file

    if [ $errors -eq 0 ];
    then
        #echo -e "${GREEN}All the nodes are accesible using SSH Keys${NC}\n"
        return 0
    else
        #echo -e "${RED}NOT all the nodes are accesible using SSH Keys${NC}\n"
        return 1
    fi
}

echo "SSH Keys Deployment"
sshKeys $1 $2

