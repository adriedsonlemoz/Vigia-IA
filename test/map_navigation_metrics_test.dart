import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/map_navigation_metrics.dart';

void main() {
  const accent = Colors.teal;
  const foreground = Colors.white;

  Future<void> pumpMetric(WidgetTester tester, {bool compact = true,
      String value = '19 km/h', String label = 'velocidade',
      double width = 170}) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: width, height: 85,
        child: MapNavigationMetricCell(
          icon: Icons.speed_rounded, value: value, label: label,
          accent: accent, foreground: foreground, compact: compact,
        ),
      ),
    ))));
  }

  Future<void> pumpChip(WidgetTester tester, {bool compact = true,
      String distance = '350 m', double width = 140}) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: width, height: 76,
        child: MapNavigationPoiChip(
          icon: Icons.water_drop_rounded, label: 'Água', distance: distance,
          foreground: foreground, accent: accent, compact: compact,
        ),
      ),
    ))));
  }

  testWidgets('célula mantém valor, rótulo e ícone', (tester) async {
    await pumpMetric(tester);
    expect(find.text('19 km/h'), findsOneWidget);
    expect(find.text('velocidade'), findsOneWidget);
    expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('métrica compacta conserva tipografia e cor', (tester) async {
    await pumpMetric(tester);
    final value = tester.widget<Text>(find.text('19 km/h'));
    expect(value.style?.fontSize, 12);
    expect(value.style?.fontWeight, FontWeight.w900);
    expect(value.style?.color, foreground);
    final icon = tester.widget<Icon>(find.byIcon(Icons.speed_rounded));
    expect(icon.size, 16);
    expect(icon.color, accent);
  });

  testWidgets('métrica normal mantém dimensões do modo expandido', (tester) async {
    await pumpMetric(tester, compact: false);
    expect(tester.widget<Text>(find.text('19 km/h')).style?.fontSize, 14);
    expect(tester.widget<Icon>(find.byIcon(Icons.speed_rounded)).size, 18);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valores longos usam reticências sem expandir linha', (tester) async {
    await pumpMetric(tester, width: 90,
      value: 'informação de navegação muito longa', label: 'referência');
    final value = tester.widget<Text>(
      find.text('informação de navegação muito longa'));
    expect(value.maxLines, 1);
    expect(value.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip mantém categoria e distância em linha reta', (tester) async {
    await pumpChip(tester);
    expect(find.text('Água'), findsOneWidget);
    expect(find.text('350 m'), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip mantém placeholder e fontes compactas', (tester) async {
    await pumpChip(tester, distance: '--');
    expect(find.text('--'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Água')).style?.fontSize, 9);
    expect(tester.widget<Icon>(find.byIcon(Icons.water_drop_rounded)).size, 17);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip expandido mantém tipografia e ícone', (tester) async {
    await pumpChip(tester, compact: false, width: 200);
    expect(tester.widget<Text>(find.text('Água')).style?.fontSize, 10.5);
    expect(tester.widget<Icon>(find.byIcon(Icons.water_drop_rounded)).size, 20);
    expect(tester.takeException(), isNull);
  });
}
