package com.example.sih

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

class OBDConnectionManager(val deviceMacAddress: String) {
    // Standard Serial Port Profile (SPP) UUID for ELM327 Bluetooth modules
    private val uuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var socket: BluetoothSocket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null

    val isConnected: Boolean
        get() = socket?.isConnected == true

    @SuppressLint("MissingPermission")
    fun connect(): Boolean {
        return try {
            val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter() ?: return false
            val device: BluetoothDevice = bluetoothAdapter.getRemoteDevice(deviceMacAddress)

            bluetoothAdapter.cancelDiscovery()

            var connected = false

            // Attempt 1: Standard RFCOMM Service Record (SPP)
            try {
                socket = device.createRfcommSocketToServiceRecord(uuid)
                socket?.connect()
                connected = true
            } catch (_: Exception) {
                try {
                    socket?.close()
                } catch (_: Exception) {}

                // Attempt 2: Insecure RFCOMM Service Record
                try {
                    socket = device.createInsecureRfcommSocketToServiceRecord(uuid)
                    socket?.connect()
                    connected = true
                } catch (_: Exception) {
                    try {
                        socket?.close()
                    } catch (_: Exception) {}

                    // Attempt 3: Reflection on channel 1 (Essential for many ELM327 clones)
                    try {
                        val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                        socket = method.invoke(device, 1) as BluetoothSocket
                        socket?.connect()
                        connected = true
                    } catch (e3: Exception) {
                        e3.printStackTrace()
                    }
                }
            }

            if (!connected || socket?.isConnected != true) {
                disconnect()
                return false
            }

            inputStream = socket?.inputStream
            outputStream = socket?.outputStream

            // Small stabilization pause for ELM microcontroller
            Thread.sleep(400)

            // Initialize ELM327 protocol and CAN bus communication
            sendCommand("AT Z\r", 1500)   // Reset ELM327 chip
            Thread.sleep(200)
            sendCommand("ATE0\r", 500)    // Echo off
            sendCommand("ATL0\r", 500)    // Linefeeds off
            sendCommand("ATS0\r", 500)    // Spaces off
            sendCommand("ATH0\r", 500)    // Headers off
            sendCommand("ATSP0\r", 1500)  // Auto-detect protocol (CAN / ISO)

            // Handshake with vehicle ECU (PID 0100: Supported PIDs).
            // Crucial: The first PID triggers ELM327 CAN protocol search which takes 2-4 seconds.
            // Performing this here allows subsequent real-time PID queries to return in ~30-50ms.
            sendCommand("0100\r", 4000)

            true
        } catch (e: Exception) {
            e.printStackTrace()
            disconnect()
            false
        }
    }

    @Synchronized
    private fun sendCommand(cmd: String, timeoutMs: Long = 1000): String {
        val out = outputStream ?: return ""
        val input = inputStream ?: return ""

        return try {
            // Drain residual bytes in buffer before transmitting new command
            while (input.available() > 0) {
                input.read()
            }

            out.write(cmd.toByteArray())
            out.flush()

            val response = StringBuilder()
            val startTime = System.currentTimeMillis()

            while (System.currentTimeMillis() - startTime < timeoutMs) {
                if (input.available() > 0) {
                    val b = input.read()
                    if (b == -1) break
                    val c = b.toChar()
                    if (c == '>') break // ELM327 command completion prompt
                    response.append(c)
                } else {
                    Thread.sleep(10)
                }
            }
            response.toString().trim()
        } catch (e: Exception) {
            e.printStackTrace()
            ""
        }
    }

    // OBD-II PID 010C is Engine RPM: ((A * 256) + B) / 4
    fun getRPM(): Float? {
        val rawResponse = sendCommand("010C\r", 1000)
        return parseRpmHex(rawResponse)
    }

    // OBD-II PID 010D is Vehicle Speed (km/h): A
    fun getSpeed(): Float? {
        val rawResponse = sendCommand("010D\r", 500)
        return parseSingleByteHex(rawResponse, "410D")
    }

    // OBD-II PID 0104 is Calculated Engine Load (%): (A * 100) / 255
    fun getEngineLoad(): Float? {
        val rawResponse = sendCommand("0104\r", 500)
        val rawByte = parseSingleByteHex(rawResponse, "4104") ?: return null
        return (rawByte * 100.0f) / 255.0f
    }

    // OBD-II PID 0111 is Throttle Position (%): (A * 100) / 255
    fun getThrottlePosition(): Float? {
        val rawResponse = sendCommand("0111\r", 500)
        val rawByte = parseSingleByteHex(rawResponse, "4111") ?: return null
        return (rawByte * 100.0f) / 255.0f
    }

    /**
     * Estimates current transmission gear based on RPM vs Vehicle Speed ratio
     * Calibrated for Triumph Scrambler 400x (6-speed gearbox).
     */
    fun calculateGear(rpm: Float, speedKmh: Float): Int {
        if (speedKmh < 3.0f) {
            return if (rpm > 2200.0f) 0 else 1 // 0 = Neutral (revving at standstill)
        }

        val ratio = rpm / speedKmh
        return when {
            ratio > 145.0f -> 1
            ratio > 105.0f -> 2
            ratio > 82.0f -> 3
            ratio > 68.0f -> 4
            ratio > 56.0f -> 5
            else -> 6
        }
    }

    private fun parseRpmHex(raw: String): Float? {
        try {
            val clean = raw.replace(" ", "").replace("\r", "").replace("\n", "").uppercase()
            val index = clean.indexOf("410C")
            if (index != -1 && clean.length >= index + 8) {
                val a = clean.substring(index + 4, index + 6).toInt(16)
                val b = clean.substring(index + 6, index + 8).toInt(16)
                return ((a * 256.0f) + b) / 4.0f
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun parseSingleByteHex(raw: String, pidHeader: String): Float? {
        try {
            val clean = raw.replace(" ", "").replace("\r", "").replace("\n", "").uppercase()
            val index = clean.indexOf(pidHeader)
            if (index != -1 && clean.length >= index + 6) {
                val a = clean.substring(index + 4, index + 6).toInt(16)
                return a.toFloat()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    fun disconnect() {
        try {
            socket?.close()
        } catch (_: Exception) {}
        socket = null
        inputStream = null
        outputStream = null
    }
}