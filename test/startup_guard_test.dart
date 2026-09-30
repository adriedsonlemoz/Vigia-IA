import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/startup_guard.dart';

void main() {
  const guard = StartupGuard();

  test('devolve o resultado quando a inicialização termina', () async {
    final value = await guard.run<int>(
      () async => 42,
      timeout: const Duration(milliseconds: 50),
    );

    expect(value, 42);
  });

  test('libera o startup quando uma inicialização não responde', () async {
    final never = Completer<int>();
    Object? capturedError;

    final value = await guard.run<int>(
      () => never.future,
      timeout: const Duration(milliseconds: 5),
      onError: (error, _) => capturedError = error,
    );

    expect(value, isNull);
    expect(capturedError, isA<TimeoutException>());
  });

  test('serviço opcional não propaga exceção para a abertura', () async {
    await guard.runOptional(
      () async => throw StateError('indisponível'),
      timeout: const Duration(milliseconds: 50),
    );
  });
}
