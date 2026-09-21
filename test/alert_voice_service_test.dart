import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/alert_voice_service.dart';
import 'package:vigiaia/services/performance_telemetry_service.dart';
import 'package:vigiaia/services/speech_service.dart';

class FakeSpeech extends SpeechService {
  final List<String> spoken = [];
  bool on = true;
  @override bool get enabled => on;
  @override bool get languageInstalled => true;
  @override void setEnabled(bool value) { on = value; }
  @override Future<void> stop() async {}
  @override Future<void> speakMessage(String text, {SpeechPriority priority = SpeechPriority.normal}) async { spoken.add(text); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('falha assíncrona do arquivo aciona TTS e sucesso evita duplicação', () async {
    final speech = FakeSpeech();
    final completion = Completer<bool>();
    final service = AlertVoiceService(speech: speech,
        playAudio: (_, priority, capturedAt) => completion.future, stopAudio: () async {});
    final delivery = service.deliver('Pessoa detectada', audioSlot: 'person_detected');
    expect(speech.spoken, isEmpty);
    completion.complete(false);
    await delivery;
    expect(speech.spoken, ['Pessoa detectada']);
    final success = AlertVoiceService(speech: speech,
        playAudio: (_, priority, capturedAt) async => true, stopAudio: () async {});
    await success.deliver('Não duplicar', audioSlot: 'person_detected');
    expect(speech.spoken, hasLength(1));
  });

  test('desativar voz durante preparação cancela fallback pendente', () async {
    final speech = FakeSpeech();
    final completion = Completer<bool>();
    final service = AlertVoiceService(speech: speech,
        playAudio: (_, priority, capturedAt) => completion.future, stopAudio: () async {});
    final delivery = service.deliver('Alerta antigo', audioSlot: 'person_detected');
    service.setEnabled(false);
    completion.complete(false);
    await delivery;
    await Future<void>.delayed(Duration.zero);
    expect(speech.spoken, isEmpty);
  });

  test('durante reprodução mantém somente o próximo alerta mais recente', () async {
    final slots = <String>[];
    final first = Completer<bool>();
    final service = AlertVoiceService(speech: FakeSpeech(), stopAudio: () async {},
      playAudio: (slot, priority, capturedAt) {
        slots.add(slot);
        return slots.length == 1 ? first.future : Future.value(true);
      });
    final a = service.deliver('A', audioSlot: 'a');
    final b = service.deliver('B', audioSlot: 'b');
    final c = service.deliver('C', audioSlot: 'c');
    first.complete(true);
    await Future.wait([a, b, c]);
    expect(slots, ['a', 'c']);
  });

  test('alta prioridade interrompe a antiga e protege contra alerta normal', () async {
    final speech = FakeSpeech();
    final first = Completer<bool>();
    final urgent = Completer<bool>();
    final slots = <String>[];
    final service = AlertVoiceService(speech: speech, stopAudio: () async {},
      playAudio: (slot, priority, capturedAt) {
        slots.add(slot);
        return slot == 'a' ? first.future : urgent.future;
      });
    final a = service.deliver('A', audioSlot: 'a');
    final b = service.deliver('Urgente', audioSlot: 'urgent', priority: SpeechPriority.high);
    await service.deliver('Normal', audioSlot: 'normal');
    await Future<void>.delayed(Duration.zero);
    first.complete(false);
    urgent.complete(true);
    await Future.wait([a, b]);
    expect(slots, ['a', 'urgent']);
    expect(speech.spoken, isEmpty);
  });

  test('descarta fala de quadro velho antes de tocar', () async {
    final slots = <String>[];
    final service = AlertVoiceService(speech: FakeSpeech(), stopAudio: () async {},
      playAudio: (slot, priority, capturedAt) async { slots.add(slot); return true; });
    await service.deliver('Antigo', audioSlot: 'old',
        capturedAt: DateTime.now().subtract(const Duration(seconds: 20)));
    expect(slots, isEmpty);
  });

  test('falha nativa registra código, etapa e fallback na telemetria', () async {
    PerformanceTelemetryService.instance.resetSession();
    final service = AlertVoiceService(
      speech: FakeSpeech(),
      stopAudio: () async {},
      playAudio: (_, priority, capturedAt) async => false,
      audioDiagnostics: () async => const <String, Object?>{
        'state': 'failed',
        'lastErrorCode': 'MEDIA_ERROR_UNSUPPORTED',
        'lastError': 'MEDIA_ERROR_UNKNOWN / MEDIA_ERROR_UNSUPPORTED',
        'lastErrorPhase': 'prepare_async',
        'lastSource': 'override',
        'lastFocusResultName': 'GRANTED',
        'mediaVolume': 8,
        'mediaMaxVolume': 15,
        'mediaMuted': false,
      },
    );

    await service.deliver('Pessoa detectada', audioSlot: 'person_detected');
    final event = PerformanceTelemetryService.instance
        .createReport()
        .alertEvents
        .firstWhere((item) => item['event'] == 'native_failed_tts_requested');
    expect(event['audioErrorCode'], 'MEDIA_ERROR_UNSUPPORTED');
    expect(event['audioErrorPhase'], 'prepare_async');
    expect(event['audioSource'], 'override');
  });
}
