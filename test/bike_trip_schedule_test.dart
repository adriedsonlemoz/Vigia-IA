import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/services/bike_trip_schedule.dart';

void main() {
  BikeTripDayPlan day(double km, int minutes) => BikeTripDayPlan(
    day: 1, startDistanceMeters: 0, endDistanceMeters: km * 1000,
    ridingDuration: Duration(minutes: minutes), stopLabel: 'Destino',
    stopLatitude: 0, stopLongitude: 0, stopKind: 'Destino',
    usesKnownPlace: true,
  );

  test('pausas e almoço entram na chegada, sem assumir serviços', () {
    final schedule = BikeTripSchedule.forDay(day: day(61, 244));
    expect(schedule.breakCount, 3);
    expect(schedule.breakMinutes, 30);
    expect(schedule.lunchMinutes, 40);
    expect(BikeTripDaySchedule.formatMinute(schedule.arrivalMinute), '12:14');
  });

  test('pedal curto nao inclui almoço ou pausa no destino', () {
    final schedule = BikeTripSchedule.forDay(day: day(20, 80));
    expect(schedule.breakCount, 0);
    expect(schedule.lunchMinutes, 0);
    expect(schedule.arrivalMinute, 500);
  });
}
