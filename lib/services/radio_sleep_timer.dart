import 'dart:async';

import 'map_radio_service.dart';

/// Temporizador de reprodução válido enquanto o processo do app permanecer vivo.
/// Não agenda alarmes no Android nem mantém o app acordado em segundo plano.
class RadioSleepTimer {
  RadioSleepTimer._();
  static Timer? _timer;
  static DateTime? _end;

  static DateTime? get endAt => _timer?.isActive == true ? _end : null;

  static void schedule(Duration duration) {
    cancel();
    if (duration <= Duration.zero) { return; }
    _end = DateTime.now().add(duration);
    _timer = Timer(duration, () {
      _timer = null;
      _end = null;
      unawaited(_stopSafely());
    });
  }

  static Future<void> _stopSafely() async {
    try {
      await MapRadioService.stop();
    } catch (_) {
      // O temporizador nunca deve derrubar o processo por erro no player nativo.
    }
  }

  static void cancel() {
    _timer?.cancel();
    _timer = null;
    _end = null;
  }
}
