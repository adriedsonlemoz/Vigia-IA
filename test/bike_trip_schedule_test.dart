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

  test('almoço manual é aplicado mesmo em trajetos curtos', () {
    final schedule = BikeTripSchedule.forDay(
      day: day(32.1, 175), lunchDurationMinutes: 60, forceLunch: true,
    );
    expect(schedule.lunchMinutes, 60);
    expect(schedule.arrivalMinute, 420 + 175 + 10 + 60);
  });

  test('almoço automático considera travessia do horário de almoço', () {
    final schedule = BikeTripSchedule.forDay(
      day: day(20, 90), departureMinute: 11 * 60,
    );
    expect(schedule.lunchMinutes, 40);
  });

  test('pedal curto nao inclui almoço ou pausa no destino', () {
    final schedule = BikeTripSchedule.forDay(day: day(20, 80));
    expect(schedule.breakCount, 0);
    expect(schedule.lunchMinutes, 0);
    expect(schedule.arrivalMinute, 500);
  });
}
