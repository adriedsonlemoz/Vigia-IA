import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.181', build: 181);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: currentVersion,
      changes: <String>[
        'Próximos pontos agora aplica raio, categorias e direção de busca automaticamente; o botão Atualizar continua disponível para consulta manual.',
        'A pesquisa ganhou ação Navegar explícita e o mapa aceita toque livre para identificar locais, navegar ou adicionar uma parada ao planejamento.',
        'Avisos por voz lembram os POIs já anunciados durante a sessão, evitando repetir o mesmo local em atualizações posteriores.',
        'A seleção de categorias ficou mais compacta para mostrar mais opções com menos rolagem.',
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
