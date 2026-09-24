import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/main_navigation_bar.dart';

void main() {
  testWidgets('menu principal mantem cinco destinos essenciais', (tester) async {
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainNavigationBar(
            currentIndex: 0,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Câmeras'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Bike'), findsNothing);

    await tester.tap(find.text('Câmeras'));
    await tester.pump();

    expect(selectedIndex, 3);
  });
}
