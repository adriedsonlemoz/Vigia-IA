import '../models/alert_preferences.dart';
import 'map_voice_service.dart';
import 'native_platform_service.dart';

class AlertDeliveryService {
  AlertDeliveryService({MapVoiceService? voice})
      : _voice = voice ?? MapVoiceService.instance;

  final MapVoiceService _voice;
  final NativePlatformService _native = NativePlatformService.instance;
  AlertOutputs _outputs = const AlertOutputs();

  Future<void> initialize(AlertOutputs outputs) async {
    _outputs = outputs;
    await _voice.initialize();
  }

  void updateOutputs(AlertOutputs outputs) {
    _outputs = outputs;
  }

  Future<void> deliver(String message, {String title = 'Vigia IA'}) async {
    final text = message.trim();
    if (text.isEmpty) return;
    if (_outputs.voice) await _voice.deliver(text);
    if (_outputs.androidNotification) {
      await _native.showAlertNotification(
        title: title,
        message: text,
        outputs: _outputs,
      );
    }
  }

  /// A voz do mapa é compartilhada e vive durante toda a sessão do app.
  Future<void> dispose() => Future<void>.value();
}
