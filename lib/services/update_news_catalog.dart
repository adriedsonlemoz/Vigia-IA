import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.184', build: 184);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.184', build: 184),
      changes: <String>[
        'A busca do mapa sugere locais enquanto você digita usando dados locais/offline, sem consultar a internet a cada caractere.',
        'O mapa ganhou painel Bike integrado ao ESP32 com pressão dos dois pneus, conexão, bateria e temperatura quando disponíveis.',
        'Perda rápida de pressão agora é confirmada por leituras sucessivas e gera alerta visual, sonoro e por voz sem bloquear a navegação.',
      ],
    ),
  ]);


  UpdateRelease? releaseFor(AppBuildVersion installed) {
    for (final release in releases) {
      if (release.version == installed) return release;
    }
    return null;
  }
}
