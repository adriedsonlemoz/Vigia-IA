import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_navigation_target.dart';
import 'package:vigiaia/models/map_travel_mode.dart';
import 'package:vigiaia/widgets/map_route_preview_card.dart';

void main() {
  MapCyclingRoute route(double meters, double seconds) => MapCyclingRoute(
        points: const [],
        distanceMeters: meters,
        durationSeconds: seconds,
      );

  Future<void> render(
    WidgetTester tester, {
    MapTravelMode mode = MapTravelMode.bicycle,
    List<MapCyclingRoute>? routes,
    int selectedIndex = 0,
    bool loading = false,
    bool collapsed = false,
    BikeTripPlan? plan,
    void Function(String)? onAction,
    ValueChanged<int>? onChoose,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MapRoutePreviewCard(
              target: MapNavigationTarget(
                latitude: -20.2,
                longitude: -45.1,
                label: 'Destino teste',
                startedAt: DateTime(2026, 10, 15),
                travelMode: mode,
              ),
              routes: routes ?? [route(30000, 3600)],
              selectedIndex: selectedIndex,
              loading: loading,
              plan: plan,
              bikePreferences: const BikeTravelPreferences(
                averageSpeedKmh: 10,
              ),
              onEditPace: () => onAction?.call('ritmo'),
              collapsed: collapsed,
              onToggleCollapsed: () => onAction?.call('recolher'),
              onShowRoute: () => onAction?.call('trajeto'),
              onClose: () => onAction?.call('fechar'),
              onChoose: onChoose ?? (_) {},
              onPlan: plan == null ? null : () => onAction?.call('plano'),
              onStart: () => onAction?.call('iniciar'),
              onSave: () => onAction?.call('salvar'),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('prévia de bicicleta usa ritmo informado e mostra ações',
      (tester) async {
    await render(tester);
    expect(find.byType(MapRoutePreviewCard), findsOneWidget);
    expect(find.text('Prévia · Destino teste'), findsOneWidget);
    expect(find.textContaining('30.0 km · 3h00'), findsOneWidget);
    expect(find.textContaining('10.0 km/h'), findsOneWidget);
    expect(find.text('Editar ritmo do pedal'), findsOneWidget);
    expect(find.text('Ver trajeto'), findsOneWidget);
    expect(find.text('Salvar offline'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('Carregando plano'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recolhida conserva resumo e botões de expandir e fechar',
      (tester) async {
    final actions = <String>[];
    await render(tester, collapsed: true, onAction: actions.add);
    expect(find.textContaining('Toque na seta para ver opções'), findsOneWidget);
    expect(find.text('Iniciar'), findsNothing);
    await tester.tap(find.byTooltip('Expandir prévia'));
    await tester.tap(find.byTooltip('Fechar prévia'));
    expect(actions, ['recolher', 'fechar']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alternativas exibem comparação e encaminham índice selecionado',
      (tester) async {
    final choices = <int>[];
    await render(tester,
        routes: [route(30000, 3600), route(35000, 3300)],
        selectedIndex: 1,
        onChoose: choices.add);
    expect(find.textContaining('Rota 1 · 30.0 km · 3h00'), findsOneWidget);
    expect(find.textContaining('Rota 2 · 35.0 km · 3h30'), findsOneWidget);
    expect(find.textContaining('+5.0 km em relação à rota 1'), findsOneWidget);
    await tester.tap(find.textContaining('Rota 1 · 30.0 km · 3h00'));
    expect(choices, [0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botões repassam callbacks sem iniciar navegação por si',
      (tester) async {
    final actions = <String>[];
    await render(tester, onAction: actions.add);
    expect(actions, isEmpty);
    await tester.tap(find.text('Editar ritmo do pedal'));
    await tester.tap(find.text('Ver trajeto'));
    await tester.tap(find.text('Salvar offline'));
    await tester.tap(find.text('Iniciar'));
    expect(actions, ['ritmo', 'trajeto', 'salvar', 'iniciar']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carro usa tempo do provedor e omite controles exclusivos da bike',
      (tester) async {
    await render(tester, mode: MapTravelMode.car);
    expect(find.textContaining('30.0 km · 1h00'), findsOneWidget);
    expect(find.text('Editar ritmo do pedal'), findsNothing);
    expect(find.text('Carregando plano'), findsNothing);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculando rotas não exibe estimativas inexistentes',
      (tester) async {
    await render(tester, routes: [], loading: true);
    expect(find.textContaining('Calculando alternativas'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Iniciar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
