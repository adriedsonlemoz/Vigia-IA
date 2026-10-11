import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.210', build: 210);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.210', build: 210),
      changes: <String>[
        'O Vigia Maps usa GPS apenas quando necessário para acompanhar a localização, gravar o percurso ou navegar.',
        'O clima não precisa ligar a comunicação ESP32 ao abrir o mapa, e o diagnóstico mostra mais dados sobre GPS e mapas offline.',
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
