import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/esp32_module.dart';
import '../models/esp32_telemetry.dart';
import 'bike_sensor_service.dart';
import 'error_log_service.dart';
import 'esp32_module_service.dart';

class Esp32TelemetryService extends ChangeNotifier with WidgetsBindingObserver {
  Esp32TelemetryService._();

  static final Esp32TelemetryService instance = Esp32TelemetryService._();

  static const List<String> _discoveryPaths = <String>[
    '/api/v1/telemetry',
    '/telemetry',
    '/api/v1/status',
    '/status',
  ];

  final Esp32ModuleService _registry = Esp32ModuleService.instance;
  final BikeSensorService _bikeSensors = BikeSensorService.instance;
  final ErrorLogService _logs = ErrorLogService.instance;
  final Map<String, Esp32RuntimeState> _states = <String, Esp32RuntimeState>{};
  final Map<String, Timer> _timers = <String, Timer>{};
  final Map<String, String> _preferredPaths = <String, String>{};
  final Set<String> _inFlight = <String>{};

  HttpClient? _client;
  bool _initialized = false;
  Future<void>? _initializing;
  bool _foreground = true;

  Map<String, Esp32RuntimeState> get states =>
      Map<String, Esp32RuntimeState>.unmodifiable(_states);

  Esp32RuntimeState? stateFor(String moduleId) => _states[moduleId];

