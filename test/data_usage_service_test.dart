import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/data_usage_service.dart';

void main() {
  test('totais somam recebido, enviado e redes sem perder valores', () {
    const first = DataUsageTotals(
      received: 100,
      sent: 20,
      wifi: 90,
      mobile: 30,
    );
    const second = DataUsageTotals(
      received: 50,
      sent: 10,
      wifi: 40,
      mobile: 20,
    );

    final result = first.plus(second);

    expect(result.received, 150);
    expect(result.sent, 30);
    expect(result.total, 180);
    expect(result.wifi, 130);
    expect(result.mobile, 50);
  });

  test('formatador usa unidades compactas para o card', () {
    expect(DataUsageService.formatBytes(0), '0 B');
    expect(DataUsageService.formatBytes(1024), '1.0 KB');
    expect(DataUsageService.formatBytes(1024 * 1024), '1.0 MB');
    expect(DataUsageService.formatBytes(1024 * 1024 * 1024), '1.00 GB');
  });

  test('viagem sempre tem ao menos um dia para calcular média', () {
    final snapshot = DataUsageSnapshot(
      session: const DataUsageTotals(),
      today: const DataUsageTotals(),
      last7Days: const DataUsageTotals(),
      month: const DataUsageTotals(),
      lifetime: const DataUsageTotals(),
      trip: const DataUsageTotals(received: 200, sent: 100),
      tripStartedAt: DateTime.now(),
      modules: const <DataUsageModule, int>{},
      connection: 'Wi-Fi',
      updatedAt: DateTime.now(),
    );

    expect(snapshot.tripDays, 1);
    expect(snapshot.tripDailyAverage, 300);
  });
}
