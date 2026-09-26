import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.179', build: 179);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: currentVersion,
      changes: <String>[
        'A pesquisa do mapa agora libera os resultados salvos imediatamente e busca cidades próximas em uma etapa rápida, ampliando a região em segundo plano quando necessário.',
        'Ao abrir o mapa diretamente, nenhuma câmera é iniciada automaticamente; fontes abertas pelo mapa podem ser encerradas ao ocultar ou minimizar para economizar bateria.',
        'As câmeras herdadas do Monitoramento continuam sob controle do Monitoramento, e o comportamento de economia fica disponível em uma opção fixa nas câmeras do mapa.',
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
