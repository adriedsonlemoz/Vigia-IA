import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/rgb_frame.dart';
import '../models/video_source_config.dart';
import 'error_log_service.dart';
import 'native_platform_service.dart';

class ClipRecorderService {
  ClipRecorderService({
    this.duration = const Duration(seconds: 8),
    this.formatPreference = ClipFormatPreference.mp4WithGifFallback,
  });

  Duration duration;
  ClipFormatPreference formatPreference;
  final List<_ClipFrame> _buffer = <_ClipFrame>[];
  final ErrorLogService _logs = ErrorLogService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  _PendingClip? _pending;
  Directory? _directory;

  bool get recording => _pending != null;

  void configure({
    required Duration clipDuration,
    required ClipFormatPreference format,
  }) {
    duration = Duration(seconds: clipDuration.inSeconds.clamp(3, 20).toInt());
    formatPreference = format;
    _trimBuffer(DateTime.now());
  }

  Future<void> initialize() async {
    if (_directory != null) return;
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}events${Platform.pathSeparator}clips',
    );
    await directory.create(recursive: true);
    _directory = directory;
  }

  void pushFrame(RgbFrame frame) {
    final compact = _ClipFrame.fromRgbFrame(frame);
    _buffer.add(compact);
    _trimBuffer(frame.capturedAt);

    final pending = _pending;
    if (pending == null || !frame.capturedAt.isAfter(pending.triggeredAt)) return;
    pending.frames.add(compact.copy());
    if (!frame.capturedAt.isBefore(pending.finishAt)) {
      _pending = null;
      unawaited(_finish(pending));
    }
  }

  void _trimBuffer(DateTime now) {
    final preDuration = Duration(milliseconds: (duration.inMilliseconds * 0.30).round());
    _buffer.removeWhere((frame) => now.difference(frame.capturedAt) > preDuration);
    while (_buffer.length > 48) {
      _buffer.removeAt(0);
    }
  }

  Future<String?> trigger() async {
    await initialize();
    final existing = _pending;
    if (existing != null) return existing.completer.future;

    final now = DateTime.now();
    final preDuration = Duration(milliseconds: (duration.inMilliseconds * 0.30).round());
    final postDuration = duration - preDuration;
    final pending = _PendingClip(
      id: now.microsecondsSinceEpoch.toString(),
      triggeredAt: now,
      finishAt: now.add(postDuration),
      frames: _buffer.map((frame) => frame.copy()).toList(growable: true),
    );
    _pending = pending;

    // Garante finalização mesmo se a fonte parar logo depois do evento.
    Timer(postDuration + const Duration(milliseconds: 800), () {
      if (identical(_pending, pending)) {
        _pending = null;
        unawaited(_finish(pending));
      }
    });
    return pending.completer.future;
  }

  Future<void> flushPending() async {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    await _finish(pending);
  }

  Future<void> _finish(_PendingClip pending) async {
    if (pending.frames.length < 2) {
      if (!pending.completer.isCompleted) pending.completer.complete(null);
      return;
    }
    try {
      final directory = _directory;
      if (directory == null) {
        if (!pending.completer.isCompleted) pending.completer.complete(null);
        return;
      }

      String? outputPath;
      if (formatPreference == ClipFormatPreference.mp4WithGifFallback) {
        outputPath = await _tryMp4(directory, pending);
      }
      outputPath ??= await _writeGif(directory, pending);
      if (!pending.completer.isCompleted) pending.completer.complete(outputPath);
    } catch (error, stackTrace) {
      await _logs.recordException(
        source: 'Clipes automáticos',
        error: error,
        stackTrace: stackTrace,
        message: 'Não foi possível gerar o clipe do evento.',
        level: ErrorLogLevel.warning,
      );
      if (!pending.completer.isCompleted) pending.completer.complete(null);
    }
  }

  Future<String?> _tryMp4(Directory directory, _PendingClip pending) async {
    final file = File('${directory.path}${Platform.pathSeparator}clip_${pending.id}.mp4');
    final normalized = await compute<List<Map<String, Object>>, List<Map<String, Object>>>(
      _normalizeFramesForNative,
      pending.frames
          .map((frame) => <String, Object>{
                'width': frame.width,
                'height': frame.height,
                'bytes': frame.bytes,
              })
          .toList(growable: false),
    );
    if (normalized.length < 2) return null;
    final elapsedMs = pending.frames.last.capturedAt
        .difference(pending.frames.first.capturedAt)
        .inMilliseconds
        .clamp(500, 60000)
        .toInt();
    final fps = ((normalized.length - 1) * 1000 / elapsedMs).round().clamp(1, 10).toInt();
    final success = await _native.encodeMp4(
      outputPath: file.path,
      frames: normalized,
      fps: fps,
    );
    if (!success || !await file.exists() || await file.length() < 1024) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      return null;
    }
    return file.path;
  }

  Future<String?> _writeGif(Directory directory, _PendingClip pending) async {
    final bytes = await compute<List<Map<String, Object>>, Uint8List?>(
      _encodeAnimatedGif,
      pending.frames
          .map((frame) => <String, Object>{
                'width': frame.width,
                'height': frame.height,
                'bytes': frame.bytes,
              })
          .toList(growable: false),
    );
    if (bytes == null || bytes.isEmpty) return null;
    final file = File('${directory.path}${Platform.pathSeparator}clip_${pending.id}.gif');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  void resetBuffer() => _buffer.clear();
}

