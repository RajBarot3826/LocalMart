<?php
// patch_backend.php
// Upload this to your 'api/' folder and open it in the browser to automatically apply DB migrations & update all APIs!

header('Content-Type: text/html');

$migrate_db = <<<'PHP'
<?php
// api/migrate_db.php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
require_once '../includes/db_config.php';

$response = ["status" => "success", "messages" => []];

function executeQuery($conn, $sql, &$messages) {
    try {
        $conn->exec($sql);
        $messages[] = "Success: " . substr($sql, 0, 60) . "...";
    } catch (PDOException $e) {
        $messages[] = "Notice: " . $e->getMessage();
    }
}

// 1. Add coordinates to vendors table
executeQuery($conn, "ALTER TABLE vendors ADD COLUMN latitude DECIMAL(10,8) NULL", $response["messages"]);
executeQuery($conn, "ALTER TABLE vendors ADD COLUMN longitude DECIMAL(11,8) NULL", $response["messages"]);

// 2. Add base_price to items (products) table
executeQuery($conn, "ALTER TABLE items ADD COLUMN base_price DECIMAL(10,2) NOT NULL DEFAULT 0.00", $response["messages"]);

// 3. Add commission and delivery tracking columns to orders table
executeQuery($conn, "ALTER TABLE orders ADD COLUMN items TEXT NULL", $response["messages"]);
executeQuery($conn, "ALTER TABLE orders ADD COLUMN customer_phone VARCHAR(20) NULL", $response["messages"]);
executeQuery($conn, "ALTER TABLE orders ADD COLUMN distance_km DECIMAL(6,2) DEFAULT 0.00", $response["messages"]);
executeQuery($conn, "ALTER TABLE orders ADD COLUMN vendor_payout DECIMAL(10,2) DEFAULT 0.00", $response["messages"]);
executeQuery($conn, "ALTER TABLE orders ADD COLUMN rider_payout DECIMAL(10,2) DEFAULT 0.00", $response["messages"]);
executeQuery($conn, "ALTER TABLE orders ADD COLUMN owner_item_commission DECIMAL(10,2) DEFAULT 0.00", $response["messages"]);
executeQuery($conn, "ALTER TABLE orders ADD COLUMN owner_delivery_commission DECIMAL(10,2) DEFAULT 0.00", $response["messages"]);
executeQuery($conn, "ALTER TABLE orders ADD COLUMN owner_total_profit DECIMAL(10,2) DEFAULT 0.00", $response["messages"]);

echo json_encode($response);
PHP;

$place_order = <<<'PHP'
<?php
// api/place_order.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../includes/db_config.php';

$inputData = json_decode(file_get_contents('php://input'), true);
if (empty($inputData)) {
    $inputData = $_POST;
}

$user_phone = $inputData['user_phone'] ?? '';
$user_name = $inputData['user_name'] ?? '';
$customer_phone = $inputData['customer_phone'] ?? $user_phone;
$store_id = intval($inputData['store_id'] ?? 0);
$store_name = $inputData['store_name'] ?? '';
$delivery_address = $inputData['delivery_address'] ?? '';
$payment_method = $inputData['payment_method'] ?? 'COD';
$items = $inputData['items'] ?? [];
$delivery_lat = isset($inputData['delivery_lat']) && $inputData['delivery_lat'] !== '' ? doubleval($inputData['delivery_lat']) : null;
$delivery_lng = isset($inputData['delivery_lng']) && $inputData['delivery_lng'] !== '' ? doubleval($inputData['delivery_lng']) : null;

if (empty($user_phone) || !$store_id || empty($delivery_address) || empty($items)) {
    echo json_encode(["status" => "error", "message" => "Missing required order details"]);
    exit;
}

// 1. Fetch store address and coordinates
$store_stmt = $conn->prepare("SELECT address, latitude, longitude FROM vendors WHERE id = ?");
$store_stmt->execute([$store_id]);
$store = $store_stmt->fetch(PDO::FETCH_ASSOC);
$store_address = $store ? $store['address'] : '';

