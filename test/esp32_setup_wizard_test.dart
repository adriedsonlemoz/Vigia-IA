import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/screens/esp32_setup_wizard.dart';

void main() {
  testWidgets('wizard ESP32 inicia pela conexao e mostra progresso', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Esp32SetupWizard()),
    );

    expect(find.text('Etapa 1 de 5'), findsOneWidget);
    expect(find.text('Conexão'), findsOneWidget);
    expect(find.text('Encontre o seu ESP32'), findsOneWidget);
    expect(find.text('Procurar e testar ESP32'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('wizard avanca para identificacao sem exigir hardware online',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Esp32SetupWizard()),
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Etapa 2 de 5'), findsOneWidget);
    expect(find.text('Identificação'), findsOneWidget);
    expect(find.text('Identifique o módulo'), findsOneWidget);
    expect(find.text('Nome do módulo'), findsOneWidget);
  });
}
