import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/map_navigation_record_control.dart';

void main() {
  Future<void> pumpControl(
    WidgetTester tester, {
    bool recording = false,
    bool paused = false,
    bool canRecord = true,
    bool hasRoute = true,
    VoidCallback? onToggleRecording,
    VoidCallback? onTogglePause,
    VoidCallback? onExport,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: MapNavigationRecordControl(
            recording: recording,
            paused: paused,
            canRecord: canRecord,
            hasRoute: hasRoute,
            onToggleRecording: onToggleRecording ?? () {},
            onTogglePause: onTogglePause ?? () {},
            onExport: onExport ?? () {},
          ),
        ),
      ),
    ));
  }

  testWidgets('GPS ausente desabilita Gravar', (tester) async {
    var started = 0;
    await pumpControl(tester, canRecord: false, onToggleRecording: () => started++);
    expect(find.byTooltip('GPS indisponível'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    await tester.tap(find.text('Gravar'));
    expect(started, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPS valido encaminha inicio sem criar estado', (tester) async {
    var started = 0;
    await pumpControl(tester, onToggleRecording: () => started++);
    expect(find.byTooltip('Gravar percurso'), findsOneWidget);
    await tester.tap(find.text('Gravar'));
    expect(started, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gravando apresenta pausar e encaminha callback', (tester) async {
    var pauses = 0;
    await pumpControl(tester, recording: true, onTogglePause: () => pauses++);
    expect(find.byTooltip('Pausar gravação'), findsOneWidget);
    await tester.tap(find.byTooltip('Pausar gravação'));
    expect(pauses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausado apresenta retomar e encaminha callback', (tester) async {
    var resumes = 0;
    await pumpControl(tester, recording: true, paused: true,
        onTogglePause: () => resumes++);
    expect(find.byTooltip('Retomar gravação'), findsOneWidget);
    await tester.tap(find.byTooltip('Retomar gravação'));
    expect(resumes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu permite encerrar sem exportar', (tester) async {
    var stops = 0;
    var exports = 0;
    await pumpControl(tester, recording: true,
        onToggleRecording: () => stops++, onExport: () => exports++);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar gravação'), findsOneWidget);
    expect(find.text('Exportar GPX'), findsOneWidget);
    await tester.tap(find.text('Encerrar gravação'));
    await tester.pumpAndSettle();
    expect(stops, 1);
    expect(exports, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu permite exportar GPX somente com rota', (tester) async {
    var exports = 0;
    await pumpControl(tester, recording: true, hasRoute: true,
        onExport: () => exports++);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar GPX'));
    await tester.pumpAndSettle();
    expect(exports, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rota insuficiente oculta exportacao GPX', (tester) async {
    var exports = 0;
    await pumpControl(tester, recording: true, hasRoute: false,
        onExport: () => exports++);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar gravação'), findsOneWidget);
    expect(find.text('Exportar GPX'), findsNothing);
    expect(exports, 0);
    expect(tester.takeException(), isNull);
  });
}
