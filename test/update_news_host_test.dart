import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/update_release.dart';
import 'package:vigiaia/services/update_news_catalog.dart';
import 'package:vigiaia/services/update_news_service.dart';
import 'package:vigiaia/widgets/update_news_host.dart';

class _Store implements UpdateNewsStore {
  String? shown;

  @override
  Future<String?> readLastShownVersion() async => shown;

  @override
  Future<void> writeLastShownVersion(String value) async {
    shown = value;
  }
}

class _Installed implements InstalledVersionProvider {
  @override
  Future<AppBuildVersion> currentVersion() async =>
      const AppBuildVersion(version: '1.0.188', build: 188);
}

void main() {
  testWidgets('mostra sobre a tela inicial e só registra ao confirmar',
      (tester) async {
    final store = _Store();
    final service = UpdateNewsService(
      catalog: const UpdateNewsCatalog(<UpdateRelease>[
        UpdateRelease(
          version: AppBuildVersion(version: '1.0.188', build: 188),
          changes: <String>['Mapa atualizado'],
        ),
      ]),
      store: store,
      versionProvider: _Installed(),
    );
    var handled = false;
    await tester.pumpWidget(MaterialApp(home: UpdateNewsHost(
      service: service,
      onHandled: () => handled = true,
      child: const Scaffold(body: Text('Tela pronta')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tela pronta'), findsOneWidget);
    expect(find.text('Novidades da atualização'), findsOneWidget);
    expect(store.shown, isNull);
    expect(handled, isFalse);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(store.shown, '1.0.188+188');
    expect(handled, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: UpdateNewsHost(
      service: service,
      child: const Scaffold(body: Text('Tela pronta')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Novidades da atualização'), findsNothing);
  });
}
