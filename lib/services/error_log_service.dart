import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum ErrorLogLevel { info, warning, error }

class ErrorLogEntry {
  const ErrorLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.details,
    this.context = const <String, String>{},
  });

  final String id;
  final DateTime timestamp;
  final ErrorLogLevel level;
  final String source;
  final String message;
  final String? details;
  final Map<String, String> context;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'source': source,
        'message': message,
        'details': details,
        'context': context,
      };

  factory ErrorLogEntry.fromJson(Map<String, Object?> json) {
    final rawContext = json['context'];
    return ErrorLogEntry(
      id: json['id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      level: ErrorLogLevel.values.firstWhere(
        (item) => item.name == json['level'],
        orElse: () => ErrorLogLevel.error,
      ),
      source: json['source'] as String? ?? 'Aplicativo',
      message: json['message'] as String? ?? 'Erro sem descrição',
      details: json['details'] as String?,
      context: rawContext is Map
          ? rawContext.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }
}

class ErrorLogService extends ChangeNotifier {
  ErrorLogService._();

  static final ErrorLogService instance = ErrorLogService._();
  static const int _maxEntries = 200;

  final List<ErrorLogEntry> _entries = <ErrorLogEntry>[];
  File? _file;
  Future<void> _writeTail = Future<void>.value();
  final Map<String, DateTime> _lastRecorded = <String, DateTime>{};
  bool _initialized = false;

  List<ErrorLogEntry> get entries =>
      List<ErrorLogEntry>.unmodifiable(_entries.reversed);
  int get count => _entries.length;
  int get problemCount => _entries
      .where((entry) => entry.level != ErrorLogLevel.info)
      .length;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final directory = await getApplicationSupportDirectory();
      final logsDirectory = Directory('${directory.path}/diagnostics');
      await logsDirectory.create(recursive: true);
      _file = File('${logsDirectory.path}/errors.jsonl');
      if (await _file!.exists()) {
        final lines = await _file!.readAsLines();
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final decoded = jsonDecode(line);
            if (decoded is Map<String, Object?>) {
              _entries.add(ErrorLogEntry.fromJson(decoded));
            } else if (decoded is Map) {
              _entries.add(ErrorLogEntry.fromJson(
                decoded.map((key, value) => MapEntry(key.toString(), value)),
              ));
            }
          } catch (_) {
            // Uma linha corrompida não impede a leitura das demais.
          }
        }
        if (_entries.length > _maxEntries) {
          _entries.removeRange(0, _entries.length - _maxEntries);
          await _rewriteFile();
        }
      }
    } catch (_) {
      // A central continua funcionando em memória se o armazenamento falhar.
    }
    notifyListeners();
  }

  Future<void> record({
    required ErrorLogLevel level,
    required String source,
    required String message,
    String? details,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    final now = DateTime.now();
    final compactMessage = _compact(message);
    final dedupKey = '${level.name}|$source|$compactMessage';
    final previous = _lastRecorded[dedupKey];
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 15)) {
      return;
    }
    _lastRecorded[dedupKey] = now;
    if (_lastRecorded.length > 300) {
      _lastRecorded.removeWhere(
        (_, value) => now.difference(value) > const Duration(minutes: 10),
      );
    }
    final entry = ErrorLogEntry(
      id: '${now.microsecondsSinceEpoch}-${_entries.length}',
      timestamp: now,
      level: level,
      source: source,
      message: compactMessage,
      details: details == null ? null : _compact(details, maxLength: 12000),
      context: context.map(
        (key, value) => MapEntry(key, value?.toString() ?? 'null'),
      ),
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
    await _enqueueWrite(entry);
  }

  Future<void> recordException({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    String? message,
    Map<String, Object?> context = const <String, Object?>{},
    ErrorLogLevel level = ErrorLogLevel.error,
  }) {
    return record(
      level: level,
      source: source,
      message: message ?? error.toString(),
      details: stackTrace == null
          ? error.toString()
          : '${error.toString()}\n\n$stackTrace',
      context: context,
    );
  }

  Future<void> clear() async {
    _entries.clear();
    _lastRecorded.clear();
    notifyListeners();
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      final file = _file;
      if (file != null) {
        try {
          await file.writeAsString('', flush: true);
        } catch (_) {}
      }
    });
    await _writeTail;
  }

  String exportText() {
    if (_entries.isEmpty) return 'Nenhum erro registrado.';
    final buffer = StringBuffer()
      ..writeln('Vigia IA - Central de Erros')
      ..writeln('Registros: ${_entries.length}')
      ..writeln();
    for (final entry in _entries.reversed) {
      buffer
        ..writeln(
          '[${entry.timestamp.toIso8601String()}] '
          '${entry.level.name.toUpperCase()} | ${entry.source}',
        )
        ..writeln(entry.message);
      if (entry.context.isNotEmpty) {
        buffer.writeln(
          entry.context.entries
              .map((item) => '${item.key}=${item.value}')
              .join(' | '),
        );
      }
      if (entry.details?.isNotEmpty == true) {
        buffer.writeln(entry.details);
      }
      buffer.writeln('---');
    }
    return buffer.toString();
  }

  Future<void> _enqueueWrite(ErrorLogEntry entry) async {
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      final file = _file;
      if (file == null) return;
      try {
        if (_entries.length >= _maxEntries) {
          await _rewriteFile();
          return;
        }
        await file.writeAsString(
          '${jsonEncode(entry.toJson())}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {
        // O monitoramento nunca deve parar por falha ao gravar diagnóstico.
      }
    });
    await _writeTail;
  }

  Future<void> _rewriteFile() async {
    final file = _file;
    if (file == null) return;
    final data = _entries.map((entry) => jsonEncode(entry.toJson())).join('\n');
    await file.writeAsString(
      data.isEmpty ? '' : '$data\n',
      flush: true,
    );
  }

  static String _compact(String value, {int maxLength = 2000}) {
    var normalized = value.trim();
    normalized = normalized.replaceAllMapped(
      RegExp(r'(rtsp://[^\s:/@]+:)[^@\s]+@', caseSensitive: false),
      (match) => '${match.group(1)}***@',
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r'(password|senha|token)=([^&\s]+)', caseSensitive: false),
      (match) => '${match.group(1)}=***',
    );
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }
}
