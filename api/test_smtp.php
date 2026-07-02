<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once __DIR__ . '/../includes/db_config.php';

$to = "raj03082006@gmail.com";
$subject = "LocalMart SMTP Test Diagnostic";
$message_body = "This is a diagnostic email from LocalMart to verify SMTP configuration.";

$diagnostics = [];
$diagnostics['smtp_defined'] = [
    'host' => defined('SMTP_HOST'),
    'user' => defined('SMTP_USER'),
    'pass' => defined('SMTP_PASS') ? (strlen(SMTP_PASS) > 0 ? "YES (hidden)" : "EMPTY") : "UNDEFINED",
    'port' => defined('SMTP_PORT') ? SMTP_PORT : "default",
    'secure' => defined('SMTP_SECURE') ? SMTP_SECURE : "default"
];

if (!defined('SMTP_HOST') || !defined('SMTP_USER') || !defined('SMTP_PASS')) {
    $diagnostics['status'] = "error";
    $diagnostics['message'] = "SMTP constants are not defined in db_config.php.";
    echo json_encode($diagnostics);
    exit;
}

$host = SMTP_HOST;
$port = defined('SMTP_PORT') ? SMTP_PORT : 465;
$user = SMTP_USER;
$pass = SMTP_PASS;
$secure = defined('SMTP_SECURE') ? SMTP_SECURE : 'ssl';

$context = stream_context_create();
$remote = ($secure === 'ssl' ? 'ssl://' : '') . $host . ':' . $port;

$errno = 0;
$errstr = "";
$socket = @stream_socket_client($remote, $errno, $errstr, 10, STREAM_CLIENT_CONNECT, $context);

if (!$socket) {
    $diagnostics['status'] = "connection_failed";
    $diagnostics['error_code'] = $errno;
    $diagnostics['error_message'] = $errstr;
    echo json_encode($diagnostics);
    exit;
}

$diagnostics['steps'] = [];

// Helper to read multi-line SMTP responses
function read_smtp_resp($socket) {
    $response = "";
    while ($line = fgets($socket, 515)) {
        $response .= $line;
        if (isset($line[3]) && $line[3] === ' ') {
            break;
        }
    }
    return trim($response);
}

$welcome = fgets($socket, 515);
$diagnostics['steps'][] = "Welcome message: " . trim($welcome);

fwrite($socket, "EHLO " . $_SERVER['SERVER_NAME'] . "\r\n");
$ehlo = read_smtp_resp($socket);
$diagnostics['steps'][] = "EHLO response: " . $ehlo;

if ($secure === 'tls') {
    fwrite($socket, "STARTTLS\r\n");
    $starttls = read_smtp_resp($socket);
    $diagnostics['steps'][] = "STARTTLS response: " . $starttls;
    
    if (!@stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
        fclose($socket);
        $diagnostics['status'] = "tls_failed";
        echo json_encode($diagnostics);
        exit;
    }
    
    fwrite($socket, "EHLO " . $_SERVER['SERVER_NAME'] . "\r\n");
    $ehlo_tls = read_smtp_resp($socket);
    $diagnostics['steps'][] = "EHLO TLS response: " . $ehlo_tls;
}

fwrite($socket, "AUTH LOGIN\r\n");
$auth = read_smtp_resp($socket);
$diagnostics['steps'][] = "AUTH LOGIN response: " . $auth;

fwrite($socket, base64_encode($user) . "\r\n");
$user_resp = read_smtp_resp($socket);
$diagnostics['steps'][] = "Username response: " . $user_resp;

fwrite($socket, base64_encode($pass) . "\r\n");
$pass_resp = read_smtp_resp($socket);
$diagnostics['steps'][] = "Password response: " . $pass_resp;

if (strpos($pass_resp, '235') === false) {
    fclose($socket);
    $diagnostics['status'] = "auth_failed";
    echo json_encode($diagnostics);
    exit;
}

$diagnostics['steps'][] = "Authenticated successfully.";

fwrite($socket, "MAIL FROM: <$user>\r\n");
$mail_from = read_smtp_resp($socket);
$diagnostics['steps'][] = "MAIL FROM response: " . $mail_from;

fwrite($socket, "RCPT TO: <$to>\r\n");
$rcpt_to = read_smtp_resp($socket);
$diagnostics['steps'][] = "RCPT TO response: " . $rcpt_to;

fwrite($socket, "DATA\r\n");
$data_resp = read_smtp_resp($socket);
$diagnostics['steps'][] = "DATA response: " . $data_resp;

$headers = "MIME-Version: 1.0\r\n";
$headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
$headers .= "To: <$to>\r\n";
$headers .= "From: LocalMart <$user>\r\n";
$headers .= "Subject: $subject\r\n";

fwrite($socket, $headers . "\r\n" . $message_body . "\r\n.\r\n");
$send_resp = read_smtp_resp($socket);
$diagnostics['steps'][] = "Send response: " . $send_resp;

fwrite($socket, "QUIT\r\n");
fclose($socket);

$diagnostics['status'] = strpos($send_resp, '250') !== false ? "success" : "failed";
echo json_encode($diagnostics);
?>
