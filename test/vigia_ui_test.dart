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


  // Regressão visual do redesign 1.0.115: os cards de modo precisam caber
  // em uma célula estreita da grade 2x2 sem overflow.
  testWidgets('modo compacto cabe em celula estreita da Home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VigiaTheme.build(
          brightness: Brightness.dark,
          seed: VigiaColors.cyan,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 158,
              child: VigiaModeCard(
                compact: true,
                icon: Icons.memory_rounded,
                title: 'ESP32',
                subtitle: 'Conecte o módulo e configure sensores e câmera.',
                accent: VigiaColors.blue,
                tags: const ['Módulo', 'Sensores'],
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ESP32'), findsOneWidget);
    expect(find.text('Módulo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // O acesso rápido mais longo é usado como sentinela para telas estreitas.
  testWidgets('acao rapida Diagnostico cabe na grade responsiva', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 104,
            height: 96,
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
    expect(tester.takeException(), isNull);
  });
}
