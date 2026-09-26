import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.164', build: 164),
      changes: <String>[
        '📊 Velocidade, Altitude, Bússola e GPS agora ocupam menos espaço no topo e deixam uma área maior do mapa visível.',
        '👆 Os quatro indicadores agora podem ser tocados para abrir detalhes úteis da leitura e da sessão.',
        '📍 Os detalhes mostram somente informações realmente disponíveis no aparelho e deixam claro quando alguma medição não está disponível.',
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
