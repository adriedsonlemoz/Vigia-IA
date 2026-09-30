import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_approach_status.dart';
import 'package:vigiaia/widgets/map_bike_approach_overlay.dart';

void main() {
  testWidgets('PiP mostra veiculo, risco e TTC durante aproximacao', (tester) async {
    final status = BikeApproachStatus(
      level: BikeApproachLevel.warning,
      updatedAt: DateTime(2026, 9, 25),
      estimatedTtcSeconds: 3.2,
      vehicleDetected: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: MapBikeApproachOverlay(status: status),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Veículo'), findsOneWidget);
    expect(find.textContaining('risco alto'), findsOneWidget);
    expect(find.textContaining('TTC ~3 s'), findsOneWidget);
  });

  testWidgets('PiP informa estado sem risco para veiculo sem aproximacao', (tester) async {
    final status = BikeApproachStatus(
      level: BikeApproachLevel.clear,
      updatedAt: DateTime(2026, 9, 25),
      vehicleDetected: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: MapBikeApproachOverlay(status: status),
          ),
        ),
      ),
    );

    expect(find.textContaining('sem aproximação'), findsOneWidget);
    expect(find.textContaining('sem risco'), findsOneWidget);
  });
}
