<?php

// Script to generate the OpenNAC Ansible Vars file to deploy a migrated 1.2.2 infraestructure

//--------------------------- 
//   VARS  
//---------------------------

$target = "Target IP";
$targetPassword = "Target Root Password";

$clients = array();
$relayhostName = 'relay.remote.com';
$relayhostPort = '25';
$mydomain = 'acme.local';
$emailAddr = 'openNAC@notifications.mycompany.com';
$mysql_root_password = "opennac" ;# Password for mysql root
$mysql_replication_password_nagios = 'Simpl3PaSs';

//--------------------------- 
//   FUNCTIONS  
//---------------------------

function getEtcHosts(){

    $mastersArray = array();
    $slavesArray = array();
    $proxyArray = array();
    $aggregatorsArray = array();
    $analyticsArray = array();
    $sensorsArray = array();

    $hosts = fopen("/etc/hosts", "r");
    if ($hosts) {
        while (($line = fgets($hosts)) !== false) {
            // ((?:[0-9]{1,3}\.){3}[0-9]{1,3})\s+(.*[^\s])

            if (preg_match('/((?:[0-9]{1,3}\.){3}[0-9]{1,3})\s+(.*[^\s])/', $line, $hostMatch)){ 
                echo "\nHost -> "; echo $hostMatch[1] . " --> " . $hostMatch[2] . "\n";
                switch ($hostMatch[2]) {

                    case (preg_match('/master.*/', $hostMatch[2]) ? true : false) :
                            array_push($mastersArray, $hostMatch[1]);
                            echo "master";
                        break;

                    case (preg_match('/slave.*/', $hostMatch[2]) ? true : false) : 
                        array_push($slavesArray, $hostMatch[1]);
                        break;

                    case (preg_match('/proxy.*/', $hostMatch[2]) ? true : false) :
                    case (preg_match('/prx.*/', $hostMatch[2]) ? true : false) :
                        array_push($sensorsArray, $hostMatch[1]);
                        break;

                    case (preg_match('/analytics.*/', $hostMatch[2]) ? true : false) :
                    case (preg_match('/ana.*/', $hostMatch[2]) ? true : false) :
                        array_push($analyticsArray, $hostMatch[1]);
                        break;

                    case (preg_match('/aggregator.*/', $hostMatch[2]) ? true : false) :
                    case (preg_match('/agg.*/', $hostMatch[2]) ? true : false) :
                        array_push($aggregatorArray, $hostMatch[1]);
                        break;

                    case (preg_match('/sensor.*/', $hostMatch[2]) ? true : false) :
                    case (preg_match('/sens.*/', $hostMatch[2]) ? true : false) :
                        array_push($sensorsArray, $hostMatch[1]);
                        break;
                }
            }
        }
        fclose($hosts);
    } else {
        // error opening the file.
        echo "Can't open /etc/hosts file \n\n";
    } 
}
function getToken( $url, $user, $password){
    echo "\n GETTING TOKEN ...";
    $curl = curl_init();
    $url = $url."/auth";
    $set_headers = array (
        "accept" => "application/json",
        "Content-Type" => "application/json"
    );

    $post_data = "{ \"username\": \"$user\", \"password\": \"$password\", \"useOnlyLocalRepo\": true}";
    //URL a transmetre
    curl_setopt($curl, CURLOPT_URL, $url);
    //tornar el resultat de la crida sense tractar
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    //per fer una crida post
    curl_setopt($curl, CURLOPT_POST, 1);
    //afegim els headers a la crida
    curl_setopt($curl, CURLOPT_HTTPHEADER, $set_headers);
    //afegim l'append a la crida
    curl_setopt($curl, CURLOPT_POSTFIELDS, $post_data);

    $response = curl_exec($curl);
    $error = curl_error ($curl);
    $response = json_decode($response, true);

    if (!empty($response) && empty($error)){
        echo "token response --> " . print_r($response) . " \n\n";
        $token = $response['token'];
        echo " \n\033[32m GETTING TOKEN DONE \033[0m \n";
    }else{
        echo "API error getting Token\n". $error;
        return false;
    }
    curl_close($curl);
    return $token;
}
//Gat all necesary files to parse config to Ansivle vars YML from remote hosts
function getRemoteFiles($mastersArray, $slavesArray, $aggregatorsArray, $analyticsArray, $sensorsArray){

    //Connect to worker
    $connection = ssh2_connect($slavesArray[0], 22);
    ssh2_auth_password($connection, 'root', 'opennac');
    ssh2_scp_recv($connection, '/etc/raddb/clients.conf', '/tmp/slave_clients.conf');
    ssh2_disconnect($connection);

    //Connect to proxy
    $connection = ssh2_connect($proxyArray[0], 22);
    ssh2_auth_password($connection, 'root', 'opennac');
    ssh2_scp_recv($connection, '/etc/raddb/proxy.conf', '/tmp/proxy.conf');
    ssh2_scp_recv($connection, '/etc/raddb/clients.conf', '/tmp/proxy_clients.conf');
    ssh2_disconnect($connection);

}

