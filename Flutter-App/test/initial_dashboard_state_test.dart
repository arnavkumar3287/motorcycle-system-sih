import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_system_hub/models/telemetry_frame.dart';

void main() {
  test('initial dashboard values stay at zero until a bike sensor connects',
      () {
    final frame = TelemetryFrame.initial();

    expect(frame.engineRpm, 0.0);
    expect(frame.throttlePosPct, 0.0);
    expect(frame.engineLoadPct, 0.0);
    expect(frame.vehicleSpeedKmh, 0.0);
    expect(frame.currentGear, 0);
    expect(frame.leanAngleDeg, 0.0);
    expect(frame.longitudinalAccelG, 0.0);
    expect(frame.lateralAccelG, 0.0);
    expect(frame.roadInclineDeg, 0.0);
    expect(frame.frontTirePressPsi, 0.0);
    expect(frame.frontTireTempC, 0.0);
    expect(frame.rearTirePressPsi, 0.0);
    expect(frame.rearTireTempC, 0.0);
    expect(frame.optimalShiftRpm, 0.0);
    expect(frame.suggestedShiftAction, 0);
  });
}
