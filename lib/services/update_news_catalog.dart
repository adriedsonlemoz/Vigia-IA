import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.224', build: 224);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.224', build: 224),
      changes: <String>[
        'Busca de cidades prioriza nomes correspondentes e mostra a região.',
        'Resultados salvos, próximos e distantes são agrupados.',
        'Localidades com acento e repetidas aparecem de forma mais clara.',
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
