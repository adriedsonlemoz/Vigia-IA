import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/monitor_ai_pip_status.dart';
import 'package:vigiaia/widgets/map_ai_status_overlay.dart';

void main() {
  testWidgets('overlay mostra o estado atual da IA de forma compacta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              child: MapAiStatusOverlay(
                status: MonitorAiPipStatus(
                  state: MonitorAiPipState.analyzing,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Analisando'), findsOneWidget);
    expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);
  });

  testWidgets('overlay deixa IA desligada explicita', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapAiStatusOverlay(
            status: MonitorAiPipStatus(
              state: MonitorAiPipState.disabled,
            ),
          ),
        ),
      ),
    );

    expect(find.text('IA desligada'), findsOneWidget);
  });
}
