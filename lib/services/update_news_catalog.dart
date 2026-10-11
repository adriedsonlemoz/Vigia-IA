import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.207', build: 207);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.207', build: 207),
      changes: <String>[
        'O diagnóstico RTSP agora guarda a etapa de abertura da câmera e identifica encerramentos anteriores do Android quando disponíveis.',
        'Uma câmera inacessível agora mostra aviso antes de abrir o player, sem expor senha ou URL completa no registro.',
        'Uma opção de compatibilidade permite testar o vídeo sem decodificação por hardware, com maior consumo de bateria.',
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
