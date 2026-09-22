import 'dart:async';
import 'dart:math' as math;
import '../models/telemetry_frame.dart';
import '../models/ride_metrics.dart';
import '../ai/shift_intelligence.dart';
import '../ai/hazard_detector.dart';
import '../ai/rider_profiler.dart';
import 'sos_blackbox_service.dart';

class TelemetrySimulatorService {
  final List<TelemetryFrame> _allFrames = [];
  final List<TelemetryFrame> _rideHistory = [];
  List<TelemetryFrame> get rideHistory => List.unmodifiable(_rideHistory);

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get totalFrames => _allFrames.length;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isSensorConnected = false;
  bool get isSensorConnected => _isSensorConnected;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  Timer? _timer;
  final StreamController<TelemetryFrame> _frameController =
      StreamController<TelemetryFrame>.broadcast();
  Stream<TelemetryFrame> get frameStream => _frameController.stream;

  final SosBlackboxService blackboxService = SosBlackboxService();
  TelemetryFrame _currentFrame = TelemetryFrame.initial();
  TelemetryFrame get currentFrame => _currentFrame;

  Future<void> loadDataset(
      {String path = 'assets/cep_telemetry_prototype_dataset.csv'}) async {
    _generateRealisticRideFrames();
    if (!_isSensorConnected) {
      _currentFrame = TelemetryFrame.initial();
      _currentIndex = 0;
      _frameController.add(_currentFrame);
    }
  }

  void connectSensor() {
    _isSensorConnected = true;
    if (_allFrames.isNotEmpty && !_isPlaying) {
      _currentFrame = _allFrames[0];
      _currentIndex = 0;
      _frameController.add(_currentFrame);
    }
  }

  void disconnectSensor() {
    pause();
    _isSensorConnected = false;
    _currentFrame = TelemetryFrame.initial();
    _currentIndex = 0;
    _frameController.add(_currentFrame);
  }

