import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.143', build: 143),
      changes: <String>[
        '🚗 Aproximação de veículos integrada ao PiP da câmera analisada no mapa.',
        '⚠️ Estado de aproximação e nível de risco aparecem de forma compacta sem cobrir a navegação.',
        '⏱️ TTC visual reutiliza o estimador existente do Modo Bike, sem criar uma segunda análise.',
        '✨ Novidades da atualização passam a aparecer uma única vez por versão instalada.',
      ],
    ),
  ]);

  List<UpdateRelease> unseenReleases({
    required AppBuildVersion installed,
    AppBuildVersion? lastShown,
  }) {
    final matches = releases.where((release) {
      if (release.version.compareTo(installed) > 0) return false;
      if (lastShown != null && release.version.compareTo(lastShown) <= 0) {
        return false;
      }
      return true;
    }).toList(growable: false)
      ..sort((a, b) => a.version.compareTo(b.version));
    return matches;
  }
}
