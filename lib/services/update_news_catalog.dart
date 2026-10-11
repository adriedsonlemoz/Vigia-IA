import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.214', build: 214);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.214', build: 214),
      changes: <String>[
        'Resumo de próximos pontos e rota lado a lado para liberar espaço no mapa.',
        'Modos e ferramentas agora ficam dentro do menu Vigia IA.',
        'Segure um ponto no mapa para abrir a ficha e navegar até ele.',
        'Gravação junto das instruções e três comandos alinhados verticalmente.',
        'Crédito do mapa no canto inferior esquerdo.',
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
