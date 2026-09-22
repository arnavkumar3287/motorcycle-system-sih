import 'package:flutter/material.dart';
import '../services/telemetry_simulator_service.dart';
import '../models/telemetry_frame.dart';

class PostRideAnalyticsScreen extends StatelessWidget {
  final TelemetrySimulatorService telemetryService;

  const PostRideAnalyticsScreen({super.key, required this.telemetryService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TelemetryFrame>(
      stream: telemetryService.frameStream,
      builder: (context, snapshot) {
        final summary = telemetryService.getRideSummary();

        Color scoreColor;
        if (summary.overallRideScore >= 80) {
          scoreColor = const Color(0xFF00FF66);
        } else if (summary.overallRideScore >= 60) {
          scoreColor = const Color(0xFFFFB300);
        } else {
          scoreColor = const Color(0xFFFF3333);
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14171F),
            elevation: 0,
            title: const Text(
              'POST-RIDE ANALYTICS & SCORE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Central Score Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171F),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF222938)),
                    boxShadow: [
                      BoxShadow(
                        color: scoreColor.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'GAMIFIED RIDE SCORE',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: summary.overallRideScore / 100.0,
                              strokeWidth: 14,
                              backgroundColor: const Color(0xFF1E2330),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${summary.overallRideScore}',
                                style: TextStyle(
                                  color: scoreColor,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const Text(
                                '/ 100',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        summary.totalFrames == 0
                            ? 'Ready for Ride • Awaiting Telemetry Packets'
                            : (summary.overallRideScore >= 80
                                ? '🌟 Excellent Powertrain & Safety Discipline'
                                : (summary.overallRideScore >= 60
                                    ? '⚡ Moderate Performance • Fuel Penalties Flagged'
                                    : '⚠️ Aggressive Driving • High Mechanical Strain')),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Score Breakdown Sub-Scores
                Row(
                  children: [
                    Expanded(
                        child: _buildSubScoreCard(
                            'Shift Efficiency',
                            summary.shiftEfficiencyScore,
                            const Color(0xFF00FF66))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildSubScoreCard('Safety Adherence',
                            summary.safetyScore, const Color(0xFF00E5FF))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildSubScoreCard('Throttle Smoothness',
                            summary.smoothnessScore, const Color(0xFFAB47BC))),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Fuel & Transmission Degrading Habits Analysis
                const Text(
                  'FUEL & TRANSMISSION DEGRADING HABITS',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),

                _buildHabitRow(
                  title: 'Engine Lugging (<2,500 RPM @ >50% Load)',
                  count: summary.luggingEventsCount,
                  duration: '${summary.luggingDurationSec}s',
                  severityColor: summary.luggingEventsCount > 0
                      ? const Color(0xFFFF3333)
                      : const Color(0xFF00FF66),
                  description:
                      'Destructive low-speed cylinder knock; downshift earlier.',
                ),
                const SizedBox(height: 10),
                _buildHabitRow(
                  title: 'Excessive Revving (>7,500 RPM)',
                  count: summary.overRevEventsCount,
                  duration: '${summary.overRevDurationSec}s',
                  severityColor: summary.overRevEventsCount > 0
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF00FF66),
                  description:
                      'Exceeds optimal torque band, degrades fuel economy.',
                ),
                const SizedBox(height: 10),
                _buildHabitRow(
                  title: 'Aggressive Corner Exit Roll-On',
                  count: summary.aggressiveCornerExitCount,
                  duration: '${summary.aggressiveCornerExitCount} events',
                  severityColor: summary.aggressiveCornerExitCount > 2
                      ? const Color(0xFFFF9900)
                      : const Color(0xFF00FF66),
                  description: 'Sudden throttle roll-on at lean angles > 15°.',
                ),
                const SizedBox(height: 10),
                _buildHabitRow(
                  title: 'Cold Tire Extreme Lean Risk',
                  count: summary.coldTireHazardCount,
                  duration: '${summary.coldTireHazardCount} warnings',
                  severityColor: summary.coldTireHazardCount > 0
                      ? const Color(0xFFFF3333)
                      : const Color(0xFF00FF66),
                  description:
                      'Deep lean angles (>25°) before tire reached 25°C operating temp.',
                ),

                const SizedBox(height: 24),

                // 4. Trip Telemetry Summary
                const Text(
                  'TELEMETRY TRIP STATISTICS',
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
                    children: [
                      _buildStatLine('Trip Duration',
                          '${summary.duration.inMinutes} min ${summary.duration.inSeconds % 60} sec'),
                      _buildStatLine(
                          'Distance Covered', '${summary.distanceKm} km'),
                      _buildStatLine(
                          'Average Speed', '${summary.avgSpeedKmh} km/h'),
                      _buildStatLine(
                          'Top Speed Recorded', '${summary.maxSpeedKmh} km/h'),
                      _buildStatLine(
                          'Average Engine RPM', '${summary.avgRpm} RPM'),
                      _buildStatLine('Peak RPM Hit', '${summary.maxRpm} RPM'),
                      _buildStatLine(
                          'Max Lean Angle', '${summary.maxLeanAngleDeg}°'),
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

  Widget _buildSubScoreCard(String title, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14171F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222938)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow({
    required String title,
    required int count,
    required String duration,
    required Color severityColor,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14171F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222938)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: severityColor),
                ),
                child: Text(
                  count > 0 ? duration : 'None',
                  style: TextStyle(
                      color: severityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
