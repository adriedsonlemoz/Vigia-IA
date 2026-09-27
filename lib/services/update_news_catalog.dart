import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.193', build: 193);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.193', build: 193),
      changes: <String>[
        'Mapa em tela inteira com relógio, bateria e modos de foco para pedalar.',
        'Selecione qualquer ponto no mapa, salve locais e veja a chegada prevista durante a rota.',
        'Velocidade do sensor da bike ou GPS, alertas configuráveis e painel dos pneus.',
        'Destaque opcional de vias e rios, vista de relevo e rádio online com estações salvas.',
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