class _ClipFrame {
  const _ClipFrame({
    required this.width,
    required this.height,
    required this.bytes,
    required this.capturedAt,
  });

  factory _ClipFrame.fromRgbFrame(RgbFrame frame) => _ClipFrame(
        width: frame.width,
        height: frame.height,
        bytes: Uint8List.fromList(frame.rgbBytes),
        capturedAt: frame.capturedAt,
      );

  final int width;
  final int height;
  final Uint8List bytes;
  final DateTime capturedAt;

  _ClipFrame copy() => _ClipFrame(
        width: width,
        height: height,
        bytes: Uint8List.fromList(bytes),
        capturedAt: capturedAt,
      );
}

class _PendingClip {
  _PendingClip({
    required this.id,
    required this.triggeredAt,
    required this.finishAt,
    required this.frames,
  });

  final String id;
  final DateTime triggeredAt;
  final DateTime finishAt;
  final List<_ClipFrame> frames;
  final Completer<String?> completer = Completer<String?>();
}

List<Map<String, Object>> _normalizeFramesForNative(List<Map<String, Object>> frames) {
  if (frames.isEmpty) return const <Map<String, Object>>[];
  final firstWidth = frames.first['width']! as int;
  final firstHeight = frames.first['height']! as int;
  final targetWidth = (firstWidth > 640 ? 640 : firstWidth) & ~1;
  final targetHeight = ((firstHeight * targetWidth / firstWidth).round()) & ~1;
  final output = <Map<String, Object>>[];
  for (final data in frames.take(120)) {
    final width = data['width']! as int;
    final height = data['height']! as int;
    final bytes = data['bytes']! as Uint8List;
    var image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      bytesOffset: bytes.offsetInBytes,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    );
    if (image.width != targetWidth || image.height != targetHeight) {
      image = img.copyResize(image, width: targetWidth, height: targetHeight);
    }
    output.add(<String, Object>{
      'width': targetWidth,
      'height': targetHeight,
      'bytes': Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgb)),
    });
  }
  return output;
}

Uint8List? _encodeAnimatedGif(List<Map<String, Object>> frames) {
  final encoder = img.GifEncoder(
    delay: 70,
    repeat: 0,
    numColors: 128,
    samplingFactor: 20,
  );
  for (final data in frames.take(80)) {
    final width = data['width']! as int;
    final height = data['height']! as int;
    final bytes = data['bytes']! as Uint8List;
    var image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      bytesOffset: bytes.offsetInBytes,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    );
    if (image.width > 480) image = img.copyResize(image, width: 480);
    encoder.addFrame(image, duration: 70);
  }
  return encoder.finish();
}
