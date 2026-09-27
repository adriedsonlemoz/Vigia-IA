import 'dart:async';

/// Evita que uma Future de inicialização impeça a interface de abrir para
/// sempre. O trabalho pode continuar fora da rota crítica, mas o chamador
/// recebe controle novamente quando o limite expira.
class StartupGuard {
  const StartupGuard();

  Future<T?> run<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      return await operation().timeout(timeout);
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return null;
    }
  }

  Future<void> runOptional(
    Future<void> Function() operation, {
    required Duration timeout,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      await operation().timeout(timeout);
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }
}
