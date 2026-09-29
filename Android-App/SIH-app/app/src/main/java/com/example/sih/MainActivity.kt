package com.example.sih

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.AssetFileDescriptor
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

class MainActivity : AppCompatActivity() {

    private lateinit var tfliteInterpreter: Interpreter
    private lateinit var layoutStatus: android.widget.LinearLayout
    private lateinit var txtStatusDot: TextView
    private lateinit var txtStatus: TextView
    private lateinit var txtShiftCue: TextView
    private lateinit var txtRPM: TextView
    private lateinit var txtGear: TextView
    private lateinit var txtLoad: TextView
    private lateinit var txtTargetRPM: TextView
    private lateinit var btnFinishRide: Button

    private enum class ConnectionState { DISCONNECTED, CONNECTING, CONNECTED }

    private var obdManager: OBDConnectionManager? = null
    @Volatile private var isPolling = false
    private var pollingThread: Thread? = null

    companion object {
        private const val PERMISSION_REQUEST_CODE = 101
        private const val PREFS_NAME = "OBD_PREFERENCES"
        private const val KEY_SAVED_MAC = "saved_obd_mac"
        const val TARGET_OBD_MAC_ADDRESS = "01:23:45:67:89:BA"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        layoutStatus = findViewById(R.id.layoutStatus)
        txtStatusDot = findViewById(R.id.txtStatusDot)
        txtStatus = findViewById(R.id.txtStatus)
        txtShiftCue = findViewById(R.id.txtShiftCue)
        txtRPM = findViewById(R.id.txtRPM)
        txtGear = findViewById(R.id.txtGear)
        txtLoad = findViewById(R.id.txtLoad)
        txtTargetRPM = findViewById(R.id.txtTargetRPM)
        btnFinishRide = findViewById(R.id.btnFinishRide)

        btnFinishRide.setOnClickListener {
            stopPolling()
            startActivity(Intent(this, RideSummaryActivity::class.java))
        }

        // 1. Initialize TFLite Model from Assets
        try {
            tfliteInterpreter = Interpreter(loadModelFile())
        } catch (e: Exception) {
            e.printStackTrace()
            txtShiftCue.text = "Model Load Error"
        }

        // Tap dedicated status card to select or reconnect OBD device
        layoutStatus.setOnClickListener {
            if (isPolling && obdManager != null) {
                AlertDialog.Builder(this)
                    .setTitle("OBD Connection")
                    .setMessage("Currently connected. Do you want to select another device or reconnect?")
                    .setPositiveButton("Select Scanner") { _, _ ->
                        stopPolling()
                        updateBluetoothStatus(ConnectionState.DISCONNECTED, "DISCONNECTED (TAP TO CONNECT)")
                        checkPermissionsAndConnect(manualSelect = true)
                    }
                    .setNegativeButton("Keep Connected", null)
                    .show()
            } else {
                checkPermissionsAndConnect(manualSelect = true)
            }
        }

        // 2. Check Permissions and Start Auto-Connection
        checkPermissionsAndConnect(manualSelect = false)
    }

    override fun onResume() {
        super.onResume()
        // Automatically connect and start streaming telemetry when the app opens or returns to foreground
        if (!isPolling && obdManager == null) {
            checkPermissionsAndConnect(manualSelect = false)
        }
    }

