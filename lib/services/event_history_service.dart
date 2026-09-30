import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/detection.dart';
import '../models/monitor_event.dart';
import '../models/rgb_frame.dart';
import '../models/storage_policy.dart';
import 'error_log_service.dart';

class EventHistoryService {
  EventHistoryService._();

  static final EventHistoryService instance = EventHistoryService._();

  static const int maxEvents = 200;

  final ErrorLogService _logs = ErrorLogService.instance;
  final List<MonitorEvent> _events = <MonitorEvent>[];
  Future<void> _tail = Future<void>.value();
  bool _initialized = false;
  Future<void>? _initialization;
  late File _indexFile;
  late Directory _snapshotDirectory;

  List<MonitorEvent> get events => List<MonitorEvent>.unmodifiable(_events);

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initialization;
    if (pending != null) return pending;
    final future = _initialize();
    _initialization = future;
    return future.whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}events');
    await directory.create(recursive: true);
    _snapshotDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}snapshots',
    );
    await _snapshotDirectory.create(recursive: true);
    _indexFile = File('${directory.path}${Platform.pathSeparator}events.json');

    if (await _indexFile.exists()) {
      try {
        final decoded = jsonDecode(await _indexFile.readAsString());
        if (decoded is List) {
          _events
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                    (item) => MonitorEvent.fromJson(
                      item.cast<String, dynamic>(),
                    ),
                  ),
            );
          _events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (_events.length > maxEvents) {
            final removed = _events.sublist(maxEvents);
            _events.removeRange(maxEvents, _events.length);
            for (final event in removed) {
              await _deleteSnapshot(event.snapshotPath);
              await _deleteClipIfUnreferenced(event.clipPath);
            }
          }
        }
      } catch (error, stackTrace) {
        await _logs.recordException(
          source: 'Histórico de eventos',
          error: error,
          stackTrace: stackTrace,
          message: 'Não foi possível carregar o histórico de eventos.',
          level: ErrorLogLevel.warning,
        );
      }
    }
    _initialized = true;
  }

  Future<MonitorEvent?> addEvent({
    required Detection detection,
    required RgbFrame frame,
    required String source,
    MonitorEventType type = MonitorEventType.alert,
    int? trackId,
    String? zoneId,
    String? zoneName,
    String? cameraId,
  }) async {
    try {
      return await _enqueue<MonitorEvent>(() async {
        await initialize();
        final createdAt = DateTime.now();
        final id = '${createdAt.microsecondsSinceEpoch}_${detection.label}_${type.name}';
        String? snapshotPath;
        try {
          snapshotPath = await _saveSnapshot(id, frame);
        } catch (error, stackTrace) {
          await _logs.recordException(
            source: 'Histórico de eventos',
            error: error,
            stackTrace: stackTrace,
            message: 'O evento foi registrado, mas a imagem não pôde ser salva.',
            level: ErrorLogLevel.warning,
          );
        }

        final event = MonitorEvent(
          id: id,
          createdAt: createdAt,
          label: detection.label,
          displayLabel: detection.displayLabel,
          confidence: detection.confidence,
          source: source,
          box: detection.box,
          snapshotPath: snapshotPath,
          type: type,
          trackId: trackId,
          zoneId: zoneId,
          zoneName: zoneName,
          cameraId: cameraId,
        );
        _events.insert(0, event);
        await _trimAndPersist();
        return event;
      });
    } catch (error, stackTrace) {
      await _logs.recordException(
        source: 'Histórico de eventos',
        error: error,
        stackTrace: stackTrace,
        message: 'Falha ao registrar um evento confirmado.',
        level: ErrorLogLevel.warning,
      );
      return null;
    }
  }

  Future<MonitorEvent?> addCameraIntegrityEvent({
    required RgbFrame frame,
    required String source,
    required MonitorEventType type,
    String? cameraId,
  }) {
    final obstructed = type == MonitorEventType.cameraObstructed;
    return addEvent(
      detection: Detection(
        label: obstructed ? 'camera_obstructed' : 'camera_moved',
        displayLabel: obstructed ? 'Câmera obstruída' : 'Câmera deslocada',
        confidence: 1,
        box: const NormalizedBox(xMin: 0, yMin: 0, xMax: 1, yMax: 1),
      ),
      frame: frame,
      source: source,
      type: type,
      cameraId: cameraId,
    );
  }

  Future<void> attachClip(Iterable<String> eventIds, String clipPath) async {
    final ids = eventIds.toSet();
    if (ids.isEmpty || clipPath.isEmpty) return;
    await _enqueue<void>(() async {
      await initialize();
      var changed = false;
      for (var i = 0; i < _events.length; i++) {
        if (!ids.contains(_events[i].id)) continue;
        _events[i] = _events[i].copyWith(clipPath: clipPath);
        changed = true;
      }
      if (changed) await _persist();
    });
  }

  Future<void> deleteEvent(String id) async {
    await _enqueue<void>(() async {
      await initialize();
      final index = _events.indexWhere((event) => event.id == id);
      if (index < 0) return;
      final removed = _events.removeAt(index);
      await _deleteSnapshot(removed.snapshotPath);
      await _deleteClipIfUnreferenced(removed.clipPath);
      await _persist();
    });
  }


  Future<int> applyStoragePolicy(StoragePolicy policy) async {
    if (!policy.autoCleanup) return 0;
    return _enqueue<int>(() async {
      await initialize();
      var removedCount = 0;
      final cutoff = DateTime.now().subtract(Duration(days: policy.retentionDays));
      final expired = _events.where((event) => event.createdAt.isBefore(cutoff)).toList(growable: false);
      for (final event in expired) {
        _events.removeWhere((item) => item.id == event.id);
        await _deleteSnapshot(event.snapshotPath);
        await _deleteClipIfUnreferenced(event.clipPath);
        removedCount++;
      }

      final maxBytes = policy.maxStorageMb * 1024 * 1024;
      while (_events.isNotEmpty && await _estimatedMediaBytes() > maxBytes) {
        final removed = _events.removeLast();
        await _deleteSnapshot(removed.snapshotPath);
        await _deleteClipIfUnreferenced(removed.clipPath);
        removedCount++;
      }
      if (removedCount > 0) await _persist();
      return removedCount;
    });
  }

  Future<int> _estimatedMediaBytes() async {
    final paths = <String>{
      ..._events.map((event) => event.snapshotPath).whereType<String>(),
      ..._events.map((event) => event.clipPath).whereType<String>(),
    };
    var total = 0;
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) total += await file.length();
      } catch (_) {}
    }
    return total;
  }

  Future<void> clear() async {
    await _enqueue<void>(() async {
      await initialize();
      final snapshots = _events.map((event) => event.snapshotPath).toSet();
      final clips = _events.map((event) => event.clipPath).toSet();
      _events.clear();
      for (final path in snapshots) {
        await _deleteSnapshot(path);
      }
      for (final path in clips) {
        await _deleteFile(path);
      }
      await _persist();
    });
  }

  Future<void> _trimAndPersist() async {
    while (_events.length > maxEvents) {
      final removed = _events.removeLast();
      await _deleteSnapshot(removed.snapshotPath);
      await _deleteClipIfUnreferenced(removed.clipPath);
    }
    await _persist();
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final previous = _tail;
    final completer = Completer<T>();
    _tail = () async {
      try {
        await previous;
      } catch (_) {}
      try {
        final result = await operation();
        if (!completer.isCompleted) completer.complete(result);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    }();
    return completer.future;
  }

  Future<String> _saveSnapshot(String id, RgbFrame frame) async {
    final encoded = await compute<Map<String, Object>, Uint8List>(
      _encodeRgbJpeg,
      <String, Object>{
        'width': frame.width,
        'height': frame.height,
        'bytes': Uint8List.fromList(frame.rgbBytes),
      },
    );
    final file = File(
      '${_snapshotDirectory.path}${Platform.pathSeparator}$id.jpg',
    );
    await file.writeAsBytes(encoded, flush: true);
    return file.path;
  }

  Future<void> _persist() async {
    final temporary = File('${_indexFile.path}.tmp');
    final json = jsonEncode(_events.map((event) => event.toJson()).toList());
    await temporary.writeAsString(json, flush: true);
    if (await _indexFile.exists()) await _indexFile.delete();
    await temporary.rename(_indexFile.path);
  }

  Future<void> _deleteSnapshot(String? path) => _deleteFile(path);

  Future<void> _deleteClipIfUnreferenced(String? path) async {
    if (path == null || path.isEmpty) return;
    if (_events.any((event) => event.clipPath == path)) return;
    await _deleteFile(path);
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Limpeza de mídia antiga não deve impedir o uso do histórico.
    }
  }
}

Uint8List _encodeRgbJpeg(Map<String, Object> data) {
  final width = data['width']! as int;
  final height = data['height']! as int;
  final bytes = data['bytes']! as Uint8List;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
  return img.encodeJpg(image, quality: 82);
}
