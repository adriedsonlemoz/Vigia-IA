import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/app_metadata.dart';
import '../models/update_release.dart';
import 'native_platform_service.dart';
import 'update_news_catalog.dart';

abstract interface class UpdateNewsStore {
  Future<String?> readLastShownVersion();
  Future<void> writeLastShownVersion(String value);
}

abstract interface class InstalledVersionProvider {
  Future<AppBuildVersion> currentVersion();
}

class FileUpdateNewsStore implements UpdateNewsStore {
  File? _file;

  Future<File> _stateFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final root = await getApplicationSupportDirectory();
    final file = File(
      '${root.path}${Platform.pathSeparator}update_news_state.json',
    );
    _file = file;
    return file;
  }

  @override
  Future<String?> readLastShownVersion() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final value = decoded['lastShownVersion'];
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeLastShownVersion(String value) async {
    final file = await _stateFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schema': 1,
        'lastShownVersion': value,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}

class NativeInstalledVersionProvider implements InstalledVersionProvider {
  const NativeInstalledVersionProvider();

  @override
  Future<AppBuildVersion> currentVersion() async {
    final info = await NativePlatformService.instance.appVersionInfo();
    return AppBuildVersion(version: info.version, build: info.build);
  }
}

class UpdateNewsService {
  UpdateNewsService({
    this.catalog = UpdateNewsCatalog.current,
    UpdateNewsStore? store,
    InstalledVersionProvider? versionProvider,
  })  : _store = store ?? FileUpdateNewsStore(),
        _versionProvider = versionProvider ?? const NativeInstalledVersionProvider();

  static final UpdateNewsService instance = UpdateNewsService();

  final UpdateNewsCatalog catalog;
  final UpdateNewsStore _store;
  final InstalledVersionProvider _versionProvider;

  Future<UpdateNewsDecision> evaluate() async {
    final installed = await _safeInstalledVersion();
    final lastShown = await _safeLastShownVersion();

    if (lastShown != null && lastShown.compareTo(installed) >= 0) {
      return UpdateNewsDecision(
        installedVersion: installed,
        releases: const <UpdateRelease>[],
      );
    }

    final unseen = catalog.unseenReleases(
      installed: installed,
      lastShown: lastShown,
    );
    return UpdateNewsDecision(installedVersion: installed, releases: unseen);
  }

  Future<AppBuildVersion> _safeInstalledVersion() async {
    try {
      return await _versionProvider.currentVersion();
    } catch (_) {
      return const AppBuildVersion(
        version: AppMetadata.version,
        build: AppMetadata.build,
      );
    }
  }

  Future<AppBuildVersion?> _safeLastShownVersion() async {
    try {
      return AppBuildVersion.tryParse(await _store.readLastShownVersion());
    } catch (_) {
      return null;
    }
  }

  Future<void> markShown(UpdateNewsDecision decision) async {
    try {
      await _store.writeLastShownVersion(decision.installedVersion.storageValue);
    } catch (_) {
      // Falha de persistência nunca deve impedir a abertura do aplicativo.
    }
  }
}
