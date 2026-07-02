<?php
// api/simulate_sms.php
?>
<!DOCTYPE html>
<html>
<head>
    <title>LocalMart SMS Webhook Simulator</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 20px; background: #f5f5f5; }
        .card { background: white; padding: 24px; border-radius: 12px; max-width: 500px; margin: 40px auto; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        h2 { margin-top: 0; color: #333; }
        textarea { width: 100%; height: 100px; padding: 12px; margin: 12px 0; border: 1px solid #ccc; border-radius: 6px; box-sizing: border-box; font-size: 14px; }
        button { background: #4CAF50; color: white; border: none; padding: 12px 20px; font-size: 16px; border-radius: 6px; cursor: pointer; width: 100%; font-weight: bold; }
        button:hover { background: #45a049; }
        .alert { padding: 12px; background: #e8f5e9; color: #2e7d32; border-radius: 6px; margin-bottom: 15px; display: none; white-space: pre-line; }
    </style>
</head>
<body>
    <div class="card">
        <h2>LocalMart Webhook Tester</h2>
        <p style="color: #666; font-size: 14px;">Simulate an incoming SMS alert to test your webhook and app polling integration.</p>
        
        <div id="alert" class="alert"></div>
        
        <form id="smsForm">
            <label><strong>Sender (e.g., SBI, HDFCBK, AXIS):</strong></label>
            <input type="text" id="sender" value="VM-HDFCBK" style="width:100%; padding:8px; margin:8px 0; border:1px solid #ccc; border-radius:6px; box-sizing:border-box;">
            
            <label><strong>SMS Message Content:</strong></label>
            <textarea id="message" placeholder="Type bank credit SMS here...">Dear Customer, A/c *7099 credited by Rs 20.00 on 01-Jul-2026 via UPI Ref 618392019283.</textarea>
            
            <button type="submit">Simulate Webhook Call</button>
        </form>
    </div>

    <script>
        document.getElementById('smsForm').addEventListener('submit', function(e) {
            e.preventDefault();
            const sender = document.getElementById('sender').value;
            const message = document.getElementById('message').value;
            const alertDiv = document.getElementById('alert');
            
            fetch('sms_webhook.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    sender: sender,
                    message: message,
                    timestamp: new Date().toISOString()
                })
            })
            .then(res => res.json())
            .then(data => {
                alertDiv.style.display = 'block';
                alertDiv.innerText = "Webhook Status: " + data.status + "\n" + data.message + (data.utr ? ("\nUTR parsed: " + data.utr) : "");
                if (data.status === 'success') {
                    alertDiv.style.background = '#e8f5e9';
                    alertDiv.style.color = '#2e7d32';
                } else {
                    alertDiv.style.background = '#ffebee';
                    alertDiv.style.color = '#c62828';
                }
            })
            .catch(err => {
                alertDiv.style.display = 'block';
                alertDiv.innerText = "Error calling webhook: " + err;
                alertDiv.style.background = '#ffebee';
                alertDiv.style.color = '#c62828';
            });
        });
    </script>
</body>
</html>
