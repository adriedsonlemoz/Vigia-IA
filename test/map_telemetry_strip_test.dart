import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_weather.dart';
import 'package:vigiaia/services/map_view_policy.dart';
import 'package:vigiaia/widgets/map_telemetry_strip.dart';

void main() {
  Future<void> render(
    WidgetTester tester, {
    double? speed = 19.75,
    String? speedSource = 'GPS',
    double? heading = 45,
    MapHeadingSource headingSource = MapHeadingSource.gps,
    bool gpsFresh = true,
    bool gpsHasFix = true,
    Duration? gpsAge,
    bool compact = false,
    MapWeatherSnapshot weather = const MapWeatherSnapshot(),
    List<VoidCallback>? callbacks,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 1000,
            height: 100,
            child: MapTelemetryStrip(
              speedKmh: speed,
              speedSource: speedSource,
              altitudeMeters: 552.5,
              headingDegrees: heading,
              headingSource: headingSource,
              gpsAccuracyMeters: 8.2,
              gpsReadingAge: gpsAge,
              gpsIsFresh: gpsFresh,
              gpsHasFix: gpsHasFix,
              orientationMode: MapOrientationMode.northUp,
              weather: weather,
              onSpeedTap: callbacks?[0] ?? () {},
              onAltitudeTap: callbacks?[1] ?? () {},
              onCompassTap: callbacks?[2] ?? () {},
              onGpsTap: callbacks?[3] ?? () {},
              onWeatherTap: callbacks?[4] ?? () {},
              compact: compact,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('apresenta velocidade, altitude, rumo, GPS e clima ausente',
      (tester) async {
    await render(tester);
    expect(find.byType(MapTelemetryStrip), findsOneWidget);
    expect(find.text('19.8'), findsOneWidget);
    expect(find.text('553'), findsOneWidget);
    expect(find.text('NE'), findsOneWidget);
    expect(find.text('±8'), findsOneWidget);
    expect(find.text('GPS'), findsNWidgets(2)); // Fonte de velocidade + cartão GPS.
    expect(find.text('Clima'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cinco cartões propagam toques sem criar ações próprias',
      (tester) async {
    final taps = List<int>.filled(5, 0);
    await render(tester, callbacks: List<VoidCallback>.generate(
      5, (index) => () => taps[index]++,
    ));
    const tooltips = <String>[
      'Velocidade: toque para ver detalhes da sessão.',
      'Altitude: toque para ver fonte e precisão.',
      'Bússola: toque para ver direção, fonte e escolher Norte, Direção ou Rota.',
      'GPS: toque para ver posição e qualidade da leitura.',
      'Clima: toque para ver sensores ESP32, dados online e fontes.',
    ];
    for (final tooltip in tooltips) {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
    }
    expect(taps, <int>[1, 1, 1, 1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPS antigo não é apresentado como leitura atual',
      (tester) async {
    await render(tester, gpsFresh: false,
      gpsAge: const Duration(minutes: 3));
    expect(find.text('GPS antigo'), findsOneWidget);
    expect(find.text('há 3 min'), findsOneWidget);
    expect(find.byTooltip('Amostra GPS inválida ou antiga. A precisão anterior não descreve a posição atual.'),
        findsOneWidget);
  });

  testWidgets('clima vencido usa aviso e não reaproveita valor antigo',
      (tester) async {
    final old = DateTime.now().subtract(const Duration(hours: 4));
    await render(tester, speed: null, heading: null,
      headingSource: MapHeadingSource.unavailable,
      weather: MapWeatherSnapshot(temperatureC: MapWeatherValue<double>(
        value: 35, source: MapWeatherSource.online, observedAt: old,
      )));
    expect(find.text('Clima antigo'), findsOneWidget);
    expect(find.text('35'), findsNothing);
    expect(find.text('Velocidade'), findsOneWidget);
    expect(find.text('Direção'), findsOneWidget);
    expect(find.text('km/h'), findsNothing);
  });

  testWidgets('layout compacto mantém cartões sem mostrar fonte secundária',
      (tester) async {
    await render(tester, speedSource: 'Simulação', compact: true);
    expect(find.text('Vel. simulada'), findsOneWidget);
    expect(find.text('Simulação'), findsNothing);
    expect(find.text('19.8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
