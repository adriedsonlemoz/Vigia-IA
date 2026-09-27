import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.186', build: 186);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.186', build: 186),
      changes: <String>[
        'A versão 1.0.186 melhora a estabilidade da entrega dos novos painéis de instrumentos do mapa.',
        'Clima, GPS, Velocidade, Altitude, Bússola e Bike mantêm o mesmo comportamento visual da 1.0.185.',
        'A base foi ajustada para passar pela análise estática do pipeline sem avisos pendentes.',
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
