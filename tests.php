<?php


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


$user = "admin";
$password = "opennac";
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




