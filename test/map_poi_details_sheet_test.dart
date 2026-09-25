import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/widgets/map_poi_details_sheet.dart';

void main() {
  testWidgets('painel completo mostra detalhes do POI e ação de navegação',
      (tester) async {
    var navigateCount = 0;
    const item = RouteExplorerResult(
      id: 'poi-1',
      category: RouteExplorerCategory.camping,
      title: 'Camping da Serra',
      subtitle: 'Pernoite/camping · Serra',
      latitude: -19.12345,
      longitude: -44.12345,
      distanceMeters: 2400,
      address: 'Estrada da Serra, 10',
      openingHours: '24/7',
      phone: '+55 31 99999-0000',
      website: 'https://example.com',
      operatorName: 'Camping Serra',
      amenities: <String>['Água potável', 'Banheiro'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapPoiDetailsSheet(
            item: item,
            icon: Icons.home_rounded,
            distanceLabel: '2,4 km',
            onNavigate: () => navigateCount++,
            onShowOnMap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Camping da Serra'), findsOneWidget);
    expect(find.text('Informações do local'), findsOneWidget);
    expect(find.text('Estrada da Serra, 10'), findsOneWidget);
    expect(find.text('+55 31 99999-0000'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Água potável'), findsOneWidget);
    expect(find.text('Ir até lá'), findsOneWidget);

    await tester.tap(find.text('Ir até lá'));
    expect(navigateCount, 1);
  });
}