    private fun updateBluetoothStatus(state: ConnectionState, message: String) {
        runOnUiThread {
            txtStatus.text = message
            val (dotColor, textColor, bgColor, strokeColor) = when (state) {
                ConnectionState.CONNECTED -> listOf("#00FF88", "#00FF88", "#0F281B", "#00FF88")
                ConnectionState.CONNECTING -> listOf("#FFB800", "#FFB800", "#241D0D", "#FFB800")
                ConnectionState.DISCONNECTED -> listOf("#FF334B", "#FFAAAA", "#261114", "#381B20")
            }
            txtStatusDot.setTextColor(Color.parseColor(dotColor))
            txtStatus.setTextColor(Color.parseColor(textColor))

            val shape = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = 48f
                setColor(Color.parseColor(bgColor))
                setStroke(2, Color.parseColor(strokeColor))
            }
            layoutStatus.background = shape
        }
    }

    private fun checkPermissionsAndConnect(manualSelect: Boolean) {
        val permissionsToRequest = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADVERTISE) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            }
        }

        // Location is required on Android 11 & below, and recommended for device scanning on OEM ROMs
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsToRequest.toTypedArray(), PERMISSION_REQUEST_CODE)
        } else {
            initiateOBDConnection(manualSelect)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            // Check if essential Bluetooth permissions are granted
            val essentialGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            } else {
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            }

            if (essentialGranted) {
                initiateOBDConnection(manualSelect = false)
            } else {
                updateBluetoothStatus(ConnectionState.DISCONNECTED, "BLUETOOTH PERMISSION DENIED (TAP TO GRANT)")
                Toast.makeText(this, "Bluetooth permissions are required for OBD connection", Toast.LENGTH_LONG).show()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun initiateOBDConnection(manualSelect: Boolean) {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null) {
            updateBluetoothStatus(ConnectionState.DISCONNECTED, "BLUETOOTH NOT SUPPORTED ON THIS DEVICE")
            return
        }

        if (!bluetoothAdapter.isEnabled) {
            updateBluetoothStatus(ConnectionState.DISCONNECTED, "PLEASE ENABLE BLUETOOTH (TAP TO RETRY)")
            try {
                val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                startActivity(enableBtIntent)
            } catch (_: Exception) {
                Toast.makeText(this, "Please turn on Bluetooth in settings", Toast.LENGTH_SHORT).show()
            }
            return
        }

        val bondedDevices = bluetoothAdapter.bondedDevices?.toList() ?: emptyList()
        if (bondedDevices.isEmpty()) {
            updateBluetoothStatus(ConnectionState.DISCONNECTED, "NO PAIRED OBD (PAIR IN PHONE SETTINGS)")
            Toast.makeText(this, "Pair your OBD-II scanner in phone Bluetooth settings first", Toast.LENGTH_LONG).show()
            return
        }

        // If manual select requested, show picker dialog
        if (manualSelect) {
            showDevicePickerDialog(bondedDevices)
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val savedMac = prefs.getString(KEY_SAVED_MAC, null)

        // 1. Direct priority match: Check if user previously saved an OBD MAC
        if (!savedMac.isNullOrBlank()) {
            val savedDevice = bondedDevices.firstOrNull { it.address.equals(savedMac, ignoreCase = true) }
            if (savedDevice != null) {
                startOBDConnection(savedDevice)
                return
            }
        }

        // 2. Direct priority match: Check if TARGET_OBD_MAC_ADDRESS is paired
        val targetDevice = bondedDevices.firstOrNull { it.address.equals(TARGET_OBD_MAC_ADDRESS, ignoreCase = true) }
        if (targetDevice != null) {
            prefs.edit().putString(KEY_SAVED_MAC, targetDevice.address).apply()
            startOBDConnection(targetDevice)
            return
        }

        // 3. Auto-detect paired device named OBD, ELM, VLINKER, SCANNER, etc.
        val obdKeywords = listOf("OBD", "ELM", "VLINKER", "V-LINK", "SCAN", "CAR", "DIAG", "ECU")
        val autoDetectedCandidates = bondedDevices.filter { device ->
            val name = (device.name ?: "").uppercase()
            obdKeywords.any { kw -> name.contains(kw) }
        }

        if (autoDetectedCandidates.isNotEmpty()) {
            val selected = autoDetectedCandidates.first()
            prefs.edit().putString(KEY_SAVED_MAC, selected.address).apply()
            startOBDConnection(selected)
            return
        }

        // 4. If only 1 paired device exists on phone, automatically connect to it
        if (bondedDevices.size == 1) {
            val selected = bondedDevices.first()
            prefs.edit().putString(KEY_SAVED_MAC, selected.address).apply()
            startOBDConnection(selected)
            return
        }

        // 5. Multiple unknown paired devices -> show picker dialog
        showDevicePickerDialog(bondedDevices)
    }

    @SuppressLint("MissingPermission")
    private fun showDevicePickerDialog(devices: List<BluetoothDevice>) {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val savedMac = prefs.getString(KEY_SAVED_MAC, null)

        val names = devices.map { device ->
            val isCurrent = if (device.address.equals(savedMac, ignoreCase = true)) " [CURRENT]" else ""
            "${device.name ?: "Unknown Device"}$isCurrent\n${device.address}"
        }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle("Select OBD-II Scanner")
            .setItems(names) { _, which ->
                val selectedDevice = devices[which]
                prefs.edit().putString(KEY_SAVED_MAC, selectedDevice.address).apply()
                startOBDConnection(selectedDevice)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    @SuppressLint("MissingPermission")
    private fun startOBDConnection(device: BluetoothDevice) {
        stopPolling()

        val displayName = if (!device.name.isNullOrBlank()) device.name else "ELM OBD (${device.address})"
        updateBluetoothStatus(ConnectionState.CONNECTING, "CONNECTING: $displayName...")

        pollingThread = Thread {
            val manager = OBDConnectionManager(device.address)
            val success = manager.connect()

            if (success) {
                obdManager = manager
                isPolling = true

                updateBluetoothStatus(ConnectionState.CONNECTED, "CONNECTED: $displayName (LIVE CAN)")
                runOnUiThread {
                    Toast.makeText(this@MainActivity, "Connected to OBD Scanner!", Toast.LENGTH_SHORT).show()
                }

                pollLiveDataLoop(manager)
            } else {
                updateBluetoothStatus(ConnectionState.DISCONNECTED, "FAILED TO CONNECT: $displayName (TAP TO RETRY)")
                runOnUiThread {
                    Toast.makeText(this@MainActivity, "Connection failed. Check bike ignition & pairing.", Toast.LENGTH_LONG).show()
                }
            }
        }.apply { start() }
    }

    private fun pollLiveDataLoop(manager: OBDConnectionManager) {
        var lastRpm = 0.0f
        var lastSpeed = 0.0f
        var lastLoad = 20.0f
        var lastThrottle = 10.0f

        while (isPolling && manager.isConnected) {
            try {
                val rpm = manager.getRPM()
                val speed = manager.getSpeed()
                val load = manager.getEngineLoad()
                val throttle = manager.getThrottlePosition()

                if (rpm != null) lastRpm = rpm
                if (speed != null) lastSpeed = speed
                if (load != null) lastLoad = load
                if (throttle != null) lastThrottle = throttle

                val gear = manager.calculateGear(lastRpm, lastSpeed)

                // Log real-time telemetry frame for Ride Scoring & Blackbox
                TripDataStore.tripLog.add(
                    TelemetryFrame(
                        rpm = lastRpm,
                        gear = gear,
                        speed = lastSpeed,
                        throttle = lastThrottle,
                        leanAngle = 0.0f
                    )
                )

                runOnUiThread {
                    processTelemetryFrame(
                        load = lastLoad,
                        throttle = lastThrottle,
                        incline = 0.0f,
                        gear = gear.toFloat(),
                        rpm = lastRpm
                    )
                }

                Thread.sleep(80) // ~12 Hz polling
            } catch (e: Exception) {
                e.printStackTrace()
                break
            }
        }

        if (isPolling) {
            updateBluetoothStatus(ConnectionState.DISCONNECTED, "OBD DISCONNECTED (TAP TO RECONNECT)")
        }
    }

    private fun stopPolling() {
        isPolling = false
        pollingThread?.interrupt()
        pollingThread = null
        obdManager?.disconnect()
        obdManager = null
    }

    private fun loadModelFile(): ByteBuffer {
        return try {
            val fileDescriptor: AssetFileDescriptor = assets.openFd("cep_shift_model.tflite")
            val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
            val fileChannel = inputStream.channel
            val startOffset = fileDescriptor.startOffset
            val declaredLength = fileDescriptor.declaredLength
            fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
        } catch (e: Exception) {
            // Fallback for compressed assets or APK packaging where openFd fails
            val inputStream = assets.open("cep_shift_model.tflite")
            val bytes = inputStream.readBytes()
            val buffer = ByteBuffer.allocateDirect(bytes.size)
            buffer.order(ByteOrder.nativeOrder())
            buffer.put(bytes)
            buffer.rewind()
            buffer
        }
    }

    private fun processTelemetryFrame(load: Float, throttle: Float, incline: Float, gear: Float, rpm: Float) {
        var predictedOptimalRpm = 5500.0f

        if (::tfliteInterpreter.isInitialized) {
            try {
                val inputArray = arrayOf(floatArrayOf(load, throttle, incline, gear))
                val outputArray = Array(1) { FloatArray(1) }
                tfliteInterpreter.run(inputArray, outputArray)
                predictedOptimalRpm = outputArray[0][0]
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Apply 250 RPM hysteresis buffer logic
        val hudSignal = evaluateHysteresisBuffer(rpm, predictedOptimalRpm, gear.toInt(), load)

        // Update UI Dashboard Cues
        txtRPM.text = "${rpm.toInt()}"
        txtGear.text = if (gear.toInt() == 0) "N" else "${gear.toInt()}"
        txtLoad.text = "${load.toInt()}%"
        txtTargetRPM.text = "${predictedOptimalRpm.toInt()} RPM"

        when (hudSignal) {
            1 -> {
                txtShiftCue.text = "🔼 SHIFT UP"
                txtShiftCue.setTextColor(Color.parseColor("#00FF66")) // Neon Green
            }
            -1 -> {
                txtShiftCue.text = "🔽 SHIFT DOWN"
                txtShiftCue.setTextColor(Color.parseColor("#FF3333")) // Alert Red
            }
            else -> {
                txtShiftCue.text = "🟢 HOLD GEAR"
                txtShiftCue.setTextColor(Color.parseColor("#3399FF")) // Cyan/Blue
            }
        }
    }

    private fun evaluateHysteresisBuffer(currentRpm: Float, optimalRpm: Float, gear: Int, load: Float): Int {
        val bufferRpm = 250.0f

        // 1. Upshift: Current RPM exceeds the AI's dynamic target
        return if (currentRpm > (optimalRpm + bufferRpm) && gear in 1..5) {
            1
            // 2. Downshift: Engine is lugging (Low RPM under heavy mechanical load)
        } else if (currentRpm < 2500.0f && load > 50.0f && gear > 1) {
            -1
            // 3. Hold Gear: Cruising or accelerating toward optimal shift point
        } else {
            0
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopPolling()
        if (::tfliteInterpreter.isInitialized) {
            tfliteInterpreter.close()
        }
    }
}