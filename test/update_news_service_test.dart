import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/update_release.dart';
import 'package:vigiaia/services/update_news_catalog.dart';
import 'package:vigiaia/services/update_news_service.dart';

class _MemoryStore implements UpdateNewsStore {
  String? value;

  @override
  Future<String?> readLastShownVersion() async => value;

  @override
  Future<void> writeLastShownVersion(String value) async {
    this.value = value;
  }
}

class _MutableVersionProvider implements InstalledVersionProvider {
  _MutableVersionProvider(this.value);

  AppBuildVersion value;

  @override
  Future<AppBuildVersion> currentVersion() async => value;
}

const _catalog = UpdateNewsCatalog(<UpdateRelease>[
  UpdateRelease(
    version: AppBuildVersion(version: '1.0.143', build: 143),
    changes: <String>['Mudança 143'],
  ),
  UpdateRelease(
    version: AppBuildVersion(version: '1.0.144', build: 144),
    changes: <String>['Mudança 144'],
  ),
]);

void main() {
  test('primeira abertura da nova versao mostra novidades', () async {
    final store = _MemoryStore()..value = '1.0.142+142';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.143', build: 143),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final decision = await service.evaluate();

    expect(decision.shouldShow, isTrue);
    expect(decision.changes, contains('Mudança 143'));
  });

  test('segunda abertura da mesma versao nao mostra novamente', () async {
    final store = _MemoryStore()..value = '1.0.142+142';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.143', build: 143),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final first = await service.evaluate();
    await service.markShown(first);
    final second = await service.evaluate();

    expect(store.value, '1.0.143+143');
    expect(second.shouldShow, isFalse);
  });

  test('atualizacao seguinte volta a mostrar e inclui versao pulada', () async {
    final store = _MemoryStore()..value = '1.0.142+142';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.143', build: 143),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final first = await service.evaluate();
    await service.markShown(first);
    provider.value = const AppBuildVersion(version: '1.0.144', build: 144);
    final upgraded = await service.evaluate();

    expect(upgraded.shouldShow, isTrue);
    expect(upgraded.changes, contains('Mudança 144'));

    store.value = '1.0.142+142';
    final skipped = await service.evaluate();
    expect(skipped.releases.map((release) => release.version.build), [143, 144]);
  });

  test('estado ausente ou corrompido falha de forma segura', () async {
    final store = _MemoryStore()..value = 'dados-corrompidos';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.143', build: 143),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final corruptDecision = await service.evaluate();
    expect(corruptDecision.shouldShow, isTrue);

    store.value = null;
    final missingDecision = await service.evaluate();
    expect(missingDecision.shouldShow, isTrue);
  });
}
