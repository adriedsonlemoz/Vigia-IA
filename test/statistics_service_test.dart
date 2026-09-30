import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/monitor_event.dart';
import 'package:vigiaia/services/statistics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const box = NormalizedBox(yMin: 0, xMin: 0, yMax: 1, xMax: 1);

  MonitorEvent event(String id, String label, String displayLabel) => MonitorEvent(
        id: id,
        createdAt: DateTime.now(),
        label: label,
        displayLabel: displayLabel,
        confidence: 0.8,
        source: 'Câmera 1',
        box: box,
      );

  test('estatísticas expõem somente Pessoa, Automóvel e Animal', () {
    final stats = const StatisticsService().calculate(<MonitorEvent>[
      event('1', 'person', 'Pessoa'),
      event('2', 'car', 'Carro'),
      event('3', 'motorcycle', 'Moto'),
      event('4', 'dog', 'Cachorro'),
      event('5', 'banana', 'Banana'),
      event('6', 'chair', 'Cadeira'),
    ]);

    expect(stats.total, 4);
    expect(stats.byObject, <String, int>{
      'Automóvel': 2,
      'Pessoa': 1,
      'Animal': 1,
    });
    expect(stats.byObject.containsKey('Banana'), isFalse);
    expect(stats.byObject.containsKey('Cadeira'), isFalse);
  });
}
