import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_ux_policy.dart';
import 'package:vigiaia/widgets/map_zoom_controls.dart';

void main() {
  for (final horizontal in <bool>[true, false]) {
    testWidgets('zoom orientado ${horizontal ? 'horizontal' : 'vertical'} encaminha toques', (tester) async {
      var plus = 0;
      var minus = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapZoomCluster(
              horizontal: horizontal,
              onZoomIn: () => plus++,
              onZoomOut: () => minus++,
            ),
          ),
        ),
      ));
      final cluster = find.byType(MapZoomCluster);
      final flex = tester.widget<Flex>(find.descendant(
        of: cluster, matching: find.byType(Flex),
      ));
      expect(flex.direction, horizontal ? Axis.horizontal : Axis.vertical);
      expect(find.byTooltip('Aumentar zoom'), findsOneWidget);
      expect(find.byTooltip('Diminuir zoom'), findsOneWidget);
      await tester.tap(find.byTooltip('Aumentar zoom'));
      await tester.pump();
      await tester.tap(find.byTooltip('Diminuir zoom'));
      expect(plus, 1);
      expect(minus, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('espacador preserva ${horizontal ? 'largura' : 'altura'} da politica UX', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: MapControlGap(horizontal: horizontal)),
        ),
      ));
      final box = tester.widget<SizedBox>(find.descendant(
        of: find.byType(MapControlGap), matching: find.byType(SizedBox),
      ));
      expect(box.width, horizontal ? MapUxPolicy.controlGap : 0);
      expect(box.height, horizontal ? 0 : MapUxPolicy.controlGap);
    });
  }
}
