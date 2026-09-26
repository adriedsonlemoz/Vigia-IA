import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.168', build: 168),
      changes: <String>[
        '🗺️ O HUD do mapa ocupa menos espaço, com locais próximos, controles laterais e navegação mais compactos.',
        '🎨 O mapa ganhou os temas Padrão, Escuro, Alto contraste e Bike/Viagem, mantendo rota e posição bem visíveis.',
        '🌗 A aparência pode ser escolhida manualmente, seguir o tema do Android ou alternar entre dia e noite pelo horário local.',
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
