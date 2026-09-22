enum RiderStyle { eco, touring, aggressive }

enum HazardType {
  none,
  coldTireLean,
  engineLugging,
  tireUnderinflated,
  highRiskOvertake,
  crashDetected,
}

class TelemetryFrame {
  final int timestampMs;
  final double engineRpm;
  final double throttlePosPct;
  final double engineLoadPct;
  final double vehicleSpeedKmh;
  final int currentGear;
  final double leanAngleDeg;
  final double longitudinalAccelG;
  final double lateralAccelG;
  final double roadInclineDeg;
  final double frontTirePressPsi;
  final double frontTireTempC;
  final double rearTirePressPsi;
  final double rearTireTempC;

  // Inference & Computed outputs
  final double optimalShiftRpm;
  final int suggestedShiftAction; // -1: Downshift, 0: Hold, 1: Upshift
  final RiderStyle riderStyle;
  final HazardType hazardType;
  final String hazardMessage;
  final bool isLugging;
  final bool isOverRevving;

  const TelemetryFrame({
    required this.timestampMs,
    required this.engineRpm,
    required this.throttlePosPct,
    required this.engineLoadPct,
    required this.vehicleSpeedKmh,
    required this.currentGear,
    required this.leanAngleDeg,
    required this.longitudinalAccelG,
    required this.lateralAccelG,
    required this.roadInclineDeg,
    required this.frontTirePressPsi,
    required this.frontTireTempC,
    this.rearTirePressPsi = 32.0,
    this.rearTireTempC = 24.0,
    this.optimalShiftRpm = 5800.0,
    this.suggestedShiftAction = 0,
    this.riderStyle = RiderStyle.touring,
    this.hazardType = HazardType.none,
    this.hazardMessage = '',
    this.isLugging = false,
    this.isOverRevving = false,
  });

  factory TelemetryFrame.initial() {
    return const TelemetryFrame(
      timestampMs: 0,
      engineRpm: 0.0,
      throttlePosPct: 0.0,
      engineLoadPct: 0.0,
      vehicleSpeedKmh: 0.0,
      currentGear: 0,
      leanAngleDeg: 0.0,
      longitudinalAccelG: 0.0,
      lateralAccelG: 0.0,
      roadInclineDeg: 0.0,
      frontTirePressPsi: 0.0,
      frontTireTempC: 0.0,
      rearTirePressPsi: 0.0,
      rearTireTempC: 0.0,
      optimalShiftRpm: 0.0,
      suggestedShiftAction: 0,
      riderStyle: RiderStyle.eco,
      hazardType: HazardType.none,
      hazardMessage: '',
      isLugging: false,
      isOverRevving: false,
    );
  }

