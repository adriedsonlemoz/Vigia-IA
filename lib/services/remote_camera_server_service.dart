import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../models/alert_preferences.dart';
import '../models/bike_mode_config.dart';
import '../models/device_telemetry.dart';
import '../models/rgb_frame.dart';
import 'background_monitor_service.dart';
import 'bike_mode_service.dart';
import 'native_platform_service.dart';
import '../sources/local_camera_source.dart';

class RemoteCameraServerService extends ChangeNotifier {
  RemoteCameraServerService._() {
    _bikeMode.addListener(_onBikeModeChanged);
  }

  static final RemoteCameraServerService instance = RemoteCameraServerService._();

  final BikeModeService _bikeMode = BikeModeService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  LocalCameraSource? _source;
  StreamSubscription<RgbFrame>? _subscription;
  HttpServer? _server;
  Uint8List? _latestJpeg;
  DateTime? _latestJpegCapturedAt;
  int _latestJpegSequence = 0;
  DateTime? _lastFrameAt;
  DateTime? _lastFpsFrameAt;
  DateTime? _lastNotificationUpdateAt;
  double _streamFps = 0;
  String _accessKey = '';
  int _port = 8765;
  String? _address;
  String? _error;
  bool _starting = false;
  bool _bikePolicyChangeInProgress = false;
  BikeModeConfig _bikeConfig = const BikeModeConfig();
  DeviceTelemetrySnapshot? _deviceTelemetry;
  Timer? _bikeTelemetryTimer;
  bool _bikeLowBatteryAlerted = false;

  bool get running => _server != null && _source != null;
  bool get starting => _starting;
  String? get address => _address;
  String get accessKey => _accessKey;
  String? get error => _error;
  DateTime? get lastFrameAt => _lastFrameAt;
  int get port => _port;
  bool get bikeModeEnabled => _bikeConfig.enabled;
  String get bikePowerProfileLabel => _bikeConfig.powerProfile.label;

  Widget buildPreview() => _source?.buildPreview() ?? const SizedBox.expand();

