import 'package:vigiaia/services/error_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ErrorLogEntry preserva dados ao serializar', () {
    final original = ErrorLogEntry(
      id: '1',
      timestamp: DateTime.utc(2026, 9, 15, 21),
      level: ErrorLogLevel.warning,
      source: 'Camera',
      message: 'Falha de teste',
      details: 'stack',
      context: const <String, String>{'fonte': 'localCamera'},
    );

    final restored = ErrorLogEntry.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.level, ErrorLogLevel.warning);
    expect(restored.source, 'Camera');
    expect(restored.message, 'Falha de teste');
    expect(restored.details, 'stack');
    expect(restored.context['fonte'], 'localCamera');
  });
}
