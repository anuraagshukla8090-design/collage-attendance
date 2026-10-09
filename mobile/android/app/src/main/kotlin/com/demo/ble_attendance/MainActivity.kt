package com.demo.ble_attendance

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSet
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.demo.ble_attendance/ble"
        private const val PERMISSION_REQUEST = 7711
        private const val COMPANY_ID = 0xFFFF
        private const val ADVERTISE_RELEASE_DELAY_MS = 600L
        private const val MAX_ADVERTISE_RETRIES = 3
        private val SERVICE_UUID = ParcelUuid.fromString("0000A77E-0000-1000-8000-00805F9B34FB")
    }

    private val handler = Handler(Looper.getMainLooper())
    private var permissionResult: MethodChannel.Result? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var advertisingSet: AdvertisingSet? = null
    private var advertisingSetCallback: AdvertisingSetCallback? = null
    private var advertisingSetResult: MethodChannel.Result? = null
    private var pendingAdvertiseStart: Runnable? = null
    private var scanCallback: ScanCallback? = null
    private var scanResult: MethodChannel.Result? = null
    private var bestScan: Map<String, Any>? = null
    private var bestRssi = Int.MIN_VALUE

    private val bluetoothManager: BluetoothManager
        get() = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> requestBlePermissions(call, result)
                "startAdvertising" -> startAdvertising(call, result)
                "stopAdvertising" -> {
                    stopAdvertising()
                    result.success(null)
                }
                "scan" -> startScan(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestBlePermissions(call: MethodCall, result: MethodChannel.Result) {
        val mode = call.argument<String>("mode") ?: "scan"
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (mode == "advertise") {
                arrayOf(Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT)
            } else {
                arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
            }
        } else if (mode == "scan") {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        } else {
            emptyArray()
        }
        val missing = permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) {
            result.success(null)
            return
        }
        if (permissionResult != null) {
            result.error("PERMISSION_BUSY", "A Bluetooth permission request is already open.", null)
            return
        }
        permissionResult = result
        requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        val result = permissionResult ?: return
        permissionResult = null
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            result.success(null)
        } else {
            result.error("PERMISSION_DENIED", "Bluetooth permission was denied.", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising(call: MethodCall, result: MethodChannel.Result) {
        val adapter = bluetoothManager.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Turn on Bluetooth to start attendance.", null)
            return
        }
        if (!adapter.isMultipleAdvertisementSupported) {
            result.error("ADVERTISE_UNSUPPORTED", "This Android phone cannot advertise BLE packets.", null)
            return
        }
        val sessionCode = call.argument<String>("sessionCode")
        val token = call.argument<String>("token")
        if (sessionCode == null || token == null || sessionCode.length != 8 || token.length != 16) {
            result.error("INVALID_PAYLOAD", "The BLE session payload is invalid.", null)
            return
        }
        val payload = byteArrayOf(1) + hexToBytes(sessionCode) + hexToBytes(token)
        val advertiser = adapter.bluetoothLeAdvertiser
        if (advertiser == null) {
            result.error("ADVERTISE_UNSUPPORTED", "BLE advertising is unavailable on this phone.", null)
            return
        }
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(SERVICE_UUID)
            .addManufacturerData(COMPANY_ID, payload)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && advertiseCallback == null) {
            startOrUpdateAdvertisingSet(advertiser, data, result)
        } else {
            stopAdvertising()
            startLegacyAdvertising(advertiser, data, result)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startLegacyAdvertising(
        advertiser: android.bluetooth.le.BluetoothLeAdvertiser,
        data: AdvertiseData,
        result: MethodChannel.Result,
    ) {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .setTimeout(0)
            .build()
        var retryCount = 0
        lateinit var callback: AdvertiseCallback
        lateinit var startAttempt: Runnable
        startAttempt = Runnable {
            if (advertiseCallback !== callback) return@Runnable
            pendingAdvertiseStart = null
            advertiser.startAdvertising(settings, data, callback)
        }
        callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                if (advertiseCallback !== this) return
                result.success(null)
            }

            override fun onStartFailure(errorCode: Int) {
                if (advertiseCallback !== this) return
                if (
                    errorCode == ADVERTISE_FAILED_TOO_MANY_ADVERTISERS &&
                    retryCount < MAX_ADVERTISE_RETRIES
                ) {
                    // Several Android BLE stacks release an advertising slot
                    // asynchronously. This is especially visible when rotating
                    // the attendance token, so allow the old slot to settle and
                    // retry instead of immediately failing the session.
                    advertiser.stopAdvertising(this)
                    retryCount++
                    pendingAdvertiseStart = startAttempt
                    handler.postDelayed(startAttempt, ADVERTISE_RELEASE_DELAY_MS)
                    return
                }
                advertiser.stopAdvertising(this)
                advertiseCallback = null
                result.error("ADVERTISE_FAILED", advertiseFailureMessage(errorCode), null)
            }
        }
        advertiseCallback = callback
        // stopAdvertising() above can return before the phone has released its
        // hardware slot. A small gap makes initial starts and token rotation
        // reliable across Samsung, Nothing, Oppo and similar Android devices.
        pendingAdvertiseStart = startAttempt
        handler.postDelayed(startAttempt, ADVERTISE_RELEASE_DELAY_MS)
    }

    @SuppressLint("MissingPermission")
    private fun startOrUpdateAdvertisingSet(
        advertiser: android.bluetooth.le.BluetoothLeAdvertiser,
        data: AdvertiseData,
        result: MethodChannel.Result,
    ) {
        advertisingSet?.let { activeSet ->
            if (advertisingSetResult != null) {
                result.error("ADVERTISE_BUSY", "The BLE broadcast is still being updated.", null)
                return
            }
            advertisingSetResult = result
            activeSet.setAdvertisingData(data)
            return
        }

        if (advertisingSetCallback != null || advertisingSetResult != null) {
            result.error("ADVERTISE_BUSY", "The BLE broadcast is still starting.", null)
            return
        }

        // Android 8+ can keep one advertising instance and update only its
        // packet. This avoids exhausting OEM BLE slots during token rotation.
        val parameters = AdvertisingSetParameters.Builder()
            .setLegacyMode(true)
            .setConnectable(false)
            .setScannable(false)
            .setInterval(AdvertisingSetParameters.INTERVAL_LOW)
            .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_MEDIUM)
            .build()
        var retryCount = 0
        lateinit var callback: AdvertisingSetCallback
        lateinit var startAttempt: Runnable
        startAttempt = Runnable {
            if (advertisingSetCallback !== callback) return@Runnable
            pendingAdvertiseStart = null
            advertiser.startAdvertisingSet(parameters, data, null, null, null, callback)
        }
        callback = object : AdvertisingSetCallback() {
            override fun onAdvertisingSetStarted(
                set: AdvertisingSet?,
                txPower: Int,
                status: Int,
            ) {
                if (advertisingSetCallback !== this) return
                if (status == ADVERTISE_SUCCESS && set != null) {
                    advertisingSet = set
                    advertisingSetResult?.success(null)
                    advertisingSetResult = null
                    return
                }
                if (status == ADVERTISE_FAILED_TOO_MANY_ADVERTISERS && retryCount < MAX_ADVERTISE_RETRIES) {
                    advertiser.stopAdvertisingSet(this)
                    retryCount++
                    pendingAdvertiseStart = startAttempt
                    handler.postDelayed(
                        startAttempt,
                        ADVERTISE_RELEASE_DELAY_MS * retryCount,
                    )
                    return
                }

                val pendingResult = advertisingSetResult
                advertisingSetResult = null
                advertisingSetCallback = null
                advertisingSet = null
                advertiser.stopAdvertisingSet(this)

                if (status == ADVERTISE_FAILED_FEATURE_UNSUPPORTED) {
                    // A few Android 8+ devices implement only the original API.
                    startLegacyAdvertising(advertiser, data, pendingResult ?: return)
                    return
                }
                pendingResult?.error(
                    "ADVERTISE_FAILED",
                    advertiseFailureMessage(status),
                    null,
                )
            }

            override fun onAdvertisingDataSet(set: AdvertisingSet?, status: Int) {
                if (advertisingSetCallback !== this) return
                val pendingResult = advertisingSetResult ?: return
                advertisingSetResult = null
                if (status == ADVERTISE_SUCCESS) {
                    pendingResult.success(null)
                } else {
                    pendingResult.error(
                        "ADVERTISE_FAILED",
                        "The BLE token could not be updated (code $status).",
                        null,
                    )
                }
            }

            override fun onAdvertisingSetStopped(set: AdvertisingSet?) {
                if (advertisingSet === set) advertisingSet = null
            }
        }
        advertisingSetCallback = callback
        advertisingSetResult = result
        pendingAdvertiseStart = startAttempt
        handler.post(startAttempt)
    }

    private fun advertiseFailureMessage(errorCode: Int): String =
        if (errorCode == AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS) {
            "No BLE advertising slot is available. Turn Bluetooth off and on, close other Bluetooth broadcast apps, then try again."
        } else {
            "BLE advertising failed (code $errorCode)."
        }

    @SuppressLint("MissingPermission")
    private fun stopAdvertising() {
        pendingAdvertiseStart?.let(handler::removeCallbacks)
        pendingAdvertiseStart = null
        val advertiser = bluetoothManager.adapter?.bluetoothLeAdvertiser
        advertiseCallback?.let { advertiser?.stopAdvertising(it) }
        advertiseCallback = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            advertisingSetCallback?.let { advertiser?.stopAdvertisingSet(it) }
        }
        advertisingSet = null
        advertisingSetCallback = null
        advertisingSetResult?.error("ADVERTISE_CANCELLED", "BLE advertising was stopped.", null)
        advertisingSetResult = null
    }

    @SuppressLint("MissingPermission")
    private fun startScan(call: MethodCall, result: MethodChannel.Result) {
        if (scanResult != null) {
            result.error("SCAN_BUSY", "A Bluetooth scan is already running.", null)
            return
        }
        val adapter = bluetoothManager.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Turn on Bluetooth to search for class.", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.error("SCAN_UNAVAILABLE", "BLE scanning is unavailable on this phone.", null)
            return
        }
        scanResult = result
        bestScan = null
        bestRssi = Int.MIN_VALUE
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, found: ScanResult) {
                parseScan(found)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach(::parseScan)
            }

            override fun onScanFailed(errorCode: Int) {
                finishScan()
                scanResult?.error("SCAN_FAILED", "BLE scan failed (code $errorCode).", null)
                scanResult = null
            }
        }
        scanCallback = callback
        val filter = ScanFilter.Builder().setServiceUuid(SERVICE_UUID).build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setReportDelay(0)
            .build()
        scanner.startScan(listOf(filter), settings, callback)
        val timeout = (call.argument<Int>("timeoutMs") ?: 5000).coerceIn(1000, 10000)
        handler.postDelayed({ completeScan() }, timeout.toLong())
    }

    private fun parseScan(found: ScanResult) {
        val payload = found.scanRecord?.getManufacturerSpecificData(COMPANY_ID) ?: return
        if (payload.size != 13 || payload[0].toInt() != 1 || found.rssi <= bestRssi) return
        val sessionCode = payload.copyOfRange(1, 5).toHex()
        val token = payload.copyOfRange(5, 13).toHex()
        bestRssi = found.rssi
        bestScan = mapOf("sessionCode" to sessionCode, "token" to token, "rssi" to found.rssi)
    }

    @SuppressLint("MissingPermission")
    private fun finishScan() {
        val callback = scanCallback ?: return
        bluetoothManager.adapter?.bluetoothLeScanner?.stopScan(callback)
        scanCallback = null
    }

    private fun completeScan() {
        val result = scanResult ?: return
        finishScan()
        scanResult = null
        result.success(bestScan)
    }

    private fun hexToBytes(value: String): ByteArray =
        value.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it.toInt() and 0xFF) }

    override fun onDestroy() {
        stopAdvertising()
        finishScan()
        scanResult?.success(null)
        scanResult = null
        super.onDestroy()
    }
}