  Future<void> start({int port = 8765}) async {
    if (running || _starting) return;
    _starting = true;
    _error = null;
    _port = port.clamp(1024, 65535).toInt();
    notifyListeners();
    try {
      _bikeConfig = await _bikeMode.initialize();
      final foregroundStarted = await BackgroundMonitorService.acquire(
        owner: BackgroundMonitorService.cameraModeOwner,
        usesCamera: true,
        statusText: 'Modo Câmera ativo • preparando transmissão local.',
      );
      if (!foregroundStarted) {
        throw StateError('O Android não permitiu iniciar o serviço de câmera em primeiro plano.');
      }
      _accessKey = _generateKey();
      final source = LocalCameraSource(
        analysisInterval: _bikeConfig.effectiveAnalysisInterval(
          const Duration(milliseconds: 400),
        ),
      );
      _source = source;
      _subscription = source.frames.listen(_onFrame);
      await source.start();
      await _native.setBikeScreenBrightness(_bikeConfig.rearScreenBrightness);
      final server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      _server = server;
      _configureBikeTelemetryTimer();
      _address = await _findLocalAddress();
      unawaited(_serve(server));
    } catch (error) {
      _error = 'Não foi possível iniciar o modo Câmera: $error';
      await stop();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  void _onBikeModeChanged() {
    if (_bikePolicyChangeInProgress) return;
    unawaited(_applyBikeModeChange());
  }

  Future<void> _applyBikeModeChange() async {
    if (_bikePolicyChangeInProgress) return;
    _bikePolicyChangeInProgress = true;
    try {
      final previous = _bikeConfig;
      final next = _bikeMode.config;
      final previousInterval = previous.effectiveAnalysisInterval(
        const Duration(milliseconds: 400),
      );
      final nextInterval = next.effectiveAnalysisInterval(
        const Duration(milliseconds: 400),
      );
      _bikeConfig = next;
      if (running) {
        await _native.setBikeScreenBrightness(next.rearScreenBrightness);
        _configureBikeTelemetryTimer();
        if (previousInterval != nextInterval) await _restartCameraSource();
      }
      notifyListeners();
    } finally {
      _bikePolicyChangeInProgress = false;
    }
  }

  void _configureBikeTelemetryTimer() {
    _bikeTelemetryTimer?.cancel();
    _bikeTelemetryTimer = null;
    if (!running) {
      _deviceTelemetry = null;
      return;
    }
    unawaited(_refreshBikeTelemetry());
    final interval = _bikeConfig.enabled
        ? _bikeConfig.powerProfile.telemetryInterval
        : const Duration(seconds: 2);
    _bikeTelemetryTimer = Timer.periodic(
      interval,
      (_) => unawaited(_refreshBikeTelemetry()),
    );
  }

  Future<void> _refreshBikeTelemetry() async {
    if (!running) return;
    final telemetry = await _native.readDeviceTelemetry();
    if (!_bikeConfig.enabled || _bikeConfig.keepRemoteTelemetry) {
      _deviceTelemetry = telemetry;
    } else {
      _deviceTelemetry = null;
    }
    if (!_bikeConfig.enabled) return;
    final battery = telemetry.batteryPercent;
    if (battery == null || !_bikeConfig.alertLowBattery) return;
    if (battery > _bikeConfig.lowBatteryPercent + 3) {
      _bikeLowBatteryAlerted = false;
      return;
    }
    if (battery <= _bikeConfig.lowBatteryPercent && !_bikeLowBatteryAlerted) {
      _bikeLowBatteryAlerted = true;
      unawaited(
        _native.showAlertNotification(
          title: 'Modo Bike • bateria baixa',
          message: 'Celular traseiro em $battery%. Verifique a alimentação.',
          outputs: const AlertOutputs(
            voice: false,
            sound: false,
            vibration: false,
            androidNotification: true,
          ),
        ),
      );
    }
  }

  Future<void> _restartCameraSource() async {
    final oldSource = _source;
    await _subscription?.cancel();
    _subscription = null;
    _source = null;
    try {
      await oldSource?.dispose();
    } catch (_) {}
    if (_server == null) return;
    final source = LocalCameraSource(
      analysisInterval: _bikeConfig.effectiveAnalysisInterval(
        const Duration(milliseconds: 400),
      ),
    );
    _source = source;
    _subscription = source.frames.listen(_onFrame);
    await source.start();
  }

  Future<void> _onFrame(RgbFrame frame) async {
    final previousFrameAt = _lastFpsFrameAt;
    if (previousFrameAt != null) {
      final elapsedMs = frame.capturedAt.difference(previousFrameAt).inMilliseconds;
      if (elapsedMs > 0) {
        final instant = 1000 / elapsedMs;
        _streamFps = _streamFps == 0
            ? instant
            : (_streamFps * 0.75 + instant * 0.25);
      }
    }
    _lastFpsFrameAt = frame.capturedAt;
    _lastFrameAt = frame.capturedAt;
    final lastUpdate = _lastNotificationUpdateAt;
    if (lastUpdate == null ||
        frame.capturedAt.difference(lastUpdate) >= const Duration(seconds: 5)) {
      _lastNotificationUpdateAt = frame.capturedAt;
      unawaited(
        BackgroundMonitorService.updateStatus(
          'Modo Câmera ativo • transmissão local recebendo imagens.',
        ),
      );
    }
    try {
      _latestJpeg = await compute<Map<String, Object>, Uint8List>(
        _encodeJpeg,
        <String, Object>{
          'width': frame.width,
          'height': frame.height,
          'bytes': Uint8List.fromList(frame.rgbBytes),
          'maxWidth': _bikeConfig.enabled ? _bikeConfig.powerProfile.targetJpegWidth : 960,
          'quality': _bikeConfig.enabled ? _bikeConfig.powerProfile.targetJpegQuality : 78,
        },
      );
      _latestJpegCapturedAt = frame.capturedAt;
      _latestJpegSequence++;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        final key = request.uri.queryParameters['key'] ?? request.headers.value('x-monitor-key');
        if (key != _accessKey) {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..write('unauthorized');
          await request.response.close();
          continue;
        }
        final path = request.uri.path;
        if (path == '/status') {
          // Bateria e estado do transmissor são dados operacionais essenciais.
          // Mesmo no perfil econômico, /status os mantém disponíveis ao receptor.
          final telemetry =
              _deviceTelemetry ?? await _native.readDeviceTelemetry();
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, Object?>{
            'online': running,
            'lastFrameAt': _lastFrameAt?.toIso8601String(),
            'frameSequence': _latestJpegSequence,
            'fps': _streamFps,
            'bikeMode': _bikeConfig.enabled,
            'bikeProfile': _bikeConfig.enabled ? _bikeConfig.powerProfile.name : null,
            'alertLowBattery': _bikeConfig.alertLowBattery,
            'lowBatteryPercent': _bikeConfig.lowBatteryPercent,
            'device': telemetry.toJson(),
            'name': 'Vigia IA - câmera remota',
          }));
        } else if (path == '/frame.jpg') {
          final jpeg = _latestJpeg;
          final afterSequence = int.tryParse(
            request.uri.queryParameters['after'] ?? '',
          );
          if (jpeg == null) {
            request.response.statusCode = HttpStatus.serviceUnavailable;
            request.response.write('frame unavailable');
          } else if (afterSequence != null &&
              afterSequence >= _latestJpegSequence) {
            request.response
              ..statusCode = HttpStatus.noContent
              ..headers.set(HttpHeaders.cacheControlHeader, 'no-store, max-age=0')
              ..headers.set(
                'x-vigia-frame-sequence',
                _latestJpegSequence.toString(),
              );
          } else {
            request.response.headers.contentType = ContentType('image', 'jpeg');
            request.response.headers
              ..set(HttpHeaders.cacheControlHeader, 'no-store, max-age=0')
              ..set(HttpHeaders.pragmaHeader, 'no-cache')
              ..set('x-vigia-frame-sequence', _latestJpegSequence.toString());
            final capturedAt = _latestJpegCapturedAt;
            if (capturedAt != null) {
              request.response.headers.set(
                'x-vigia-frame-captured-at',
                capturedAt.toUtc().toIso8601String(),
              );
            }
            request.response.add(jpeg);
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('not found');
        }
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
      } finally {
        await request.response.close();
      }
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _source?.dispose();
    } catch (_) {}
    _source = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _bikeTelemetryTimer?.cancel();
    _bikeTelemetryTimer = null;
    _deviceTelemetry = null;
    _latestJpeg = null;
    _latestJpegCapturedAt = null;
    _latestJpegSequence = 0;
    _lastFrameAt = null;
    _lastFpsFrameAt = null;
    _streamFps = 0;
    _lastNotificationUpdateAt = null;
    _address = null;
    _accessKey = '';
    await _native.setBikeScreenBrightness(null);
    await BackgroundMonitorService.release(BackgroundMonitorService.cameraModeOwner);
    notifyListeners();
  }

