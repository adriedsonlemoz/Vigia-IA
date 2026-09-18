import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/storage_policy.dart';
import 'event_history_service.dart';

class StorageUsage {
  const StorageUsage({required this.mediaBytes, required this.files});
  final int mediaBytes;
  final int files;
  double get mediaMb => mediaBytes / (1024 * 1024);
}

class StorageManagementService {
  const StorageManagementService();

  Future<StorageUsage> usage() async {
    final root = await getApplicationSupportDirectory();
    final events = Directory('${root.path}${Platform.pathSeparator}events');
    if (!await events.exists()) return const StorageUsage(mediaBytes: 0, files: 0);
    var bytes = 0;
    var files = 0;
    await for (final entity in events.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          bytes += await entity.length();
          files++;
        } catch (_) {}
      }
    }
    return StorageUsage(mediaBytes: bytes, files: files);
  }

  Future<int> cleanup(StoragePolicy policy) => EventHistoryService.instance.applyStoragePolicy(policy);
}
