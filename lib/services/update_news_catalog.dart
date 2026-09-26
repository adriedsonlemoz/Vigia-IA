import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.170', build: 170),
      changes: <String>[
        '🧭 A navegação 3D ficou mais suave e estável em bicicleta, moto, carro e caminhada, inclusive em curvas e manobras.',
        '🛣️ A rota, a posição atual e o destino ganharam mais destaque nos temas Padrão, Escuro, Alto contraste e Bike/Viagem.',
        '🏙️ Os prédios 3D ficaram mais discretos e a rota continua visível acima deles, mantendo o movimento manual do mapa sem disputa com o acompanhamento.',
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