  Future<String?> _findLocalAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    String? bestAddress;
    var bestScore = -1000;
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final value = address.address;
        if (address.isLoopback || value.startsWith('169.254.')) continue;
        final score = _addressScore(interface.name, value);
        if (bestAddress == null || score > bestScore) {
          bestAddress = value;
          bestScore = score;
        }
      }
    }
    return bestAddress == null ? null : 'http://$bestAddress:$_port';
  }

  int _addressScore(String interfaceName, String value) {
    final name = interfaceName.toLowerCase();
    var score = _isPrivateIpv4(value) ? 40 : 0;
    if (value.startsWith('192.168.')) score += 3;
    if (value.startsWith('172.')) score += 2;
    if (value.startsWith('10.')) score += 1;
    if (name.contains('wlan') || name.contains('wifi') || name.startsWith('ap')) {
      score += 30;
    }
    if (name.contains('tun') || name.contains('vpn')) score -= 40;
    if (name.contains('rmnet') || name.contains('ccmni')) score -= 20;
    return score;
  }

  bool _isPrivateIpv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList(growable: false);
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  String _generateKey() {
    final random = Random.secure();
    return List<String>.generate(12, (_) => random.nextInt(36).toRadixString(36)).join().toUpperCase();
  }
}

Uint8List _encodeJpeg(Map<String, Object> data) {
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
  final maxWidth = data['maxWidth']! as int;
  final quality = data['quality']! as int;
  if (image.width > maxWidth) image = img.copyResize(image, width: maxWidth);
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}
