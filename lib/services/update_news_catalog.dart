import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.189', build: 189);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.189', build: 189),
      changes: <String>[
        'A abertura libera a tela principal antes de preparar ESP32, sensores e alertas em segundo plano.',
        'A preparação de voz/TTS ganhou limite de espera para não prender a inicialização.',
        'O app mantém um caminho de recuperação quando uma etapa de abertura demora além do esperado.',
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
