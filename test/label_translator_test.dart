import 'package:vigiaia/services/label_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('traduz rotulos comuns para pt-BR', () {
    expect(LabelTranslator.ptBr('person'), 'pessoa');
    expect(LabelTranslator.ptBr('cell phone'), 'celular');
  });

  test('mantem rotulo desconhecido', () {
    expect(LabelTranslator.ptBr('custom object'), 'custom object');
  });
}
