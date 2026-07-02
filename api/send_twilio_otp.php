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
    $conn->exec("CREATE TABLE IF NOT EXISTS sms_otps (
        id INT AUTO_INCREMENT PRIMARY KEY,
        phone VARCHAR(20) NOT NULL,
        otp VARCHAR(10) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
} catch (PDOException $e) {
    // Ignore error
}

$inputData = json_decode(file_get_contents('php://input'), true);
$phone = trim($_POST['phone'] ?? $inputData['phone'] ?? '');

if (empty($phone)) {
    echo json_encode(["status" => false, "message" => "Phone number is required."]);
    exit;
}

// Clean phone to 10 digits
$cleanPhone = preg_replace('/[^0-9]/', '', $phone);
if (strlen($cleanPhone) > 10) {
    $cleanPhone = substr($cleanPhone, -10);
}

if (strlen($cleanPhone) !== 10) {
    echo json_encode(["status" => false, "message" => "Please enter a valid 10-digit mobile number."]);
    exit;
}

// Fixed mock OTP for testing
$otp = "111111";

try {
    // Save to database
    $stmtDel = $conn->prepare("DELETE FROM sms_otps WHERE phone = ?");
    $stmtDel->execute([$cleanPhone]);

    $stmtIns = $conn->prepare("INSERT INTO sms_otps (phone, otp) VALUES (?, ?)");
    $stmtIns->execute([$cleanPhone, $otp]);

    // Return success instantly without calling Twilio REST API
    echo json_encode([
        "status" => true,
        "message" => "Mobile verification code prepared successfully."
    ]);

} catch (PDOException $e) {
    echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
