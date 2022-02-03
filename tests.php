<?php

$hosts = fopen("/etc/hosts", "r");

if ($hosts) {
    while (($line = fgets($hosts)) !== false) {
        // ((?:[0-9]{1,3}\.){3}[0-9]{1,3})\s+(.*[^\s])

        if (preg_match('/((?:[0-9]{1,3}\.){3}[0-9]{1,3})\s+(.*[^\s])/', $lines, $hostMatch)){ 
            echo "\nHost -> "; echo $hostMatch[1] . " --> " . $hostMatch[0] . "\n";
        }


    }
    fclose($hosts);
} else {
    // error opening the file.
    echo "Can't open /etc/hosts file \n\n";
} 
