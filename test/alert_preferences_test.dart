import 'package:vigiaia/models/alert_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migra voiceEnabled legado sem alterar outras saídas', () {
    final outputs = AlertOutputs.fromJson(const <String, dynamic>{}, legacyVoice: false);

    expect(outputs.voice, isFalse);
    expect(outputs.sound, isFalse);
    expect(outputs.vibration, isTrue);
    expect(outputs.androidNotification, isTrue);
  });

  test('frase específica de objeto e área tem precedência', () {
    const messages = AlertMessages(
      person: 'Pessoa geral.',
      byObjectAndArea: <String, String>{
        'person|Portão': 'Pessoa no {area}.',
        'vehicle|*': '{objeto} em qualquer área.',
      },
    );

    expect(
      messages.resolve(label: 'person', displayLabel: 'Pessoa', zoneName: 'Portão'),
      'Pessoa no Portão.',
    );
    expect(
      messages.resolve(label: 'car', displayLabel: 'Automóvel', zoneName: 'Garagem'),
      'Automóvel em qualquer área.',
    );
  });

  test('entrada e saída usam mensagens próprias', () {
    const messages = AlertMessages(
      entered: '{objeto} entrou em {area}.',
      exited: '{objeto} saiu de {area}.',
    );

    expect(
      messages.resolve(label: 'dog', displayLabel: 'Animal', zoneName: 'Quintal', event: 'entered'),
      'Animal entrou em Quintal.',
    );
    expect(
      messages.resolve(label: 'dog', displayLabel: 'Animal', zoneName: 'Quintal', event: 'exited'),
      'Animal saiu de Quintal.',
    );
  });

  test('preferencias de voz persistem slots silenciados e politica de TTS', () {
    const prefs = VoiceAlertPreferences(
      mutedSlots: <String>{'person_detected', 'bike_sensor_disconnected'},
      ttsFallbackEnabled: true,
      dynamicTtsEnabled: false,
    );
    final restored = VoiceAlertPreferences.fromJson(prefs.toJson());
    expect(restored.allowsSlot('person_detected'), isFalse);
    expect(restored.allowsSlot('vehicle_detected'), isTrue);
    expect(restored.ttsFallbackEnabled, isTrue);
    expect(restored.dynamicTtsEnabled, isFalse);
  });

}
