import 'device_telemetry.dart';
import 'remote_phone_status.dart';

class SessionStatusData {
  const SessionStatusData({
    required this.sampledAt,
    required this.imageSource,
    required this.aiDevice,
    required this.sourceConnection,
    required this.sourceOnline,
    required this.receivedFps,
    required this.analyzedFps,
    required this.framesReceived,
    required this.framesAnalyzed,
    required this.framesDropped,
    this.frameWidth,
    this.frameHeight,
    this.analysisWidth,
    this.analysisHeight,
    this.inferenceMs,
    this.frameDelayMs,
    this.networkLatencyMs,
    this.localDevice,
    this.remotePhone,
  });

  final DateTime sampledAt;
  final String imageSource;
  final String aiDevice;
  final String sourceConnection;
  final bool sourceOnline;
  final double receivedFps;
  final double analyzedFps;
  final int framesReceived;
  final int framesAnalyzed;
  final int framesDropped;
  final int? frameWidth;
  final int? frameHeight;
  final int? analysisWidth;
  final int? analysisHeight;
  final double? inferenceMs;
  final int? frameDelayMs;
  final int? networkLatencyMs;
  final DeviceTelemetrySnapshot? localDevice;
  final RemotePhoneStatus? remotePhone;

  String get frameResolution => frameWidth == null || frameHeight == null
      ? '—'
      : '$frameWidth×$frameHeight';

  String get analysisResolution => analysisWidth == null || analysisHeight == null
      ? '—'
      : '$analysisWidth×$analysisHeight';

  String get compactVideoSummary {
    final received = receivedFps > 0 ? receivedFps.toStringAsFixed(1) : '0,0';
    final analyzed = analyzedFps > 0 ? analyzedFps.toStringAsFixed(1) : '0,0';
    final delay = frameDelayMs == null ? 'atraso —' : 'atraso $frameDelayMs ms';
    return '$frameResolution • $received FPS recebidos • $analyzed FPS analisados • $delay';
  }
}
