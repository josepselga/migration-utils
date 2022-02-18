# OpenNAC Migration Utils

## check_Changes.sh

The check_Changes script will be useful to us to check if configuration changes have been made in the files with respect to those found in the base OVA deployment.

The operation of this script is basic, it is possible to launch it against an OpenNAC machine remotely. When executed, all the files on the remote machine will be retrieved and compared with those loaded in the files/<Type_Node> directory.
At the end of the execution, we will be shown which files are not the same as the ones we have loaded (OVA). We must check which are the modifications in each of these files and then apply them to the 1.2.2 installation.

To run the script:

``` shell
./check_Changes.sh -n <Node_IP> -t <Node_Type[Core/Analytics]> -p <Node_SSH_Password>
```


## generate_Ansible.php 

Required: PHP installed on the machine where the script is launched.

The generate_Ansible script is a tool that will allow us to generate the “vars_<Node_Type>.yml” files used for the deployment of the new 1.2.2 machines.

This script is launched against a specific machine, the necessary configuration files are recovered and a file “vars_<Node_Type>.yml” is generated that we can find in the /tmpFiles directory of the repository.

This new YAML file is defined using the configuration of the node it was launched against.

To run the script:

``` shell
php generate_Ansible.php -t <Target_IP>  --type <Node_Type[Core/Analytics]> -p <Node_SSH_Password>
```


## migrate_MySQL.sh

This script (migrate_MySQL.sh) is responsible for migrating the database from the 1.2.1 installation to the new 1.2.2.

It has two execution methods, node-node migration and file-node migration.

In the first case, the script will take care of performing the dump on the 1.2.1 machine and moving it to the new node for later import. Besides, the application.ini and check_MySQL.sh files will be recovered as they contain configurations that are necessary for the operation in 1.2.2. In this method it is only necessary to enter the IP of the node 1.2.1 and that of 1.2.2 (in addition, it may be necessary to enter the SSH passwords if they are not the default ones).

In the second method, file-node, we can use the dump of a database (1.2.1) that we have already exported. Running the script will send the database to the new node and perform the migration. In this case, it will be necessary to introduce the read/write password of the admin user that can be found in the application.ini file of the 1.2.1 installation and the healthckeck password that can be found in the check_MySQL.sh file.

To run the script:

• Node-node:

```
migrate_MySQL.sh -p <Node 1.2.2> -s <Node 1.2.1>
```

*It is recommended that, if possible, node 1.2.1 be a “Core slave”.

Options:

```
--principalPass = SSH password for root user on Principal (1.2.2) node (default = opennac)
--slavePass = SSH password for root user on Slave (1.2.1) node (default = opennac)
```

• File-Node

```
migrate_MySQL.sh -p <Node 1.2.2> -f <Dump 1.2.1>.sql --mysqlpass <Password_application.ini> --healthpass <Password_check_Mysql.sh>
```

Options:

```
--principalPass = SSH password for root user on Principal (1.2.2) node (default = opennac)
```

After execution the database will be migrated to node 1.2.2 but some points must be taken into account:

• Loss of license: The migration process from one node to another implies the loss of the previous license. It will be necessary to sign a new license with a TTL equal to the one we had in the 1.2.1 installation.

• Administration portal password: To access the administration portal we must use the credentials of the 1.2.1 installation.

## migrate_Elastic.sh  

To migrate the Analytics (Elasticsearch) database, we can use the migrate_Elastic.sh script.

This script will move the data from the Analytics 1.2.1 node to the 1.2.2 node. To do this, internally we will use the elasticdump tool.

To run the script:

```
```