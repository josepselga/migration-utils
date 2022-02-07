#!/bin/bash

onslave = $arg1
son_slave_root_password = $arg2
ddbbName = opennac121_$(date +%d-%m-%Y).sql
ddbbPath = /tmp
SSH_KEY_SCRIPT="./set_up_ssh_keys.sh"

# POST ANSIBLE DEPLOYMENT

## executar script al nou principal , fer mysql dump al slave (indicar manualment ip)

####################
#  REMOTE ON SLAVE 
####################

#set up ssh keys
sh "$SSH_KEY_SCRIPT" "$onslave $on_slave_root_password"

# Dump database
ssh root@$onslave "mysqldump -u root -popennac opennac > $dbbPath/$ddbbName"

# Get database from slave
#scp -i ~/.ssh/id_rsa opennac.sql root@onprincipal:$dbbPath/$ddbbName
#scp -i ~/.ssh/id_rsa root@$onslave:$dbbPath/$ddbbName $ddbbPath/$ddbbName
scp root@$onslave:$ddbbPath/$ddbbName $ddbbPath/$ddbbName

# Get application.ini from slave 
#scp -i ~/.ssh/id_rsa root@$onslave:/usr/share/opennac/api/application/configs/application.ini $ddbbPath/application.ini.old
scp root@$onslave:/usr/share/opennac/api/application/configs/application.ini $ddbbPath/application.ini.old

#scp -i ~/.ssh/id_rsa root@$onslave:/usr/share/opennac/healthcheck/libexec/checkMysql.sh $ddbbPath/checkMysql.sh.old
scp root@$onslave:/usr/share/opennac/healthcheck/libexec/checkMysql.sh $ddbbPath/checkMysql.sh.old

# Clear DDBB
# Remove License
sed -i '/^INSERT\sINTO\s`LICENSES`\sVALUES/d' $ddbbPath/$ddbbName

# Nomenclator onmaster -> onprincipal
sed -i 's/whost=onmaster/whost=onprincipal/g' $ddbbPath/$ddbbName


########################
#  LOCAL ON PRINCIPAL #
########################

# Connecto to the ON Principal and start de migration
# Import the 1.2.1 DDBB
mysql -u root -popennac opennac < $ddbbPath/$ddbbName

# Restart Services 
systemctl restart redis
systemctl restart dhcp-helper-reader
systemctl restart mysqld
systemctl restart gearmand
systemctl restart radiusd
systemctl restart httpd
systemctl restart opennac
systemctl restart snmptrapd
systemctl restart collectd
systemctl restart filebeat
systemctl restart rsyslog

# Apply updatedb.php 
php /usr/share/opennac/api/scripts/updatedb.php --assumeyes

# Change application.ini passwords

### regex db info --> /resources\.multidb\.db[R|W]\.(username|password).*=.*"(.*)"/
## We can take all match and replace in the new infra 
## application.ini i al mysql
## usuaris --> root / healthcheck / replicacio

usernameRDB = grep -oP 'resources.multidb.dbR.username.*' $ddbbPath/application.ini.old
passwordRDB = grep -oP 'resources.multidb.dbR.password.*' $ddbbPath/application.ini.old
usernameWDB = grep -oP 'resources.multidb.dbW.username.*' $ddbbPath/application.ini.old
passwordWDB = grep -oP 'resources.multidb.dbW.password.*' $ddbbPath/application.ini.old

# Apply application.ini changes

sed -i "s/resources.multidb.dbR.username.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini
sed -i "s/resources.multidb.dbR.password.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini
sed -i "s/resources.multidb.dbW.username.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini
sed -i "s/resources.multidb.dbW.password.*/$usernameRDB/g" /usr/share/opennac/api/application/configs/application.ini

# Canviar password root mysql

# Canviar usuari healthcheck
cp $ddbbPath/checkMysql.sh.old /usr/share/opennac/healthcheck/libexec/checkMysql.sh 

# Canviar usuari replicacio
