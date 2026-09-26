import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  /// Releases somente tecnicas nao fabricam uma mudanca visivel para exibir.
  static const currentVersion =
      AppBuildVersion(version: '1.0.172', build: 172);

  static const current = UpdateNewsCatalog(<UpdateRelease>[]);

  UpdateRelease? releaseFor(AppBuildVersion installed) {
    for (final release in releases) {
      if (release.version == installed) return release;
    }
    return null;
  }
}
