import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.182', build: 182);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: currentVersion,
      changes: <String>[
        'O painel de navegação agora pode ser minimizado sem encerrar a rota e mostra quando o mapa está em modo livre.',
        'Rotas alternativas foram integradas ao card com comparação compacta de distância e tempo antes da troca.',
        'Próximos pontos passa a destacar os pontos úteis mais próximos e, durante a navegação, identifica o resumo como Próximos na rota.',
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
