#!/bin/bash

# OpenNAC 1.2.1 ElasticSearch migration to 1.2.2

#Screen colour constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHT_BLUE='\033[0;34m'
NC='\033[0m'

helpMenu(){

    echo -e "\n${GREEN}Description:${NC}
    To migrate the Analytics (Elasticsearch) database, we can use the migrate_Elastic.sh script.
    This script will move the data from the Analytics 1.2.1 node to the 1.2.2 node. 
    To do this, internally we will use the elasticdump tool.

    ${GREEN}Prerequisite:${NC}
        - Elasticdump installed on execution node.
            Please check: https://github.com/elasticsearch-dump/elasticsearch-dump#installing
    
    ${GREEN}Usage:${NC}
        migrate_Elastic.sh -o [Old ANALYTICS IP] -n [New ANALYTICS IP]

    ${GREEN}OPTIONS:${NC}
        -o = IP of the Old Analytics node where the elasticsearch is dumped
        -p = Password for root user on Old Analytics node (default = opennac)
        -n = IP of the New Analytics node where the elasticsearch is transfered
        -h [help] --help = shows this menu\n\n"
}


# Parametres entrada

while [ -n "$1" ]; do
    case "$1" in
    -o | --old) oldAnalytics=$2; shift 2;;
    -p | --oldpass) oldAnalyticsPass=$2; shift 2;;
    -n | --new) newAnalytics=$2; shift 2;;
    -h | --help) help_menu=true; shift ;;
    --) shift; break ;;
    *) break ;;
    esac
done

if [ "$help_menu" = true ]
then
    helpMenu
    exit 0
fi

if [ -z "$oldAnalytics" ]; then
    echo -e "${RED}Missing -o / --old (Old Analytics Target)${NC}"
    exit 1
fi
if [ -z "$newAnalytics" ]; then
    echo -e "${RED}Missing -n / --new (New Analytics Target)${NC}"
    exit 1
fi

if [ -z "$oldAnalyticsPass" ]; then
    echo -e "${YELLOW}Missing -p / --oldpass (Pasword for Old Analytics), using default \"opennac\"${NC}"
    oldAnalyticsPass='opennac'
fi

if ! hash "elasticdump" &> /dev/null; then
  echo -e "${RED}Please install elasticdump in order to run this script${NC}"
  exit 1
fi


indices=$(curl -s -XGET $oldAnalytics:9200/_cat/indices?h=i)

echo -e "${YELLOW}\nDumping .kibana from elasticsearch DB to New Analytics node${NC}\n"

elasticdump --input=http://$oldAnalytics:9200/.kibana --output=http://$newAnalytics:9200/.kibana --type=data

echo -e "${YELLOW}\nDumping DATA from elasticsearch DB to New Analytics node${NC}\n"

for INDEX in $indices
do
    if [[ $INDEX != ".kibana_"* ]]; then
        echo -e "\n${LIGHT_BLUE}---> $INDEX${NC}\n"
        elasticdump --input=http://$oldAnalytics:9200/$INDEX --output=http://$newAnalytics:9200/$INDEX --type=data
    fi
done

echo -e "${YELLOW}\nRestarting Elastic services on New Analytics${NC}\n"

sshpass -p "opennac" ssh -o StrictHostKeyChecking=no root@$newAnalytics "systemctl restart elasticsearch || systemctl restart logstash || systemctl restart kibana"