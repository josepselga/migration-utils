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
    
    if  [ -f $localFile ]; then echo "hola"
        
        #diff <(md5sum opennac) <(md5sum opennac.md5)
        #cat opennac | tr -d '[:space:]' > opennac_cut

        if diff <(cat $localFile | tr -d '[:space:]' | md5sum) <(cat $confFile | tr -d '[:space:]' | md5sum); then
            echo "Changes detected on --> " $confFile
        fi
    
    else
        echo "File " $confFile " not find on files folder"
    fi
}


####################
#  LOCAL ON MASTER #
####################

# Dump database
mysqldump -u root -popennac opennac > $dbbPath/$ddbbName

# Clear DDBB
# Remove License
sed -i '/^INSERT\sINTO\s`LICENSES`\sVALUES/d' $dbbPath/$ddbbName

# Nomenclator onmaster -> onprincipal
sed -i 's/onmaster/onprincipal/g' $dbbPath/$ddbbName

# Send database to principal
scp -i ~/.ssh/id_rsa opennac.sql root@onprincipal:$dbbPath/$ddbbName

## Comprovar modificaciones de la instalacion 

for i in "${filesToCheck[@]}"
do
    check_changes $i
done


########################
#  REMOTE ON PRINCIPAL #
########################

# Connecto to the ON Principal and start de migration
# Import the 1.2.1 DDBB
ssh root@$onprincipal 'mysql -u root -popennac opennac < $dbbPath/$ddbbName'

# Restart Services 
ssh root@$onprincipal 'systemctl restart redis; systemctl restart dhcp-helper-reader ; systemctl restart mysqld; systemctl restart gearmand; systemctl restart radiusd; systemctl restart httpd; systemctl restart opennac; systemctl restart slapd; systemctl restart snmptrapd; systemctl restart collectd; systemctl restart filebeat; systemctl restart rsyslog'

# Apply updatedb.php 
ssh root@$onprincipal 'php /usr/share/opennac/api/scripts/updatedb.php'
