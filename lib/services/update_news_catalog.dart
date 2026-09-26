import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.160', build: 160),
      changes: <String>[
        '🗺️ A navegação 3D agora usa mapa vetorial MapLibre: Stadia Outdoors quando há chave configurada e OpenFreeMap Liberty como alternativa sem chave.',
        '🧭 A câmera acompanha posição e direção com zoom e inclinação adaptativos à velocidade e à proximidade da próxima manobra, deixando o usuário mais abaixo para mostrar mais estrada à frente.',
        '👆 Ao mover o mapa 3D manualmente, o acompanhamento pausa e aparece o botão Centralizar para retomar o follow sem interromper a rota.',
        '🏙️ Prédios 3D são adicionados quando o estilo vetorial oferece dados compatíveis; se não houver suporte, a navegação continua normalmente sem derrubar o renderer.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.159', build: 159),
      changes: <String>[
        '🔊 O mapa ganhou um botão rápido de áudio na lateral, acessível também durante a navegação 3D.',
        '🧭 Navegação, IA/Detecções e Pontos próximos agora podem ser ligados ou silenciados de forma independente e persistente.',
        '🔕 O popup inclui Silenciar tudo sem abrir outra tela e mantém um atalho discreto para as configurações completas de Áudios e voz.',
        '💾 A voz da navegação é salva no mapa, Pontos próximos mantém sua preferência própria e os controles deixam de depender todos da mesma chave global.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.158', build: 158),
      changes: <String>[
        '🧭 Velocidade, altitude, bússola e GPS agora priorizam o valor principal com tipografia maior e leitura mais rápida durante o deslocamento.',
        '📐 Os quatro cards mantêm exatamente a mesma área do HUD, mas aproveitam melhor o espaço interno com ícone e título em cabeçalho compacto.',
        '🔎 Unidades como km/h e m ficam menores que o valor; quando altitude ou precisão GPS não estão disponíveis, o card mostra -- sem inventar dados.',
        '🗺️ Bússola, orientação do mapa e toda a navegação existente permanecem funcionais sem aumento da faixa superior.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.157', build: 157),
      changes: <String>[
        '🚲 O seletor de Bicicleta, Moto, Carro e A pé agora usa quatro cartões em grade 2 × 2, com ícone grande e indicação clara do modo selecionado.',
        '💾 O último perfil de transporte utilizado passa a ser persistido e volta selecionado por padrão mesmo depois de fechar e abrir o aplicativo.',
        '📱 O painel de escolha agora reserva explicitamente a área da barra de navegação do Android, tanto em três botões quanto em gestos, sem esconder controles ou textos.',
        '🛣️ Os quatro perfis continuam alterando o cálculo real da rota no Valhalla; nenhuma lógica foi reduzida a bicycle.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.156', build: 156),
      changes: <String>[
        '🔧 Corrigido o Android-APK-119, que parava no flutter analyze ao preparar o diagnóstico da navegação MapLibre 3D.',
        '🧩 O renderer 3D agora importa diretamente a extensão MapTravelModeX usada para registrar o perfil Bicicleta/Moto/Carro/A pé.',
        '🗺️ A correção é somente de compilação/análise estática e preserva a estabilização 2D → 3D, fallback, rota, GPS, voz, POIs e offline da versão anterior.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.155', build: 155),
      changes: <String>[
        '🗺️ O mapa 2D agora permanece visível enquanto o renderer MapLibre 3D inicializa, eliminando a troca prematura que podia deixar a navegação preta.',
        '🛡️ O 3D só aparece após mapa, estilo, rota, câmera e primeiro ciclo de render estarem prontos; falha ou timeout retorna automaticamente ao 2D.',
        '🧪 Falhas de criação, estilo, rota, câmera, timeout e fallback 3D → 2D passam a ser registradas no diagnóstico e na telemetria interna.',
        '📴 Offline continua usando automaticamente FlutterMap/MBTiles sem tentar manter o renderer 3D.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.154', build: 154),
      changes: <String>[
        '🔧 Corrigido o Android-APK-117, que falhava ao configurar o MapLibre Android durante o build release.',
        '🧩 O Gradle agora resolve explicitamente a versão do plugin ktlint exigido pelo maplibre_android 0.3.6.',
        '🗺️ A navegação 3D, os modos Bicicleta/Moto/Carro/A pé e o fallback 2D/offline permanecem sem alteração funcional.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.153', build: 153),
      changes: <String>[
        '🔧 Corrigido o bloqueio do Android-APK-116 na análise estática da primeira etapa do mapa 3D.',
        '🗺️ Removidas assertions de nulabilidade redundantes no destino de navegação 3D, sem mudar rota, câmera, POIs ou fallback 2D.',
        '🧪 A correção preserva seleção de Bicicleta/Moto/Carro/A pé e a entrada automática no renderer 3D durante rotas online.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.152', build: 152),
      changes: <String>[
        '🧭 Ao iniciar uma rota online, o Vigia IA entra automaticamente na primeira etapa da navegação em perspectiva 3D.',
        '🚲 Antes de navegar, agora é possível escolher Bicicleta, Moto, Carro ou A pé; o perfil escolhido também é salvo no destino.',
        '🛣️ O roteamento passa a solicitar ao Valhalla um caminho adequado ao modo de transporte selecionado, mantendo alternativas e recálculo.',
        '🗺️ A navegação 3D acompanha posição e rumo, permite voltar ao mapa 2D e usa o renderer 2D atual como fallback offline.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.151', build: 151),
      changes: <String>[
        '🔧 Corrigido o bloqueio do build Android-APK-114 na análise estática.',
        '🗺️ O suporte a mapas offline deixa de manter um estado interno sem uso, sem alterar o funcionamento do MBTiles.',
        '🧪 A falha ao abrir um pacote offline continua registrada no diagnóstico técnico do app.',
      ],
    ),
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.150', build: 150),
      changes: <String>[
        '🗺️ O mapa ganha um HUD reorganizado, mais próximo do visual Bike/Viagem planejado.',
        '⚙️ Configurações, camadas e pontos próximos agora têm botões próprios e funções separadas.',
        '🧭 Velocidade, altitude, bússola e GPS usam cards quadrados; a bússola também alterna a orientação do mapa.',
        '📍 Tocar em um POI abre um card compacto com Detalhes e Navegar, e o mapa aceita rotação manual por gesto.',
      ],
    ),
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
