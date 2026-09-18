import 'package:vigiaia/models/monitor_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agenda simples respeita intervalo no mesmo dia', () {
    const schedule = MonitorSchedule(
      enabled: true,
      weekdays: <int>{DateTime.tuesday},
      startMinute: 8 * 60,
      endMinute: 18 * 60,
    );

    expect(schedule.isActiveAt(DateTime(2026, 9, 15, 10)), isTrue);
    expect(schedule.isActiveAt(DateTime(2026, 9, 15, 19)), isFalse);
  });

  test('agenda noturna continua ativa depois da meia-noite', () {
    const schedule = MonitorSchedule(
      enabled: true,
      weekdays: <int>{DateTime.tuesday},
      startMinute: 22 * 60,
      endMinute: 6 * 60,
    );

    expect(schedule.isActiveAt(DateTime(2026, 9, 15, 23)), isTrue);
    expect(schedule.isActiveAt(DateTime(2026, 9, 16, 2)), isTrue);
    expect(schedule.isActiveAt(DateTime(2026, 9, 16, 7)), isFalse);
  });

  test('agenda desativada nao bloqueia monitoramento', () {
    const schedule = MonitorSchedule(enabled: false, weekdays: <int>{});
    expect(schedule.isActiveAt(DateTime(2026, 9, 15, 12)), isTrue);
  });
}
