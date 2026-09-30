import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_compass_service.dart';

void main() {
  test('leitura nativa válida normaliza heading sem inventar valor', () {
    final reading = MapCompassReading.fromPlatform(<String, Object>{
      'headingDegrees': 361.5,
      'sensor': 'rotation_vector',
      'timestampMs': 1_700_000_000_000,
    });
    expect(reading, isNotNull);
    expect(reading!.headingDegrees, closeTo(1.5, 0.001));
    expect(reading.sensor, 'rotation_vector');
  });

  test('payload incompleto permanece indisponível', () {
    expect(MapCompassReading.fromPlatform(<String, Object>{}), isNull);
    expect(
      MapCompassReading.fromPlatform(<String, Object>{
        'headingDegrees': double.nan,
        'sensor': 'rotation_vector',
        'timestampMs': 1,
      }),
      isNull,
    );
  });
}