function getFiles($target, $files, $local){
    //Connect to target
    $connection = ssh2_connect($target, 22);
    #ssh2_auth_password($connection, 'root', 'opennac');
    #$connect = ssh2_connect($target, 22);
    if(ssh2_auth_pubkey_file($connect, 'root', '/root/.ssh/id_rsa.pub'))
    {
        echo "Public Key Authentication Successful\n";
        echo "Retrieving files...\n";
        foreach ($files as $file) {
            ssh2_scp_recv($connection, $file, "$local/basename($file)");
        }
    }
    else
    {
        echo "Public Key Authentication Failed\n";
    }
    ssh2_disconnect($connection);
}
###########################
# PRINCIPAL CONFIGURATION #
###########################
function parse_ntp(){

    #$ntpServers = array();
    $ntpServer = "";

    //^server\s+([^\s]+)
    $file = fopen("/etc/ntp.conf", "r");

    if ($file) {
        while (($line = fgets($file)) !== false) {
            if (preg_match('/^server\s+([^\s]+)/', $line, $hostMatch)){ 
                echo "\NTP Server -> "; echo $hostMatch[1] . "\n";
                #array_push($ntpServers, $hostMatch[1]);
                $ntpServer = $hostMatch[1];
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/ntp.conf file \n\n";
    } 
    #return $ntpServers;
    return $ntpServer;
}
function parse_repoAuth(){

    $repoCredentials = "";
    $repoOpennac = "repo-opennac.opencloudfactory.com/x86_64";
    //^server\s+([^\s]+)
    $file = fopen("/etc/yum.repos.d/opennac.repo", "r");

    if ($file) {
        while (($line = fgets($file)) !== false) {
            if (preg_match('/^baseurl.+?\/\/(.+?)@(.+)$/', $line, $repoMatch)){ 
                if ($repoMatch[2] == $repoOpennac){
                    $repoCredentials = $repoMatch[1];
                    echo "Repo Credentials --> " .  $repoCredentials . "\n\n";
                }
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/yum.repos.d/opennac.repo file \n\n";
    } 
    return $repoCredentials;
}
function parse_criticalAlert($user, $password){

    $token = getToken("http://127.0.0.1/api", $user, $password);
    
    $ch = curl_init();
    
    curl_setopt($ch, CURLOPT_URL, 'https://127.0.0.1/api/configuration/notification');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'GET');
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
    
    
    $headers = array();
    $headers[] = 'Accept: application/json';
    $headers[] = 'X-Opennac-Token:' . $token;
    $headers[] = 'X-Opennac-Username:' . $user;
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    
    $response = curl_exec($ch);
    
    if (curl_errno($ch)) {
        echo 'Error:' . curl_error($ch);
    }else{
    
        $result = json_decode($response, true);
    
        $criticalAlertEmail =  $result['params']['alertcritical'];
        $criticalAlertMailTitle = $result['params']['acmsgtitle'];
        $criticalAlertMailContent = $result['params']['acmsgcontent'];
    
    
        echo "Email ---> " . $criticalAlertEmail . "\n";
        echo "Title ---> " . $criticalAlertMailTitle . "\n";
        echo "Msg ---> " . $criticalAlertMailContent . "\n";
    
    }
    curl_close($ch);

}
function parse_clientsConf(){
    /*
    ----------------------------
    |   0    |    1   |    2   |
    ----------------------------
        ^
        |
    -------------
    |    IP     |
    -------------
    |  secret   |
    -------------
    | shortname |
    -------------
    */

    $file = fopen("/etc/raddb/clients.conf", "r");

    if ($file) {
        while (($line = fgets($file)) !== false ) {
            
            if (preg_match('/^client\s([^\s]+)/', $line, $clientMatch)){
                if (strpos($clientMatch[1], "localhost") === false ){  
                    $clientIp = $clientMatch[1];
                    $line = fgets($file);
    
                    if (preg_match('/secret.*=(.*)/', $line, $clientMatch)){
                        $clientSecret = $clientMatch[1];
                        $line = fgets($file);
                        if(preg_match('/shortname.*=(.*)/', $line, $clientMatch)){
                            $clientShortname = $clientMatch[1];
                        }
                    }else{
                        if (preg_match('/shortname.*=(.*)/', $line, $clientMatch)){
                            $clientShortname = $clientMatch[1];
                            $line = fgets($file);
                            if(preg_match('/secret.*=(.*)/', $line, $clientMatch)){
                                $clientSecret = $clientMatch[1];
                            }
                        }
                    }
                    
                    $client = array(trim($clientIp), trim($clientSecret), trim($clientShortname));
                    
                    array_push($clients, $client);
                    
                    /*echo "IP --> " . $clientIp . "\n\n";
                    echo "Secret --> " . $clientSecret . "\n\n";
                    echo "Shortname --> " . $clientShortname . "\n\n";*/
    
                }
            }
        }
    
        print_r($clients);
    
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/raddb/clients.conf file \n\n";
    } 
}
function parse_postfix($maincf, $generic){

    $relayhostName = "relay.remote.com";
    $relayhostPort = "25";
    $mydomain = "acme.local";
    $emailAddr = "openNAC@notifications.mycompany.com";


    #### /etc/postfix/main.cf.
    /*
        relayhost = [smtp.gmail.com]:587
        smtp_use_tls = yes
        smtp_sasl_auth_enable = yes
        smtp_sasl_security_options =
        smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
        smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt
    */
    $file = fopen($maincf, "r");

    if ($file) {
        while (($line = fgets($file)) !== false) {
            #$relayhostName and #$relayhostPort
            # ^relayhost\s+=\s+\[(.*)]:(.*)$
            if (preg_match('/^relayhost\s+=\s+\[(.*)]:(.*)$/', $line, $relayMatch)){ 
                $relayhostName = $relayMatch[1];
                $relayhostPort = $relayMatch[2];
                echo "Postfix relay Host --> " .  $relayhostName . "\n\n";
                echo "Postfix relay Port --> " .  $relayhostPort . "\n\n";
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/postfix/main.cf file \n\n";
    } 

    $file = fopen($generic, "r");

    if ($file) {
        while (($line = fgets($file)) !== false) {
            #$mydomain and $emailAddr
            #^(?!#)(.*)\s+(.*)$
            if (preg_match('/^(?!#)(.*)\s+(.*)$/', $line, $emailMatch)){ 
                $mydomain = $emailMatch[1];
                $emailAddr = $emailMatch[2];
                echo "Postfix domain --> " .  $mydomain . "\n\n";
                echo "Postfix email --> " .  $mydomain . "\n\n";
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/postfix/generic file \n\n";
    } 

    return $repoCredentials;

}
######################
# WORKER REPLICATION #
######################
function parse_mysqlReplication($file){
    
    $file = fopen($maincf, "r");

    if ($file) {
        while (($line = fgets($file)) !== false) {
            #$relayhostName and #$relayhostPort
            # ^relayhost\s+=\s+\[(.*)]:(.*)$
            if (preg_match('/.* -u\s+(.*)\s+-p\s+\'(.*)\'/', $line, $relayMatch)){ 
                $nagiosPass = $relayMatch[2];
                echo "MySQL Nagios Pass --> " .  $nagiosPass . "\n\n";
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /usr/share/opennac/healthcheck/libexec/checkMysql.sh file \n\n";
    } 
}
#######################
# PROXY CONFIGURATION #
#######################
function parse_servers_data(){
}
function parse_pools_data(){
}


//--------------------------- 
//   START OF EXECUTION   
//---------------------------

//The idea is to parse all the 1.2.1 config and put into vars YAML file used to deploy an OpenNAC infraestructure so the new nodes will mantain the old ones config
// We can use the IPs defined in /etc/hosts to get the maximum of variables connecting to each node of the infraestructure and get the values (example: proxy config, clients.conf)

if ($argc > 1) {
    foreach ($argv as $arg) {
        switch ($arg) {
            
                case '--help':
                    help();
                    break;

                case '--type':
                    $type = true;
                    break;

                case '--target':
                    $target = true;
                    break;

                default:
                    echo "Invalid option: '$arg'\nTry '$command --help' for more information." . PHP_EOL;
                    exit(1);
        }
    }
}

//1st we wull read and parse all the information on /etc/hosts
//getEtcHosts($target);

shell_exec("sh ./set_up_ssh_keys.sh $target $targetPassword");

switch ($type) {

    case "proxy":
        $files = array ();
        $folder = "/tmp/generateAnsible";
        getFiles($target, $files, $folder); //Get necesary files and store on /tmp/generateAnsible
        $ntp = parse_ntp($folder . "/");
        $repoAuth = parse_repoAuth();
        $servers = parse_servers_data();
        $pools = parse_pools_data();
        $clients = parse_clientsConf();
        cleanProxyFiles();
        generateAnsible_Proxy($ntp, $repoAuth, $servers, $pools, $clients);
        break;

    case "core":
        $files = array ();
        $local = "/tmp";
        getFiles($target, $files, $local);
        //getEtcHosts($target);
        $ntp = parse_ntp("$local/");
        $repoAuth = parse_repoAuth("$local/");
        //parse_criticalAlert("admin", "opennac"); // This configuration will be imported with the DB migration
        $clients = parse_clientsConf("$local/clients.conf");
        $replication = parse_mysqlReplication();
        generateAnsible_Core($ntp, $repoAuth, $clients, $replication);
        cleanCoreFiles();
        break;

    case "analytics":

        break;

}

function help()
{
    global $argv;
    echo "
Usage: Generate OpenNAC Ansible YAML [options]

Generates the vars YAML for OpenNAC deployment using Ansible.

Available options:
    --help          display this help and exit
    --type          Set the type of the target (Core, Proxy, Analytics, Sensor)
    --target        Set the target to get variables (IP)
";
    exit;
}



// -------------------------------------------------->>>    YAML EXAMPLE
/*

################
# INSTALLATION #
################

ntpserv1: '0.centos.pool.ntp.org'
repo_auth: 'user:password' 

PRINCIPAL CONFIGURATION 

clients_data: 
  - [ip: '192.168.0.0/16', shortname: 'internal192168', secret: 'testing123']
  - [ip: '10.10.36.0/24', shortname: 'internal1010', secret: 'testing123']
  - [ip: '172.16.0.0/16', shortname: 'internal17216', secret: 'testing123']
  - [ip: '10.0.0.0/8', shortname: 'internal10', secret: 'testing123']

relayhostName: 'relay.remote.com' ---> main.cf
relayhostPort: '25' ---> main.cf
mydomain: 'acme.local' ---> /etc/postfix/generic i main.cf
emailAddr: 'openNAC@notifications.mycompany.com'  ---> /etc/postfix/generic


WORKER REPLICATION

mysql_root_password: opennac  # el pass sempre sera opennac no?
mysql_replication_password_nagios: 'Simpl3PaSs' # es el pasword que s utilitza o el que es defineix?


PROXY CONFIGURATION

sharedkey: 'CHANGE_ME'

servers_data:
  - [name: 'slv01lata', ipaddr: '10.111.16.72', secret: '{{ sharedkey }}']
  - [name: 'slv02latb', ipaddr: '10.111.16.73', secret: '{{ sharedkey }}']

pools_data:
  - [namepool: 'auth', namerealm: 'DEFAULT']

clients_data_PROXY:
  - [ip: '192.168.0.0/16', shortname: 'internal192168', secret: '{{ sharedkey }}']
  - [ip: '172.16.0.0/16', shortname: 'internal17216', secret: '{{ sharedkey }}']
  - [ip: '10.0.0.0/8', shortname: 'internal10', secret: '{{ sharedkey }}']

*/



// -------------------------------------------------->>>    YAML EXAMPLE
/*

################
# INSTALLATION #
################

inventory: 'static'
ntpserv1: '0.centos.pool.ntp.org' # A NTP server where you must get the synchronization
deploy_testing_version: false
repo_auth: 'user:password' # CHANGE the actual user and password


###########################
# PRINCIPAL CONFIGURATION #
###########################

criticalAlertEmail: 'notify1@opennac.org,notify2@opennac.org'
criticalAlertMailTitle: 'openNAC policy message [%MSG%]'
criticalAlertMailContent: 'Alert generated by policy [%RULENAME%], on %DATE%.\n\nData:\nMAC: %MAC%\nUser: %USERID%\nIP Switch: %SWITCHIP%\nPort: %SWITCHPORT% - %SWITCHPORTID%\n'


# Variables to configure /etc/raddb/clients.conf
clients_data: 
  - [ip: '192.168.0.0/16', shortname: 'internal192168', secret: 'testing123']
  - [ip: '10.10.36.0/24', shortname: 'internal1010', secret: 'testing123']
  - [ip: '172.16.0.0/16', shortname: 'internal17216', secret: 'testing123']
  - [ip: '10.0.0.0/8', shortname: 'internal10', secret: 'testing123']

# Variables to configure /etc/postfix/main.cf and /etc/postfix/generic
relayhostName: 'relay.remote.com'
relayhostPort: '25'
mydomain: 'acme.local'
emailAddr: 'openNAC@notifications.mycompany.com'


######################
# WORKER REPLICATION #
######################

mysql_root_password: opennac # Password for mysql root
mysql_replication_password_nagios: 'Simpl3PaSs'

# Path where will be saved files created with the script WITHOUT THE LAST "/"
# Make sure you have enough space
path: /tmp


#######################
# PROXY CONFIGURATION #
#######################

sharedkey: 'CHANGE_ME' # The string to encrypt the packets between the Proxy Servers and Backends

# PROXY.CONF
# Edit the following lines in order to configure /etc/raddb/proxy.conf
# You may either need to add new lines or to delete some.
servers_data:
  - [name: 'slv01lata', ipaddr: '10.111.16.72', secret: '{{ sharedkey }}']
  - [name: 'slv02latb', ipaddr: '10.111.16.73', secret: '{{ sharedkey }}']

pools_data:
  - [namepool: 'auth', namerealm: 'DEFAULT']

# CLIENTS.CONF
# Edit the following lines in order to configure /etc/raddb/clients.conf
# You may either need to add new lines or to delete some. 
# Follow the structure indicated below:
clients_data_PROXY:
  - [ip: '192.168.0.0/16', shortname: 'internal192168', secret: '{{ sharedkey }}']
  - [ip: '172.16.0.0/16', shortname: 'internal17216', secret: '{{ sharedkey }}']
  - [ip: '10.0.0.0/8', shortname: 'internal10', secret: '{{ sharedkey }}']

*/