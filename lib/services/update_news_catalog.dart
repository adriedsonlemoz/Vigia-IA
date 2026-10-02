import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.206', build: 206);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.206', build: 206),
      changes: <String>[
        'Alertas e histórico agora mostram o que foi visto: cachorro, gato, moto, carro, ônibus e outros, em vez de só Animal ou Automóvel.',
        'Quando só existe uma pista de movimento com cor de pele, o app mostra Possível pessoa e só avisa depois de confirmar em vários quadros.',
        'As frases de alerta padrão acompanham o nome do objeto; as que você personalizou continuam como estão.',
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
