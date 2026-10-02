import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/alert_preferences.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/monitoring_zone.dart';
import 'package:vigiaia/models/object_filter_catalog.dart';
import 'package:vigiaia/services/detection_confidence_policy.dart';
import 'package:vigiaia/services/monitoring_zone_service.dart';

void main() {
  const box = NormalizedBox(xMin: 0.2, yMin: 0.2, xMax: 0.6, yMax: 0.8);

  test('detecção inferida nunca conta como evidência forte', () {
    const inferred = Detection(
      label: 'person',
      displayLabel: 'Possível pessoa',
      confidence: 0.95,
      box: box,
      inferred: true,
    );
    const real = Detection(
      label: 'person',
      displayLabel: 'Pessoa',
      confidence: 0.95,
      box: box,
    );

    expect(DetectionConfidencePolicy.isStrong(inferred, 0.55), isFalse);
    expect(DetectionConfidencePolicy.isStrong(real, 0.55), isTrue);
  });

  test('copyWith e remapeamento de zona preservam a marca de inferida', () {
    const inferred = Detection(
      label: 'person',
      displayLabel: 'Possível pessoa',
      confidence: 0.5,
      box: box,
      inferred: true,
    );
    expect(inferred.copyWith(confidence: 0.4).inferred, isTrue);

    const zone = MonitoringZone(xMin: 0.0, yMin: 0.0, xMax: 0.5, yMax: 0.5);
    expect(MonitoringZoneService.remapDetection(inferred, zone).inferred, isTrue);
  });

  test('nomes específicos e concordância de gênero', () {
    expect(ObjectFilterCatalog.displayNameForLabel('dog'), 'Cachorro');
    expect(ObjectFilterCatalog.displayNameForLabel('motorcycle'), 'Moto');
    expect(ObjectFilterCatalog.displayNameForLabel('bus'), 'Ônibus');
    expect(ObjectFilterCatalog.displayNameForLabel('banana'), isNull);
    expect(ObjectFilterCatalog.detectedWordForLabel('dog'), 'detectado');
    expect(ObjectFilterCatalog.detectedWordForLabel('motorcycle'), 'detectada');
    expect(ObjectFilterCatalog.detectedWordForLabel('cow'), 'detectada');
    // O grupo continua disponível para estatísticas, ícones e regras.
    expect(ObjectFilterCatalog.singularNameForLabel('dog'), 'Animal');
  });

  test('mensagens padrão mostram o nome específico do objeto', () {
    const messages = AlertMessages();
    expect(
      messages.resolve(label: 'dog', displayLabel: 'Cachorro', zoneName: 'Quintal'),
      'Cachorro detectado.',
    );
    expect(
      messages.resolve(label: 'motorcycle', displayLabel: 'Moto', zoneName: 'Garagem'),
      'Moto detectada.',
    );
    expect(
      messages.resolve(label: 'person', displayLabel: 'Pessoa', zoneName: 'Portão'),
      'Pessoa detectada.',
    );
  });

  test('textos padrão antigos migram, textos personalizados continuam', () {
    final migrated = AlertMessages.fromJson(<String, dynamic>{
      'vehicle': 'Automóvel detectado.',
      'animal': 'Animal detectado.',
    });
    expect(migrated.vehicle, AlertMessages.defaultVehicle);
    expect(migrated.animal, AlertMessages.defaultAnimal);

    final custom = AlertMessages.fromJson(<String, dynamic>{
      'vehicle': 'Atenção: veículo no portão.',
      'animal': 'Bicho no quintal!',
    });
    expect(custom.vehicle, 'Atenção: veículo no portão.');
    expect(custom.animal, 'Bicho no quintal!');
  });
}