  List<Map<String, Object?>> get diagnostics => _registry.modules
      .map(
        (module) => <String, Object?>{
          'id': module.id,
          'name': module.name,
          'position': module.positionLabel,
          'enabled': module.enabled,
          'configuredCapabilities':
              module.capabilities.map((item) => item.name).toList()..sort(),
          'telemetryIntervalMs': module.telemetryIntervalMs,
          'runtime': _states[module.id]?.toDiagnosticJson(),
        },
      )
      .toList(growable: false);

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _registry.initialize();
      await _bikeSensors.initialize();
      await _logs.initialize();
      _client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      _registry.addListener(_onRegistryChanged);
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      _syncModules(forceImmediate: true);
    } finally {
      _initializing = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (foreground) {
      _syncModules(forceImmediate: true);
    } else {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    }
  }

  Future<void> refreshNow([String? moduleId]) async {
    await initialize();
    final targets = moduleId == null
        ? _registry.modules.where((item) => item.enabled).toList(growable: false)
        : _registry.modules
            .where((item) => item.id == moduleId && item.enabled)
            .toList(growable: false);
    await Future.wait(
      targets.map((module) async {
        _timers.remove(module.id)?.cancel();
        await _poll(module, scheduleAfter: true);
      }),
    );
  }

  void _onRegistryChanged() => _syncModules(forceImmediate: true);

  void _syncModules({bool forceImmediate = false}) {
    if (!_initialized) return;
    final modules = _registry.modules;
    final ids = modules.map((item) => item.id).toSet();

    for (final id in _states.keys.where((id) => !ids.contains(id)).toList()) {
      _states.remove(id);
      _preferredPaths.remove(id);
      _timers.remove(id)?.cancel();
      _bikeSensors.removeEsp32Module(id);
    }

    for (final module in modules) {
      if (!module.enabled) {
        _timers.remove(module.id)?.cancel();
        _preferredPaths.remove(module.id);
        _bikeSensors.removeEsp32Module(module.id);
        _states[module.id] = Esp32RuntimeState(
          moduleId: module.id,
          connectionState: Esp32ConnectionState.disabled,
        );
        continue;
      }
      _states.putIfAbsent(
        module.id,
        () => Esp32RuntimeState(
          moduleId: module.id,
          connectionState: Esp32ConnectionState.connecting,
        ),
      );
      if (_foreground && (forceImmediate || !_timers.containsKey(module.id))) {
        _schedule(module, Duration.zero);
      }
    }
    notifyListeners();
  }

  void _schedule(Esp32Module module, Duration delay) {
    _timers.remove(module.id)?.cancel();
    if (!_foreground || !module.enabled) return;
    _timers[module.id] = Timer(
      delay,
      () {
        _timers.remove(module.id);
        unawaited(_poll(module, scheduleAfter: true));
      },
    );
  }

  Future<void> _poll(
    Esp32Module module, {
    required bool scheduleAfter,
  }) async {
    if (!_foreground || !module.enabled) return;
    if (_inFlight.contains(module.id)) {
      if (scheduleAfter) _schedule(module, const Duration(milliseconds: 500));
      return;
    }
    final currentModule = _registry.modules.where((item) => item.id == module.id);
    if (currentModule.isEmpty || !currentModule.first.enabled) return;
    module = currentModule.first;

    _inFlight.add(module.id);
    final previous = _states[module.id];
    final attemptAt = DateTime.now();
    if (previous == null ||
        previous.connectionState == Esp32ConnectionState.offline ||
        previous.connectionState == Esp32ConnectionState.disabled) {
      _states[module.id] = Esp32RuntimeState(
        moduleId: module.id,
        connectionState: Esp32ConnectionState.connecting,
        lastAttemptAt: attemptAt,
        lastSuccessAt: previous?.lastSuccessAt,
        consecutiveFailures: previous?.consecutiveFailures ?? 0,
        packet: previous?.packet,
      );
      notifyListeners();
    }

    try {
      final response = await _fetchTelemetry(module);
      final packet = Esp32TelemetryPacket.fromJson(
        response.payload,
        fallbackModuleId: module.id,
        receivedAt: DateTime.now(),
      );
      final successAt = DateTime.now();
      _preferredPaths[module.id] = response.path;
      _states[module.id] = Esp32RuntimeState(
        moduleId: module.id,
        connectionState: packet.connected
            ? Esp32ConnectionState.online
            : Esp32ConnectionState.degraded,
        lastAttemptAt: attemptAt,
        lastSuccessAt: successAt,
        nextRetryAt: successAt.add(_successDelay(module)),
        latency: response.latency,
        endpointPath: response.path,
        packet: packet,
      );
      if (packet.hasBikeTelemetry) {
        _bikeSensors.applyEsp32Telemetry(
          packet.bikePayload,
          moduleId: module.id,
          minimumTirePressurePsi: module.minimumTirePressurePsi,
          maximumTemperatureC: module.maximumTemperatureC,
          telemetryIntervalMs: module.telemetryIntervalMs,
        );
      }
      if (previous?.connectionState != Esp32ConnectionState.online) {
        unawaited(
          _logs.record(
            level: ErrorLogLevel.info,
            source: 'ESP32/${module.name}',
            message: 'Telemetria conectada.',
            context: <String, Object?>{
              'moduleId': module.id,
              'endpoint': response.path,
              'latencyMs': response.latency.inMilliseconds,
              if (packet.firmwareVersion != null)
                'firmware': packet.firmwareVersion,
              if (packet.rssiDbm != null) 'rssiDbm': packet.rssiDbm,
            },
          ),
        );
      }
      notifyListeners();
      if (scheduleAfter) _schedule(module, _successDelay(module));
    } catch (error, stackTrace) {
      final failures = (previous?.consecutiveFailures ?? 0) + 1;
      if (failures >= 2) _preferredPaths.remove(module.id);
      final now = DateTime.now();
      final lastSuccess = previous?.lastSuccessAt;
      final stillFresh = lastSuccess != null &&
          now.difference(lastSuccess) <= module.staleAfter;
      final state = stillFresh
          ? Esp32ConnectionState.degraded
          : Esp32ConnectionState.offline;
      final delay = _failureDelay(module, failures);
      _states[module.id] = Esp32RuntimeState(
        moduleId: module.id,
        connectionState: state,
        lastAttemptAt: attemptAt,
        lastSuccessAt: lastSuccess,
        nextRetryAt: now.add(delay),
        endpointPath: previous?.endpointPath,
        consecutiveFailures: failures,
        error: _friendlyError(error),
        packet: previous?.packet,
      );
      if (state == Esp32ConnectionState.offline) {
        _bikeSensors.markEsp32ModuleDisconnected(module.id);
      }
      if (previous?.connectionState != state || failures == 1) {
        unawaited(
          _logs.recordException(
            source: 'ESP32/${module.name}',
            error: error,
            stackTrace: stackTrace,
            level: state == Esp32ConnectionState.offline
                ? ErrorLogLevel.warning
                : ErrorLogLevel.info,
            message: state == Esp32ConnectionState.offline
                ? 'Módulo sem telemetria; reconexão automática ativa.'
                : 'Telemetria instável; mantendo a última leitura válida.',
            context: <String, Object?>{
              'moduleId': module.id,
              'tentativa': failures,
              'proximaTentativaMs': delay.inMilliseconds,
            },
          ),
        );
      }
      notifyListeners();
      if (scheduleAfter) _schedule(module, delay);
    } finally {
      _inFlight.remove(module.id);
    }
  }

  Future<_Esp32HttpResponse> _fetchTelemetry(Esp32Module module) async {
    final address = module.address?.trim() ?? '';
    final uri = Uri.tryParse(address);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('Endereço do ESP32 inválido.');
    }
    final root = address.endsWith('/')
        ? address.substring(0, address.length - 1)
        : address;
    final preferred = _preferredPaths[module.id];
    final paths = preferred == null
        ? _discoveryPaths
        : <String>[preferred, ..._discoveryPaths.where((p) => p != preferred)];

    Object? lastError;
    for (final path in paths) {
      final stopwatch = Stopwatch()..start();
      try {
        final target = Uri.parse('$root$path').replace(
          queryParameters: (module.accessKey ?? '').isEmpty
              ? null
              : <String, String>{'key': module.accessKey!},
        );
        var client = _client;
        if (client == null) {
          client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 2);
          _client = client;
        }
        final request = await client.getUrl(target);
        if ((module.accessKey ?? '').isNotEmpty) {
          request.headers.set('x-monitor-key', module.accessKey!);
        }
        request.headers.set('accept', 'application/json');
        final response = await request.close().timeout(const Duration(seconds: 3));
        final body = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 3));
        stopwatch.stop();

        if (response.statusCode == HttpStatus.unauthorized ||
            response.statusCode == HttpStatus.forbidden) {
          throw _Esp32TransportException('Chave do módulo recusada.');
        }
        if (response.statusCode == HttpStatus.notFound ||
            response.statusCode == HttpStatus.methodNotAllowed) {
          lastError = 'Endpoint $path indisponível';
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw _Esp32TransportException('HTTP ${response.statusCode} em $path.');
        }
        if (body.trim().isEmpty) {
          return _Esp32HttpResponse(
            path: path,
            latency: stopwatch.elapsed,
            payload: <String, dynamic>{
              'moduleId': module.id,
              'connected': true,
            },
          );
        }
        final decoded = jsonDecode(body);
        if (decoded is! Map) {
          if (path.endsWith('/status')) {
            return _Esp32HttpResponse(
              path: path,
              latency: stopwatch.elapsed,
              payload: <String, dynamic>{
                'moduleId': module.id,
                'connected': true,
                'legacyStatus': body.trim(),
              },
            );
          }
          lastError = 'Resposta não JSON em $path';
          continue;
        }
        return _Esp32HttpResponse(
          path: path,
          latency: stopwatch.elapsed,
          payload: decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      } on _Esp32TransportException {
        rethrow;
      } catch (error) {
        stopwatch.stop();
        lastError = error;
        if (preferred != null && path == preferred) break;
      }
    }
    throw _Esp32TransportException(
      lastError == null
          ? 'Nenhum endpoint de telemetria respondeu.'
          : 'Telemetria indisponível: $lastError',
    );
  }

  Duration _successDelay(Esp32Module module) => Duration(
        milliseconds: module.telemetryIntervalMs.clamp(500, 30000).toInt(),
      );

  Duration _failureDelay(Esp32Module module, int failures) {
    final baseMs = math.max(2000, module.telemetryIntervalMs).toInt();
    final exponent = math.min(math.max(0, failures - 1), 4).toInt();
    final multiplier = 1 << exponent;
    return Duration(milliseconds: math.min(30000, baseMs * multiplier).toInt());
  }

  String _friendlyError(Object error) {
    if (error is _Esp32TransportException) return error.message;
    if (error is TimeoutException) return 'Tempo limite excedido.';
    if (error is SocketException) return 'ESP32 não respondeu na rede local.';
    if (error is FormatException) return error.message;
    return error.toString();
  }
}

class _Esp32HttpResponse {
  const _Esp32HttpResponse({
    required this.path,
    required this.latency,
    required this.payload,
  });

  final String path;
  final Duration latency;
  final Map<String, dynamic> payload;
}

class _Esp32TransportException implements Exception {
  const _Esp32TransportException(this.message);
  final String message;

  @override
  String toString() => message;
}
