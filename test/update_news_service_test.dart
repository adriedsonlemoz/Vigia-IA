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
  test('primeira abertura mostra somente a versao instalada atual', () async {
    final store = _MemoryStore()..value = '1.0.142+142';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.144', build: 144),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final decision = await service.evaluate();

    expect(decision.shouldShow, isTrue);
    expect(decision.releases, hasLength(1));
    expect(decision.releases.single.version.build, 144);
    expect(decision.changes, <String>['Mudança 144']);
    expect(decision.changes, isNot(contains('Mudança 143')));
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

  test('pular versoes nao mistura novidades antigas', () async {
    final store = _MemoryStore()..value = '1.0.100+100';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.144', build: 144),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final decision = await service.evaluate();

    expect(decision.releases, hasLength(1));
    expect(decision.releases.single.version.build, 144);
    expect(decision.changes, <String>['Mudança 144']);
  });

  test('sem entrada da versao atual nao mostra historico como fallback', () async {
    final store = _MemoryStore()..value = '1.0.142+142';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.145', build: 145),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final decision = await service.evaluate();

    expect(decision.shouldShow, isFalse);
    expect(decision.releases, isEmpty);
  });

  test('estado ausente ou corrompido ainda usa somente a versao atual', () async {
    final store = _MemoryStore()..value = 'dados-corrompidos';
    final provider = _MutableVersionProvider(
      const AppBuildVersion(version: '1.0.144', build: 144),
    );
    final service = UpdateNewsService(
      catalog: _catalog,
      store: store,
      versionProvider: provider,
    );

    final corruptDecision = await service.evaluate();
    expect(corruptDecision.shouldShow, isTrue);
    expect(corruptDecision.releases.single.version.build, 144);

    store.value = null;
    final missingDecision = await service.evaluate();
    expect(missingDecision.shouldShow, isTrue);
    expect(missingDecision.releases.single.version.build, 144);
  });
}
