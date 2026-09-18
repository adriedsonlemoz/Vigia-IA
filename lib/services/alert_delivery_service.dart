import '../models/alert_preferences.dart';
import 'native_platform_service.dart';
import 'speech_service.dart';

class AlertDeliveryService {
  AlertDeliveryService({SpeechService? speech}) : _speech = speech ?? SpeechService();

  final SpeechService _speech;
  final NativePlatformService _native = NativePlatformService.instance;
  AlertOutputs _outputs = const AlertOutputs();

  Future<void> initialize(AlertOutputs outputs) async {
    _outputs = outputs;
    await _speech.initialize();
    _speech.setEnabled(outputs.voice);
  }

  void updateOutputs(AlertOutputs outputs) {
    _outputs = outputs;
    _speech.setEnabled(outputs.voice);
  }

  Future<void> deliver(String message, {String title = 'Vigia IA'}) async {
    final text = message.trim();
    if (text.isEmpty) return;
    if (_outputs.voice) await _speech.speakMessage(text);
    if (_outputs.androidNotification) {
      await _native.showAlertNotification(title: title, message: text, outputs: _outputs);
    }
  }

  Future<void> dispose() => _speech.dispose();
}
