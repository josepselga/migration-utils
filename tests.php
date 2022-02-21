#!/usr/bin/php
<?php



$vars = file("./tmpFiles/vars_core.yml");

$toAdd = array("1\n","2\n","3\n","4\n");

//print_r($vars);

foreach($vars as $line => $string) {
    if (strpos($string, "clients_data:") !== FALSE){
        $clientsPos = $line;
        $iRemove = $clientsPos + 1;
        while (strpos($vars[$iRemove], "    -") !== FALSE) {
            unset($vars[$iRemove]);
            $iRemove++;
        }
        $varsClear = array_values($vars);
        array_splice($varsClear, $clientsPos + 1, 0, $toAdd );
    }
}

//print_r($varsClear);


echo "--------------------------------\n";

file_put_contents('./tmpFiles/tests.yml', $varsClear);

