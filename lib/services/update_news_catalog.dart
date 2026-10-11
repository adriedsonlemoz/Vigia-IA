import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.211', build: 211);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.211', build: 211),
      changes: <String>[
        'O Vigia IA abre diretamente no mapa e permite alternar entre Explorar, Pedalar, Navegar e Monitorar sem perder seu percurso.',
        'Um menu reuniu monitoramento, historico, cameras, Bike e configuracoes. O mapa so prepara cameras e sensores quando voce solicita.',
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
