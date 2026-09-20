part of 'bike_mode_screen.dart';

class _BikeHero extends StatelessWidget {
  const _BikeHero({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.directions_bike_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usar este aparelho na bike',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Ative no celular que ficará na traseira. O perfil passa a controlar consumo, tela e telemetria durante a operação.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({
    required this.telemetry,
    required this.profile,
    required this.enabled,
  });

  final DeviceTelemetrySnapshot? telemetry;
  final BikePowerProfile profile;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final data = telemetry;
    String unavailable(Object? value, String Function() formatter) =>
        value == null ? 'Indisponível' : formatter();
    final battery = unavailable(
      data?.batteryPercent,
      () => '${data!.batteryPercent}%',
    );
    final charging = data?.batteryCharging == null
        ? null
        : data!.batteryCharging!
            ? '${data.batteryPowerSource ?? 'Carregando'}${data.batteryCurrentMa == null ? '' : ' · ${data.batteryCurrentMa!.toStringAsFixed(0)} mA'}'
            : 'Usando bateria';
    final memory = data?.appMemoryUsedBytes == null
        ? 'Indisponível'
        : StorageSizeFormatter.formatBytes(data!.appMemoryUsedBytes!);
    final deviceMemory = data?.memoryAvailableBytes == null ||
            data?.memoryTotalBytes == null
        ? null
        : '${StorageSizeFormatter.formatBytes(data!.memoryAvailableBytes!)} livres de ${StorageSizeFormatter.formatBytes(data.memoryTotalBytes!)}';

    return _SectionCard(
      title: 'Condições deste celular',
      subtitle: enabled
          ? 'Perfil ${profile.label} ativo. Estes dados já estão prontos para o painel do celular da frente.'
          : 'Telemetria local disponível para conferência; ative o Modo Bike para enviá-la durante a transmissão.',
      child: data == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                _TelemetryTile(
                  icon: data.batteryCharging == true
                      ? Icons.battery_charging_full_rounded
                      : Icons.battery_5_bar_outlined,
                  title: 'Bateria',
                  value: battery,
                  subtitle: charging,
                ),
                _TelemetryTile(
                  icon: Icons.device_thermostat_outlined,
                  title: 'Temperatura da bateria',
                  value: data.batteryTemperatureC == null
                      ? 'Indisponível'
                      : '${data.batteryTemperatureC!.toStringAsFixed(1)} °C',
                ),
                _TelemetryTile(
                  icon: Icons.brightness_6_outlined,
                  title: 'Tela / brilho',
                  value: data.screenBrightnessPercent == null
                      ? 'Indisponível'
                      : '${data.screenBrightnessPercent}%',
                  subtitle: data.screenDimmedByBike
                      ? 'Brilho reduzido pelo Modo Bike'
                      : data.automaticBrightness == true
                          ? 'Brilho automático do Android'
                          : data.screenInteractive == false
                              ? 'Tela não interativa'
                              : 'Brilho atual do aparelho',
                ),
                _TelemetryTile(
                  icon: Icons.speed_rounded,
                  title: 'CPU do Vigia IA',
                  value: data.appCpuPercent == null
                      ? 'Calculando…'
                      : '${data.appCpuPercent!.toStringAsFixed(1)}%',
                  subtitle: data.processorCount == null
                      ? 'Uso do processo do aplicativo'
                      : 'Uso do processo · ${data.processorCount} núcleos disponíveis',
                ),
                _TelemetryTile(
                  icon: Icons.memory_rounded,
                  title: 'Memória',
                  value: memory,
                  subtitle: deviceMemory == null
                      ? 'Uso aproximado do processo'
                      : 'App · $deviceMemory no aparelho',
                ),
              ],
            ),
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  const _TelemetryTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(subtitle),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _RemotePanelReadyCard extends StatelessWidget {
  const _RemotePanelReadyCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.route_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Painel remoto disponível',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ao usar Outro celular como fonte, toque no ícone de bicicleta no monitor para acompanhar estas condições e os avisos do aparelho traseiro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
