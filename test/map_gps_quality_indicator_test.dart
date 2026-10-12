import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_telemetry_policy.dart';
import 'package:vigiaia/widgets/map_telemetry_panel.dart';

void main() {
  testWidgets('GPS antigo indica claramente que a precisao e historica',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MapGpsQualityIndicator(
          quality: MapGpsQuality.stale,
          accuracyMeters: 7,
        ),
      ),
    ));
    expect(find.text('Leitura antiga'), findsOneWidget);
    expect(find.textContaining('Última precisão histórica'), findsOneWidget);
    expect(find.textContaining('Não é a posição atual'), findsOneWidget);
  });

  testWidgets('GPS recente permite mostrar precisao como atual',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MapGpsQualityIndicator(
          quality: MapGpsQuality.good,
          accuracyMeters: 7,
        ),
      ),
    ));
    expect(find.text('Boa'), findsOneWidget);
    expect(find.textContaining('Raio informado pelo GPS'), findsOneWidget);
    expect(find.textContaining('Última precisão histórica'), findsNothing);
  });
}
