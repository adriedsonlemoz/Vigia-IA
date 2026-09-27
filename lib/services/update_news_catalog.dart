import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.190', build: 190);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.190', build: 190),
      changes: <String>[
        'A instrução minimizada da navegação agora pode ficar ao lado do botão Gravar no rodapé.',
        'Novas rotas entram minimizadas por padrão no layout compacto para liberar mais mapa visível.',
        'Tocar no resumo inferior ou no card superior continua expandindo o painel completo da navegação.',
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
