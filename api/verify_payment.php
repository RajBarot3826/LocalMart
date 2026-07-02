<?php
// api/verify_payment.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit(0);
require_once '../includes/db_config.php';

$amount = floatval($_GET['amount'] ?? 0);
if ($amount <= 0) {
    echo json_encode(["status" => false, "message" => "Invalid amount"]);
    exit;
}

try {
    // Check if there's a payment of matching amount received within the last 120 seconds
    $lookbackSeconds = 120;
    $stmt = $conn->prepare("SELECT utr, amount, created_at FROM received_payments WHERE amount = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? SECOND) ORDER BY id DESC LIMIT 1");
    $stmt->execute([$amount, $lookbackSeconds]);
    $payment = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($payment) {
        // Delete or mark used so it can't be reused for another order
        $stmtDelete = $conn->prepare("DELETE FROM received_payments WHERE utr = ?");
        $stmtDelete->execute([$payment['utr']]);

        echo json_encode([
            "status" => true,
            "verified" => true,
            "utr" => $payment['utr']
        ]);
    } else {
        echo json_encode([
            "status" => true,
            "verified" => false
        ]);
    }
} catch (PDOException $e) {
    echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
}
