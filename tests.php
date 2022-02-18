#!/usr/bin/php
<?php


$deviceUserMapper = new Application_Model_DeviceuserMapper();
$networkDeviceMapper = new Application_Model_DeviceMapper();

$configEnv = Common_Config::get()->{"production"};

$dbdata = $configEnv->resources->multidb->dbR->toArray();
$dbR = Zend_Db::factory('PDO_MYSQL',$dbdata);

//$netdevicesInGroups = $dbR->fetchAll('SELECT GROUPS.ID, GROUPS.ID_ITEM, GROUPS_CATEG.NAME, GROUPS.ID_GROUPS_CATEG FROM GROUPS JOIN GROUPS_CATEG ON (GROUPS.ID_GROUPS_CATEG = GROUPS_CATEG.ID AND GROUPS_CATEG.APP = "devices")');

$device = $networkDeviceMapper->find($argv[1]);

if ($device == null) {
    echo "[warning] Network device in group not found, device id: " . $deviceId . PHP_EOL;
    exit;
}

$aDevice = $device->toArray();

try {
    echo var_export($aDevice,true) . PHP_EOL;
}
catch (Common_Model_ValidationException $vE) {
    echo "Error: " . var_export($vE->getMessages(),true) . PHP_EOL;
}
catch(Exception $e) {
    echo "Error: " . $e->getMessage() . PHP_EOL;
}
