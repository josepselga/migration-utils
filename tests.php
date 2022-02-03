<?php

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

                case (preg_match('/analytics.*/', $hostMatch[2]) ? true : false) :
                    array_push($analyticsArray, $hostMatch[1]);
                    break;

                case (preg_match('/aggregator.*/', $hostMatch[2]) ? true : false) :
                    array_push($aggregatorArray, $hostMatch[1]);
                    break;

                case (preg_match('/sensor.*/', $hostMatch[2]) ? true : false) :
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
