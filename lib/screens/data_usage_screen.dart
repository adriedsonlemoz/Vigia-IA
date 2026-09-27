import 'dart:async';

import 'package:flutter/material.dart';

import '../services/data_usage_service.dart';

class DataUsageCompactCard extends StatelessWidget {
  const DataUsageCompactCard({
    super.key,
    required this.snapshot,
    required this.onTap,
  });

  final DataUsageSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radio = snapshot.modules[DataUsageModule.radio] ?? 0;
    final maps = snapshot.modules[DataUsageModule.maps] ?? 0;
    final other = snapshot.modules[DataUsageModule.other] ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.data_usage_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Uso de dados',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                      DataUsageService.formatBytes(snapshot.today.total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Hoje · Wi-Fi ${DataUsageService.formatBytes(snapshot.today.wifi)} · '
                      'Móvel ${DataUsageService.formatBytes(snapshot.today.mobile)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Rádio ${DataUsageService.formatBytes(radio)} · '
                      'Mapas ${DataUsageService.formatBytes(maps)} · '
                      'Outros ${DataUsageService.formatBytes(other)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  final DataUsageService _service = DataUsageService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _service.initialize();
    await _service.refresh(immediate: true);
  }

  Future<void> _resetTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zerar contador da viagem?'),
        content: const Text(
          'O novo período começa agora. O histórico diário do aplicativo será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zerar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.resetTrip();
  }

  Future<int?> _chooseLimit(String title, int current) async {
    final controller = TextEditingController(
      text: current > 0 ? (current / (1024 * 1024)).round().toString() : '',
    );
    try {
      return await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const <(String, int)>[
                    ('Desligado', 0),
                    ('100 MB', 100 * 1024 * 1024),
                    ('500 MB', 500 * 1024 * 1024),
                    ('1 GB', 1024 * 1024 * 1024),
                  ])
                    ActionChip(
                      label: Text(option.$1),
                      onPressed: () => Navigator.pop(context, option.$2),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Limite personalizado em MB',
                  suffixText: 'MB',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final mb = int.tryParse(controller.text.trim());
                Navigator.pop(
                  context,
                  mb == null || mb < 0 ? null : mb * 1024 * 1024,
                );
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _service.snapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uso de dados'),
        actions: [
          IconButton(
            tooltip: 'Atualizar agora',
            onPressed: _service.refreshing ? null : () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            _UsageHero(snapshot: snapshot),
            const SizedBox(height: 12),
            _PeriodGrid(snapshot: snapshot),
            const SizedBox(height: 12),
            _TripCard(snapshot: snapshot, onReset: _resetTrip),
            const SizedBox(height: 12),
            _ModuleCard(snapshot: snapshot),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.savings_outlined),
                    title: const Text('Economia de dados'),
                    subtitle: const Text(
                      'Reduz consultas automáticas, clima, Pontos Próximos e prioriza rádios de menor bitrate.',
                    ),
                    value: _service.dataSaverEnabled,
                    onChanged: (value) => unawaited(_service.setDataSaver(value)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.video_settings_outlined),
                    title: const Text('Reduzir qualidade de transmissão'),
                    subtitle: const Text(
                      'Só permite reduzir vídeo quando a transmissão consultar esta preferência.',
                    ),
                    value: _service.reduceTransmissionQuality,
                    onChanged: _service.dataSaverEnabled
                        ? (value) => unawaited(
                              _service.setReduceTransmissionQuality(value),
                            )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.notifications_active_outlined),
                    title: Text('Alertas de consumo'),
                    subtitle: Text('100 MB, 500 MB, 1 GB ou valor personalizado.'),
                  ),
                  _limitTile(
                    'Dados móveis · dia',
                    _service.mobileDailyLimitBytes,
                    (value) => _service.setLimits(mobile: value),
                  ),
                  _limitTile(
                    'Wi-Fi · dia',
                    _service.wifiDailyLimitBytes,
                    (value) => _service.setLimits(wifi: value),
                  ),
                  _limitTile(
                    'Viagem atual',
                    _service.tripLimitBytes,
                    (value) => _service.setLimits(trip: value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'O total usa os contadores reais do UID do Vigia IA quando o Android os fornece. A divisão Wi-Fi/móvel é atribuída conforme a rede ativa em cada amostra; a separação por recurso usa contadores internos e estimativas de stream.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _limitTile(
    String label,
    int value,
    Future<void> Function(int) apply,
  ) => ListTile(
        title: Text(label),
        subtitle: Text(
          value <= 0 ? 'Desligado' : DataUsageService.formatBytes(value),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final selected = await _chooseLimit(label, value);
          if (selected != null) await apply(selected);
        },
      );
}

class _UsageHero extends StatelessWidget {
  const _UsageHero({required this.snapshot});
  final DataUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total do Vigia IA',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              Text(
                DataUsageService.formatBytes(snapshot.lifetime.total),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              Text(
                'Recebido ${DataUsageService.formatBytes(snapshot.lifetime.received)} · '
                'Enviado ${DataUsageService.formatBytes(snapshot.lifetime.sent)}',
              ),
              const SizedBox(height: 4),
              Text('${snapshot.connection} · atualização eficiente a cada 15 min'),
            ],
          ),
        ),
      );
}

class _PeriodGrid extends StatelessWidget {
  const _PeriodGrid({required this.snapshot});
  final DataUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <(String, DataUsageTotals)>[
      ('Sessão atual', snapshot.session),
      ('Hoje', snapshot.today),
      ('Últimos 7 dias', snapshot.last7Days),
      ('Mês atual', snapshot.month),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 650 ? 4 : 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 116,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(DataUsageService.formatBytes(item.$2.total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('Wi-Fi ${DataUsageService.formatBytes(item.$2.wifi)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('Móvel ${DataUsageService.formatBytes(item.$2.mobile)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.snapshot, required this.onReset});
  final DataUsageSnapshot snapshot;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final start = snapshot.tripStartedAt.toLocal();
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Viagem atual',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            Text(DataUsageService.formatBytes(snapshot.trip.total),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text('Desde $date · ${snapshot.tripDays} dia(s)'),
            Text(
              'Média: ${DataUsageService.formatBytes(snapshot.tripDailyAverage)}/dia',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Zerar contador da viagem'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.snapshot});
  final DataUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Por recurso',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              for (final module in DataUsageModule.values)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(module.label),
                  trailing: Text(
                    DataUsageService.formatBytes(snapshot.modules[module] ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
      );
}
