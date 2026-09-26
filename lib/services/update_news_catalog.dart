import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.162', build: 162),
      changes: <String>[
        '🎙️ O controle rápido de áudio mantém Navegação, IA/Detecções e Pontos próximos independentes e persistentes no mapa.',
        '📷 A segunda câmera permanece como visualização auxiliar, enquanto os alertas de IA continuam centralizados no pipeline principal de monitoramento.',
        '✨ Novidades da atualização continua mostrando somente o conteúdo desta versão instalada, sem misturar o histórico de versões anteriores.',
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
