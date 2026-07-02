<?php
// api/sms_webhook.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit(0);
require_once '../includes/db_config.php';

// Retrieve post data
$sms = $_POST['message'] ?? $_POST['text'] ?? '';
if (empty($sms)) {
    $inputData = json_decode(file_get_contents('php://input'), true);
    $sms = $inputData['message'] ?? $inputData['text'] ?? '';
}

if (empty($sms)) {
    echo json_encode(["status" => false, "message" => "Empty message received"]);
    exit;
}

$amount = 0.0;
$utr = "";

// Regex for common Indian banks SMS notifications:
// HDFC: "credited with Rs 20.00 by Ref 412345678901"
// SBI: "credited by Rs 20.00 via UPI Ref 412345678901"
// Paytm Bank: "received Rs.20.00 from X. UTR: 412345678901"
if (preg_match('/(?:rs\.?|inr|received|credited)\s*([\d\.,]+)/i', $sms, $matches)) {
    $amount = floatval(str_replace(',', '', $matches[1]));
}
if (preg_match('/(?:ref|utr|val|reference|no\.?)\s*(?:no\.?\s*)?(\d{12})/i', $sms, $matches)) {
    $utr = $matches[1];
}

if (empty($utr) && preg_match('/(?:ref\s*no\.?|utr)\s*:?\s*(\d{12})/i', $sms, $matches)) {
    $utr = $matches[1];
}

if ($amount > 0 && !empty($utr)) {
    try {
        $stmt = $conn->prepare("INSERT IGNORE INTO received_payments (utr, amount, raw_sms, created_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)");
        $stmt->execute([$utr, $amount, $sms]);
        echo json_encode([
            "status" => true,
            "message" => "Payment recorded successfully",
            "utr" => $utr,
            "amount" => $amount
        ]);
    } catch (PDOException $e) {
        echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
    }
} else {
    echo json_encode([
        "status" => false, 
        "message" => "Could not parse amount or UTR", 
        "parsed_amount" => $amount,
        "parsed_utr" => $utr,
        "raw" => $sms
    ]);
}