  void _generateRealisticRideFrames() {
    _allFrames.clear();
    const totalFrames =
        1000; // 50 seconds at 50ms intervals (20 FPS smooth ride)

    for (int i = 0; i < totalFrames; i++) {
      final t = i * 0.05; // elapsed time in seconds
      double speed = 0.0;
      double rpm = 1350.0;
      int gear = 1;
      double throttle = 0.0;
      double load = 15.0;
      double lean = 0.0;
      double incline = 0.0;
      double longAccel = 0.0;
      double latAccel = 0.0;

      if (t < 3.0) {
        // 1. Idle at traffic stop (0-3s)
        gear = 1;
        speed = 0.0;
        rpm = 1350.0 + math.sin(t * 8) * 20.0;
        throttle = 0.0;
        load = 14.0 + math.sin(t * 4) * 2.0;
        lean = 0.0;
        incline = 0.0;
        longAccel = 0.0;
      } else if (t < 7.0) {
        // 2. 1st Gear Acceleration (3-7s)
        final p = (t - 3.0) / 4.0;
        gear = 1;
        throttle = 20.0 + p * 25.0;
        load = 35.0 + p * 20.0;
        speed = p * 26.0;
        rpm = 1400.0 + p * 3400.0; // 1400 -> 4800 (triggers SHIFT UP near 4400)
        longAccel = 0.25;
      } else if (t < 8.0) {
        // 3. Shift from 1st to 2nd (7-8s)
        final p = (t - 7.0) / 1.0;
        gear = (p < 0.4) ? 1 : 2;
        throttle = 10.0;
        load = 22.0;
        speed = 26.0 + p * 2.0;
        rpm = 4800.0 - p * 2000.0; // drops smoothly to 2800
        longAccel = 0.05;
      } else if (t < 13.0) {
        // 4. 2nd Gear Roll-on (8-13s)
        final p = (t - 8.0) / 5.0;
        gear = 2;
        throttle = 35.0 + p * 25.0;
        load = 40.0 + p * 22.0;
        speed = 28.0 + p * 26.0; // 28 -> 54 km/h
        rpm = 2800.0 + p * 2900.0; // 2800 -> 5700 (triggers SHIFT UP near 5400)
        longAccel = 0.30;
      } else if (t < 14.0) {
        // 5. Shift to 3rd (13-14s)
        final p = (t - 13.0) / 1.0;
        gear = (p < 0.4) ? 2 : 3;
        throttle = 15.0;
        load = 25.0;
        speed = 54.0 + p * 2.0;
        rpm = 5700.0 - p * 2000.0; // drops to 3700
        longAccel = 0.05;
      } else if (t < 20.0) {
        // 6. 3rd Gear & Sweeping Left Corner (14-20s)
        final p = (t - 14.0) / 6.0;
        gear = 3;
        throttle = 40.0 + p * 20.0;
        load = 45.0 + p * 15.0;
        speed = 56.0 + p * 20.0; // 56 -> 76 km/h
        rpm = 3700.0 + p * 2550.0; // 3700 -> 6250
        final cornerCurve = math.sin(p * math.pi);
        lean = -cornerCurve * 21.5; // smooth left lean
        latAccel = cornerCurve * 0.35;
        longAccel = 0.20;
      } else if (t < 21.0) {
        // 7. Shift to 4th (20-21s)
        final p = (t - 20.0) / 1.0;
        gear = (p < 0.4) ? 3 : 4;
        throttle = 20.0;
        load = 28.0;
        speed = 76.0 + p * 3.0;
        rpm = 6250.0 - p * 1850.0; // drops to 4400
        lean = 0.0;
      } else if (t < 27.0) {
        // 8. 4th Gear Undulating Country Road (21-27s)
        final p = (t - 21.0) / 6.0;
        gear = 4;
        throttle = 45.0 + math.sin(p * 4 * math.pi) * 8.0;
        load = 48.0 + math.sin(p * 4 * math.pi) * 12.0;
        speed = 79.0 + p * 16.0; // 79 -> 95 km/h
        rpm = 4400.0 + p * 2300.0; // 4400 -> 6700
        incline = math.sin(p * 2 * math.pi) * 2.8; // rolling hills
        longAccel = 0.18;
      } else if (t < 28.0) {
        // 9. Shift to 5th (27-28s)
        final p = (t - 27.0) / 1.0;
        gear = (p < 0.4) ? 4 : 5;
        throttle = 25.0;
        load = 32.0;
        speed = 95.0 + p * 3.0;
        rpm = 6700.0 - p * 1800.0; // drops to 4900
      } else if (t < 34.0) {
        // 10. 5th Gear Sweeping Right Turn (28-34s)
        final p = (t - 28.0) / 6.0;
        gear = 5;
        throttle = 50.0 + p * 15.0;
        load = 52.0 + p * 12.0;
        speed = 98.0 + p * 16.0; // 98 -> 114 km/h
        rpm = 4900.0 + p * 2250.0; // 4900 -> 7150
        final cornerCurve = math.sin(p * math.pi);
        lean = cornerCurve * 17.5; // smooth right lean
        latAccel = cornerCurve * 0.28;
        longAccel = 0.15;
      } else if (t < 35.0) {
        // 11. Shift to 6th Highway Overdrive (34-35s)
        final p = (t - 34.0) / 1.0;
        gear = (p < 0.4) ? 5 : 6;
        throttle = 30.0;
        load = 35.0;
        speed = 114.0 + p * 2.0;
        rpm = 7150.0 - p * 1650.0; // drops to 5500
        lean = 0.0;
      } else if (t < 40.0) {
        // 12. 6th Gear Smooth High-Speed Cruise (35-40s)
        final p = (t - 35.0) / 5.0;
        gear = 6;
        throttle = 38.0 + math.sin(p * 3) * 4.0;
        load = 42.0 + math.sin(p * 3) * 5.0;
        speed = 116.0 + math.sin(p * 4) * 3.0; // steady ~117 km/h
        rpm = 5500.0 + math.sin(p * 4) * 120.0;
        incline = -0.5;
        longAccel = 0.02;
      } else if (t < 44.0) {
        // 13. Simulated Lugging Scenario (40-44s)
        // Decelerating to 36 km/h while remaining in high gear (5th) under load
        final p = (t - 40.0) / 4.0;
        gear = 5;
        speed = 116.0 - p * 80.0; // drops from 116 to 36 km/h
        rpm = 5500.0 - p * 3450.0; // drops down to 2050 RPM (< 2500 limit)
        throttle = 55.0; // rider gives throttle in high gear
        load = 62.0; // high load (> 50% threshold)
        longAccel = -0.22;
      } else if (t < 46.0) {
        // 14. Quick Downshift Recovery to 3rd (44-46s)
        final p = (t - 44.0) / 2.0;
        gear = 3;
        speed = 36.0 - p * 8.0; // 36 -> 28 km/h
        rpm = 2050.0 + (1.0 - p) * 1600.0; // rev match to 3650
        throttle = 20.0;
        load = 32.0;
        longAccel = -0.15;
      } else {
        // 15. Smooth Braking to Full Stop (46-50s)
        final p = (t - 46.0) / 4.0;
        gear = (p > 0.6) ? 1 : 2;
        speed = (28.0 * (1.0 - p)).clamp(0.0, 30.0);
        rpm = 1350.0 + (1.0 - p) * 1400.0;
        throttle = 0.0;
        load = 15.0;
        lean = 0.0;
        longAccel = -0.32;
      }

      final optimalShiftRpm = ShiftIntelligence.predictOptimalShiftRpm(
        engineLoadPct: load,
        throttlePosPct: throttle,
        roadInclineDeg: incline,
        currentGear: gear,
      );

      final shiftAction = ShiftIntelligence.evaluateHysteresisBuffer(
        currentRpm: rpm,
        optimalShiftRpm: optimalShiftRpm,
        currentGear: gear,
        engineLoadPct: load,
      );

      final isLugging = (rpm < 2500.0 && load > 50.0 && gear > 1);

      final hazardAssessment = HazardDetector.assess(
        leanAngleDeg: lean,
        frontTireTempC: 28.0 + (speed / 10.0),
        frontTirePressPsi: 29.5,
        rearTireTempC: 29.0 + (speed / 9.0),
        rearTirePressPsi: 32.0,
        longitudinalAccelG: longAccel,
        lateralAccelG: latAccel,
        engineRpm: rpm,
        engineLoadPct: load,
        currentGear: gear,
      );

      final riderStyle = RiderProfiler.classifyRiderHabit(
        throttlePosPct: throttle,
        engineRpm: rpm,
        vehicleSpeedKmh: speed,
        lateralAccelG: latAccel,
        longitudinalAccelG: longAccel,
      );

      _allFrames.add(TelemetryFrame(
        timestampMs: (t * 1000).round(),
        engineRpm: rpm,
        throttlePosPct: throttle,
        engineLoadPct: load,
        vehicleSpeedKmh: speed,
        currentGear: gear,
        leanAngleDeg: lean,
        longitudinalAccelG: longAccel,
        lateralAccelG: latAccel,
        roadInclineDeg: incline,
        frontTirePressPsi: 29.5 + (speed / 150.0),
        frontTireTempC: 25.0 + (speed / 12.0),
        rearTirePressPsi: 32.0 + (speed / 140.0),
        rearTireTempC: 26.0 + (speed / 10.0),
        optimalShiftRpm: optimalShiftRpm,
        suggestedShiftAction: shiftAction,
        riderStyle: riderStyle,
        hazardType: hazardAssessment.type,
        hazardMessage: hazardAssessment.message,
        isLugging: isLugging,
        isOverRevving: rpm > 8500.0,
      ));
    }
    if (_allFrames.isNotEmpty) {
      _currentFrame = _allFrames[0];
      _frameController.add(_currentFrame);
    }
  }

