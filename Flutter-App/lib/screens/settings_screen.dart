import 'package:flutter/material.dart';
import '../services/telemetry_simulator_service.dart';

class SettingsScreen extends StatefulWidget {
  final TelemetrySimulatorService telemetryService;

  const SettingsScreen({super.key, required this.telemetryService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _simulationMode = true;
  double _hysteresisBuffer = 250.0;
  double _coldTireThreshold = 25.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14171F),
        elevation: 0,
        title: const Text(
          'SETTINGS & HARDWARE CONFIG',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'HARDWARE ARCHITECTURE BRIDGE',
            style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
              'Motorcycle Platform',
              'Triumph Scrambler 400x (Euro 5 6-Pin)',
              Icons.two_wheeler_rounded),
          _buildInfoTile(
              'Diagnostic Scanner',
              'ELM327 v1.5 Bluetooth (SPP UUID 00001101)',
              Icons.bluetooth_connected_rounded),
          _buildInfoTile(
              'Tire Telemetry',
              'BLE 5.0 External Valve Caps (Front & Rear)',
              Icons.tire_repair_rounded),
          _buildInfoTile(
              'Compute Core',
              'Android Smartphone (6-Axis IMU + GNSS GPS)',
              Icons.phone_android_rounded),
          const SizedBox(height: 24),
          const Text(
            'DATA INGESTION MODE',
            style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF14171F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF222938)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replay 10,000-Row Prototype Telemetry',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Replays synchronized OBD-II + TPMS + IMU test logs',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                Switch(
                  value: _simulationMode,
                  activeThumbColor: const Color(0xFF00FF66),
                  onChanged: (val) {
                    setState(() {
                      _simulationMode = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'EDGE AI & HYSTERESIS TUNING',
            style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF14171F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF222938)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hysteresis Shift Buffer',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Text('±${_hysteresisBuffer.toInt()} RPM',
                        style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _hysteresisBuffer,
                  min: 100,
                  max: 500,
                  divisions: 8,
                  activeColor: const Color(0xFF00E5FF),
                  onChanged: (v) {
                    setState(() {
                      _hysteresisBuffer = v;
                    });
                  },
                ),
                const Text(
                  'Prevents erratic shift-cue oscillation near boundary limits.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Divider(color: Color(0xFF222938), height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cold Tire Alert Limit',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Text('${_coldTireThreshold.toInt()}°C',
                        style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _coldTireThreshold,
                  min: 15,
                  max: 35,
                  divisions: 4,
                  activeColor: const Color(0xFF00E5FF),
                  onChanged: (v) {
                    setState(() {
                      _coldTireThreshold = v;
                    });
                  },
                ),
                const Text(
                  'Warns if lean angle exceeds 25° before rubber reaches optimal operating temperature.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14171F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222938)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
