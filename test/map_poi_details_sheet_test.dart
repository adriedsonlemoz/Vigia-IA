import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/widgets/map_poi_details_sheet.dart';

void main() {
  testWidgets('ficha sem metadados exibe origem e aviso de serviço não verificado',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const item = RouteExplorerResult(
      id: 'node-99-fuel',
      category: RouteExplorerCategory.fuel,
      title: 'Posto sem nome',
      subtitle: 'Combustível',
      latitude: -20,
      longitude: -45,
      distanceMeters: 800,
      source: 'cache',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapPoiDetailsSheet(
          item: item,
          icon: Icons.local_gas_station,
          distanceLabel: '800 m',
          centered: true,
          onNavigate: () {},
          onShowOnMap: () {},
        ),
      ),
    ));
    expect(find.text('Posto sem nome'), findsOneWidget);
    expect(find.text('800 m em linha reta'), findsOneWidget);
    expect(find.text('Cache local (OSM)'), findsOneWidget);
    expect(find.text('Data da consulta desconhecida'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ficha POI nao estoura em larguras pequenas e texto ampliado',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const item = RouteExplorerResult(
      id: 'node-99-fuel',
      category: RouteExplorerCategory.fuel,
      title: 'Posto sem nome',
      subtitle: 'Combustível',
      latitude: -20,
      longitude: -45,
      distanceMeters: 800,
      source: 'cache',
    );
    for (final width in <double>[320, 360, 412]) {
      for (final scale in <double>[1.0, 1.5]) {
        await tester.binding.setSurfaceSize(Size(width, 720));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: MapPoiDetailsSheet(
                item: item,
                icon: Icons.local_gas_station,
                distanceLabel: '800 m',
                centered: true,
                onNavigate: () {},
                onShowOnMap: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Cache local (OSM)'), findsOneWidget);
        expect(find.text('800 m em linha reta'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Overflow no POI em $width dp e escala $scale');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

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

    await tester.scrollUntilVisible(
      find.text('Água potável'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Água potável'), findsOneWidget);
    expect(find.text('Ir até lá'), findsOneWidget);

    await tester.tap(find.text('Ir até lá'));
    expect(navigateCount, 1);
  });
}
