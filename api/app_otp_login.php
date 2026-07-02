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
if (empty($inputData)) {
    $inputData = $_POST;
}

$phone = trim($inputData['phone'] ?? '');
$role = $inputData['role'] ?? 'customer';

if (empty($phone)) {
    echo json_encode(["status" => "error", "message" => "Phone number is required."]);
    exit;
}

if ($role === 'rider') {
    $stmt = $conn->prepare("SELECT * FROM riders WHERE phone=?");
    $stmt->execute([$phone]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row) {
        echo json_encode([
            "status" => "success",
            "role" => "rider",
            "user" => [
                "id" => (int)$row['id'],
                "name" => $row['name'],
                "phone" => $row['phone'],
                "email" => $row['email'],
                "vehicle_number" => $row['vehicle_number']
            ]
        ]);
        exit;
    }
} else {
    $stmt = $conn->prepare("SELECT * FROM users WHERE phone=?");
    $stmt->execute([$phone]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row) {
        echo json_encode([
            "status" => "success",
            "role" => "customer",
            "user" => [
                "id" => (int)$row['id'],
                "name" => $row['name'],
                "phone" => $row['phone'],
                "email" => $row['email']
            ]
        ]);
        exit;
    }
}

echo json_encode(["status" => "error", "message" => "User record not found."]);
exit;
?>
