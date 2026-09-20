enum BikePowerProfile { normal, economy, extremeEconomy }


enum BikeSimulationScenario {
  normal,
  frontTireLow,
  rearTireLow,
  sensorBatteryLow,
  disconnected,
}

extension BikeSimulationScenarioUi on BikeSimulationScenario {
  String get label => switch (this) {
        BikeSimulationScenario.normal => 'Normal',
        BikeSimulationScenario.frontTireLow => 'Pneu dianteiro baixo',
        BikeSimulationScenario.rearTireLow => 'Pneu traseiro baixo',
        BikeSimulationScenario.sensorBatteryLow => 'Bateria dos sensores baixa',
        BikeSimulationScenario.disconnected => 'Sensores desconectados',
      };

  String get description => switch (this) {
        BikeSimulationScenario.normal =>
          'Velocidade e pressões normais para conferir o HUD discreto.',
        BikeSimulationScenario.frontTireLow =>
          'Força pressão crítica no pneu dianteiro e exibe alerta no vídeo.',
        BikeSimulationScenario.rearTireLow =>
          'Força pressão crítica no pneu traseiro e exibe alerta no vídeo.',
        BikeSimulationScenario.sensorBatteryLow =>
          'Simula bateria baixa na futura central/sensores da bike.',
        BikeSimulationScenario.disconnected =>
          'Simula perda de comunicação com os sensores.',
      };
}

extension BikePowerProfileUi on BikePowerProfile {
  String get label => switch (this) {
        BikePowerProfile.normal => 'Normal',
        BikePowerProfile.economy => 'Economia',
        BikePowerProfile.extremeEconomy => 'Economia extrema',
      };

  String get description => switch (this) {
        BikePowerProfile.normal =>
          'Prioriza resposta da IA e imagem mais fluida, com economia leve.',
        BikePowerProfile.economy =>
          'Equilibra detecção, transmissão e autonomia para pedais longos.',
        BikePowerProfile.extremeEconomy =>
          'Reduz atividade visual e frequência de atualização para preservar bateria.',
      };

  int get targetAnalysisIntervalMs => switch (this) {
        BikePowerProfile.normal => 400,
        BikePowerProfile.economy => 650,
        BikePowerProfile.extremeEconomy => 1000,
      };

  int get targetStreamFps => switch (this) {
        BikePowerProfile.normal => 10,
        BikePowerProfile.economy => 6,
        BikePowerProfile.extremeEconomy => 3,
      };

  Duration get telemetryInterval => switch (this) {
        BikePowerProfile.normal => const Duration(seconds: 4),
        BikePowerProfile.economy => const Duration(seconds: 6),
        BikePowerProfile.extremeEconomy => const Duration(seconds: 10),
      };

  int get targetJpegWidth => switch (this) {
        BikePowerProfile.normal => 960,
        BikePowerProfile.economy => 720,
        BikePowerProfile.extremeEconomy => 540,
      };

  int get targetJpegQuality => switch (this) {
        BikePowerProfile.normal => 76,
        BikePowerProfile.economy => 68,
        BikePowerProfile.extremeEconomy => 58,
      };
}

class BikeModeConfig {
  const BikeModeConfig({
    this.enabled = false,
    this.powerProfile = BikePowerProfile.economy,
    this.dimRearScreen = true,
    this.keepRemoteTelemetry = true,
    this.alertLowBattery = true,
    this.lowBatteryPercent = 20,
    this.sensorSimulationEnabled = false,
    this.simulationScenario = BikeSimulationScenario.normal,
  });

  final bool enabled;
  final BikePowerProfile powerProfile;
  final bool dimRearScreen;
  final bool keepRemoteTelemetry;
  final bool alertLowBattery;
  final int lowBatteryPercent;
  final bool sensorSimulationEnabled;
  final BikeSimulationScenario simulationScenario;

  Duration effectiveAnalysisInterval(Duration configured) {
    if (!enabled) return configured;
    final target = Duration(milliseconds: powerProfile.targetAnalysisIntervalMs);
    return configured >= target ? configured : target;
  }

  int? get streamFpsCap => enabled ? powerProfile.targetStreamFps : null;

  double? get rearScreenBrightness {
    if (!enabled || !dimRearScreen) return null;
    return switch (powerProfile) {
      BikePowerProfile.normal => 0.08,
      BikePowerProfile.economy => 0.035,
      BikePowerProfile.extremeEconomy => 0.01,
    };
  }

  BikeModeConfig copyWith({
    bool? enabled,
    BikePowerProfile? powerProfile,
    bool? dimRearScreen,
    bool? keepRemoteTelemetry,
    bool? alertLowBattery,
    int? lowBatteryPercent,
    bool? sensorSimulationEnabled,
    BikeSimulationScenario? simulationScenario,
  }) =>
      BikeModeConfig(
        enabled: enabled ?? this.enabled,
        powerProfile: powerProfile ?? this.powerProfile,
        dimRearScreen: dimRearScreen ?? this.dimRearScreen,
        keepRemoteTelemetry: keepRemoteTelemetry ?? this.keepRemoteTelemetry,
        alertLowBattery: alertLowBattery ?? this.alertLowBattery,
        lowBatteryPercent: (lowBatteryPercent ?? this.lowBatteryPercent).clamp(5, 50).toInt(),
        sensorSimulationEnabled: sensorSimulationEnabled ?? this.sensorSimulationEnabled,
        simulationScenario: simulationScenario ?? this.simulationScenario,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'powerProfile': powerProfile.name,
        'dimRearScreen': dimRearScreen,
        'keepRemoteTelemetry': keepRemoteTelemetry,
        'alertLowBattery': alertLowBattery,
        'lowBatteryPercent': lowBatteryPercent,
        'sensorSimulationEnabled': sensorSimulationEnabled,
        'simulationScenario': simulationScenario.name,
      };

  factory BikeModeConfig.fromJson(Map<String, dynamic> json) {
    final profileName = json['powerProfile'] as String?;
    final profile = BikePowerProfile.values.firstWhere(
      (item) => item.name == profileName,
      orElse: () => BikePowerProfile.economy,
    );
    final scenarioName = json['simulationScenario'] as String?;
    final scenario = BikeSimulationScenario.values.firstWhere(
      (item) => item.name == scenarioName,
      orElse: () => BikeSimulationScenario.normal,
    );
    return BikeModeConfig(
      enabled: json['enabled'] as bool? ?? false,
      powerProfile: profile,
      dimRearScreen: json['dimRearScreen'] as bool? ?? true,
      keepRemoteTelemetry: json['keepRemoteTelemetry'] as bool? ?? true,
      alertLowBattery: json['alertLowBattery'] as bool? ?? true,
      lowBatteryPercent: ((json['lowBatteryPercent'] as num?)?.toInt() ?? 20).clamp(5, 50).toInt(),
      sensorSimulationEnabled: json['sensorSimulationEnabled'] as bool? ?? false,
      simulationScenario: scenario,
    );
  }
}
