import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.205', build: 205);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.205', build: 205),
      changes: <String>[
        'Rádio com player novo: mais estável, toca mais formatos e continua com a tela apagada.',
        'Agora aparece a música que está tocando e os controles ficam na tela de bloqueio e nos fones.',
        'Se o sinal cair ou a internet trocar, a rádio reconecta sozinha.',
        'Catálogo de rádios mais confiável: guarda a última busca para usar sem conexão e deixa por último as estações que não respondem.',
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
