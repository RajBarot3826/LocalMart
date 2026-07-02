package com.example.localmart

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.localmart/upi"
    private var pendingResult: MethodChannel.Result? = null
    private val UPI_PAYMENT_REQUEST_CODE = 1001
    private val TAG = "LocalMart_UPI"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startUpiPayment") {
                val upiUri = call.argument<String>("upiUri")
                if (upiUri != null) {
                    pendingResult = result
                    try {
                        Log.d(TAG, "Launching UPI with URI: $upiUri")

                        val upiIntent = Intent(Intent.ACTION_VIEW)
                        upiIntent.data = Uri.parse(upiUri)

                        val pm = packageManager
                        val upiActivities = pm.queryIntentActivities(upiIntent, 0)

                        if (upiActivities.isEmpty()) {
                            Log.d(TAG, "No UPI apps resolved by packageManager, falling back to implicit chooser")
                            val chooser = Intent.createChooser(upiIntent, "Pay with")
                            startActivityForResult(chooser, UPI_PAYMENT_REQUEST_CODE)
                        } else {
                            val intentList = ArrayList<Intent>()
                            for (info in upiActivities) {
                                val targetIntent = Intent(Intent.ACTION_VIEW)
                                targetIntent.data = Uri.parse(upiUri)
                                targetIntent.setPackage(info.activityInfo.packageName)
                                intentList.add(targetIntent)
                            }
                            
                            if (intentList.isNotEmpty()) {
                                val target = intentList.removeAt(0)
                                val chooserIntent = Intent.createChooser(target, "Pay with")
                                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intentList.toTypedArray())
                                startActivityForResult(chooserIntent, UPI_PAYMENT_REQUEST_CODE)
                            } else {
                                Log.d(TAG, "Intent list is empty after filtering, falling back to implicit chooser")
                                val chooser = Intent.createChooser(upiIntent, "Pay with")
                                startActivityForResult(chooser, UPI_PAYMENT_REQUEST_CODE)
                            }
                        }
                    } catch (e: android.content.ActivityNotFoundException) {
                        Log.e(TAG, "No UPI apps found: ${e.message}")
                        result.error("NO_UPI_APP", "No UPI apps found on this device", null)
                        pendingResult = null
                    } catch (e: Exception) {
                        Log.e(TAG, "Launch error: ${e.message}")
                        result.error("LAUNCH_ERROR", e.message, null)
                        pendingResult = null
                    }
                } else {
                    result.error("BAD_ARGS", "Missing upiUri argument", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isUpiAppInstalled(): Boolean {
        try {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.data = Uri.parse("upi://pay")
            val list = packageManager.queryIntentActivities(intent, 0)
            return list.isNotEmpty()
        } catch (e: Exception) {
            return false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == UPI_PAYMENT_REQUEST_CODE) {
            val result = pendingResult
            if (result != null) {
                pendingResult = null

                Log.d(TAG, "onActivityResult: resultCode=$resultCode")

                // User pressed back or cancelled the UPI app
                if (resultCode == Activity.RESULT_CANCELED && data == null) {
                    Log.d(TAG, "User cancelled payment (pressed back)")
                    result.success("Status=FAILURE&responseCode=ZD&txnId=&ApprovalRefNo=")
                    return
                }

                // Try to extract the UPI response from the intent
                var response = ""

                if (data != null) {
                    // Method 1: Most UPI apps (BHIM, PhonePe, Paytm) return via "response" extra
                    val responseExtra = data.getStringExtra("response")
                    if (!responseExtra.isNullOrBlank()) {
                        response = responseExtra
                        Log.d(TAG, "Got response from getStringExtra('response'): $response")
                    }

                    // Method 2: Some apps return via "Status" extra directly
                    if (response.isBlank()) {
                        val status = data.getStringExtra("Status")
                        if (!status.isNullOrBlank()) {
                            val txnId = data.getStringExtra("txnId") ?: ""
                            val txnRef = data.getStringExtra("txnRef") ?: ""
                            val approvalRefNo = data.getStringExtra("ApprovalRefNo") ?: ""
                            val responseCode = data.getStringExtra("responseCode") ?: ""
                            response = "Status=$status&txnId=$txnId&txnRef=$txnRef&ApprovalRefNo=$approvalRefNo&responseCode=$responseCode"
                            Log.d(TAG, "Built response from individual extras: $response")
                        }
                    }

                    // Method 3: Try reading from intent data URI (GPay sometimes does this)
                    if (response.isBlank() && data.data != null) {
                        val dataUri = data.data.toString()
                        Log.d(TAG, "Trying intent data URI: $dataUri")
                        if (dataUri.contains("Status=") || dataUri.contains("status=")) {
                            response = dataUri
                        }
                    }

                    // Method 4: Try reading all bundle extras as last resort
                    if (response.isBlank() && data.extras != null) {
                        val bundle = data.extras!!
                        val sb = StringBuilder()
                        for (key in bundle.keySet()) {
                            val value = bundle.getString(key, "")
                            if (value.isNotBlank()) {
                                if (sb.isNotEmpty()) sb.append("&")
                                sb.append("$key=$value")
                            }
                        }
                        if (sb.isNotEmpty()) {
                            response = sb.toString()
                            Log.d(TAG, "Built response from bundle extras: $response")
                        }
                    }
                }

                if (response.isBlank()) {
                    Log.d(TAG, "No response data found, treating as failure")
                    response = "Status=FAILURE&responseCode=ZD&txnId=&ApprovalRefNo="
                }

                Log.d(TAG, "Final UPI response: $response")
                result.success(response)
            }
        }
    }
}
