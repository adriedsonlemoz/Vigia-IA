import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.175', build: 175);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: currentVersion,
      changes: <String>[
        'Rotas de bicicleta longas agora podem ser organizadas em dias conforme sua média e o tempo diário de pedal.',
        'O plano de viagem sugere cidades, comunidades ou campings conhecidos próximos da rota quando esses dados estão disponíveis.',
        'A navegação mostra um acesso rápido ao plano por dias durante a cicloviagem.',
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
