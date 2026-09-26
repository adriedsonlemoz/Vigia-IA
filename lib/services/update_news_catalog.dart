import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.149', build: 149),
      changes: <String>[
        '🧭 Mapa e Bike passam a limpar juntos estados antigos quando a navegação é encerrada.',
        '🚗 TTC deixa de aparecer quando o dado está antigo ou a câmera/IA não está mais pronta.',
        '📴 POIs offline evitam usar pacotes salvos muito longe da região atual.',
        '📍 Categorias de POI desativadas somem imediatamente das listas e do mapa.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.148', build: 148),
      changes: <String>[
        '⚡ Mapa e Bike fazem menos atualizações e reconstruções desnecessárias.',
        '📍 GPS e POIs foram ajustados para reduzir CPU e bateria sem perder alertas.',
        '🌐 Buscas automáticas evitam consultas repetidas em sequência.',
        '📷 PiPs remotos deixam de reconstruir quando o estado da câmera não mudou.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.147', build: 147),
      changes: <String>[
        '🔧 Buildfix do Android-APK-110 para restaurar a análise estática do projeto.',
        '🗣️ Corrigida a nulabilidade na política de avisos de navegação por voz.',
        '📴 Ajustes técnicos do suporte offline eliminam avisos do analyzer sem mudar o comportamento.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.146', build: 146),
      changes: <String>[
        '📴 Navegação agora entra em fallback offline sem apagar a última rota conhecida.',
        '🔄 Quando a conexão volta, POIs e rota viária tentam se recuperar automaticamente.',
        '🗺️ O mapa indica claramente o estado offline e usa mapas/POIs salvos sem depender da internet.',
        '✨ HUD, zoom, filtros, banner de navegação e PiPs foram compactados para liberar mais área do mapa.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.145', build: 145),
      changes: <String>[
        '📍 Avisos de POIs relevantes respeitam categorias, distância configurada e dados offline.',
        '🔕 Um cooldown global evita sequências excessivas de alertas durante o percurso.',
        '🗣️ Navegação por voz anuncia próximas manobras, distância, saída da rota, recálculo e chegada.',
        '🔊 POIs e navegação reutilizam o sistema global de áudio/TTS e suas preferências.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.144', build: 144),
      changes: <String>[
        '🧠 Estados da IA agora aparecem claramente nos PiPs do mapa.',
        '🎞️ A interface diferencia IA ativa, analisando, aguardando frames e sem frames.',
        '📷 Falhas de câmera e conexão perdida ficam visíveis sem fingir que a IA está analisando.',
        '⚠️ Possíveis erros da IA ganham um estado próprio e compacto.',
      ],
    ),
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
