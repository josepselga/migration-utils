<?php

// Script to generate the OpenNAC Ansible Vars file to deploy a migrated 1.2.2 infraestructure

//--------------------------- 
//   VARS  
//---------------------------
$mysql_root_password = "opennac" ;

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

//Get all necesary files to parse config to Ansivle vars YML from remote hosts
function getFiles($target, $targetPassword, $files, $local){
    //Connect to target
    $connection = ssh2_connect($target, 22);
    if($connection){
        #ssh2_auth_password($connection, 'root', 'opennac');
        #$connect = ssh2_connect($target, 22);
        if(ssh2_auth_password($connection, 'root', $targetPassword)){
            echo "Password Authentication Successful\n";
            echo "Retrieving files...\n";
            foreach ($files as $file) {
                $basename = basename($file);
                ssh2_scp_recv($connection, $file, "$local/$basename");
            }
            ssh2_disconnect($connection);
        }
        else
        {
            echo "Password Authentication Failed\n";
            ssh2_disconnect($connection);
            exit;
        }
    }else{
        echo "Can't connect to host via SSH: $target\n";
        exit;
    }
}

function removeTmpFiles($files, $local){
    foreach ($files as $file) {
        $basename = basename($file);
        unlink("$local/$basename");
    }
}


function parse_ntp($file){

    #$ntpServers = array();
    $ntpServers = array();

    //^server\s+([^\s]+)
    $file = fopen($file, "r");

    if ($file) {
        $i=1;
        while (($line = fgets($file)) !== false) {
            if (preg_match('/^server\s+([^\s]+)/', $line, $hostMatch)){ 
                //echo "NTP Server -> "; echo $hostMatch[1] . "\n";
                $ntpServers["NTPServ.$i"]=$hostMatch[1];
                //array_push($ntpServers, $hostMatch[1]);
                $ntpServer = $hostMatch[1];
                $i++;
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/ntp.conf file \n\n";
    } 
    return $ntpServers;
}
function parse_repoAuth($file){

    $repoCredentials = "";
    $repoOpennac = "repo-opennac.opencloudfactory.com/x86_64";
    //^server\s+([^\s]+)
    $file = fopen($file, "r");

    if ($file) {
        while (($line = fgets($file)) !== false) {
            if (preg_match('/^baseurl.+?\/\/(.+?)@(.+)$/', $line, $repoMatch)){ 
                //if ($repoMatch[0] == $repoOpennac){
                    $repoCredentials = $repoMatch[1];
                    //echo "Repo Credentials --> " .  $repoCredentials . "\n";
                //}
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
function parse_clientsConf($file){
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
    $clients = array();
    $file = fopen($file, "r");

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
                    
                    $client = array("IP" => trim($clientIp), "Key" => trim($clientSecret), "Name" =>  trim($clientShortname));
                    
                    array_push($clients, $client);
                    
                }
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/raddb/clients.conf file \n\n";
    } 
    return $clients;
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
    $postfixConfig = array();
    if ($file) {
        while (($line = fgets($file)) !== false) {
            #$relayhostName and #$relayhostPort
            # ^relayhost\s+=\s+\[(.*)]:(.*)$
            if (preg_match('/^relayhost\s+=\s+\[(.*)]:(.*)$/', $line, $relayMatch)){ 
                $relayhostName = $relayMatch[1];
                $relayhostPort = $relayMatch[2];
                $postfixConfig["Relay Host"]=$relayMatch[1];
                $postfixConfig["Relay Port"]=$relayMatch[2];
                //echo "Postfix relay Host --> " .  $relayhostName . "\n\n";
                //echo "Postfix relay Port --> " .  $relayhostPort . "\n\n";
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
            if (preg_match('/^(?!#)(.*?)[\s](.*)$/', $line, $emailMatch)){ 
                $mydomain = $emailMatch[1];
                $emailAddr = $emailMatch[2];
                $postfixConfig["Postfix Domain"]=$emailMatch[1];
                $postfixConfig["Postfix Email"]=$emailMatch[2];
                //echo "Postfix domain --> " .  $mydomain . "\n\n";
                //echo "Postfix email --> " .  $emailAddr . "\n\n";
            }
        }
        fclose($file);
    } else {
        // error opening the file.
        echo "Can't open /etc/postfix/generic file \n\n";
    } 
    return $postfixConfig;
}
function parse_mysqlReplication($file){
    $nagiosPass = 'Simpl3PaSs';
    $file = fopen($file, "r");
    $nagiosPass = "";
    if ($file) {
        while (($line = fgets($file)) !== false) {
            #$relayhostName and #$relayhostPort
            # ^relayhost\s+=\s+\[(.*)]:(.*)$
            if (preg_match('/.* -u\s+(.*)\s+-p\s+\'(.*)\'/', $line, $relayMatch)){ 
                $nagiosPass = $relayMatch[2];
            }
        }
        fclose($file);

    } else {
        // error opening the file.
        echo "Can't open /usr/share/opennac/healthcheck/libexec/checkMysql.sh file \n\n";
    }
    return $nagiosPass;
}
function parse_servers_data(){
}
function parse_pools_data(){
}

function generateAnsibleVarsV2($location, $targetType, $ntp, $repoAuth, $clients, $postfix, $replication){

    $clientString="";
    $clientsString="";

    //- [ip: '192.168.0.0/16', shortname: 'internal192168', secret: 'testing123']
    foreach ($clients as $client){
        $clientString = "  - [ip: '". $client['IP'] ."', shortname: '". $client['Name'] ."', secret: '". $client['Key'] ."']\n";
        $clientsString .= $clientString;
    }
    
    $vars = file("$location/vars_core.yml");
    
    //print_r($vars);

    if ($targetType == "core"){
        $clientsType = "clients_data:";
    }elseif ($targetType == "proxy"){
        $clientsType = "clients_data_PROXY:";
    }

    foreach($vars as $line => $string) {
        if (strpos($string, "ntpserv:") !== FALSE && $targetType == "core"){
            $vars[$line] = "ntpserv: '" . $ntp['NTPServ.1'] ."' # A NTP server where you must get the synchronization";
        }
        if (strpos($string, "repo_auth:") !== FALSE && $targetType == "core"){
            $vars[$line] = "repo_auth: '" . $repoAuth . "' # CHANGE the actual user and password";
        }
        if (strpos($string, $clientsType) !== FALSE){
            $clientsPos = $line;
            $iRemove = $clientsPos + 1;
            while (strpos($vars[$iRemove], "    -") !== FALSE) {
                unset($vars[$iRemove]);
                $iRemove++;
            }
            $varsClear = array_values($vars);
            array_splice($varsClear, $clientsPos + 1, 0, $clientsString );
        }
        if (strpos($string, "relayhostName:") !== FALSE && $targetType == "core"){
            $vars[$line] = "relayhostName: '" . $postfix['Relay Host'] . "'\n";
            $vars[$line+1] = "relayhostPort: '" . $postfix['Relay Port'] . "'\n";
            $vars[$line+2] = "mydomain: '" . $postfix['Postfix Domain'] . "'\n";
            $vars[$line+3] = "emailAddr: '" . $postfix['Postfix Email'] . "'\n";

        }

    }
    if (strpos($string, "mysql_root_password:") !== FALSE && $targetType == "core"){
        $vars[$line] = "mysql_root_password: opennac # Password for mysql root";
    }
    if (strpos($string, "mysql_replication_password_nagios:") !== FALSE && $targetType == "core"){
        $vars[$line] = "mysql_replication_password_nagios: '" . $replication ."'";
    }
    //print_r($varsClear);

    file_put_contents("$location/tests.yml", $varsClear);

}

function generateAnsibleVars($location, $targetType, $ntp, $repoAuth, $clients, $postfix, $replication){

    $clientString="";
    $clientsString="";

    //- [ip: '192.168.0.0/16', shortname: 'internal192168', secret: 'testing123']
    foreach ($clients as $client){
        $clientString = "  - [ip: '". $client['IP'] ."', shortname: '". $client['Name'] ."', secret: '". $client['Key'] ."']\n";
        $clientsString .= $clientString;
    }
    
    $core_vars = fopen("$location/vars_core.yml", "w") or die("Unable to generate vars file!");
    if ($targetType == "core"){
        $txt = "
################
# INSTALLATION #
################

inventory: 'static'
timezone_custom: 'Europe/Madrid'
ntpserv: '" . $ntp['NTPServ.1'] ."' # A NTP server where you must get the synchronization

# The version packages that we want to be installed
# It could be the stable version or the testing one
# Change it if necessary
deploy_testing_version: false
repo_auth: '" . $repoAuth . "' # CHANGE the actual user and password


###########################
# PRINCIPAL CONFIGURATION #
###########################

criticalAlertEmail: 'notify1@opennac.org,notify2@opennac.org'
criticalAlertMailTitle: 'openNAC policy message [%MSG%]'
criticalAlertMailContent: 'Alert generated by policy [%RULENAME%], on %DATE%.\\n\\nData:\\nMAC: %MAC%\\nUser: %USERID%\\nIP Switch: %SWITCHIP%\\nPort: %SWITCHPORT% - %SWITCHPORTID%\\n'


# Variables to configure /etc/raddb/clients.conf
clients_data: 
" . $clientsString . "

# Variables to configure /etc/postfix/main.cf and /etc/postfix/generic
relayhostName: '" . $postfix['Relay Host'] . "'
relayhostPort: '" . $postfix['Relay Port'] . "'
mydomain: '" . $postfix['Postfix Domain'] . "'
emailAddr: '" . $postfix['Postfix Email'] . "'


######################
# WORKER REPLICATION #
######################

mysql_root_password: opennac # Password for mysql root
mysql_replication_password_nagios: '" . $replication ."'
path: /tmp/ # The path to save the dump .sql file


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

";
    }elseif ($targetType == "proxy"){
        $txt = "
################
# INSTALLATION #
################

inventory: 'static'
timezone_custom: 'Europe/Madrid'
ntpserv: '" . $ntp['NTPServ.1'] ."' # A NTP server where you must get the synchronization

# The version packages that we want to be installed
# It could be the stable version or the testing one
# Change it if necessary
deploy_testing_version: false
repo_auth: '" . $repoAuth . "' # CHANGE the actual user and password


###########################
# PRINCIPAL CONFIGURATION #
###########################

criticalAlertEmail: 'notify1@opennac.org,notify2@opennac.org'
criticalAlertMailTitle: 'openNAC policy message [%MSG%]'
criticalAlertMailContent: 'Alert generated by policy [%RULENAME%], on %DATE%.\\n\\nData:\\nMAC: %MAC%\\nUser: %USERID%\\nIP Switch: %SWITCHIP%\\nPort: %SWITCHPORT% - %SWITCHPORTID%\\n'


# Variables to configure /etc/raddb/clients.conf
clients_data: 
    - [ip: '192.168.0.0/16', shortname: 'internal192168', secret: 'testing123']
    - [ip: '10.10.36.0/24', shortname: 'internal1010', secret: 'testing123']
    - [ip: '172.16.0.0/16', shortname: 'internal17216', secret: 'testing123']
    - [ip: '10.0.0.0/8', shortname: 'internal10', secret: 'testing123']

# Variables to configure /etc/postfix/main.cf and /etc/postfix/generic
relayhostName: '" . $postfix['Relay Host'] . "'
relayhostPort: '" . $postfix['Relay Port'] . "'
mydomain: '" . $postfix['Postfix Domain'] . "'
emailAddr: '" . $postfix['Postfix Email'] . "'


######################
# WORKER REPLICATION #
######################

mysql_root_password: opennac # Password for mysql root
mysql_replication_password_nagios: '" . $replication ."'
path: /tmp/ # The path to save the dump .sql file


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
" . $clientsString . "
";
    }

    fwrite($core_vars, $txt);
    
    fclose($core_vars);
}

//--------------------------- 
//   START OF EXECUTION   
//---------------------------

//The idea is to parse all the 1.2.1 config and put into vars YAML file used to deploy an OpenNAC infraestructure so the new nodes will mantain the old ones config
// We can use the IPs defined in /etc/hosts to get the maximum of variables connecting to each node of the infraestructure and get the values (example: proxy config, clients.conf)

$shortopts  = "t:";  // Target (must)
$shortopts .= "p:"; // Target Password
$shortopts .= "n:"; // Target Type

$longopts  = array(
    "type:"    // Target Type
);

$options = getopt($shortopts, $longopts);

//1st we wull read and parse all the information on /etc/hosts
//getEtcHosts($target);

if (!$options["t"]){
    echo "No target specified, pleas select a target \"-t\"\n\n";
    exit;
}else{
    $target = $options["t"];
}

if (!$options["p"]){
    echo "No root password specified, using default...\n\n";
    $targetPassword = "opennac";
}else{
    $targetPassword = $options["p"];
}

echo "----------------------"  . $targetType;

if (!$options["n"]){
    echo "No node type specified, using default (core)...\n\n";
    $targetType = "core";
}else{
    echo "Node type Proxy\n\n";
    $targetType = "proxy";
}



$files = array("/etc/raddb/clients.conf", 
                "/etc/postfix/main.cf", 
                "/etc/postfix/generic", 
                "/etc/ntp.conf", 
                "/usr/share/opennac/healthcheck/libexec/checkMysql.sh",
                "/etc/yum.repos.d/opennac.repo");

//shell_exec("sh ./set_up_ssh_keys.sh $target $targetPassword");

getFiles($target, $targetPassword, $files, "./tmpFiles");

echo "\n\n";
$ntp = parse_ntp("./tmpFiles/ntp.conf");
echo "NTP Servers: \n\n";
print_r ($ntp);
echo "\n---------------------------------------------------------\n\n";

$repoAuth = parse_repoAuth("./tmpFiles/opennac.repo");
echo "REPO Auth: \n\n";
echo "    " . $repoAuth;
echo "\n\n---------------------------------------------------------\n\n";

$clients = parse_clientsConf("./tmpFiles/clients.conf");
echo "Clients.conf: \n\n";
print_r ($clients);
echo "\n---------------------------------------------------------\n\n";

$postfix = parse_postfix("./tmpFiles/main.cf", "./tmpFiles/generic");
echo "Postfix Config: \n\n";
print_r ($postfix);
echo "\n---------------------------------------------------------\n\n";

$replication = parse_mysqlReplication("./tmpFiles/checkMysql.sh");
echo "Nagios Pass: \n\n";
echo "    " . $replication;
echo "\n\n---------------------------------------------------------\n\n";

//generateAnsibleVars("./tmpFiles", $targetType, $ntp, $repoAuth, $clients, $postfix, $replication);

generateAnsibleVarsV2("./tmpFiles", $targetType, $ntp, $repoAuth, $clients, $postfix, $replication);



removeTmpFiles($files, "./tmpFiles");


/*

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

*/

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