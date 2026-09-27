import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.185', build: 185);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.185', build: 185),
      changes: <String>[
        'Clima, GPS, Velocidade, Altitude e Bússola agora abrem painéis de instrumentos responsivos e ricos sem cobrir desnecessariamente o mapa.',
        'Clima ganhou previsão horária de 12 horas e leitura para pedal; GPS mostra qualidade, idade e precisão da localização.',
        'Velocidade ganhou mostrador de sessão, Altitude mostra perfil real das leituras e Bússola ganhou rosa dinâmica com fonte e modo de orientação.',
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
