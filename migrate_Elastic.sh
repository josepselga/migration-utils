#!/bin/bash

# OpenNAC 1.2.1 ElasticSearch migration to 1.2.2


newAnalytics = $arg1


elasticdump --input=http://localhost:9200/my_index --output=http://$newAnalytics:9200/my_index --type=mapping

elasticdump --input=http://localhost:9200/my_index --output=http://$newAnalytics:9200/my_index --type=data