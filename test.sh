#!/bin/bash
    
    
version=$(ssh root@10.250.102.187 "cat /usr/share/opennac/api/.version | cut -f1 -d\"-\"" 2>&1)


if [[ "$version" != *"1.2.1"* ]]; then
    echo -e "${RED}Slave node must be in 1.2.1 Verion${NC}\n"
fi