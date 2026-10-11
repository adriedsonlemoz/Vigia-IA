import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.209', build: 209);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.209', build: 209),
      changes: <String>[
        'A transmissão de imagem entre celulares ficou mais leve, evitando compressões simultâneas e reduzindo o trabalho com a câmera remota sem espectadores.',
        'A exibição remota agora segue independente do processamento de IA, com menor uso de memória quando quadros se repetem.',
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