  factory TelemetryFrame.fromCsvRow(List<dynamic> row) {
    // Expected order:
    // timestamp_ms,engine_rpm,throttle_pos_pct,engine_load_pct,vehicle_speed_kmh,current_gear,lean_angle_deg,longitudinal_accel_g,lateral_accel_g,road_incline_deg,tire_press_psi,tire_temp_c,suggested_shift_action,optimal_shift_rpm,rider_style_label,hazard_alert_flag
    try {
      final tMs = int.tryParse(row[0].toString()) ?? 0;
      final rpm = double.tryParse(row[1].toString()) ?? 0.0;
      final throttle = double.tryParse(row[2].toString()) ?? 0.0;
      final load = double.tryParse(row[3].toString()) ?? 0.0;
      final speed = double.tryParse(row[4].toString()) ?? 0.0;
      final gear = int.tryParse(row[5].toString().split('.')[0]) ?? 1;
      final lean = double.tryParse(row[6].toString()) ?? 0.0;
      final longG = double.tryParse(row[7].toString()) ?? 0.0;
      final latG = double.tryParse(row[8].toString()) ?? 0.0;
      final incline = double.tryParse(row[9].toString()) ?? 0.0;
      final psi = double.tryParse(row[10].toString()) ?? 29.0;
      final temp = double.tryParse(row[11].toString()) ?? 20.0;
      final shiftAction = int.tryParse(row[12].toString().split('.')[0]) ?? 0;
      final optRpm = double.tryParse(row[13].toString()) ?? 5500.0;
      final riderStyleInt = int.tryParse(row[14].toString().split('.')[0]) ?? 1;
      final hazardFlag = int.tryParse(row[15].toString().split('.')[0]) ?? 0;

      RiderStyle style = RiderStyle.touring;
      if (riderStyleInt == 0) style = RiderStyle.eco;
      if (riderStyleInt == 2) style = RiderStyle.aggressive;

      HazardType hType = HazardType.none;
      String msg = '';
      if (hazardFlag == 1 || (lean.abs() > 25.0 && temp < 25.0)) {
        hType = HazardType.coldTireLean;
        msg = '⚠️ Extreme Lean Angle on Cold Tires!';
      } else if (rpm < 2500 && load > 50 && gear > 1) {
        hType = HazardType.engineLugging;
        msg = '⚠️ Engine Lugging! Downshift Required';
      }

      return TelemetryFrame(
        timestampMs: tMs,
        engineRpm: rpm,
        throttlePosPct: throttle,
        engineLoadPct: load,
        vehicleSpeedKmh: speed,
        currentGear: gear,
        leanAngleDeg: lean,
        longitudinalAccelG: longG,
        lateralAccelG: latG,
        roadInclineDeg: incline,
        frontTirePressPsi: psi,
        frontTireTempC: temp,
        rearTirePressPsi: psi + 2.5,
        rearTireTempC: temp + 1.2,
        optimalShiftRpm: optRpm,
        suggestedShiftAction: shiftAction,
        riderStyle: style,
        hazardType: hType,
        hazardMessage: msg,
        isLugging: rpm < 2500 && load > 50 && gear > 1,
        isOverRevving: rpm > 7500,
      );
    } catch (e) {
      return TelemetryFrame.initial();
    }
  }

  TelemetryFrame copyWith({
    int? timestampMs,
    double? engineRpm,
    double? throttlePosPct,
    double? engineLoadPct,
    double? vehicleSpeedKmh,
    int? currentGear,
    double? leanAngleDeg,
    double? longitudinalAccelG,
    double? lateralAccelG,
    double? roadInclineDeg,
    double? frontTirePressPsi,
    double? frontTireTempC,
    double? rearTirePressPsi,
    double? rearTireTempC,
    double? optimalShiftRpm,
    int? suggestedShiftAction,
    RiderStyle? riderStyle,
    HazardType? hazardType,
    String? hazardMessage,
    bool? isLugging,
    bool? isOverRevving,
  }) {
    return TelemetryFrame(
      timestampMs: timestampMs ?? this.timestampMs,
      engineRpm: engineRpm ?? this.engineRpm,
      throttlePosPct: throttlePosPct ?? this.throttlePosPct,
      engineLoadPct: engineLoadPct ?? this.engineLoadPct,
      vehicleSpeedKmh: vehicleSpeedKmh ?? this.vehicleSpeedKmh,
      currentGear: currentGear ?? this.currentGear,
      leanAngleDeg: leanAngleDeg ?? this.leanAngleDeg,
      longitudinalAccelG: longitudinalAccelG ?? this.longitudinalAccelG,
      lateralAccelG: lateralAccelG ?? this.lateralAccelG,
      roadInclineDeg: roadInclineDeg ?? this.roadInclineDeg,
      frontTirePressPsi: frontTirePressPsi ?? this.frontTirePressPsi,
      frontTireTempC: frontTireTempC ?? this.frontTireTempC,
      rearTirePressPsi: rearTirePressPsi ?? this.rearTirePressPsi,
      rearTireTempC: rearTireTempC ?? this.rearTireTempC,
      optimalShiftRpm: optimalShiftRpm ?? this.optimalShiftRpm,
      suggestedShiftAction: suggestedShiftAction ?? this.suggestedShiftAction,
      riderStyle: riderStyle ?? this.riderStyle,
      hazardType: hazardType ?? this.hazardType,
      hazardMessage: hazardMessage ?? this.hazardMessage,
      isLugging: isLugging ?? this.isLugging,
      isOverRevving: isOverRevving ?? this.isOverRevving,
    );
  }
}
