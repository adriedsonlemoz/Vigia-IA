/// Mantém um único stream ativo apenas quando há demanda concreta.
/// Gravação e navegação são exceções à suspensão em segundo plano;
/// ainda assim dependem das permissões e restrições de Android.
class MapLocationSubscriptionPolicy {
  const MapLocationSubscriptionPolicy._();

  static bool keepStream({
    required bool hasConsumer,
    required bool recording,
    required bool navigating,
    required bool appForeground,
  }) => recording || navigating || (hasConsumer && appForeground);

  static bool needsOneShotFix({
    required bool streamActive,
    required bool keepStream,
  }) => !streamActive && !keepStream;
}
