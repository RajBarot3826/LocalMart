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
$email = trim($_POST['email'] ?? $inputData['email'] ?? '');
$otp = trim($_POST['otp'] ?? $inputData['otp'] ?? '');

if (empty($email) || empty($otp)) {
    echo json_encode(["status" => false, "message" => "Email and OTP are required."]);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT otp, created_at FROM email_otps WHERE email = ? ORDER BY id DESC LIMIT 1");
    $stmt->execute([$email]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($row) {
        $db_otp = $row['otp'];
        $created_time = strtotime($row['created_at']);
        
        // 10 minutes expiry
        if ($db_otp === $otp) {
            if ($created_time + 600 > time()) {
                // Delete OTP after successful verification
                $stmtDel = $conn->prepare("DELETE FROM email_otps WHERE email = ?");
                $stmtDel->execute([$email]);

                echo json_encode(["status" => true, "message" => "OTP verified successfully."]);
            } else {
                echo json_encode(["status" => false, "message" => "OTP has expired. Please request a new one."]);
            }
        } else {
            echo json_encode(["status" => false, "message" => "Invalid OTP code. Please try again."]);
        }
    } else {
        echo json_encode(["status" => false, "message" => "No OTP request found for this email."]);
    }

} catch (PDOException $e) {
    echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
