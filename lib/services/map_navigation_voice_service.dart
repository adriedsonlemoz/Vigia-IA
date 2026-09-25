import 'map_navigation_guidance.dart';
import 'map_navigation_voice_policy.dart';
import 'map_voice_service.dart';
import 'speech_service.dart';

/// Orquestra a voz da navegação sem misturar TTS com cálculo de rota.
class MapNavigationVoiceService {
  MapNavigationVoiceService({MapVoiceService? voice})
      : _voice = voice ?? MapVoiceService.instance;

  final MapVoiceService _voice;
  final MapNavigationVoicePolicy _policy = MapNavigationVoicePolicy();

  Future<void> initialize() => _voice.initialize();

  void resetRoute() => _policy.reset();

  Future<void> handleProgress(MapNavigationProgress? progress) async {
    final announcement = _policy.evaluate(progress);
    if (announcement == null) return;
    await _voice.deliver(
      announcement.text,
      priority: announcement.highPriority
          ? SpeechPriority.high
          : SpeechPriority.normal,
    );
  }

  Future<void> announceOffRouteAndRecalculation() => _voice.deliver(
        'Você saiu da rota. Recalculando o caminho.',
        priority: SpeechPriority.high,
      );

  Future<void> announceRecalculated(MapNavigationProgress? progress) async {
    _policy.resetManeuver();
    await _voice.deliver(
      'Rota recalculada.',
      priority: SpeechPriority.high,
    );
    await handleProgress(progress);
  }
}
