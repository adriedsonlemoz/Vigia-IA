import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.244', build: 244);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.244', build: 244),
      changes: <String>[
        'Painel MCRP v1: controle do Minha Câmera por Wi-Fi local e QR.',
        'Central Multimídia remota para vídeos e fotos, com download autenticado.',
        'Monitor de câmera MJPEG com IA das versões 242/243 permanece disponível.'
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
