import 'package:flutter/material.dart';
import '../services/telemetry_simulator_service.dart';
import '../models/telemetry_frame.dart';
import '../models/ride_metrics.dart';

class UbiInsuranceScreen extends StatelessWidget {
  final TelemetrySimulatorService telemetryService;

  const UbiInsuranceScreen({super.key, required this.telemetryService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TelemetryFrame>(
      stream: telemetryService.frameStream,
      builder: (context, snapshot) {
        final summary = telemetryService.getRideSummary();

        Color tierColor;
        String tierName;
        String tierDesc;

        switch (summary.riskTier) {
          case UbiRiskTier.safe:
            tierColor = const Color(0xFF00FF66);
            tierName = 'SAFE COMMUTER (TIER 1)';
            tierDesc =
                'Demonstrates defensive cornering, optimal shift timing, and zero cold-tire risks.';
            break;
          case UbiRiskTier.moderate:
            tierColor = const Color(0xFFFFB300);
            tierName = 'MODERATE RISK (TIER 2)';
            tierDesc =
                'Occasional rev violations or corner roll-ons; steady overall control.';
            break;
          case UbiRiskTier.highRisk:
            tierColor = const Color(0xFFFF3333);
            tierName = 'HIGH RISK (TIER 3)';
            tierDesc =
                'Frequent lugging knock, high-risk overtakes, or dangerous cold-tire leans.';
            break;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14171F),
            elevation: 0,
            title: const Text(
              'PAY-HOW-YOU-RIDE • UBI PROFILING',
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
                // 1. Insurance Tier Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171F),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: tierColor.withValues(alpha: 0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: tierColor.withValues(alpha: 0.15),
                        blurRadius: 18,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tierColor),
                            ),
                            child: Text(
                              tierName,
                              style: TextStyle(
                                  color: tierColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.verified_user_rounded,
                              color: Colors.white70, size: 28),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        summary.projectedDiscountPct >= 0
                            ? '${summary.projectedDiscountPct}% PREMIUM DISCOUNT'
                            : '${summary.projectedDiscountPct.abs()}% RISK SURCHARGE',
                        style: TextStyle(
                          color: summary.projectedDiscountPct >= 0
                              ? const Color(0xFF00FF66)
                              : const Color(0xFFFF3333),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tierDesc,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Underwriting Risk Metric Radar
                const Text(
                  'TELEMETRY RISK UNDERWRITING FACTORS',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),

                _buildRiskFactorCard(
                  title: 'Cornering & Lean Grip Stability',
                  rating: summary.coldTireHazardCount == 0
                      ? 'Low Risk (Score: 95/100)'
                      : 'Warning Flagged',
                  description:
                      'Measures lean angle acceleration relative to TPMS tire surface temperature.',
                  statusColor: summary.coldTireHazardCount == 0
                      ? const Color(0xFF00FF66)
                      : const Color(0xFFFF3333),
                ),
                const SizedBox(height: 10),
                _buildRiskFactorCard(
                  title: 'High-G Longitudinal Braking',
                  rating: 'Safe Deceleration',
                  description:
                      'Checks for panic braking events (>0.65G) indicating tailgating or late anticipation.',
                  statusColor: const Color(0xFF00FF66),
                ),
                const SizedBox(height: 10),
                _buildRiskFactorCard(
                  title: 'High-Risk Overtaking Maneuvers',
                  rating: '${summary.highRiskOvertakesCount} events detected',
                  description:
                      'Tracks aggressive acceleration bursts (>0.4G) at speeds above 70 km/h.',
                  statusColor: summary.highRiskOvertakesCount <= 2
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFFFF9900),
                ),
                const SizedBox(height: 10),
                _buildRiskFactorCard(
                  title: 'Powertrain Strain & Lugging',
                  rating: '${summary.luggingEventsCount} knock risks',
                  description:
                      'Engine strain under low RPM high throttle degrades mechanical reliability.',
                  statusColor: summary.luggingEventsCount == 0
                      ? const Color(0xFF00FF66)
                      : const Color(0xFFFFB300),
                ),

                const SizedBox(height: 24),

                // 3. Projected Annual Savings
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF222938)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x2200FF66),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.savings_rounded,
                            color: Color(0xFF00FF66), size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROJECTED ANNUAL SAVINGS',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.projectedDiscountPct >= 0
                                  ? '₹${(summary.projectedDiscountPct * 280).round()} / year'
                                  : 'Standard Base Rate Applies',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildRiskFactorCard({
    required String title,
    required String rating,
    required String description,
    required Color statusColor,
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
              Text(
                rating,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
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
}
