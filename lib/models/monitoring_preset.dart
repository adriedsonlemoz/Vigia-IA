enum MonitoringPreset { home, away, night, custom }

extension MonitoringPresetLabel on MonitoringPreset {
  String get label => switch (this) {
        MonitoringPreset.home => 'Casa',
        MonitoringPreset.away => 'Ausente',
        MonitoringPreset.night => 'Noite',
        MonitoringPreset.custom => 'Personalizado',
      };

  String get description => switch (this) {
        MonitoringPreset.home => 'Alertas moderados para rotina com pessoas no local.',
        MonitoringPreset.away => 'Maior sensibilidade e alertas completos quando ninguém deveria estar no local.',
        MonitoringPreset.night => 'Foco em movimento relevante e menos repetição durante a noite.',
        MonitoringPreset.custom => 'Mantém exatamente as regras configuradas manualmente.',
      };
}
