import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_hud_presentation.dart';
import 'package:vigiaia/widgets/map_hud_context_pill.dart';

void main() {
  for (final width in <double>[320, 360, 412]) {
    for (final scale in <double>[1, 1.5]) {
      testWidgets('HUD compacto cabe em ${width}dp com texto ${scale}x',
          (tester) async {
        var taps = 0;
        final presentation = MapHudPresentationPolicy.resolve(
          hasNavigation: true,
          recording: true,
          speedKmh: 12,
          compactScreen: width < 380,
          cameraOverlayVisible: false,
          radioActive: false,
          bikeConnected: false,
          bikeAlert: false,
        );
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width - 12,
                  child: MapHudContextPill(
                    presentation: presentation,
                    onToggleTelemetry: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        ));
        expect(find.text('Navegar'), findsOneWidget);
        expect(find.text(' REC'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(MapHudContextPill));
        expect(taps, 1);
      });
    }
  }
}
