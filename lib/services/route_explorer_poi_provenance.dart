import '../models/route_explorer_models.dart';

/// Proveniência do resultado: consulta OSM, pacote offline ou cache restaurado.
/// Uma consulta recente nunca significa que o serviço está funcionando agora.
class RouteExplorerPoiProvenance {
  const RouteExplorerPoiProvenance._();

  static String sourceLabel(RouteExplorerResult item) => switch (item.source) {
        'offline' => 'Pacote offline',
        'cache' => 'Cache local (OSM)',
        _ => 'OSM mapeado',
      };

  static String ageLabel(RouteExplorerResult item, {DateTime? now}) {
    final fetched = item.fetchedAt;
    if (fetched == null) return 'Data da consulta desconhecida';
    final elapsed = (now ?? DateTime.now()).difference(fetched);
    if (elapsed.isNegative) return 'Data da consulta não confirmada';
    if (elapsed.inMinutes < 1) return 'Consultado há menos de 1 min';
    if (elapsed.inMinutes < 60) return 'Consultado há ${elapsed.inMinutes} min';
    if (elapsed.inHours < 48) return 'Consultado há ${elapsed.inHours} h';
    return 'Consultado há ${elapsed.inDays} dias';
  }

  static const String serviceDisclaimer =
      'Local cadastrado no OpenStreetMap. Funcionamento, atendimento, '
      'horários, água potável e acesso não foram verificados em tempo real.';
}