// 2. Calculate Distance (in km)
$distance = 5.0; // Default fallback
if ($store && isset($store['latitude']) && isset($store['longitude']) && $delivery_lat && $delivery_lng) {
    $lat1 = doubleval($store['latitude']);
    $lon1 = doubleval($store['longitude']);
    $lat2 = doubleval($delivery_lat);
    $lon2 = doubleval($delivery_lng);
    if ($lat1 != 0 && $lon1 != 0 && $lat2 != 0 && $lon2 != 0) {
        $earthRadius = 6371; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat/2) * sin($dLat/2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon/2) * sin($dLon/2);
        $c = 2 * atan2(sqrt($a), sqrt(1-$a));
        $distance = round($earthRadius * $c, 2);
    }
} else {
    // Pincode extraction fallback
    preg_match('/364[0-9]{3}/', $store_address, $m1);
    preg_match('/364[0-9]{3}/', $delivery_address, $m2);
    $p1 = isset($m1[0]) ? intval($m1[0]) : 0;
    $p2 = isset($m2[0]) ? intval($m2[0]) : 0;
    if ($p1 > 0 && $p2 > 0) {
        $diff = abs($p1 - $p2);
        $distance = $diff == 0 ? 3.0 : 3.0 + ($diff * 2.5);
    }
}

// 3. Compute dynamic delivery fare
$delivery_fee = round($distance * 9.0, 2);
$rider_payout = round($distance * 7.0, 2);
$owner_delivery_commission = round($distance * 2.0, 2);

// 4. Compute items subtotal & store splits
$subtotal = 0.00;
$vendor_payout = 0.00;
$owner_item_commission = 0.00;

$processed_items = [];
foreach ($items as $item) {
    $product_id = intval($item['product_id'] ?? 0);
    $quantity = intval($item['quantity'] ?? 1);
    
    // Look up item prices in database to prevent manipulation
    $prod_stmt = $conn->prepare("SELECT name, price FROM items WHERE id = ?");
    $prod_stmt->execute([$product_id]);
    $prod = $prod_stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($prod) {
        $price = doubleval($prod['price']);
        
        $subtotal += $price * $quantity;
        $vendor_payout += $price * $quantity; // Vendor gets 100% of price
        
        $processed_items[] = [
            "product_id" => $product_id,
            "product_name" => $prod['name'],
            "quantity" => $quantity,
            "price" => number_format($price, 2, '.', '')
        ];
    }
}

$total_amount = $subtotal + $delivery_fee;
$owner_total_profit = $owner_delivery_commission; // Only delivery commission (Owner Item Commission is 0)

// Generate Order ID
$order_id = "ORD-" . strval(rand(100000, 999999));

