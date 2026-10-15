import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_speed_policy.dart';
import 'package:vigiaia/widgets/map_status_indicators.dart';

void main() {
  testWidgets('HUD do sistema mostra valores ausentes e GPS indisponivel', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 390,
        child: MapSystemHud(
          batteryPercent: null, gpsReady: false, speedSource: null,
        ),
      ))),
    ));
    expect(find.text('--%'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
    expect(find.byIcon(Icons.gps_off_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD do sistema mostra bateria, procedencia e GPS ativo', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 390,
        child: MapSystemHud(
          batteryPercent: 81, gpsReady: true, speedSource: 'GPS',
        ),
      ))),
    ));
    expect(find.text('81%'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
    expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);
  });

  testWidgets('velocimetro foca detalhe por callback e preserva fonte/rumo', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: MapFocusSpeedPill(
        reading: const MapSpeedReading(24.55, 'GPS'),
        heading: 91.8,
        onTap: () => taps++,
      ))),
    ));
    expect(find.text('24.6 km/h'), findsOneWidget);
    expect(find.text('GPS · 92°'), findsOneWidget);
    await tester.tap(find.byType(MapFocusSpeedPill));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('velocimetro sem leitura nao inventa numero ou rumo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: MapFocusSpeedPill(
        reading: null, heading: null, onTap: () {},
      ))),
    ));
    expect(find.text('-- km/h'), findsOneWidget);
    expect(find.text('Sem leitura · rumo --'), findsOneWidget);
  });
}
