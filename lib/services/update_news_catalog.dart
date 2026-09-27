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
        'Corrigida uma trava na abertura do app: a inicialização da voz podia ficar presa indefinidamente se o motor de fala do sistema não respondesse, deixando a tela de carregamento girando para sempre.',
        'ESP32 e Bike agora inicializam em segundo plano, sem atrasar a tela inicial caso algum sensor ou serviço demore para responder.',
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
