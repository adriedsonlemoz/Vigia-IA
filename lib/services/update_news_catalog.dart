import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.245', build: 245);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.245', build: 245),
      changes: <String>[
        'Painel Minha Câmera: vídeo, comandos remotos e análise por IA na mesma tela.',
        'Conexão por QR com versões anteriores e reconexão automática do MJPEG.',
        'Fotos e vídeos recebidos agora podem aparecer na Galeria do Android.',
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
