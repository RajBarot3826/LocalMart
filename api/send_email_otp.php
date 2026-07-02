<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../includes/db_config.php';

// Auto-create table if not exists
try {
    $conn->exec("CREATE TABLE IF NOT EXISTS email_otps (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) NOT NULL,
        otp VARCHAR(10) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
} catch (PDOException $e) {
    // Ignore error if table creation fails
}

$inputData = json_decode(file_get_contents('php://input'), true);
$email = trim($_POST['email'] ?? $inputData['email'] ?? '');

if (empty($email)) {
    echo json_encode(["status" => false, "message" => "Email address is required."]);
    exit;
}

$otp = sprintf("%06d", mt_rand(100000, 999999));

try {
    // Save to database (delete old OTPs for this email first)
    $stmtDel = $conn->prepare("DELETE FROM email_otps WHERE email = ?");
    $stmtDel->execute([$email]);

    $stmtIns = $conn->prepare("INSERT INTO email_otps (email, otp) VALUES (?, ?)");
    $stmtIns->execute([$email, $otp]);

    // Send Email
    $subject = "LocalMart - Registration OTP Verification";
    $message = "Hello,\n\nYour OTP code for LocalMart registration is: $otp\n\nThis code will expire in 10 minutes.\n\nThank you,\nLocalMart Team";

    $mail_sent = send_smtp_email($email, $subject, $message);

    // SECURE REAL-WORLD RESPONSE: No debug_otp is returned in JSON!
    if ($mail_sent) {
        echo json_encode([
            "status" => true,
            "message" => "OTP sent successfully to your email."
        ]);
    } else {
        echo json_encode([
            "status" => false,
            "message" => "Failed to send verification email. Please check SMTP credentials or try again."
        ]);
    }

} catch (PDOException $e) {
    echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
}

/**
 * Pure PHP lightweight SMTP socket mailer (Supports multi-line EHLO response)
 */
function send_smtp_email($to, $subject, $message_body) {
    if (!defined('SMTP_HOST') || !defined('SMTP_USER') || !defined('SMTP_PASS')) {
        // Fallback to PHP mail() if SMTP is not configured
        $headers = "From: LocalMart <noreply@localmart.free.nf>\r\n";
        $headers .= "Reply-To: noreply@localmart.free.nf\r\n";
        $headers .= "X-Mailer: PHP/" . phpversion();
        return @mail($to, $subject, $message_body, $headers);
    }

    $host = SMTP_HOST;
    $port = defined('SMTP_PORT') ? SMTP_PORT : 465;
    $user = SMTP_USER;
    $pass = SMTP_PASS;
    $secure = defined('SMTP_SECURE') ? SMTP_SECURE : 'ssl';

    $context = stream_context_create();
    $remote = ($secure === 'ssl' ? 'ssl://' : '') . $host . ':' . $port;
    
    $socket = @stream_socket_client($remote, $errno, $errstr, 10, STREAM_CLIENT_CONNECT, $context);
    if (!$socket) {
        return false;
    }

    // Helper to read multi-line SMTP responses
    $read_resp = function($s) {
        $response = "";
        while ($line = fgets($s, 515)) {
            $response .= $line;
            if (isset($line[3]) && $line[3] === ' ') {
                break;
            }
        }
        return $response;
    };

    // Read welcome message
    fgets($socket, 515);
    
    // Send EHLO and read multi-line response
    fwrite($socket, "EHLO " . $_SERVER['SERVER_NAME'] . "\r\n");
    $read_resp($socket);

    if ($secure === 'tls') {
        fwrite($socket, "STARTTLS\r\n");
        $read_resp($socket);
        if (!@stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
            fclose($socket);
            return false;
        }
        fwrite($socket, "EHLO " . $_SERVER['SERVER_NAME'] . "\r\n");
        $read_resp($socket);
    }

    // Auth
    fwrite($socket, "AUTH LOGIN\r\n");
    $read_resp($socket);
    fwrite($socket, base64_encode($user) . "\r\n");
    $read_resp($socket);
    fwrite($socket, base64_encode($pass) . "\r\n");
    $response = $read_resp($socket);
    if (strpos($response, '235') === false) {
        fclose($socket);
        return false;
    }

    // Mail commands
    fwrite($socket, "MAIL FROM: <$user>\r\n");
    $read_resp($socket);
    fwrite($socket, "RCPT TO: <$to>\r\n");
    $read_resp($socket);
    fwrite($socket, "DATA\r\n");
    $read_resp($socket);

    $headers = "MIME-Version: 1.0\r\n";
    $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
    $headers .= "To: <$to>\r\n";
    $headers .= "From: LocalMart <$user>\r\n";
    $headers .= "Subject: $subject\r\n";

    fwrite($socket, $headers . "\r\n" . $message_body . "\r\n.\r\n");
    $response = $read_resp($socket);
    
    fwrite($socket, "QUIT\r\n");
    fclose($socket);

    return strpos($response, '250') !== false;
}
?>