  void play() {
    if (_isPlaying || !_isSensorConnected || _allFrames.isEmpty) return;
    _isPlaying = true;

    // 50ms interval = 20 FPS silky smooth continuous ride animation
    final intervalMs = (50 / _playbackSpeed).round();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (_currentIndex >= _allFrames.length) {
        _currentIndex = 0; // Loop simulation
      }

      final rawFrame = _allFrames[_currentIndex];

      // Run real-time AI & Edge inference
      final optimalShiftRpm = ShiftIntelligence.predictOptimalShiftRpm(
        engineLoadPct: rawFrame.engineLoadPct,
        throttlePosPct: rawFrame.throttlePosPct,
        roadInclineDeg: rawFrame.roadInclineDeg,
        currentGear: rawFrame.currentGear,
      );

      final shiftAction = ShiftIntelligence.evaluateHysteresisBuffer(
        currentRpm: rawFrame.engineRpm,
        optimalShiftRpm: optimalShiftRpm,
        currentGear: rawFrame.currentGear,
        engineLoadPct: rawFrame.engineLoadPct,
      );

      final hazardAssessment = HazardDetector.assess(
        leanAngleDeg: rawFrame.leanAngleDeg,
        frontTireTempC: rawFrame.frontTireTempC,
        frontTirePressPsi: rawFrame.frontTirePressPsi,
        rearTireTempC: rawFrame.rearTireTempC,
        rearTirePressPsi: rawFrame.rearTirePressPsi,
        longitudinalAccelG: rawFrame.longitudinalAccelG,
        lateralAccelG: rawFrame.lateralAccelG,
        engineRpm: rawFrame.engineRpm,
        engineLoadPct: rawFrame.engineLoadPct,
        currentGear: rawFrame.currentGear,
      );

      final riderStyle = RiderProfiler.classifyRiderHabit(
        throttlePosPct: rawFrame.throttlePosPct,
        engineRpm: rawFrame.engineRpm,
        vehicleSpeedKmh: rawFrame.vehicleSpeedKmh,
        lateralAccelG: rawFrame.lateralAccelG,
        longitudinalAccelG: rawFrame.longitudinalAccelG,
      );

      _currentFrame = rawFrame.copyWith(
        optimalShiftRpm: optimalShiftRpm,
        suggestedShiftAction: shiftAction,
        hazardType: hazardAssessment.type,
        hazardMessage: hazardAssessment.message,
        riderStyle: riderStyle,
      );

      _rideHistory.add(_currentFrame);
      blackboxService.ingestFrame(_currentFrame);

      _frameController.add(_currentFrame);
      _currentIndex++;
    });
  }

  void pause() {
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
  }

  void seekTo(int index) {
    if (index >= 0 && index < _allFrames.length) {
      _currentIndex = index;
      _currentFrame = _allFrames[_currentIndex];
      _frameController.add(_currentFrame);
    }
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlaying) {
      pause();
      play();
    }
  }

  void resetRide() {
    pause();
    _currentIndex = 0;
    _rideHistory.clear();
    if (_allFrames.isNotEmpty && _isSensorConnected) {
      _currentFrame = _allFrames[0];
      _frameController.add(_currentFrame);
    } else {
      _currentFrame = TelemetryFrame.initial();
      _frameController.add(_currentFrame);
    }
  }

  RideMetrics getRideSummary() {
    return RideMetrics.fromFrames(_rideHistory);
  }

  void dispose() {
    pause();
    _frameController.close();
    blackboxService.dispose();
  }
}
