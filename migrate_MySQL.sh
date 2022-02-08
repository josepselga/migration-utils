#!/bin/bash

#Screen colour constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHT_BLUE='\033[0;34m'
NC='\033[0m'


ddbbName=opennac121_$(date +%d-%m-%Y).sql
ddbbPath="/tmp"
SSH_KEY_SCRIPT="$(dirname "$0")/set_up_ssh_keys.sh"

# POST ANSIBLE DEPLOYMENT

## executar script al nou principal , fer mysql dump al slave (indicar manualment ip)

: <<'END'
while getopts p:x:s:z: flag
do
    case "${flag}" in
        p) principal=${OPTARG};;
        x) principalPassword=${OPTARG};;
        s) slave=${OPTARG};;
        z) slavePassword=${OPTARG};;
        *)
            echo 'Error in line parse' >&2
            exit 1
    esac
done
shift "$(( OPTIND - 1 ))"
END

# Cogemeos los diferentes argumentos que nos introduzcan
while [ -n "$1" ]; do
    case "$1" in
    -p | --principal) principal=$2; shift 2;;
    -s | --slave) slave=$2; shift 2;;
    -h | --help) help_menu=true; shift ;;
    --principalPass) principalPassword=$2; shift 2;;
    --slavePass) slavePassword=$2; shift 2;;
    --) shift; break ;;
    *) break ;;
    esac
done

# Si detectamos el parametro help, llamaremos a la funcion para mostrar las diferentes opciones
if [ "$help_menu" = true ]
then
    help
    exit 0
fi

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
    echo -e "${RED}Connection with Principal fails${NC}\n"
    exit 0
fi
if $SSH_KEY_SCRIPT "$slave" "$slavePassword" ; then
    echo -e "${GREEN}Connection with Slave success${NC}\n"
else
    echo -e "${RED}Connection with Slave fails${NC}\n"
    exit 0
fi

exit 0

echo -e "\n${LIGHT_BLUE}[ON SLAVE 1.2.1]${NC}\n"
# Dump database
echo -e "${YELLOW}  Dumping DB on slave node${NC}\n"
ssh root@$slave "mysqldump -u root -popennac opennac > $dbbPath/$ddbbName"

# Get database from slave
#scp -i ~/.ssh/id_rsa opennac.sql root@onprincipal:$dbbPath/$ddbbName
#scp -i ~/.ssh/id_rsa root@$onslave:$dbbPath/$ddbbName $ddbbPath/$ddbbName
#scp root@$onslave:$ddbbPath/$ddbbName $ddbbPath/$ddbbName
echo -e "${YELLOW}  Sendind DB from slave (1.2.1) to principal (1.2.2)${NC}\n"
ssh root@$slave "sshpass -p $principalPassword scp $dbbPath/$ddbbName root@$principal:$dbbPath/$ddbbName"

# Get application.ini from slave 
#scp -i ~/.ssh/id_rsa root@$onslave:/usr/share/opennac/api/application/configs/application.ini $ddbbPath/application.ini.old
#scp root@$onslave:/usr/share/opennac/api/application/configs/application.ini $ddbbPath/application.ini.old
echo -e "${YELLOW}  Sendind application.ini from slave (1.2.1) to principal (1.2.2)${NC}\n"
ssh root@$slave "sshpass -p $principalPassword scp /usr/share/opennac/api/application/configs/application.ini root@$principal:$ddbbPath/application.ini.old"

#scp -i ~/.ssh/id_rsa root@$onslave:/usr/share/opennac/healthcheck/libexec/checkMysql.sh $ddbbPath/checkMysql.sh.old
#scp root@$onslave:/usr/share/opennac/healthcheck/libexec/checkMysql.sh $ddbbPath/checkMysql.sh.old
echo -e "${YELLOW}  Sendind checkMysql.sh from slave (1.2.1) to principal (1.2.2)${NC}\n"
ssh root@$slave "sshpass -p $principalPassword scp /usr/share/opennac/healthcheck/libexec/checkMysql.sh root@$principal:$ddbbPath/checkMysql.sh.old"


echo -e "${LIGHT_BLUE}[ON PRINCIPAL 1.2.2]${NC}\n"
# Clear DDBB
# Remove License
echo -e "${YELLOW}  Removing old License in sql dump${NC}\n"
ssh root@$principal "sed -i '/^INSERT\sINTO\s`LICENSES`\sVALUES/d' $ddbbPath/$ddbbName"

# Nomenclator onmaster -> onprincipal
echo -e "${YELLOW}  Changing nomenclator onmaster -> onprincipal in sql dump${NC}\n"
ssh root@$principal "sed -i 's/whost=onmaster/whost=onprincipal/g' $ddbbPath/$ddbbName"

# Connecto to the ON Principal and start de migration
# Import the 1.2.1 DDBB
echo -e "${YELLOW}  Importing sql dump to MariaDB${NC}\n"
ssh root@$principal "mysql -u root -popennac opennac < $ddbbPath/$ddbbName"

# Restart Services 
echo -e "${YELLOW}  Restarting services${NC}\n"
ssh root@$principal "systemctl restart redis | systemctl restart dhcp-helper-reader | systemctl restart mysqld | systemctl restart gearmand | systemctl restart radiusd | systemctl restart httpd | systemctl restart opennac | systemctl restart snmptrapd | systemctl restart collectd | systemctl restart filebeat | systemctl restart rsyslog"

# Apply updatedb.php 
echo -e "${YELLOW}  Applying updatedb.php (This may take a while)${NC}\n"
ssh root@$principal "php /usr/share/opennac/api/scripts/updatedb.php --assumeyes"

# Change application.ini passwords

### regex db info --> /resources\.multidb\.db[R|W]\.(username|password).*=.*"(.*)"/
## We can take all match and replace in the new infra 
## application.ini i al mysql
## usuaris --> root / healthcheck / replicacio
echo -e "${YELLOW}  Applying changes to application.ini${NC}\n"
ssh root@$principal "usernameRDB = grep -oP 'resources.multidb.dbR.username.*' $ddbbPath/application.ini.old | 
                     passwordRDB = grep -oP 'resources.multidb.dbR.password.*' $ddbbPath/application.ini.old | 
                     usernameWDB = grep -oP 'resources.multidb.dbW.username.*' $ddbbPath/application.ini.old | 
                     passwordWDB = grep -oP 'resources.multidb.dbW.password.*' $ddbbPath/application.ini.old"

# Apply application.ini changes
ssh root@$principal "sed -i "s/resources.multidb.dbR.username.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini | 
                     sed -i "s/resources.multidb.dbR.password.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini | 
                     sed -i "s/resources.multidb.dbW.username.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini | 
                     sed -i "s/resources.multidb.dbW.password.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini"

# Canviar password root mysql

# Canviar usuari healthcheck
echo -e "${YELLOW}  Applying changes to checkMysql.sh${NC}\n"
ssh root@$principal "cp $ddbbPath/checkMysql.sh.old /usr/share/opennac/healthcheck/libexec/checkMysql.sh"

# Canviar usuari replicacio



echo -e "${GREEN}¡IMPORTANT! Remember that the portal password may have changed and a new license may need to be generated${NC}\n"



help(){

    echo -e "Usage:
    dbReplication -t [deploy/fix] [OPTIONS]

    OPTIONS:
        --dest = ip of the node to fix or deploy. This can be the ip or a file containing all the ips of the secondary nodes. IMPORTANT: if we use a file, it must be in the same directory as the db_replication script
        -h [help] --help = shows this menu
        --src = ONLY used in fix mode. This is the ip of the source node. If it's not included or left blank the current node will be used."
}