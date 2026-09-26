import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.165', build: 165),
      changes: <String>[
        '🛡️ O diagnóstico exportado do mapa 3D mantém informações úteis de inicialização sem expor chaves de acesso.',
        '📊 A telemetria compacta de Velocidade, Altitude, Bússola e GPS permanece disponível com detalhes baseados somente em leituras reais.',
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
