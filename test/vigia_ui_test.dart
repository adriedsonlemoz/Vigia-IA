import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/core/vigia_design.dart';
import 'package:vigiaia/widgets/vigia_ui.dart';

void main() {
  testWidgets('modo principal preserva titulo, descricao e tags', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: VigiaTheme.build(
          brightness: Brightness.dark,
          seed: VigiaColors.cyan,
        ),
        home: Scaffold(
          body: VigiaModeCard(
            icon: Icons.videocam_rounded,
            title: 'Monitor ao vivo',
            subtitle: 'Acompanhe em tempo real.',
            accent: VigiaColors.cyan,
            tags: const ['IA local', 'Alertas'],
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Monitor ao vivo'), findsOneWidget);
    expect(find.text('IA local'), findsOneWidget);
    await tester.tap(find.text('Monitor ao vivo'));
    expect(tapped, isTrue);
  });

  testWidgets('acao rapida mantem rotulo visivel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 72,
            child: VigiaQuickAction(
              icon: Icons.monitor_heart_outlined,
              label: 'Diagnóstico',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Diagnóstico'), findsOneWidget);
  });
}