try {
    $stmt = $conn->prepare("
        INSERT INTO orders (
            order_id, user_phone, user_name, customer_phone, store_id, store_name, 
            total_amount, status, delivery_address, subtotal, delivery_fee, 
            payment_method, items, rider_id, rider_status, distance_km, 
            vendor_payout, rider_payout, owner_item_commission, owner_delivery_commission, 
            owner_total_profit, delivery_lat, delivery_lng
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'Placed', ?, ?, ?, ?, ?, 0, 'pending', ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    
    $success = $stmt->execute([
        $order_id, $user_phone, $user_name, $customer_phone, $store_id, $store_name,
        number_format($total_amount, 2, '.', ''), $delivery_address, 
        number_format($subtotal, 2, '.', ''), number_format($delivery_fee, 2, '.', ''),
        $payment_method, json_encode($processed_items), $distance,
        number_format($vendor_payout, 2, '.', ''), number_format($rider_payout, 2, '.', ''),
        number_format($owner_item_commission, 2, '.', ''), number_format($owner_delivery_commission, 2, '.', ''),
        number_format($owner_total_profit, 2, '.', ''), $delivery_lat, $delivery_lng
    ]);
    
    if ($success) {
        echo json_encode([
            "status" => "success",
            "success" => true,
            "order_id" => $order_id,
            "message" => "Order placed successfully"
        ]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to save order to database"]);
    }
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}
PHP;

$rider_earnings = <<<'PHP'
<?php
// api/rider_earnings.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
require_once '../includes/db_config.php';

$rider_id = isset($_GET['rider_id']) ? intval($_GET['rider_id']) : 0;
$filter = isset($_GET['filter']) ? $_GET['filter'] : 'week';

if (!$rider_id) {
    echo json_encode(["status" => false, "message" => "Rider ID is required"]);
    exit;
}

// 1. Set Date filter
$date_constraint = "";
if ($filter === 'today') {
    $date_constraint = "AND created_at >= CURDATE()";
} else if ($filter === 'month') {
    $date_constraint = "AND created_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)";
} else { // default week
    $date_constraint = "AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
}

try {
    // 2. Fetch completed orders details for this rider
    $stmt = $conn->prepare("
        SELECT id, rider_payout, created_at, status 
        FROM orders 
        WHERE rider_id = ? AND status = 'Delivered' $date_constraint 
        ORDER BY id DESC
    ");
    $stmt->execute([$rider_id]);
    $orders = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $total_earned = 0.00;
    $delivery_fees = 0.00;
    $tips = 0.00;
    $platform_fee = 0.00;
    
    $processed_orders = [];
    foreach ($orders as $o) {
        $earned = doubleval($o['rider_payout']);
        $total_earned += $earned;
        $delivery_fees += $earned;
        
        $processed_orders[] = [
            "id" => $o['id'],
            "date" => date("d M Y, h:i A", strtotime($o['created_at'])),
            "earned" => $earned,
            "is_cancelled" => false
        ];
    }
    
    $deliveries_count = count($orders);
    $avg_per_order = $deliveries_count > 0 ? round($total_earned / $deliveries_count, 2) : 0.00;
    
    echo json_encode([
        "status" => true,
        "data" => [
            "total" => number_format($total_earned, 2, '.', ''),
            "deliveries" => $deliveries_count,
            "rating" => "4.8",
            "per_order" => number_format($avg_per_order, 2, '.', ''),
            "delivery_fees" => number_format($delivery_fees, 2, '.', ''),
            "tips" => number_format($tips, 2, '.', ''),
            "platform_fee" => number_format($platform_fee, 2, '.', ''),
            "orders" => $processed_orders
        ]
    ]);
} catch (PDOException $e) {
    echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
}
PHP;

$admin_reports = <<<'PHP'
<?php
// api/admin_reports.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
require_once '../includes/db_config.php';

// Simple passcode protection for security
$passcode = isset($_GET['passcode']) ? $_GET['passcode'] : '';
if ($passcode !== 'localmart_owner_3826') {
    echo json_encode(["status" => false, "message" => "Unauthorized access"]);
    exit;
}

try {
    // 1. Fetch overall summaries
    $summary = $conn->query("
        SELECT 
            COUNT(id) as total_orders,
            SUM(total_amount) as total_sales,
            SUM(vendor_payout) as total_vendor_payout,
            SUM(rider_payout) as total_rider_payout,
            SUM(owner_item_commission) as total_item_commission,
            SUM(owner_delivery_commission) as total_delivery_commission,
            SUM(owner_total_profit) as total_owner_profit
        FROM orders 
        WHERE status = 'Delivered'
    ")->fetch(PDO::FETCH_ASSOC);

    // 2. Fetch recent completed orders details
    $orders = $conn->query("
        SELECT 
            id, order_id, store_name, total_amount, subtotal, delivery_fee, 
            distance_km, vendor_payout, rider_payout, owner_item_commission, 
            owner_delivery_commission, owner_total_profit, created_at, status
        FROM orders 
        ORDER BY id DESC LIMIT 50
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        "status" => true,
        "summary" => [
            "total_orders" => intval($summary['total_orders'] ?? 0),
            "total_sales" => number_format(doubleval($summary['total_sales'] ?? 0), 2, '.', ''),
            "total_vendor_payout" => number_format(doubleval($summary['total_vendor_payout'] ?? 0), 2, '.', ''),
            "total_rider_payout" => number_format(doubleval($summary['total_rider_payout'] ?? 0), 2, '.', ''),
            "total_item_commission" => number_format(doubleval($summary['total_item_commission'] ?? 0), 2, '.', ''),
            "total_delivery_commission" => number_format(doubleval($summary['total_delivery_commission'] ?? 0), 2, '.', ''),
            "total_owner_profit" => number_format(doubleval($summary['total_owner_profit'] ?? 0), 2, '.', '')
        ],
        "orders" => $orders
    ]);
} catch (PDOException $e) {
    echo json_encode(["status" => false, "message" => "Database error: " . $e->getMessage()]);
}
PHP;

$get_available_orders = <<<'PHP'
<?php
// api/get_available_orders.php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
require_once '../includes/db_config.php';

$shop_table = 'vendors';

$sql = "
    SELECT o.*, s.shop_name as store_name, s.address as store_address, s.contact_number as store_phone
    FROM orders o 
    LEFT JOIN $shop_table s ON o.store_id = s.id
    WHERE o.status IN ('prepared', 'shipped') AND (o.rider_id IS NULL OR o.rider_id = 0)
    ORDER BY o.created_at DESC
";

$result = $conn->query($sql)->fetchAll(PDO::FETCH_ASSOC);
$orders = [];
foreach ($result as $row) {
    $row['items'] = is_string($row['items']) ? json_decode($row['items'], true) : $row['items'];
    $orders[] = $row;
}

echo json_encode([
    "status" => true,
    "available_orders" => $orders
]);
PHP;

$accept_order = <<<'PHP'
<?php
// api/accept_order.php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
require_once '../includes/db_config.php';

$inputData = json_decode(file_get_contents('php://input'), true);
if (empty($inputData)) {
    $inputData = $_POST;
}

$rider_id = isset($inputData['rider_id']) ? intval($inputData['rider_id']) : 0;
$order_id = isset($inputData['order_id']) ? intval($inputData['order_id']) : 0;

if (!$rider_id || !$order_id) {
    echo json_encode(["status" => false, "message" => "Missing parameters"]);
    exit;
}

$check_stmt = $conn->prepare("SELECT id FROM orders WHERE id = ? AND (rider_id IS NULL OR rider_id = 0)");
$check_stmt->execute([$order_id]);
if (!$check_stmt->fetch()) {
    echo json_encode(["status" => false, "message" => "Order already accepted by another rider"]);
    exit;
}

$rider_stmt = $conn->prepare("SELECT name, phone, vehicle_number FROM riders WHERE id = ?");
$rider_stmt->execute([$rider_id]);
$rider = $rider_stmt->fetch(PDO::FETCH_ASSOC);

$rider_name = $rider ? $rider['name'] : 'Rider';
$rider_phone = $rider ? $rider['phone'] : '';
$vehicle_number = $rider ? $rider['vehicle_number'] : '';

$stmt = $conn->prepare("UPDATE orders SET rider_id = ?, status = 'Accepted', rider_status = 'assigned', rider_name = ?, rider_phone = ?, vehicle_number = ? WHERE id = ?");
if ($stmt->execute([$rider_id, $rider_name, $rider_phone, $vehicle_number, $order_id])) {
    echo json_encode(["status" => true, "message" => "Order accepted successfully"]);
} else {
    echo json_encode(["status" => false, "message" => "Failed to accept order"]);
}
PHP;

$get_orders = <<<'PHP'
<?php
// api/get_orders.php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
require_once '../includes/db_config.php';

if (!isset($_GET['phone'])) {
    echo json_encode(["status" => false, "message" => "Phone required"]);
    exit;
}

$phone = $_GET['phone'];
$shop_table = 'vendors';

$stmt = $conn->prepare("
    SELECT o.*, 
           r.name as rider_name, r.phone as rider_phone, r.vehicle_number,
           s.shop_name as store_name, s.address as store_address, s.contact_number as store_phone
    FROM orders o 
    LEFT JOIN riders r ON o.rider_id = r.id 
    LEFT JOIN $shop_table s ON o.store_id = s.id
    WHERE o.customer_phone = ? OR o.user_phone = ?
    ORDER BY o.id DESC
");
$stmt->execute([$phone, $phone]);
$result = $stmt->fetchAll(PDO::FETCH_ASSOC);

$orders = [];
foreach ($result as $row) {
    $row['items'] = is_string($row['items']) ? json_decode($row['items'], true) : $row['items'];
    $orders[] = $row;
}

echo json_encode(["status" => true, "orders" => $orders]);
PHP;

$rider_active_order = <<<'PHP'
<?php
// api/rider_active_order.php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
require_once '../includes/db_config.php';

if (!isset($_GET['rider_id'])) {
    echo json_encode(["status" => false, "message" => "Rider ID required"]);
    exit;
}

$rider_id = intval($_GET['rider_id']);
$shop_table = 'vendors';

$stmt = $conn->prepare("
    SELECT o.*, 
           s.shop_name as store_name, s.address as store_address, s.contact_number as store_phone
    FROM orders o 
    LEFT JOIN $shop_table s ON o.store_id = s.id
    WHERE o.rider_id = ? AND o.status NOT IN ('Delivered', 'Cancelled', 'Pending', 'Confirmed')
    ORDER BY o.id DESC LIMIT 1
");
$stmt->execute([$rider_id]);
$order = $stmt->fetch(PDO::FETCH_ASSOC);

if ($order) {
    $order['items'] = is_string($order['items']) ? json_decode($order['items'], true) : $order['items'];
    
    $normalized_order = [
        "id" => (int)$order['id'],
        "order_id" => $order['order_id'],
        "status" => $order['status'],
        "rider_status" => $order['rider_status'] ?? '',
        "customer_name" => $order['user_name'],
        "customer_phone" => $order['user_phone'],
        "delivery_address" => $order['delivery_address'],
        "delivery_lat" => $order['delivery_lat'],
        "delivery_lng" => $order['delivery_lng'],
        "store_name" => $order['store_name'],
        "store_address" => $order['store_address'] ?? '',
        "store_phone" => $order['store_phone'] ?? '',
        "payment_method" => $order['payment_method'],
        "total_amount" => $order['total_amount'],
        "items" => $order['items']
    ];
    echo json_encode(["status" => true, "order" => $normalized_order]);
} else {
    echo json_encode(["status" => false, "message" => "No active orders found"]);
}
PHP;

$app_login = <<<'PHP'
<?php
// api/app_login.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../includes/db_config.php';

$phone = $_POST['phone'] ?? '';
$email = $_POST['email'] ?? $phone;
$password = $_POST['password'] ?? '';
$role = $_POST['role'] ?? '';

if (empty($phone) || empty($password)) {
    echo json_encode(["status" => "error", "message" => "Phone/Rider ID and password are required"]);
    exit;
}

if ($role === 'rider') {
    checkRiderLogin($conn, $phone, $email, $password);
    checkCustomerLogin($conn, $phone, $email, $password);
} else if ($role === 'customer') {
    checkCustomerLogin($conn, $phone, $email, $password);
    checkRiderLogin($conn, $phone, $email, $password);
} else {
    checkCustomerLogin($conn, $phone, $email, $password);
    checkRiderLogin($conn, $phone, $email, $password);
}

echo json_encode(["status" => "error", "message" => "Invalid credentials"]);
exit;

function checkCustomerLogin($conn, $phone, $email, $password) {
    $stmt = $conn->prepare("SELECT * FROM users WHERE (phone=? OR email=?) AND password=?");
    $stmt->execute([$phone, $email, $password]);
    if ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo json_encode([
            "status" => "success",
            "role" => "customer",
            "user" => [
                "id" => (int)$row['id'],
                "name" => $row['name'],
                "phone" => $row['phone']
            ]
        ]);
        exit;
    }
}

function checkRiderLogin($conn, $phone, $email, $password) {
    $rider_id_num = is_numeric($phone) ? intval($phone) : 0;
    $stmt = $conn->prepare("SELECT * FROM riders WHERE (phone=? OR email=? OR id=?) AND password=?");
    $stmt->execute([$phone, $email, $rider_id_num, $password]);
    
    if ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo json_encode([
            "status" => "success",
            "role" => "rider",
            "user" => [
                "id" => (int)$row['id'],
                "name" => $row['name'],
                "phone" => $row['phone'],
                "email" => $row['email'],
                "vehicle_number" => $row['vehicle_number'] ?? ''
            ]
        ]);
        exit;
    }
}
PHP;

$inspect = <<<'PHP'
<?php
// api/inspect.php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
require_once '../includes/db_config.php';

$res = [];
$tables = [];
$t_res = $conn->query("SHOW TABLES")->fetchAll();
foreach ($t_res as $row) {
    $tables[] = $row[0];
}
$res['tables'] = $tables;

$shop_table = 'vendors';
$res['detected_shop_table'] = $shop_table;

$shop_cols = [];
if (in_array($shop_table, $tables)) {
    $c_res = $conn->query("SHOW COLUMNS FROM `$shop_table`")->fetchAll(PDO::FETCH_ASSOC);
    foreach ($c_res as $row) {
        $shop_cols[] = $row;
    }
}
$res['shop_table_columns'] = $shop_cols;

$orders_cols = [];
if (in_array('orders', $tables)) {
    $c_res = $conn->query("SHOW COLUMNS FROM `orders`")->fetchAll(PDO::FETCH_ASSOC);
    foreach ($c_res as $row) {
        $orders_cols[] = $row;
    }
}
$res['orders_table_columns'] = $orders_cols;

$recent_orders = [];
if (in_array('orders', $tables)) {
    $o_res = $conn->query("SELECT * FROM `orders` ORDER BY id DESC LIMIT 5")->fetchAll(PDO::FETCH_ASSOC);
    foreach ($o_res as $row) {
        $recent_orders[] = $row;
    }
}
$res['recent_orders'] = $recent_orders;

echo json_encode($res);
PHP;

$read_file = <<<'PHP'
<?php
// api/read_file.php
header('Content-Type: text/plain');
header("Access-Control-Allow-Origin: *");
if (isset($_GET['file'])) {
    $f = $_GET['file'];
    if (file_exists($f)) {
        echo file_get_contents($f);
    } else if (file_exists('../' . $f)) {
        echo file_get_contents('../' . $f);
    } else {
        echo "File not found: " . $f;
    }
} else {
    echo "No file specified";
}
PHP;

$products = <<<'PHP'
<?php
// api/products.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../includes/db_config.php';

try {
    // 1. Fetch all items
    $stmt = $conn->query("SELECT * FROM items ORDER BY id DESC");
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // 2. Fetch all item images
    $img_stmt = $conn->query("SELECT * FROM item_images");
    $images = $img_stmt->fetchAll(PDO::FETCH_ASSOC);

    // Group images by item_id
    $images_by_item = [];
    foreach ($images as $img) {
        $itemId = $img['item_id'];
        if (!isset($images_by_item[$itemId])) {
            $images_by_item[$itemId] = [];
        }
        $path = $img['image_path'];
        if (strpos($path, 'http') === 0) {
            $images_by_item[$itemId][] = $path;
        } else {
            $images_by_item[$itemId][] = "https://localmart.free.nf/" . $path;
        }
    }

    $processed_products = [];
    foreach ($items as $item) {
        $itemId = $item['id'];
        
        $price = doubleval($item['price']);
        
        $item['price'] = number_format($price, 2, '.', '');
        $item['base_price'] = number_format($price, 2, '.', '');
        $item['store_id'] = intval($item['vendor_id']);
        
        $primary_image = $item['image_path'];
        if (strpos($primary_image, 'http') === 0) {
            $item['image_url'] = $primary_image;
        } else {
            $item['image_url'] = "https://localmart.free.nf/" . $primary_image;
        }
        
        $item_imgs = $images_by_item[$itemId] ?? [];
        if (empty($item_imgs)) {
            $item_imgs = [$item['image_url']];
        }
        $item['images_urls'] = $item_imgs;
        
        $processed_products[] = $item;
    }

    echo json_encode([
        "status" => true,
        "products" => $processed_products
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "status" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
PHP;

// Write updated contents on the server
$success1 = file_put_contents('get_available_orders.php', $get_available_orders);
$success2 = file_put_contents('accept_order.php', $accept_order);
$success3 = file_put_contents('get_orders.php', $get_orders);
$success4 = file_put_contents('rider_active_order.php', $rider_active_order);
$success5 = file_put_contents('inspect.php', $inspect);
$success6 = file_put_contents('app_login.php', $app_login);
$success7 = file_put_contents('read_file.php', $read_file);
$success8 = file_put_contents('migrate_db.php', $migrate_db);
$success9 = file_put_contents('place_order.php', $place_order);
$success10 = file_put_contents('rider_earnings.php', $rider_earnings);
$success11 = file_put_contents('admin_reports.php', $admin_reports);
$success12 = file_put_contents('products.php', $products);

echo "<h1>Backend Patch Applied!</h1>";
echo "<ul>";
echo "<li>get_available_orders.php: " . ($success1 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>accept_order.php: " . ($success2 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>get_orders.php: " . ($success3 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>rider_active_order.php: " . ($success4 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>inspect.php: " . ($success5 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>app_login.php: " . ($success6 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>read_file.php: " . ($success7 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>migrate_db.php: " . ($success8 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>place_order.php: " . ($success9 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>rider_earnings.php: " . ($success10 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>admin_reports.php: " . ($success11 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "<li>products.php: " . ($success12 !== false ? "✅ OK" : "❌ FAILED") . "</li>";
echo "</ul>";
echo "<h3>The commission tracking system and order split API backend have been written successfully!</h3>";
?>
