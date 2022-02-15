#!/bin/bash

# OpenNAC 1.2.1 ElasticSearch migration to 1.2.2


while getopts r:o:n: flag
do
    case "${flag}" in
        r) remote='true';;
        o) oldAnalytics=${OPTARG};;
        n) newAnalytics=${OPTARG};;
    esac
done
echo "Remote: $username";
echo "oldAnalytics: $age";
echo "newAnalytics: $fullname";


#newAnalytics = $arg1

elasticdump --input=http://$oldAnalytics:9200/my_index --output=http://$newAnalytics:9200/my_index --type=mapping
elasticdump --input=http://$oldAnalytics:9200/my_index --output=http://$newAnalytics:9200/my_index --type=data --limit=10000
