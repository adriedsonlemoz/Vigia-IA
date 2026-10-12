import 'dart:math' as math;

import '../models/bike_trip_plan.dart';

/// Estimativa determinística: tempos de pedal + pausas, sem tráfego ou clima.
/// Horários são minutos a partir da meia-noite local; não há consulta de rede.
class BikeTripDaySchedule {
  const BikeTripDaySchedule({
    required this.departureMinute,
    required this.arrivalMinute,
    required this.breakMinutes,
    required this.breakCount,
    required this.lunchMinutes,
  });

  final int departureMinute;
  final int arrivalMinute;
  final int breakMinutes;
  final int breakCount;
  final int lunchMinutes;

  int get elapsedMinutes => arrivalMinute - departureMinute;

  static String formatMinute(int minute) {
    final normalized = minute % (24 * 60);
    final hours = normalized ~/ 60;
    final minutes = normalized % 60;
    final dayOffset = minute ~/ (24 * 60);
    final text = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    return dayOffset > 0 ? '$text (+$dayOffset dia)' : text;
  }
}

class BikeTripSchedule {
  const BikeTripSchedule._();

  static BikeTripDaySchedule forDay({
    required BikeTripDayPlan day,
    int departureMinute = 7 * 60,
    int breakEveryKm = 20,
    int breakDurationMinutes = 10,
    int lunchDurationMinutes = 40,
    bool forceLunch = false,
  }) {
    final rideMinutes = (day.ridingDuration.inSeconds / 60).ceil();
    // Pausas a cada trecho completo, exceto no próprio destino.
    final count = day.distanceMeters <= 0
        ? 0
        : math.max(0, (day.distanceMeters / (breakEveryKm * 1000)).ceil() - 1);
    final shortBreaks = count * breakDurationMinutes;
    // No modo automático, considere uma refeição se o dia for longo ou
    // atravessar a janela típica de almoço. A escolha manual é respeitada,
    // mesmo em percursos curtos (0 min significa dispensar almoço).
    final possibleLunchTime = departureMinute + rideMinutes + shortBreaks;
    final crossesLunchWindow = rideMinutes >= 60 &&
        departureMinute < 14 * 60 && possibleLunchTime >= 11 * 60 + 30;
    final lunch = forceLunch || rideMinutes >= 240 || crossesLunchWindow
        ? lunchDurationMinutes
        : 0;
    return BikeTripDaySchedule(
      departureMinute: departureMinute,
      arrivalMinute: departureMinute + rideMinutes + shortBreaks + lunch,
      breakMinutes: shortBreaks,
      breakCount: count,
      lunchMinutes: lunch,
    );
  }
}
