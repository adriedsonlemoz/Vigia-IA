import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/widgets/map_route_alternatives_button.dart';

void main() {
  MapCyclingRoute route(double distanceMeters, double durationSeconds) =>
      MapCyclingRoute(
        points: const [],
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );

  Future<void> render(
    WidgetTester tester, {
    List<MapCyclingRoute>? routes,
    int selectedIndex = 0,
    bool compact = true,
    ValueChanged<int>? onSelected,
    String Function(MapCyclingRoute)? deltaLabel,
  }) async {
    await tester.binding.setSurfaceSize(const Size(850, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 150,
            height: 100,
            child: MapRouteAlternativesButton(
              routes: routes ?? [route(10000, 2400), route(12500, 2600)],
              selectedIndex: selectedIndex,
              accent: Colors.teal,
              foreground: Colors.black,
              compact: compact,
              distanceLabel: (meters) => '${(meters / 1000).toStringAsFixed(1)} km',
              durationLabel: (r) => '${(r.durationSeconds / 60).round()} min',
              deltaLabel: deltaLabel ?? (r) => '+${(r.distanceMeters - 10000).toStringAsFixed(0)} m',
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('duas rotas permitem abrir menu e comparar distâncias e tempos',
      (tester) async {
    await render(tester);
    expect(find.text('2 opções'), findsOneWidget);
    await tester.tap(find.byTooltip('Comparar rotas alternativas'));
    await tester.pumpAndSettle();
    expect(find.text('Rota 1 · 10.0 km · 40 min'), findsOneWidget);
    expect(find.text('Rota 2 · 12.5 km · 43 min'), findsOneWidget);
    expect(find.text('+2500 m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seleção de alternativa encaminha somente o índice escolhido',
      (tester) async {
    final choices = <int>[];
    await render(tester, selectedIndex: 0, onSelected: choices.add);
    expect(choices, isEmpty);
    await tester.tap(find.byTooltip('Comparar rotas alternativas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rota 2 · 12.5 km · 43 min'));
    await tester.pumpAndSettle();
    expect(choices, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uma rota desabilita o menu sem bloquear visualização',
      (tester) async {
    final choices = <int>[];
    await render(tester, routes: [route(10000, 2400)], onSelected: choices.add);
    expect(find.text('1 opção'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<int>>(find.byType(PopupMenuButton<int>));
    expect(menu.enabled, isFalse);
    expect(find.byTooltip('Sem rotas alternativas'), findsOneWidget);
    await tester.tap(find.byTooltip('Sem rotas alternativas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rota 1 ·'), findsNothing);
    expect(choices, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparação ausente é explicitamente apresentada',
      (tester) async {
    await render(tester, deltaLabel: (_) => '');
    await tester.tap(find.byTooltip('Comparar rotas alternativas'));
    await tester.pumpAndSettle();
    expect(find.text('Sem comparação disponível'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout não compacto conserva rótulos e acesso às alternativas',
      (tester) async {
    await render(tester, compact: false);
    expect(find.text('2 opções'), findsOneWidget);
    expect(find.text('rotas'), findsOneWidget);
    await tester.tap(find.byTooltip('Comparar rotas alternativas'));
    await tester.pumpAndSettle();
    expect(find.text('Rota 1 · 10.0 km · 40 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
