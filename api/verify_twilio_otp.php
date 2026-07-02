<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../includes/db_config.php';

$inputData = json_decode(file_get_contents('php://input'), true);
$phone = trim($_POST['phone'] ?? $inputData['phone'] ?? '');
$otp = trim($_POST['otp'] ?? $inputData['otp'] ?? '');

if (empty($phone) || empty($otp)) {
    echo json_encode(["status" => false, "message" => "Phone number and OTP are required."]);
    exit;
}

// Clean phone to 10 digits
$cleanPhone = preg_replace('/[^0-9]/', '', $phone);
if (strlen($cleanPhone) > 10) {
    $cleanPhone = substr($cleanPhone, -10);
}

// Immediate bypass for developer friendly mock OTP
if ($otp === '111111') {
    // Delete database entries for cleanup
    try {
        $stmtDel = $conn->prepare("DELETE FROM sms_otps WHERE phone = ?");
        $stmtDel->execute([$cleanPhone]);
    } catch (PDOException $e) {}

    echo json_encode([
        "status" => true,
        "message" => "OTP verified successfully."
    ]);
    exit;
}

try {
    // Regular validation check
    $stmt = $conn->prepare("SELECT created_at FROM sms_otps WHERE phone = ? AND otp = ?");
    $stmt->execute([$cleanPhone, $otp]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($row) {
        $created_time = strtotime($row['created_at']);
        $current_time = time();
        
        if (($current_time - $created_time) <= 600) {
            $stmtDel = $conn->prepare("DELETE FROM sms_otps WHERE phone = ?");
            $stmtDel->execute([$cleanPhone]);

            echo json_encode([
                "status" => true,
                "message" => "OTP verified successfully."
            ]);
        } else {
            echo json_encode([
                "status" => false,
                "message" => "OTP has expired. Please request a new one."
            ]);
        }
    } else {
        echo json_encode([
            "status" => false,
            "message" => "Invalid OTP. Please enter the correct verification code."
        ]);
    }
} catch (PDOException $e) {
    echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
