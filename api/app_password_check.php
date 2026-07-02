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
$password = $inputData['password'] ?? '';
$role = $inputData['role'] ?? 'customer';

if (empty($phone) || empty($password)) {
    echo json_encode(["status" => "error", "message" => "Phone number and password are required."]);
    exit;
}

if ($role === 'rider') {
    checkRiderPassword($conn, $phone, $password);
} else {
    checkCustomerPassword($conn, $phone, $password);
}

echo json_encode(["status" => "error", "message" => "Invalid phone number or password."]);
exit;

function checkCustomerPassword($conn, $phone, $password) {
    $stmt = $conn->prepare("SELECT * FROM users WHERE phone=? OR email=?");
    $stmt->execute([$phone, $phone]);
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $db_pass = $row['password'] ?? '';
        if ($db_pass === $password || $db_pass === md5($password) || password_verify($password, $db_pass)) {
            echo json_encode([
                "status" => "success",
                "message" => "Password verified.",
                "role" => "customer"
            ]);
            exit;
        }
    }
}

function checkRiderPassword($conn, $phone, $password) {
    $stmt = $conn->prepare("SELECT * FROM riders WHERE phone=? OR email=?");
    $stmt->execute([$phone, $phone]);
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $db_pass = $row['password'] ?? '';
        if ($db_pass === $password || $db_pass === md5($password) || password_verify($password, $db_pass)) {
            echo json_encode([
                "status" => "success",
                "message" => "Password verified.",
                "role" => "rider"
            ]);
            exit;
        }
    }
}
?>
