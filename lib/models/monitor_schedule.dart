class MonitorSchedule {
  const MonitorSchedule({
    this.enabled = false,
    this.weekdays = const <int>{
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    },
    this.startMinute = 22 * 60,
    this.endMinute = 6 * 60,
  });

  final bool enabled;
  final Set<int> weekdays;
  final int startMinute;
  final int endMinute;

  bool isActiveAt(DateTime now) {
    if (!enabled) return true;
    if (weekdays.isEmpty) return false;
    final minute = now.hour * 60 + now.minute;
    if (startMinute == endMinute) {
      return weekdays.contains(now.weekday);
    }
    if (startMinute < endMinute) {
      return weekdays.contains(now.weekday) &&
          minute >= startMinute &&
          minute < endMinute;
    }
    if (minute >= startMinute) {
      return weekdays.contains(now.weekday);
    }
    if (minute < endMinute) {
      final previous = now.weekday == DateTime.monday
          ? DateTime.sunday
          : now.weekday - 1;
      return weekdays.contains(previous);
    }
    return false;
  }

  MonitorSchedule copyWith({
    bool? enabled,
    Set<int>? weekdays,
    int? startMinute,
    int? endMinute,
  }) =>
      MonitorSchedule(
        enabled: enabled ?? this.enabled,
        weekdays: weekdays ?? this.weekdays,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'weekdays': weekdays.toList()..sort(),
        'startMinute': startMinute,
        'endMinute': endMinute,
      };

  factory MonitorSchedule.fromJson(Map<String, dynamic> json) {
    final weekdays = (json['weekdays'] as List?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value >= 1 && value <= 7)
            .toSet() ??
        const <int>{};
    return MonitorSchedule(
      enabled: json['enabled'] as bool? ?? false,
      weekdays: weekdays.isEmpty && json['weekdays'] == null
          ? const <int>{
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
              DateTime.saturday,
              DateTime.sunday,
            }
          : weekdays,
      startMinute: ((json['startMinute'] as num?)?.toInt() ?? 22 * 60)
          .clamp(0, 1439)
          .toInt(),
      endMinute: ((json['endMinute'] as num?)?.toInt() ?? 6 * 60)
          .clamp(0, 1439)
          .toInt(),
    );
  }
}

String formatMinuteOfDay(int value) {
  final minute = value.clamp(0, 1439).toInt();
  final hour = minute ~/ 60;
  final rest = minute % 60;
  return '${hour.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

String monitorScheduleSummary(MonitorSchedule schedule) {
  if (!schedule.enabled) return 'Agendamento desativado';
  if (schedule.weekdays.isEmpty) return 'Nenhum dia selecionado';
  return '${formatMinuteOfDay(schedule.startMinute)}–${formatMinuteOfDay(schedule.endMinute)} · '
      '${schedule.weekdays.length} dia(s)';
}
