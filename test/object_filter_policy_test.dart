import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/object_filter_catalog.dart';
import 'package:vigiaia/services/object_filter_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const box = NormalizedBox(yMin: 0, xMin: 0, yMax: 1, xMax: 1);

  test('mantém somente os três grupos visuais e normaliza os nomes', () {
    const detections = <Detection>[
      Detection(label: 'person', displayLabel: 'pessoa', confidence: 0.9, box: box),
      Detection(label: 'bed', displayLabel: 'cama', confidence: 0.8, box: box),
      Detection(label: 'car', displayLabel: 'carro', confidence: 0.7, box: box),
      Detection(label: 'dog', displayLabel: 'cachorro', confidence: 0.75, box: box),
    ];

    final result = ObjectFilterPolicy.apply(
      detections,
      const <String>{'person', 'car', 'dog'},
    );

    expect(result.map((item) => item.label), <String>['person', 'car', 'dog']);
    expect(result.map((item) => item.displayLabel), <String>['Pessoa', 'Automóvel', 'Animal']);
  });

  test('seleção antiga de uma classe migra para o grupo correspondente', () {
    expect(
      ObjectFilterCatalog.normalizeSelection(const <String>{'car'}),
      ObjectFilterCatalog.automobiles,
    );
    expect(
      ObjectFilterCatalog.normalizeSelection(const <String>{'dog'}),
      ObjectFilterCatalog.animals,
    );
  });

  test('classes antigas ocultas não voltam para a interface', () {
    expect(ObjectFilterCatalog.groupKeyForLabel('banana'), isNull);
    expect(ObjectFilterCatalog.groupKeyForLabel('chair'), isNull);
    expect(ObjectFilterCatalog.groupKeyForLabel('fork'), isNull);
  });

  test('seleção vazia não libera detecções', () {
    const detections = <Detection>[
      Detection(label: 'person', displayLabel: 'pessoa', confidence: 0.9, box: box),
    ];

    expect(ObjectFilterPolicy.apply(detections, const <String>{}), isEmpty);
  });
}
