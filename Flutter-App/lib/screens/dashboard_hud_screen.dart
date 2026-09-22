import 'package:flutter/material.dart';
import '../services/telemetry_simulator_service.dart';
import '../models/telemetry_frame.dart';
import '../ai/rider_profiler.dart';
import '../widgets/shift_cue_banner.dart';
import '../widgets/tachometer_gauge.dart';
import '../widgets/lean_angle_widget.dart';
import '../widgets/tpms_tire_card.dart';
import '../widgets/metric_card.dart';

class DashboardHudScreen extends StatefulWidget {
  final TelemetrySimulatorService telemetryService;

  const DashboardHudScreen({super.key, required this.telemetryService});

  @override
  State<DashboardHudScreen> createState() => _DashboardHudScreenState();
}

class _DashboardHudScreenState extends State<DashboardHudScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.telemetryService.isSensorConnected) {
      widget.telemetryService.disconnectSensor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TelemetryFrame>(
      stream: widget.telemetryService.frameStream,
      initialData: widget.telemetryService.isSensorConnected
          ? widget.telemetryService.currentFrame
          : TelemetryFrame.initial(),
      builder: (context, snapshot) {
        final frame = snapshot.data ??
            (widget.telemetryService.isSensorConnected
                ? widget.telemetryService.currentFrame
                : TelemetryFrame.initial());

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14171F),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF66),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF66).withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'EDGE AI HUD • 400X',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2330),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(
                  child: Text(
                    RiderProfiler.getStyleName(frame.riderStyle),
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Shift Cue Banner (Prompt Action: -1 Downshift, 0 Hold, 1 Upshift)
                ShiftCueBanner(
                  shiftAction: frame.suggestedShiftAction,
                  isLugging: frame.isLugging,
                ),

                // Hazard Banner if active
                if (frame.hazardMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x33FF3333),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF3333)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFF3333)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            frame.hazardMessage,
                            style: const TextStyle(
                              color: Color(0xFFFF3333),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // 2. Central Primary Cockpit Display: Tachometer Gauge
                Center(
                  child: TachometerGauge(
                    currentRpm: frame.engineRpm,
                    optimalRpm: frame.optimalShiftRpm,
                    currentGear: frame.currentGear,
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Primary Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Speed',
                        value: frame.vehicleSpeedKmh.toStringAsFixed(1),
                        unit: 'KM/H',
                        icon: Icons.speed_rounded,
                        accentColor: const Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Engine Load',
                        value: frame.engineLoadPct.toStringAsFixed(0),
                        unit: '%',
                        icon: Icons.offline_bolt_rounded,
                        accentColor: frame.engineLoadPct > 75.0
                            ? const Color(0xFFFF3333)
                            : const Color(0xFFFFB300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Throttle (TPS)',
                        value: frame.throttlePosPct.toStringAsFixed(0),
                        unit: '%',
                        icon: Icons.navigation_rounded,
                        accentColor: const Color(0xFF00FF66),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Road Incline',
                        value:
                            '${frame.roadInclineDeg > 0 ? '+' : ''}${frame.roadInclineDeg.toStringAsFixed(1)}',
                        unit: 'DEG',
                        icon: Icons.landscape_rounded,
                        accentColor: const Color(0xFFAB47BC),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. Smartphone IMU Lean Angle & Tire Telemetry
                LeanAngleWidget(
                  leanAngleDeg: frame.leanAngleDeg,
                  isColdTireHazard: frame.hazardType == HazardType.coldTireLean,
                ),

                const SizedBox(height: 16),

                // 5. BLE TPMS External Tire Sensors
                Row(
                  children: [
                    Expanded(
                      child: TpmsTireCard(
                        title: 'Front Tire',
                        pressurePsi: frame.frontTirePressPsi,
                        temperatureC: frame.frontTireTempC,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TpmsTireCard(
                        title: 'Rear Tire',
                        pressurePsi: frame.rearTirePressPsi,
                        temperatureC: frame.rearTireTempC,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 6. Real-time Simulation Controller
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF222938)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TELEMETRY REPLAY STREAM',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Frame ${widget.telemetryService.currentIndex} / ${widget.telemetryService.totalFrames}',
                            style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11,
                                fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              widget.telemetryService.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: const Color(0xFF00E5FF),
                              size: 36,
                            ),
                            onPressed: () {
                              setState(() {
                                if (widget.telemetryService.isPlaying) {
                                  widget.telemetryService.pause();
                                } else {
                                  widget.telemetryService.play();
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.restart_alt_rounded,
                                color: Colors.grey, size: 28),
                            onPressed: () {
                              setState(() {
                                widget.telemetryService.resetRide();
                              });
                            },
                          ),
                          const Spacer(),
                          // Speed toggles
                          for (final speed in [1.0, 2.0, 5.0])
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text('${speed.toInt()}x'),
                                selected:
                                    widget.telemetryService.playbackSpeed ==
                                        speed,
                                selectedColor: const Color(0xFF00E5FF),
                                backgroundColor: const Color(0xFF1E2330),
                                labelStyle: TextStyle(
                                  color:
                                      widget.telemetryService.playbackSpeed ==
                                              speed
                                          ? Colors.black
                                          : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    widget.telemetryService
                                        .setPlaybackSpeed(speed);
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
