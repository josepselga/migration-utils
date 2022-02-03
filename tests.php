
<?php

$clients = array();
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

            /*
            preg_match('/secret.*=(.*)/', $line, $clientMatch);
            $clientSecret = $clientMatch[1];
            $line = fgets($file);
            
            preg_match('/shortname.*=(.*)/', $line, $clientMatch);
            $clientShortname = $clientMatch[1];
            */
        }
    }

    print_r($clients);

    fclose($file);
} else {
    // error opening the file.
    echo "Can't open /etc/raddb/clients.conf file \n\n";
} 