import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/alert_preferences.dart';
import 'map_radio_service.dart';
import 'native_platform_service.dart';

enum DataUsageModule {
  radio,
  maps,
  cameras,
  nearby,
  weather,
  downloads,
  other,
}

extension DataUsageModuleUi on DataUsageModule {
  String get label => switch (this) {
        DataUsageModule.radio => 'Rádio',
        DataUsageModule.maps => 'Mapas',
        DataUsageModule.cameras => 'Câmeras/transmissão',
        DataUsageModule.nearby => 'Busca e Pontos Próximos',
        DataUsageModule.weather => 'Clima',
        DataUsageModule.downloads => 'Downloads/atualizações',
        DataUsageModule.other => 'Outros',
      };
}

class DataUsageTotals {
  const DataUsageTotals({
    this.received = 0,
    this.sent = 0,
    this.wifi = 0,
    this.mobile = 0,
  });

  final int received;
  final int sent;
  final int wifi;
  final int mobile;
  int get total => received + sent;

  DataUsageTotals plus(DataUsageTotals other) => DataUsageTotals(
        received: received + other.received,
        sent: sent + other.sent,
        wifi: wifi + other.wifi,
        mobile: mobile + other.mobile,
      );

  Map<String, int> toJson() => <String, int>{
        'received': received,
        'sent': sent,
        'wifi': wifi,
        'mobile': mobile,
      };

  factory DataUsageTotals.fromJson(Object? raw) {
    if (raw is! Map) return const DataUsageTotals();
    int value(String key) => (raw[key] as num?)?.toInt() ?? 0;
    return DataUsageTotals(
      received: value('received'),
      sent: value('sent'),
      wifi: value('wifi'),
      mobile: value('mobile'),
    );
  }
}

class DataUsageSnapshot {
  const DataUsageSnapshot({
    required this.session,
    required this.today,
    required this.last7Days,
    required this.month,
    required this.lifetime,
    required this.trip,
    required this.tripStartedAt,
    required this.modules,
    required this.connection,
    required this.updatedAt,
  });

  final DataUsageTotals session;
  final DataUsageTotals today;
  final DataUsageTotals last7Days;
  final DataUsageTotals month;
  final DataUsageTotals lifetime;
  final DataUsageTotals trip;
  final DateTime tripStartedAt;
  final Map<DataUsageModule, int> modules;
  final String connection;
  final DateTime updatedAt;

  int get tripDays {
    final start = DateTime(
      tripStartedAt.year,
      tripStartedAt.month,
      tripStartedAt.day,
    );
    final now = DateTime.now();
    return (DateTime(now.year, now.month, now.day).difference(start).inDays + 1)
        .clamp(1, 100000)
        .toInt();
  }

  int get tripDailyAverage =>
      trip.total ~/ tripDays.clamp(1, 100000).toInt();
}

class DataUsageService extends ChangeNotifier {
  DataUsageService._();

  static final DataUsageService instance = DataUsageService._();
  static const refreshInterval = Duration(minutes: 15);

  final NativePlatformService _native = NativePlatformService.instance;
  File? _file;
  Timer? _timer;
  Timer? _persistDebounce;
  Future<void> _writeTail = Future<void>.value();
  bool _initialized = false;
  bool _hasPersistedSnapshot = false;
  Future<void>? _initializing;
  bool _refreshing = false;
  int? _lastUidReceived;
  int? _lastUidSent;
  int _totalReceived = 0;
  int _totalSent = 0;
  int _wifiTotal = 0;
  int _mobileTotal = 0;
  int _sessionBaselineReceived = 0;
  int _sessionBaselineSent = 0;
  int _sessionBaselineWifi = 0;
  int _sessionBaselineMobile = 0;
  int _tripBaselineReceived = 0;
  int _tripBaselineSent = 0;
  int _tripBaselineWifi = 0;
  int _tripBaselineMobile = 0;
  DateTime _tripStartedAt = DateTime.now();
  final Map<String, DataUsageTotals> _daily = <String, DataUsageTotals>{};
  final Map<DataUsageModule, int> _modules = <DataUsageModule, int>{};
  final Set<String> _deliveredAlerts = <String>{};
  int _lastRadioEstimate = 0;
  String _connection = 'Indisponível';
  DateTime _updatedAt = DateTime.now();
  bool dataSaverEnabled = false;
  bool reduceTransmissionQuality = false;
  int mobileDailyLimitBytes = 0;
  int wifiDailyLimitBytes = 0;
  int tripLimitBytes = 0;

