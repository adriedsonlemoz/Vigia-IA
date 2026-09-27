import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.187', build: 187);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.187', build: 187),
      changes: <String>[
        'A tela de novidades agora acompanha corretamente a versão instalada.',
        'A validação da atualização ficou mais consistente entre desenvolvimento e entrega.',
        'Mapa, Bike/ESP32, IA e recursos offline mantêm o mesmo comportamento da versão anterior.',
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
