import 'dart:io';

/// Proteção por endpoint para evitar sobrecarregar instâncias públicas de
/// Overpass que acabaram de responder 429/504 ou falhar por transporte.
class RouteExplorerOverpassPolicy {
  RouteExplorerOverpassPolicy();

  final Map<String, DateTime> _retryAt = <String, DateTime>{};

  bool canAttempt(String endpoint, {required DateTime now}) {
    final retry = _retryAt[endpoint];
    return retry == null || !now.isBefore(retry);
  }

  DateTime? nextRetry(String endpoint) => _retryAt[endpoint];

  void succeeded(String endpoint) => _retryAt.remove(endpoint);

  void failed(
    String endpoint, {
    required DateTime now,
    int? httpStatus,
    String? retryAfter,
  }) {
    final delay = switch (httpStatus) {
      429 => const Duration(minutes: 3),
      504 => const Duration(minutes: 2),
      503 => const Duration(minutes: 1),
      _ => const Duration(seconds: 30),
    };
    var until = now.add(delay);
    if (httpStatus == 429 || httpStatus == 503) {
      final seconds = int.tryParse(retryAfter?.trim() ?? '');
      if (seconds != null && seconds > 0) {
        final capped = seconds.clamp(0, 3600).toInt();
        final fromHeader = now.add(Duration(seconds: capped));
        if (fromHeader.isAfter(until)) until = fromHeader;
      } else {
        DateTime? date;
        try {
          if (retryAfter != null) date = HttpDate.parse(retryAfter);
        } on FormatException {
          // Header inválido: aplica espera padrão conservadora.
        } on HttpException {
          // Outro formato inválido do cabeçalho HTTP.
        }
        if (date != null && date.isAfter(until)) {
          final maximum = now.add(const Duration(hours: 1));
          until = date.isAfter(maximum) ? maximum : date;
        }
      }
    }
    final existing = _retryAt[endpoint];
    if (existing == null || until.isAfter(existing)) {
      _retryAt[endpoint] = until;
    }
  }
}