  bool get initialized => _initialized;
  bool get refreshing => _refreshing;
  DataUsageSnapshot get snapshot => _buildSnapshot();

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initializeInternal().whenComplete(
          () => _initializing = null,
        );
  }

  Future<void> _initializeInternal() async {
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}data_usage.json');
    await _load();
    await refresh(immediate: true);
    _sessionBaselineReceived = _totalReceived;
    _sessionBaselineSent = _totalSent;
    _sessionBaselineWifi = _wifiTotal;
    _sessionBaselineMobile = _mobileTotal;
    _initialized = true;
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    notifyListeners();
  }

  Future<void> refresh({bool immediate = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final native = await _native.networkUsageSnapshot();
      _connection = native.connection;
      _updatedAt = native.capturedAt;
      final received = native.receivedBytes;
      final sent = native.sentBytes;
      if (received != null && sent != null) {
        final first = _lastUidReceived == null || _lastUidSent == null;
        final deltaReceived = first
            ? (_hasPersistedSnapshot
                ? received.clamp(0, 1 << 62).toInt()
                : 0)
            : received >= _lastUidReceived!
                ? received - _lastUidReceived!
                : received.clamp(0, 1 << 62).toInt();
        final deltaSent = first
            ? (_hasPersistedSnapshot
                ? sent.clamp(0, 1 << 62).toInt()
                : 0)
            : sent >= _lastUidSent!
                ? sent - _lastUidSent!
                : sent.clamp(0, 1 << 62).toInt();
        _lastUidReceived = received;
        _lastUidSent = sent;
        if (first && !_hasPersistedSnapshot) {
          // TrafficStats é cumulativo e não informa quando cada byte ocorreu.
          // O primeiro valor vira o total de referência sem atribuir todo o
          // histórico do UID ao dia ou à rede que estiver ativa agora.
          _totalReceived = received.clamp(0, 1 << 62).toInt();
          _totalSent = sent.clamp(0, 1 << 62).toInt();
        }
        _applyUidDelta(deltaReceived, deltaSent, native.connection);
      }
      await _captureRadioEstimate();
      _pruneHistory();
      await _checkAlerts();
      await _persistNow();
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void _applyUidDelta(int received, int sent, String connection) {
    if (received <= 0 && sent <= 0) return;
    _totalReceived += received;
    _totalSent += sent;
    final combined = received + sent;
    if (connection == 'Dados móveis') {
      _mobileTotal += combined;
    } else if (connection == 'Wi-Fi' || connection == 'Ethernet') {
      _wifiTotal += combined;
    }
    final key = _dayKey(DateTime.now());
    final previous = _daily[key] ?? const DataUsageTotals();
    _daily[key] = previous.plus(DataUsageTotals(
      received: received,
      sent: sent,
      wifi: connection == 'Wi-Fi' || connection == 'Ethernet' ? combined : 0,
      mobile: connection == 'Dados móveis' ? combined : 0,
    ));
  }

  Future<void> _captureRadioEstimate() async {
    try {
      final radio = await MapRadioService.statusDetails();
      final current = radio.estimatedBytes;
      if (current >= _lastRadioEstimate) {
        final delta = current - _lastRadioEstimate;
        if (delta > 0) record(DataUsageModule.radio, received: delta);
      }
      _lastRadioEstimate = current;
    } catch (_) {}
  }

  void record(
    DataUsageModule module, {
    int received = 0,
    int sent = 0,
  }) {
    final delta = received.clamp(0, 1 << 62).toInt() +
        sent.clamp(0, 1 << 62).toInt();
    if (delta <= 0) return;
    _modules[module] = (_modules[module] ?? 0) + delta;
    _schedulePersist();
  }

  Future<void> setDataSaver(bool value) async {
    dataSaverEnabled = value;
    notifyListeners();
    await _persistNow();
  }

  Future<void> setReduceTransmissionQuality(bool value) async {
    reduceTransmissionQuality = value;
    notifyListeners();
    await _persistNow();
  }

  Future<void> setLimits({int? mobile, int? wifi, int? trip}) async {
    if (mobile != null) {
      mobileDailyLimitBytes = mobile.clamp(0, 1 << 62).toInt();
    }
    if (wifi != null) wifiDailyLimitBytes = wifi.clamp(0, 1 << 62).toInt();
    if (trip != null) tripLimitBytes = trip.clamp(0, 1 << 62).toInt();
    _deliveredAlerts.clear();
    notifyListeners();
    await _persistNow();
  }

  Future<void> resetTrip() async {
    _tripBaselineReceived = _totalReceived;
    _tripBaselineSent = _totalSent;
    _tripBaselineWifi = _wifiTotal;
    _tripBaselineMobile = _mobileTotal;
    _tripStartedAt = DateTime.now();
    _deliveredAlerts.removeWhere((key) => key.startsWith('trip:'));
    notifyListeners();
    await _persistNow();
  }

  DataUsageSnapshot _buildSnapshot() {
    final now = DateTime.now();
    final today = _daily[_dayKey(now)] ?? const DataUsageTotals();
    var last7 = const DataUsageTotals();
    var month = const DataUsageTotals();
    for (var offset = 0; offset < 7; offset++) {
      last7 = last7.plus(
        _daily[_dayKey(now.subtract(Duration(days: offset)))] ??
            const DataUsageTotals(),
      );
    }
    final monthPrefix =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-';
    for (final entry in _daily.entries) {
      if (entry.key.startsWith(monthPrefix)) month = month.plus(entry.value);
    }
    final lifetime = DataUsageTotals(
      received: _totalReceived,
      sent: _totalSent,
      wifi: _wifiTotal,
      mobile: _mobileTotal,
    );
    final modules = <DataUsageModule, int>{..._modules};
    final known = modules.entries
        .where((entry) => entry.key != DataUsageModule.other)
        .fold<int>(0, (sum, entry) => sum + entry.value);
    modules[DataUsageModule.other] =
        (lifetime.total - known).clamp(0, 1 << 62).toInt();
    return DataUsageSnapshot(
      session: DataUsageTotals(
        received: (_totalReceived - _sessionBaselineReceived)
            .clamp(0, 1 << 62).toInt(),
        sent: (_totalSent - _sessionBaselineSent)
            .clamp(0, 1 << 62).toInt(),
        wifi: (_wifiTotal - _sessionBaselineWifi)
            .clamp(0, 1 << 62).toInt(),
        mobile: (_mobileTotal - _sessionBaselineMobile)
            .clamp(0, 1 << 62).toInt(),
      ),
      today: today,
      last7Days: last7,
      month: month,
      lifetime: lifetime,
      trip: DataUsageTotals(
        received: (_totalReceived - _tripBaselineReceived)
            .clamp(0, 1 << 62).toInt(),
        sent: (_totalSent - _tripBaselineSent)
            .clamp(0, 1 << 62).toInt(),
        wifi: (_wifiTotal - _tripBaselineWifi)
            .clamp(0, 1 << 62).toInt(),
        mobile: (_mobileTotal - _tripBaselineMobile)
            .clamp(0, 1 << 62).toInt(),
      ),
      tripStartedAt: _tripStartedAt,
      modules: Map<DataUsageModule, int>.unmodifiable(modules),
      connection: _connection,
      updatedAt: _updatedAt,
    );
  }

  Future<void> _checkAlerts() async {
    final current = _buildSnapshot();
    await _checkLimit(
      key: 'mobile:${_dayKey(DateTime.now())}:$mobileDailyLimitBytes',
      label: 'dados móveis hoje',
      value: current.today.mobile,
      limit: mobileDailyLimitBytes,
    );
    await _checkLimit(
      key: 'wifi:${_dayKey(DateTime.now())}:$wifiDailyLimitBytes',
      label: 'Wi-Fi hoje',
      value: current.today.wifi,
      limit: wifiDailyLimitBytes,
    );
    await _checkLimit(
      key: 'trip:${_tripStartedAt.toIso8601String()}:$tripLimitBytes',
      label: 'viagem atual',
      value: current.trip.total,
      limit: tripLimitBytes,
    );
  }

  Future<void> _checkLimit({
    required String key,
    required String label,
    required int value,
    required int limit,
  }) async {
    if (limit <= 0 || value < limit || !_deliveredAlerts.add(key)) return;
    await _native.showAlertNotification(
      title: 'Limite de dados atingido',
      message: '$label chegou a ${formatBytes(value)}.',
      outputs: const AlertOutputs(
        androidNotification: true,
        sound: false,
        vibration: false,
      ),
    );
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      _hasPersistedSnapshot = true;
      int value(String key) => (raw[key] as num?)?.toInt() ?? 0;
      _lastUidReceived = (raw['lastUidReceived'] as num?)?.toInt();
      _lastUidSent = (raw['lastUidSent'] as num?)?.toInt();
      _totalReceived = value('totalReceived');
      _totalSent = value('totalSent');
      _wifiTotal = value('wifiTotal');
      _mobileTotal = value('mobileTotal');
      _tripBaselineReceived = value('tripBaselineReceived');
      _tripBaselineSent = value('tripBaselineSent');
      _tripBaselineWifi = value('tripBaselineWifi');
      _tripBaselineMobile = value('tripBaselineMobile');
      _tripStartedAt = DateTime.tryParse(raw['tripStartedAt']?.toString() ?? '') ??
          DateTime.now();
      dataSaverEnabled = raw['dataSaverEnabled'] == true;
      reduceTransmissionQuality = raw['reduceTransmissionQuality'] == true;
      mobileDailyLimitBytes = value('mobileDailyLimitBytes');
      wifiDailyLimitBytes = value('wifiDailyLimitBytes');
      tripLimitBytes = value('tripLimitBytes');
      final daily = raw['daily'];
      if (daily is Map) {
        for (final entry in daily.entries) {
          _daily[entry.key.toString()] = DataUsageTotals.fromJson(entry.value);
        }
      }
      final modules = raw['modules'];
      if (modules is Map) {
        for (final module in DataUsageModule.values) {
          _modules[module] = (modules[module.name] as num?)?.toInt() ?? 0;
        }
      }
      _deliveredAlerts.addAll(
        (raw['deliveredAlerts'] as List?)?.whereType<String>() ?? const [],
      );
    } catch (_) {}
  }

  void _schedulePersist() {
    if (_persistDebounce?.isActive == true) return;
    _persistDebounce = Timer(
      const Duration(seconds: 30),
      () => unawaited(_persistNow()),
    );
  }

  Future<void> _persistNow() {
    final file = _file;
    if (file == null) return Future<void>.value();
    final payload = <String, Object?>{
      'schema': 1,
      'lastUidReceived': _lastUidReceived,
      'lastUidSent': _lastUidSent,
      'totalReceived': _totalReceived,
      'totalSent': _totalSent,
      'wifiTotal': _wifiTotal,
      'mobileTotal': _mobileTotal,
      'tripBaselineReceived': _tripBaselineReceived,
      'tripBaselineSent': _tripBaselineSent,
      'tripBaselineWifi': _tripBaselineWifi,
      'tripBaselineMobile': _tripBaselineMobile,
      'tripStartedAt': _tripStartedAt.toIso8601String(),
      'dataSaverEnabled': dataSaverEnabled,
      'reduceTransmissionQuality': reduceTransmissionQuality,
      'mobileDailyLimitBytes': mobileDailyLimitBytes,
      'wifiDailyLimitBytes': wifiDailyLimitBytes,
      'tripLimitBytes': tripLimitBytes,
      'daily': <String, Object?>{
        for (final entry in _daily.entries) entry.key: entry.value.toJson(),
      },
      'modules': <String, int>{
        for (final entry in _modules.entries) entry.key.name: entry.value,
      },
      'deliveredAlerts': _deliveredAlerts.toList(growable: false),
    };
    final encoded = jsonEncode(payload);
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    });
    return _writeTail;
  }

  void _pruneHistory() {
    final cutoff = DateTime.now().subtract(const Duration(days: 62));
    _daily.removeWhere((key, _) {
      final date = DateTime.tryParse(key);
      return date != null && date.isBefore(cutoff);
    });
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 10 ? 1 : 2)} GB';
  }
}
