
#!/bin/bash

#Screen colour constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHT_BLUE='\033[0;34m'
NC='\033[0m'


ddbbName=opennac121_$(date +%Y%m%d).sql
ddbbPath="/tmp"
help_menu=false
SSH_KEY_SCRIPT="$(dirname "$0")/set_up_ssh_keys.sh"


helpMenu(){

    echo -e "\n${GREEN}Description:${NC}
    This script will migrate the database (MySQL) from a Core 1.2.1 node to another Core 1.2.2 node.
    It is recommended that both nodes are updated to the latest version.
    It is essential to indicate the IP or host accessible by SSH of each of the two nodes.
    
    ${GREEN}Usage:${NC}
        migrate_MySQL.sh -p [PRINCIPAL IP] -s [SLAVE IP]

    ${GREEN}OPTIONS:${NC}
        --principalPass = SSH password for root user on Principal (1.2.2) node
        --slavePass = SSH password for root user on Slave (1.2.1) node
        -h [help] --help = shows this menu\n\n"
}

# POST ANSIBLE DEPLOYMENT

## executar script al nou principal , fer mysql dump al slave (indicar manualment ip)

# Parametres entrada

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
    helpMenu
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

echo -e "\n${LIGHT_BLUE}[ON SLAVE 1.2.1]${NC}\n"

scp $SSH_KEY_SCRIPT root@$slave:/tmp
ssh root@$slave "chmod u+x /tmp/$(basename $SSH_KEY_SCRIPT) | /tmp/$(basename $SSH_KEY_SCRIPT) $principal $principalPassword"
ssh root@$slave "rm -rf /tmp/$(basename $SSH_KEY_SCRIPT)"

# Dump database
echo -e "${YELLOW}  Dumping DB on slave node${NC}\n"
ssh root@$slave "mysqldump -u root -popennac opennac > $ddbbPath/$ddbbName"

# Send database to principal
echo -e "${YELLOW}  Sendind DB from slave (1.2.1) to principal (1.2.2)${NC}\n"
ssh root@$slave "scp $ddbbPath/$ddbbName root@$principal:$ddbbPath/$ddbbName"


# Get application.ini from slave 
echo -e "${YELLOW}  Sendind application.ini from slave (1.2.1) to principal (1.2.2)${NC}\n"
ssh root@$slave "scp /usr/share/opennac/api/application/configs/application.ini root@$principal:$ddbbPath/application.ini.old"

echo -e "${YELLOW}  Sendind checkMysql.sh from slave (1.2.1) to principal (1.2.2)${NC}\n"
ssh root@$slave "scp /usr/share/opennac/healthcheck/libexec/checkMysql.sh root@$principal:$ddbbPath/checkMysql.sh.old"


echo -e "${LIGHT_BLUE}[ON PRINCIPAL 1.2.2]${NC}\n"
# Clear DDBB
# Remove License
echo -e "${YELLOW}  Removing old License in sql dump${NC}\n"
ssh root@$principal "sed -i '/^INSERT\sINTO\s\`LICENSES\`\sVALUES/d' $ddbbPath/$ddbbName"

# Nomenclator onmaster -> onprincipal
echo -e "${YELLOW}  Changing nomenclator onmaster -> onprincipal in sql dump${NC}\n"
ssh root@$principal "sed -i 's/whost=onmaster/whost=onprincipal/g' $ddbbPath/$ddbbName"

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

ssh root@$principal "usernameRDB=$(grep -oP 'resources.multidb.dbR.username.*' $ddbbPath/application.ini.old) | 
                     passwordRDB=$(grep -oP 'resources.multidb.dbR.password.*' $ddbbPath/application.ini.old) | 
                     usernameWDB=$(grep -oP 'resources.multidb.dbW.username.*' $ddbbPath/application.ini.old) | 
                     passwordWDB=$(grep -oP 'resources.multidb.dbW.password.*' $ddbbPath/application.ini.old)"

# Apply application.ini changes
ssh root@$principal "sed -i "s/resources.multidb.dbR.username.*/'$usernameRDB'/g" /usr/share/opennac/api/application/configs/application.ini | 
                     sed -i "s/resources.multidb.dbR.password.*/'$usernameRDB'/g" /usr/share/opennac/api/application/configs/application.ini | 
                     sed -i "s/resources.multidb.dbW.username.*/'$usernameRDB'/g" /usr/share/opennac/api/application/configs/application.ini | 
                     sed -i "s/resources.multidb.dbW.password.*/'$usernameRDB'/g" /usr/share/opennac/api/application/configs/application.ini"

# Canviar password root mysql

# Canviar usuari healthcheck
echo -e "${YELLOW}  Applying changes to checkMysql.sh${NC}\n"
ssh root@$principal "cp $ddbbPath/checkMysql.sh.old /usr/share/opennac/healthcheck/libexec/checkMysql.sh"

# Canviar usuari replicacio



echo -e "${GREEN}¡IMPORTANT! Remember that the portal password may have changed and a new license may need to be generated${NC}\n"
