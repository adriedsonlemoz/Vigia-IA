import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.166', build: 166),
      changes: <String>[
        '🌦️ O mapa ganhou um mini-card de clima que combina sensores ESP32 e dados online conforme a disponibilidade.',
        '🌡️ A tela de clima mostra somente medições disponíveis, com origem ESP32, Online ou Misto e atualização manual.',
        '🔊 O clima pode ser ouvido pelo mesmo sistema de voz do mapa e respeita o controle de áudio do aplicativo.',
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
