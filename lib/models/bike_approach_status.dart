enum BikeApproachLevel { clear, watch, warning, critical }

class BikeApproachStatus {
  const BikeApproachStatus({
    required this.level,
    required this.updatedAt,
    this.trackId,
    this.label,
    this.estimatedTtcSeconds,
    this.growthRatePerSecond = 0,
    this.confidence = 0,
    this.simulated = false,
    this.vehicleDetected = false,
  });

  factory BikeApproachStatus.clear(DateTime now) => BikeApproachStatus(
        level: BikeApproachLevel.clear,
        updatedAt: now,
      );

  final BikeApproachLevel level;
  final DateTime updatedAt;
  final int? trackId;
  final String? label;
  final double? estimatedTtcSeconds;

  /// Crescimento suavizado da escala aparente por segundo.
  /// Nao e velocidade fisica nem distancia em metros.
  final double growthRatePerSecond;
  final double confidence;
  final bool simulated;
  final bool vehicleDetected;

  bool get visible => level != BikeApproachLevel.clear;
  bool get shouldAlert =>
      level == BikeApproachLevel.warning || level == BikeApproachLevel.critical;

  String get title => switch (level) {
        BikeApproachLevel.clear => 'Sem aproximação',
        BikeApproachLevel.watch => 'Veículo se aproximando',
        BikeApproachLevel.warning => 'VEÍCULO SE APROXIMANDO',
        BikeApproachLevel.critical => 'APROXIMAÇÃO RÁPIDA',
      };

  String get ttcLabel {
    final ttc = estimatedTtcSeconds;
    if (ttc == null || !ttc.isFinite) return 'TTC estimado indisponível';
    return 'TTC ~${ttc.toStringAsFixed(ttc < 3 ? 1 : 0)} s';
  }
}
