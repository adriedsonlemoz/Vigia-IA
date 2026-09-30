import 'dart:async';

import 'package:flutter/material.dart';

import '../services/event_history_service.dart';
import '../services/statistics_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _history = EventHistoryService.instance;
  final _statistics = const StatisticsService();
  Duration? _period = const Duration(days: 7);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _history.initialize();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final stats = _statistics.calculate(_history.events, period: _period);
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '1', label: Text('24h')),
              ButtonSegment(value: '7', label: Text('7 dias')),
              ButtonSegment(value: '30', label: Text('30 dias')),
              ButtonSegment(value: 'all', label: Text('Tudo')),
            ],
            selected: {_period == null ? 'all' : _period!.inDays == 1 ? '1' : _period!.inDays == 30 ? '30' : '7'},
            onSelectionChanged: (value) => setState(() => _period = switch (value.first) {'1' => const Duration(days: 1), '30' => const Duration(days: 30), 'all' => null, _ => const Duration(days: 7)}),
          ),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _Metric(title: 'Eventos', value: '${stats.total}', icon: Icons.notifications_none_rounded)), const SizedBox(width: 8), Expanded(child: _Metric(title: 'Hoje', value: '${stats.today}', icon: Icons.today_outlined))]),
          const SizedBox(height: 8),
          _Metric(title: 'Horário de maior movimento', value: stats.busiestHour == null ? 'Sem dados' : '${stats.busiestHour.toString().padLeft(2, '0')}:00–${((stats.busiestHour! + 1) % 24).toString().padLeft(2, '0')}:00', icon: Icons.schedule_rounded),
          const SizedBox(height: 18),
          _Ranking(title: 'Por categoria', values: stats.byObject, icon: Icons.category_outlined),
          _Ranking(title: 'Por área', values: stats.byArea, icon: Icons.grid_view_rounded),
          _Ranking(title: 'Por câmera', values: stats.byCamera, icon: Icons.videocam_outlined),
          const SizedBox(height: 12),
          const Text('Movimento por hora', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...List<Widget>.generate(24, (hour) {
            final count = stats.byHour[hour] ?? 0;
            final maxValue = stats.byHour.values.fold<int>(1, (a, b) => a > b ? a : b);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [SizedBox(width: 48, child: Text('${hour.toString().padLeft(2, '0')}h')), Expanded(child: LinearProgressIndicator(value: count / maxValue)), const SizedBox(width: 10), SizedBox(width: 32, child: Text('$count', textAlign: TextAlign.end))]),
            );
          }),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(title, style: Theme.of(context).textTheme.bodySmall)]))])));
}

class _Ranking extends StatelessWidget {
  const _Ranking({required this.title, required this.values, required this.icon});
  final String title;
  final Map<String, int> values;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]), const SizedBox(height: 10), if (values.isEmpty) const Text('Sem dados no período.') else ...values.entries.take(8).map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(entry.key)), Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w900))])))]),
        ),
      );
}
