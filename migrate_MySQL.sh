#!/bin/bash

onprincipal = $arg1
ddbbName = opennac121_$(date +%d-%m-%Y).sql
dbbPath = /tmp

####################
#  LOCAL ON MASTER 
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
