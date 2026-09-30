import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/main_navigation_bar.dart';

void main() {
  testWidgets('usa NavigationRail em celular paisagem largo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(900, 400)),
          child: AdaptiveMainScaffold(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('mantem NavigationBar em celular retrato', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 900)),
          child: AdaptiveMainScaffold(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
