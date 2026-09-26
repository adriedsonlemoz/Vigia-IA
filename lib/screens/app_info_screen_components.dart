part of 'app_info_screen.dart';

class _AboutPanel extends StatelessWidget {
  const _AboutPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.shield_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppMetadata.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('Vigilância local com IA offline'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _InfoRow(
            label: 'Versão',
            value: '${AppMetadata.version}+${AppMetadata.build}',
          ),
          const _InfoRow(label: 'Desenvolvedor', value: AppMetadata.developer),
          const Divider(height: 28),
          const Text(
            'O Vigia IA usa a câmera do dispositivo, RTSP, outro celular ou uma câmera ESP32 para analisar objetos localmente no aparelho receptor, registrar eventos e emitir alertas sem depender de serviços de nuvem para a IA.',
          ),
        ],
      ),
    );
  }
}

/// Histórico completo preservado para consulta de desenvolvimento.
class AllChangesPanel extends StatelessWidget {
  const AllChangesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ReleaseCard(
          version: '1.0.157',
          current: true,
          changes: [
            'Bicicleta, Moto, Carro e A pé agora aparecem em uma grade 2 × 2 mais compacta e visual.',
            'O último perfil utilizado fica salvo e volta selecionado por padrão na próxima navegação.',
            'O seletor respeita a área segura inferior do Android em navegação por gestos e por três botões.',
            'Os quatro modos continuam usando perfis reais e distintos no cálculo da rota.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.156',
          changes: [
            'Corrigido o Android-APK-119 no flutter analyze.',
            'O renderer MapLibre 3D agora importa diretamente a extensão usada para serializar o modo de transporte no diagnóstico.',
            'A correção preserva integralmente a estabilização e o fallback 2D → 3D da etapa anterior.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.155',
          changes: [
            'Corrigida a tela preta ao entrar na navegação MapLibre 3D.',
            'O FlutterMap 2D permanece visível até mapa, estilo, rota, câmera e primeiro render do 3D estarem prontos.',
            'Falhas e timeout do MapLibre acionam fallback automático para 2D e ficam registradas no diagnóstico e na telemetria.',
            'Offline continua usando automaticamente o mapa 2D/MBTiles.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.154',
          changes: [
            'Corrigido o Android-APK-117 no build release do MapLibre Android.',
            'O plugin Gradle ktlint exigido pelo maplibre_android 0.3.6 agora recebe uma versão explícita pelo pluginManagement.',
            'A correção é de infraestrutura de build e preserva a navegação 3D e o fallback 2D/offline.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.153',
          changes: [
            'Corrigido o bloqueio do Android-APK-116 no flutter analyze.',
            'Removidas assertions ! redundantes no destino da navegação 3D.',
            'A correção não altera o comportamento do mapa 3D, roteamento, modos de transporte ou fallback 2D.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.152',
          changes: [
            'Primeira etapa da navegação 3D: rotas online passam a usar um renderer MapLibre inclinado durante o acompanhamento.',
            'Antes de navegar, é possível escolher Bicicleta, Moto, Carro ou A pé.',
            'O perfil escolhido é enviado ao roteamento e persistido com o destino, preservando alternativas, voz e recálculo.',
            'O usuário pode voltar ao mapa 2D a qualquer momento; offline continua usando o renderer 2D existente.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.151',
          changes: [
            'Corrigido o aviso de análise estática que bloqueava o Android-APK-114.',
            'Removido o estado interno de erro offline que era gravado, mas nunca lido pela interface.',
            'Falhas de abertura de MBTiles continuam registradas no log técnico sem mudar o comportamento do mapa offline.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.150',
          changes: [
            'HUD do mapa reorganizado com engrenagem à esquerda, Perto/Região/Rota no topo e camadas em botão próprio.',
            'Velocidade, altitude, bússola e GPS agora usam cards quadrados mais legíveis.',
            'O botão de pontos próximos virou um marcador dedicado, a câmera ganhou atalho abaixo do card de locais e Gravar foi fixado no canto inferior direito.',
            'POIs abrem um card compacto com Detalhes/Navegar e o mapa volta a aceitar rotação manual por gesto.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.149',
          changes: [
            'Mapa e Bike passam a limpar juntos a rota local quando a navegação é encerrada fora da tela do mapa.',
            'TTC antigo deixa de aparecer quando perde validade ou quando câmera/IA deixa de estar pronta.',
            'POIs offline rejeitam pacotes distantes e categorias desativadas somem imediatamente da interface.',
            'O mini mapa automático permanece disponível durante uma navegação ativa, mesmo com a bicicleta parada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.148',
          changes: [
            'GPS do mapa reduz amostras redundantes sem perder a precisão necessária para navegação Bike.',
            'POIs continuam precisos para alertas, mas a interface deixa de reconstruir a cada ponto do GPS.',
            'Buscas automáticas de POIs ganham cooldown e câmeras remotas deduplicam estados repetidos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.147',
          changes: [
            'Buildfix do Android-APK-110: corrigida a nulabilidade na política de voz que bloqueava o flutter analyze.',
            'Suporte offline deixa de chamar setState diretamente pela extension, eliminando avisos de membro protegido.',
            'Removidos avisos estáticos redundantes sem alterar navegação, POIs, offline ou layout do mapa.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.146',
          changes: [
            'Navegação preserva a última rota viária conhecida quando a internet cai e deixa claro quando só há direção ao destino.',
            'POIs offline entram imediatamente durante perda de conexão e a busca online volta automaticamente após recuperação.',
            'O seletor de camada mostra Sem internet/Offline automático sem adicionar outra barra sobre o mapa.',
            'Controles, filtros, banner de navegação e PiPs foram compactados em retrato e paisagem para ampliar a área útil.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.145',
          changes: [
            'Avisos de POIs respeitam categorias escolhidas, distância configurada, direção do deslocamento e pacotes offline.',
            'Cooldown global e consumo de marcos já ultrapassados evitam sequências repetitivas de avisos próximos.',
            'Navegação por voz anuncia próxima manobra e distância em marcos progressivos, com prioridade perto da conversão.',
            'Saída da rota, recálculo, rota recalculada e chegada recebem avisos falados usando as preferências globais de áudio/TTS.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.144',
          changes: [
            'PiPs mostram IA ativa, IA desligada, aguardando frames, sem frames, analisando e possível erro da IA.',
            'Falhas da câmera local aparecem como Câmera indisponível; fontes de rede distinguem Conexão perdida.',
            'O estado Analisando só é permitido quando a IA está realmente habilitada e o detector está pronto.',
            'Câmeras abertas apenas para visualização deixam IA desligada explícita sem criar outro pipeline de análise.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.143',
          changes: [
            'PiP da câmera analisada no mapa passa a mostrar aproximação de veículos usando o mesmo estimador TTC do Modo Bike.',
            'O indicador diferencia veículo sem aproximação, atenção, risco alto e risco crítico sem bloquear informações da navegação.',
            'Novo sistema global de Novidades da atualização aparece uma única vez por versão instalada e funciona offline.',
            'A versão instalada é lida do Android e o histórico exibido é persistido localmente por versão + build.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.142',
          changes: [
            'Corrigido o Android-APK-107: o teste do painel de POI agora rola até a comodidade realmente ficar visível.',
            'A rolagem usa scrollUntilVisible e não depende mais de um deslocamento fixo que podia apenas expandir o painel.',
            'Nenhum comportamento de produção do mapa, painel de POI ou PiPs foi alterado neste buildfix.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.141',
          changes: [
            'Corrigido o Android-APK-106: o teste do painel de POI agora rola a lista antes de validar comodidades fora da área inicial.',
            'A correção não altera o painel nem o PiP em produção; apenas torna o teste compatível com a construção lazy do ListView.',
            'flutter analyze já havia passado sem avisos no build 106; a falha estava isolada em um único teste de widget.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.140',
          changes: [
            'PiPs lembram a visibilidade global e ganham atalho Mostrar câmera quando todas as janelas estiverem ocultas.',
            'Durante a navegação, câmeras grandes reduzem temporariamente para preservar rota e instruções sem perder o tamanho salvo.',
            'Encaixe automático evita duas câmeras no mesmo canto e mantém organização adequada em retrato e paisagem.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.139',
          changes: [
            'POI selecionado ganha painel completo com categoria, distância, origem, endereço, horário, telefone, site, operador e comodidades.',
            'Endereço, telefone, site e coordenadas podem ser copiados rapidamente sem sair do mapa.',
            'Ação principal passa a ser Ir até lá, mantendo Mostrar no mapa como ação secundária.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.138',
          changes: [
            'POIs preservam endereço, horário, telefone, site e comodidades quando essas informações estão disponíveis.',
            'Mapa ganha categorias próprias para camping, mirantes, cachoeiras e mercados, além de filtros Natureza e Bike/viagem.',
            'Pacotes offline preservam os dados enriquecidos e instalações antigas recebem as novas categorias sem reinstalação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.137',
          changes: [
            'Roteamento ciclável passa a solicitar até duas alternativas adicionais quando o servidor consegue fornecê-las.',
            'Mapa desenha as alternativas de forma secundária e mantém a rota ativa em destaque.',
            'Banner permite comparar distância e duração e trocar a rota ativa sem encerrar a navegação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.136',
          changes: [
            'Navegação guiada mostra instrução atual, próxima manobra, distância até a ação e progresso da rota.',
            'Saída confirmada da rota dispara recálculo automático a partir da posição atual, com proteção contra chamadas repetidas.',
            'Navegação restaurada recupera novamente a rota viária e mantém direção direta como fallback se o serviço falhar.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.135',
          changes: [
            'Corrige o Android-APK-102, que parava no flutter analyze antes dos testes e do build Android.',
            'Remove cinco assertions nulas redundantes no card do POI selecionado, eliminando os avisos unnecessary_non_null_assertion.',
            'Mantém inalterados a rota ciclável, o HUD de navegação e o fallback por direção direta da 1.0.134.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.134',
          changes: [
            'Mapa calcula rota viária real para bicicleta ao escolher um destino, desenhando o trajeto sobre as vias.',
            'HUD da navegação mostra distância e duração estimadas da rota ciclável.',
            'Se o roteamento online falhar, a navegação continua disponível por direção direta.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.133',
          changes: [
            'Refinamento visual do mapa após revisão em vídeo: POIs agora usam clustering, densidade por zoom e cores/ícones por categoria.',
            'HUD fica mais leve: telemetria prioriza velocidade/altitude, lateral mantém zoom/seguir/opções e tempo/distância migram para a barra compacta de percurso.',
            'PiPs ganham bolha minimizada, duplo toque para tamanho, arranjo automático da segunda câmera e troca direta entre câmera 1 e 2 para fontes abertas pelo mapa.',
            'Barras do Android recebem contraste próprio sobre mapas claros e o card do POI não fica duplicado quando ele já virou destino de navegação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.132',
          changes: [
            'Correção do Android-APK-99: MapMonitoringScreen volta a importar explicitamente OfflinePoiPackage, eliminando dois erros undefined_class no flutter analyze.',
            'MapRouteService remove import redundante de flutter/foundation.dart, eliminando o issue unnecessary_import do analyzer.',
            'Verificador preventivo passa a exigir o import do modelo de pacote offline e a bloquear a reintrodução do import redundante.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.131',
          changes: [
            'UX final do mapa: HUD responsivo em telas estreitas/paisagem, zoom consolidado e camadas acessíveis pelo chip superior sem duplicar controles.',
            'PiPs passam a respeitar zonas seguras do HUD e dos cards inferiores; persistência de posição foi corrigida e há ação para restaurar o layout.',
            'Ações do PiP foram condensadas em um menu para não cobrir a imagem em tamanhos pequenos; tela de GPS indisponível também segue o visual sem AppBar grande.',
            'Revisão final corrige atualização de pacotes offline para buscar dados novos pela internet sem apagar o cache salvo quando a atualização falha.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.130',
          changes: [
            'Mapa passa a gerenciar duas câmeras diretamente: fonte local/traseira, frontal, RTSP, celular remoto, ESP32 e câmeras já abertas pelo Monitor.',
            'PiPs podem trocar fonte, minimizar, ocultar, alternar tamanho e encaixar nos cantos; posição, tamanho e estado visual ficam persistidos.',
            'Fontes abertas só pelo mapa são suspensas ao minimizar, ocultar ou mandar o app ao fundo, sem interromper a câmera de IA já usada pelo Monitor.',
            'Desempenho do mapa melhora com cronômetro isolado, GPS por consumidores, recálculo de POIs apenas em GPS novo e redução visual de percursos muito longos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.129',
          changes: [
            'Mapa ganha camadas Padrão, Bike/Viagem, Terreno, Topográfico e Satélite, preservando OSM como opção gratuita e usando a chave Stadia existente apenas quando necessária.',
            'Controles são reorganizados: funções secundárias passam para Opções, reduzindo a coluna permanente sem esconder Próximos pontos, offline e configurações.',
            'Próximos pontos passa a usar pacotes offline regionais com nome, área, data e quantidade de locais, incluindo migração da antiga lista única.',
            'POI selecionado permanece destacado com card compacto e ações; atualização automática passa a considerar movimento, tempo, direção e borda da área mesmo sem gravar percurso.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.128',
          changes: [
            'Corrigido o Android-APK-95 que parava no flutter analyze por usar Icons.offline_map_rounded, inexistente no Flutter 3.44.9.',
            'O botão Mapas offline passa a usar download_for_offline_outlined, já compatível com a versão estável usada no workflow.',
            'Verificação preventiva passa a rejeitar o identificador de ícone inválido antes de uma nova tentativa de build.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.127',
          changes: [
            'Mapa ganha visão à frente: ao seguir o GPS, o usuário fica abaixo do centro para mostrar mais estrada no sentido do deslocamento.',
            'Novo controle alterna Norte fixo e acompanhamento por direção, com rotação suavizada por dead-zone e sem tremedeira quando parado.',
            'Atalhos Perto, Região e Rota mudam rapidamente o enquadramento; Rota ajusta a câmera ao percurso gravado e/ou destino ativo.',
            'Preferência de orientação e visão de acompanhamento é persistida, e o mapa deixa de recentralizar a câmera a cada tick do cronômetro.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.126',
          changes: [
            'GPS passa por filtro de precisão, ordem temporal, velocidade e deslocamento plausível antes de mover a posição do mapa.',
            'Gravação de percurso usa precisão mais rigorosa, suavização de posição/rumo e limiar contra jitter para evitar distância artificial.',
            'Gravar percurso fica separado de Navegar até: POIs podem virar destino persistente com distância e rumo direto.',
            'Persistência sobe para schema 3, preserva migração do estado anterior e corrige retomada após recriação do processo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.125',
          changes: [
            'Mapa completo passa a usar praticamente toda a tela, sem AppBar fixa, com controles flutuantes que respeitam notch e navegação.',
            'Próximos pontos agora aparece também no mapa como marcadores filtráveis, com lista, foco do ponto tocado, atualização e cache offline.',
            'Zoom, seguir GPS, câmeras, mapas offline, configurações e gravação de rota ficam acessíveis sobre o mapa em retrato e paisagem.',
            'Percursos quebram o segmento após saltos grandes de GPS e a busca no caminho se renova automaticamente durante rotas ativas.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.124',
          changes: [
            'Sensores e recursos passam a mostrar separadamente leitura ativa, detecção do firmware, espera por leitura e estado offline.',
            'Sensor novo informado pelo ESP32 aparece como detectado e não configurado, com atalho para revisar o wizard.',
            'Firmware legado pode ter Hall, pneus, temperatura, bateria e energia inferidos pelos valores reais recebidos, mesmo sem capabilities.',
            'Wi-Fi, endpoint, uptime, sequência e reconexão ficam em Conexão, sem misturar rede com valores dos sensores.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.123',
          changes: [
            'ESP32 ganha capacidade Energia separada da bateria do próprio módulo, permitindo monitorar a bateria principal sem acoplar as duas alimentações.',
            'Wizard aceita testes por power bank/tomada sem bateria e perfis de chumbo-ácido ou LiFePO₄ para a instalação definitiva.',
            'Preparados divisor de tensão, INA219, INA226, BMS e entrada solar; /config e telemetria ganham bloco de energia opcional.',
            'Card e diagnóstico passam a mostrar bateria principal, corrente, potência e solar sem confundir esses dados com a bateria do ESP32.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.122',
          changes: [
            'A configuração do ESP32 passa para um assistente em 5 etapas: conexão, identificação, capacidades, ajustes e revisão.',
            'A busca inicial tenta o endereço informado e os candidatos 192.168.4.1/esp32.local, mantendo endereço e chave manual como opção.',
            'Sensores mostram apenas os ajustes relevantes; capacidades futuras continuam no mesmo cadastro e as detectadas pelo firmware são aproveitadas.',
            'Corrigido o Android-APK-90 removendo o import redundante apontado pelo flutter analyze e eliminado o botão duplicado de conexão.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.121',
          changes: [
            'Telemetria ESP32 passa a ser lida continuamente pelo app, com descoberta automática de endpoints novos e compatibilidade com /status legado.',
            'Cada módulo mantém estado próprio de conexão, latência, RSSI, firmware, protocolo, bateria, falhas e próxima tentativa de reconexão.',
            'Vários ESP32 podem contribuir para o HUD ao mesmo tempo sem alternar a fonte; sensores ausentes deixam de gerar alertas falsos.',
            'Reconexão automática usa backoff e o diagnóstico/exportação passa a incluir o estado detalhado dos módulos ESP32.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.120',
          changes: [
            'ESP32 passa a ser cadastrado como módulo independente; câmera vira uma capacidade opcional e continua aparecendo normalmente como fonte quando instalada.',
            'Cadastros antigos são migrados automaticamente e cada módulo pode guardar posição, capacidades, calibração, limites e intervalo de telemetria.',
            'A base já reconhece múltiplos moduleId e capacidades futuras como mmWave, térmico, ToF, ultrassom, GPS e atuadores.',
            'Timeout da telemetria acompanha o intervalo configurado e os limites de pressão/temperatura passam a controlar os alertas do HUD.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.119',
          changes: [
            'A Home passa a usar os novos ícones transparentes de Ao vivo, Transmissão, Remoto e ESP32 diretamente nos cards.',
            'Os filtros do Histórico foram refeitos para manter ícones e rótulos Todos, Pessoas, Veículos e Animais alinhados sem check duplicado.',
            'Em Câmeras, Monitorar fica compacto ao lado do nome da câmera; abrir com segunda câmera continua disponível no menu.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.118',
          changes: [
            'Perfis Bike passam a preservar mais informação visual: Economia usa 7 FPS/960 px/JPEG 76 e Economia extrema 5 FPS/800 px/JPEG 72.',
            'Áudios e voz ganhou controle por fala: cada aviso pode ser ativado ou silenciado individualmente, com ações para ativar ou silenciar todos.',
            'TTS de fallback fica desligado por padrão para evitar mistura de vozes; mensagens sem áudio integrado continuam configuráveis separadamente.',
            'As falas Bike/ESP32 deixam de ser marcadas como futuras e o emulador dispara áudios integrados para os cenários simulados.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.117',
          changes: [
            'Home reorganizada em quatro cards compactos: Ao vivo, Transmissão, Remoto e ESP32; os cinco acessos rápidos ficam na mesma linha no celular.',
            'Bike deixa de ser um modo inicial e passa a ser um perfil em Ajustes > Bike e economia, sem apagar as preferências existentes.',
            'O emulador de sensores foi movido para a engrenagem da tela ESP32 e continua reutilizando o mesmo contrato de telemetria.',
            'Transmissão ganhou engrenagem para alterar Bike/economia sem trocar de modo, bateria do aparelho atual e política de frames separada da frequência da IA.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.116',
          changes: [
            'Corrigido o Android-APK-84: os dois testes de layout compacto agora cabem sem RenderFlex overflow.',
            'Cards compactos da Home ganharam espaçamentos, ícones e tags mais densos sem remover título, descrição ou indicadores.',
            'Acessos rápidos foram reduzidos para manter Diagnóstico legível em células estreitas da grade responsiva.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.115',
          changes: [
            'Home compactada em grade 2x2 com Monitor ao vivo, Modo transmissão, Modo Bike e acesso dedicado ao ESP32.',
            'ESP32 saiu da lista geral de Monitoramento em Ajustes e abre diretamente sua tela existente de módulo, sensores e câmera.',
            'Configurações do mapa e percurso ficaram mais compactas, com categorias, alertas, distâncias e ações offline reduzidas sem duplicar serviços.',
            'Acessos rápidos passam a usar grade responsiva para evitar rótulos cortados em celulares estreitos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.114',
          changes: [
            'Corrigido o Android-APK-82: ButtonStyle usa minimumSize compatível com Flutter 3.44.9.',
            'Corrigidos delimitadores no monitor multicâmera que geravam a cascata de erros de parser no analyzer.',
            'Toggles da Home atualizam o estado por helper do próprio State e warnings privados sem uso foram removidos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.113',
          changes: [
            'Iniciado o redesign amplo com um design system compartilhado para tema, cards, botões, chips, painéis e navegação.',
            'A Home agora destaca Monitor ao vivo, Modo transmissão e Modo Bike, com acessos rápidos para Câmeras, Mapa, Histórico, Diagnóstico e Ajustes.',
            'Configurações técnicas do monitor foram preservadas e recolhidas em Preparar monitoramento para reduzir poluição visual sem remover funções.',
            'A navegação principal passa a incluir Ajustes como quinto destino e adota a mesma linguagem visual em retrato e paisagem.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.112',
          changes: [
            'Mapa abre diretamente Próximos pontos, com filtros rápidos, distância, categoria e origem Online/Offline.',
            'Configurações do mapa e percurso ficam separadas na engrenagem, incluindo raio, categorias, alertas, dados e mapas offline.',
            'Câmera permite Ligada, Desligada ou Mapa, que expande para ocupar a área principal da transmissão.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.111',
          changes: [
            'O botão Mapa passou a abrir o painel Mapa e percurso com busca por raio, lista de resultados e atalhos do mapa.',
            'A exploração consulta postos, restaurantes, paradas, oficinas, saúde, água/banheiro e rios/pontes.',
            'A lista pode ser salva para uso offline e alimentar alertas por fala e notificação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.110',
          changes: [
            'A fileira fixa do monitor agora tem cinco ações: Câmera, Mapa, Áudio, Painel e Ajustes.',
            'O botão Mapa mostra ou oculta o mini mapa diretamente e destaca o estado quando ele está visível.',
            'Corrigido o Android-APK-78: o ZIP-fonte volta a preservar o .gitignore exigido pela verificação de segurança da assinatura.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.109',
          changes: [
            'O menu dos três pontinhos do monitor Ao vivo agora traz um atalho Mostrar mapa / Ocultar mapa, funcionando mesmo fora do modo bicicleta.',
            'Quando o mapa foi forçado ou ocultado, o mesmo menu oferece Mapa automático para voltar ao comportamento inteligente anterior.',
            'A preferência continua persistida no serviço de rota, então o estado escolhido é lembrado na próxima abertura do monitor.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.108',
          changes: [
            'Corrigido o Android-APK-76 restaurando ic_launcher, LaunchTheme e NormalTheme que faltavam no projeto Android versionado.',
            'Recursos nativos agora ficam preservados no ZIP-fonte e são verificados antes do build.',
            'A compilação única de universal + três ABIs, o cache e o paralelismo continuam ativos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.107',
          changes: [
            'Corrigido o Android-APK-75, que falhava ao compilar o script Gradle Android antes de gerar os APKs.',
            'build.gradle.kts foi alinhado ao template oficial do Flutter 3.44.9: Kotlin explícito legado removido e compilerOptions moderno aplicado.',
            'A compilação única de universal + três ABIs, o cache e o paralelismo da 1.0.106 foram preservados.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.106',
          changes: [
            'Workflow Android otimizado para gerar APK universal e APKs por ABI em uma única compilação Gradle.',
            'Cache e paralelismo do Gradle foram ativados; o projeto Android versionado deixa de ser recriado em todo build.',
            'setup-gradle foi atualizado para v6 e a coleta dos APKs agora usa o output-metadata do Android.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.105',
          changes: [
            'Corrigido o Android-APK-73 removendo dois imports que faziam o flutter analyze encerrar o workflow.',
            'Mapa e câmeras preservam o comportamento da 1.0.104; a mudança é uma correção estática de build.',
            'Verificadores ganharam proteção contra a reintrodução dos dois apontamentos encontrados no log.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.104',
          changes: [
            'Configuração Stadia ganhou painel completo com status da chave, Colar, Ver, Copiar, Testar, Trocar e Remover.',
            'Seleção offline ganhou modos Mapa/Área e controles de zoom − / z / + na parte inferior.',
            'Mapa completo moveu velocidade, distância, tempo, altitude, rumo e acompanhamento para chips no topo; embaixo fica somente Iniciar/Encerrar rota.',
            'Câmera principal e segunda câmera podem aparecer juntas sobre o mapa, são arrastáveis, podem ser ocultadas e adaptam o PiP à proporção detectada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.103',
          changes: [
            'Corrigido o warning unnecessary_non_null_assertion que interrompia o flutter analyze no Android-APK-71.',
            'Mapas offline agora mostram créditos estimados antes do download: um tile raster padrão corresponde a aproximadamente um crédito.',
            'Adicionado contador mensal local persistente, limite configurável e bloqueio preventivo quando o download ultrapassaria o saldo definido.',
            'O contador deixa claro que mede apenas downloads diretos feitos neste aparelho e não substitui o consumo exibido no painel da Stadia Maps.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.102',
          changes: [
            'Configurar fonte ganhou ajuda Como conseguir a chave? com passo a passo para obter a API key da Stadia Maps.',
            'A ajuda abre diretamente o painel oficial da Stadia Maps e a documentação de API keys.',
            'Se o navegador não puder ser aberto, o link oficial é copiado; a credencial continua protegida pelo Android Keystore.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.101',
          changes: [
            'O planejamento de mapas offline agora limita raio, margem e zoom ao espaço seguro restante, sem permitir configurações impossíveis acima do cache disponível.',
            'Ajustar ao limite disponível preenche automaticamente a maior combinação válida e a tela explica a reserva de segurança dentro do teto de 100 MB.',
            'Selecionar região ganhou um quadro visual arrastável e redimensionável para escolher exatamente a área que será preparada para download.',
            'O mapa completo ganhou painel de navegação mais informativo com altitude, rumo, precisão do GPS e estado Seguindo/Mapa livre.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.100',
          changes: [
            'Corrigidos quatro apontamentos do flutter analyze encontrados no Android-APK-68.',
            'O suporte MBTiles do mini-mapa deixou de chamar setState diretamente pela extension e reutiliza o refresh seguro do State.',
            'O stream de localização usa atribuição condicional e a comparação de expiração do mapa offline não mantém operador nulo desnecessário.',
            'Nenhuma funcionalidade de mapas offline, rota, GPX, câmera ou IA foi alterada nesta correção de build.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.99',
          changes: [
            'Mapas offline agora podem ser baixados diretamente por região ou corredor do trajeto usando uma fonte autorizada configurada pelo usuário.',
            'O download mostra progresso, tiles e bytes, respeita limite de cache, pode ser pausado/retomado ou cancelado e mantém importação/link MBTiles.',
            'A rota compartilhada ganhou Pausar/Continuar sem criar saltos de distância e pode ser exportada em GPX pelo seletor do Android.',
            'Pacotes offline guardam limites geográficos e validade estimada para avisar quando a posição sair da área baixada ou quando a atualização for recomendada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.98',
          changes: [
            'O mapa do Monitor ganhou modos Automático, Sempre mostrar e Ocultar; no automático ele some em monitoramento doméstico e reaparece com Bike, rota ativa ou deslocamento por GPS.',
            'Mini-mapa e mapa completo agora compartilham uma única sessão de trajeto persistente, restaurada ao reabrir o app.',
            'Mapas offline agora permitem importar MBTiles do aparelho e planejar Região atual, Selecionar região ou Trajeto com estimativa de tamanho e espaço livre.',
            'O mapa completo identifica a fonte como Online, Offline ou Mapa local e mantém a câmera principal flutuante e arrastável.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.97',
          changes: [
            'Corrigido o teste de AppMetadata que ainda esperava a versão 1.0.95 e interrompia o workflow da 1.0.96.',
            'O verificador de sincronização agora confere também as expectativas de versão e build do teste de metadados.',
            'Nenhuma funcionalidade de mapa, câmera ou IA foi alterada nesta correção de build.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.96',
          changes: [
            'O mapa completo ganhou suporte a pacotes MBTiles baixados e armazenados no aparelho.',
            'Mapas offline oferece modos Automático, Online e Offline, com seleção, progresso e exclusão de pacotes.',
            'No modo Automático, o mapa local funciona como base/fallback enquanto a camada online atualiza os tiles quando houver rede.',
            'Ao abrir o mapa pelo Monitor, a câmera principal aparece em PiP flutuante e pode ser arrastada por toda a área útil da tela.',
            'O servidor público do OpenStreetMap continua restrito ao uso online normal; o app não faz download em massa dele.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.95',
          changes: [
            'Cards de velocidade, temperatura, pneus e distância ficaram mais estreitos para caber mais telemetria na mesma linha.',
            'O mapa vertical ficou ainda mais alto e qualquer toque na área útil abre a tela completa; o botão Abrir mapa foi substituído por Câmera.',
            'O botão Câmera centraliza fonte principal, modo com uma ou duas câmeras, frontal de teste, ESP32 e demais câmeras cadastradas.',
            'Áudio, Painel e Ajustes receberam contraste correto para não parecerem desabilitados, e os seis atalhos do painel passam a caber em uma linha quando houver largura.',
            'O botão de áudio superior e as entradas duplicadas de câmeras/Status da sessão foram removidos do menu superior.',
            'Duplo toque na área de vídeo entra em tela inteira; a identificação da principal foi reduzida para Local e o PiP da segunda câmera agora pode ser arrastado dentro da área de vídeo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.94',
          changes: [
            'O mapa vertical ficou mais alto e o card Detectados foi deslocado para baixo sem esconder os quatro atalhos.',
            'Abrir mapa, Áudio, Painel e Ajustes agora ficam sempre na mesma linha com margens e altura menores.',
            'O mapa passa a mostrar altitude real do GPS em destaque menor, sem o rótulo Bike; a distância continua na telemetria superior.',
            'Cards de velocidade, temperatura e pneus ficaram mais compactos para caber mais telemetria do ESP32.',
            'Foi adicionado um teste temporário de segunda câmera frontal em janela PiP; a IA continua somente na câmera principal.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.93',
          changes: [
            'O bloco grande Detectados agora saiu da tela fixa e virou um resumo compacto tocável.',
            'Os detalhes das detecções agora sobem em um painel arrastável, liberando espaço vertical.',
            'O mini-mapa ganhou rótulos curtos, controles menores e organização mais limpa.',
            'A faixa de telemetria da bike ficou mais compacta para priorizar temperatura, pneus e câmera.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.92',
          changes: [
            'O aplicativo fica travado em retrato fora do modo Transmissão.',
            'O modo Transmissão acompanha livremente a posição física do celular, sem forçar paisagem.',
            'A tela inteira do Monitor permanece vertical e não altera mais a orientação do aparelho.',
            'A rotação dos frames continua usando a orientação do sensor e do dispositivo antes do envio.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.91',
          changes: [
            'Corrigido o lint unnecessary_underscores no separador horizontal da tela vertical do Ao vivo.',
            'O flutter analyze deixa de falhar nesse ponto sem mudança visual ou funcional no Monitor.',
            'A tela vertical com câmera maior, mapa e painel da 1.0.90 foi preservada integralmente.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.90',
          changes: [
            'Tela vertical do Ao vivo redesenhada com câmera maior, mapa do trajeto e ações mais organizadas.',
            'Mini-mapa foi integrado ao modo retrato com rota, distância e botão para abrir a tela completa.',
            'Atalhos avançados saíram da faixa fixa e agora ficam no botão Painel, liberando espaço para a câmera e as detecções.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.89',
          changes: [
            'Corrigidos quatro avisos invalid_use_of_protected_member do dashboard Ao vivo.',
            'A extensão do dashboard não chama mais setState diretamente; a atualização passa pela State do Monitor.',
            'Visual da 1.0.88 com câmera, mapa, telemetria e ações rápidas foi preservado.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.88',
          changes: [
            'Tela Ao vivo em paisagem redesenhada com câmera, mapa do trajeto, telemetria da bike e ações rápidas.',
            'Detecções da câmera única passam a abrir em painel dedicado sob demanda, liberando mais espaço para o vídeo.',
            'Mini-mapa usa o GPS local quando disponível e orienta o usuário quando a localização ainda não foi liberada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.87',
          changes: [
            'Corrigida a ordem da diretiva part of no componente do Modo Bike.',
            'Eliminado o erro directive_after_declaration que bloqueava o flutter analyze no workflow.',
            'Mapa, GPS e registro de rota da 1.0.86 foram preservados sem alteração funcional.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.86',
          changes: [
            'Modo Bike ganha Mapa do monitoramento com OpenStreetMap e GPS local.',
            'Mapa mostra posição, precisão, velocidade, distância, tempo e última atualização.',
            'Rotas podem ser iniciadas e encerradas, preservando linha do trajeto e marcadores de início/fim durante a sessão.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.85',
          changes: [
            'Faixa de telemetria ESP32/Bike reorganizada em uma única linha horizontal rolável.',
            'Velocidade, temperatura, pneus, sensores/simulação e distância ficam mais compactos e liberam altura para a câmera.',
            'Diagnóstico compacta estados e deixa os botões de desempenho alinhados na mesma linha.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.84',
          changes: [
            'Corrigida a compilação dos rótulos adaptativos na Central de Câmeras.',
            'Configurações não mantém mais parâmetro interno de expansão sem uso.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.83',
          changes: [
            'Cadastro de celular e câmera RTSP agora explica o tipo de fonte antes da conexão.',
            'Central compacta ações e mostra modelo, resolução, FPS e bateria da câmera remota quando disponíveis.',
            'Alterar modo fica acessível sem apagar dados; Configurações e Histórico também foram reorganizados.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.82',
          changes: [
            'A Release passa a disponibilizar APKs diretos: universal, arm64-v8a, armeabi-v7a e x86_64.',
            'Cada arquivo inclui a versão no nome, facilitando escolher e identificar a instalação.',
            'Relatórios técnicos ficam separados do APK para o download não vir dentro de ZIP.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.81',
          changes: [
            'Monitor vertical reorganizado com status, modos, câmera, atalhos e detecções em áreas fixas.',
            'Detectados agora usa rolagem interna e não sobe mais sobre a câmera quando encontra objetos.',
            'Câmera local deixa de repetir a bateria do receptor; bateria remota continua visível quando existe outro aparelho.',
            'Corrigido o use_build_context_synchronously que interrompeu o Android-APK-49 no flutter analyze.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.80',
          changes: [
            'Histórico reorganizado com filtros adaptativos, ícones, metadados compactos e melhor hierarquia visual.',
            'Detalhes de detecção agora permitem salvar a captura ou excluir o registro após confirmação.',
            'Painel ESP32 conecta e gerencia sensores Hall, temperatura, pneus, telemetria e câmera futura.',
            'ESP32 passa a ser fonte selecionável na Home, no Monitor e na página Câmeras, inclusive como segunda câmera.',
            'Workflow entrega VigiaIA-v1.0.80.apk, usa caches e gera relatório interno de tamanho sem remover recursos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.79',
          changes: [
            'Corrige os nove problemas do flutter analyze encontrados no Android-APK-47.',
            'Atualizações visuais dos módulos multicâmera agora passam pela classe State proprietária.',
            'O menu principal volta a ter somente Início, Histórico, Monitor e Câmeras.',
            'Modo Bike continua disponível na escolha inicial e foi movido para Configurações > Monitoramento.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.78',
          changes: [
            'Monitor usa a mesma tela responsiva com uma câmera em área integral ou duas câmeras empilhadas/lado a lado.',
            'Velocidade Hall, temperatura, pressão dianteira/traseira, bateria dos sensores e distância aparecem em faixa compacta.',
            'Telemetria dos sensores pode vir do ESP32 local ou do celular transmissor; somente a câmera principal executa IA.',
            'Permissões voltam a ser explicadas antes da escolha de modo e o botão Voltar do transmissor retorna à seleção.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.77',
          changes: [
            'Corrige a falha resource_id_zero dos áudios integrados no Android.',
            'Os 78 slots agora usam referências R.raw explícitas, sem busca dinâmica por nome.',
            'O diagnóstico informa a quantidade de recursos empacotados e qualquer slot ausente.',
            'O verificador compara catálogo Dart, catálogo Android e arquivos M4A antes da entrega.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.76',
          changes: [
            'Modo Monitor agora aparece como opção explícita na escolha inicial.',
            'O receptor pode escanear QR, preencher endereço/chave ou abrir a Central multicâmera.',
            'Ao conectar, o Monitor usa Celular remoto e mantém IA, histórico, alertas e áudios neste aparelho.',
            'Textos de Normal, Bike e Transmissão deixam claro se este celular usa, recebe ou envia imagem.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.75',
          changes: [
            'Corrige o lint que interrompeu o Android-APK-43 antes dos testes e do build.',
            'Foco de áudio negado deixa de bloquear a reprodução; a tentativa continua e a condição fica registrada.',
            'Telemetria registra código nativo, etapa, origem, arquivo, volume, rota, foco e tempos de cada tentativa.',
            'Falhas aparecem no Diagnóstico e no relatório de desempenho com fallback para TTS identificado.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.74',
          changes: [
            'Remove a AppBar fixa do Monitor em paisagem e usa HUD translúcido sobre a transmissão.',
            'Agrupa status, IA, detecções, aparelhos e dados Bike na parte superior em paisagem/tela cheia.',
            'Adiciona saída clara do monitoramento em paisagem e tela cheia.',
            'Modo Câmera ganha estado parado integrado, saída clara, botão Parar e painel adaptativo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.73',
          changes: [
            'Adiciona a escolha inicial entre Modo normal, Modo Bike e Modo transmissão.',
            'A escolha fica salva e define a primeira tela nas próximas aberturas.',
            'Configurações ganhou o item Modo inicial para trocar a decisão depois.',
            'O Modo transmissão continua dedicado à câmera; mapa/GPS fica planejado para o receptor.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.72',
          changes: [
            'Corrige os dois avisos do flutter analyze encontrados no Android-APK-40.',
            'Remove o operador nulo desnecessário no status da câmera remota.',
            'Remove import redundante do teste da câmera remota.',
            'Registra que o mini mapa/GPS futuro pertence ao aparelho receptor, mantendo o transmissor dedicado à imagem.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.71',
          changes: [
            'A câmera remota consulta quadros novos rapidamente e evita baixar ou analisar novamente imagens repetidas.',
            'Receptor e transmissor permanecem visíveis no Monitor com bateria, estado, carregamento e acesso ao painel completo.',
            'O HUD ocupa menos a imagem em retrato, paisagem e tela inteira.',
            'A resolução dos áudios Android usa o identificador compilado do recurso e registra detalhes quando o arquivo não puder ser aberto.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.70',
          changes: [
            'Corrige o pacote-fonte para incluir o .gitignore exigido pela verificação preventiva.',
            'Protege arquivos *.jks, *.keystore e android/key.properties contra versionamento acidental.',
            'Não altera o comportamento funcional da IA, áudio, alertas ou tela inteira.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.69',
          changes: [
            'Corrige o único lint restante do flutter analyze no serviço de fala.',
            'Usa elemento null-aware para registrar erro na telemetria somente quando houver valor.',
            'Mantém sem alteração funcional a IA, os alertas, o áudio e a tela inteira.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.68',
          changes: [
            'Corrige a compilação do worker da IA e das Regras Inteligentes encontrada pelo flutter analyze.',
            'Mantém as melhorias de detecção, áudio integrado e tela inteira da versão 1.0.67.',
            'Remove avisos restantes do analisador sem alterar o comportamento esperado do monitoramento.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.67',
          changes: [
            'IA com buffers reutilizáveis, processamento de imagem mais leve e troca automática para modelo leve em caso de lentidão persistente.',
            'Confirmação acompanha a cadência real; recortes extras respeitam o orçamento da análise.',
            'Áudios usam volume de mídia, preparação assíncrona, prioridade e fallback para voz quando a reprodução falha.',
            'Tela inteira horizontal com Ajustar/Preencher, controles que somem e saída pelo botão Voltar.',
            'Diagnóstico registra início/erro de áudio, regras ativas, idade do frame e o tempo nativo da inferência.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.66',
          changes: [
            'Buildfix do Android-APK-34: corrigido teste desatualizado do hotspot do pipeline após a telemetria granular.',
            'O hotspot continua considerando as etapas locais mensuradas; o round-trip agregado da inferência principal não disputa essa classificação.',
            'Nenhuma lógica funcional de IA, telemetria, exportação ou interface foi alterada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.65',
          changes: [
            'Buildfix do Android-APK-33: removido import redundante em NativePlatformService.',
            'Teste de exportação de diagnóstico atualizado para tratar corretamente o retorno anulável da API.',
            'Nenhuma lógica de telemetria, exportação, onboarding, IA ou interface foi alterada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.64',
          changes: [
            'Telemetria detalhada separa conversão da fonte, isolate, resize, tensor, LiteRT puro, pós-processamento e tempo fim a fim.',
            'Diagnóstico ganhou captura profunda de 30/60 s e exporta ZIP com resumo, JSON e CSV para análise de desempenho.',
            'Relatórios salvam em Downloads/Vigia IA por padrão ou usam o seletor do Android conforme a preferência.',
            'Acesso inicial aparece apenas em instalação nova; permissões continuam acessíveis manualmente em Configurações.',
            'Paisagem/tablet ganhou ações mais compactas na Central, Histórico mais organizado, Alertas em duas colunas e Status lateral sem bottom sheet empilhado.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.63',
          changes: [
            'Buildfix pós-refatoração: removidos 19 qualificadores this. redundantes reportados pelo flutter analyze.',
            'Os wrappers do MonitorController continuam delegando para as mesmas implementações internas, sem mudança de comportamento.',
            'Nenhuma regra de IA, Bike, TTC, telemetria, áudio ou interface foi alterada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.62',
          changes: [
            'Buildfix do workflow: scripts shell agora são chamados explicitamente via bash, sem depender do bit executável preservado pelo ZIP/GitHub Manager.',
            'Bootstrap Android, download do modelo e verificação preventiva usam o mesmo caminho robusto no GitHub Actions.',
            'Nenhuma lógica do Monitor, Bike, IA ou interface foi alterada nesta correção.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.61',
          changes: [
            'Buildfix após a refatoração: removidos três wrappers privados obsoletos que faziam o flutter analyze falhar com unused_element.',
            'Telemetria da sessão, entrega de alertas e diagnóstico de áreas continuam usando diretamente os módulos internos extraídos.',
            'Nenhuma lógica funcional do Monitor, Bike, TTC, IA ou diagnóstico foi alterada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.60',
          changes: [
            'Quarto lote da refatoração estrutural concluído em status da sessão, Saúde do sistema e detector de objetos.',
            'Analisador de saúde, componentes visuais e runtime interno da IA foram movidos para módulos próprios sem alterar APIs públicas.',
            'Os 12 arquivos planejados foram concluídos em quatro lotes de três, com verificadores preventivos para a nova estrutura.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.59',
          changes: [
            'Terceiro lote da refatoração estrutural concluído em Status da sessão, Central de diagnóstico e Histórico.',
            'Componentes visuais e mídia foram movidos para módulos próprios, mantendo estado, filtros, ações, navegação e contratos nos arquivos principais.',
            'Verificadores foram atualizados para validar a nova estrutura e impedir que os três arquivos principais voltem a concentrar centenas de linhas.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.58',
          changes: [
            'Segundo lote da refatoração estrutural concluído na Central multicâmera, Informações do aplicativo e Modo Bike.',
            'Componentes visuais foram movidos para módulos próprios sem alterar rotas, persistência, textos ou comportamento.',
            'Os três arquivos principais agora concentram estado, ações e navegação, com limites preventivos no verificador para evitar novo crescimento excessivo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.57',
          changes: [
            'Primeiro lote de refatoração estrutural concluído em MonitorController, MonitorScreen e HomeScreen.',
            'Telemetria/saúde da sessão, eventos/alertas/TTC e estado/diagnóstico foram separados do núcleo do MonitorController sem mudar sua API pública.',
            'Componentes auxiliares do Monitor e da Home foram movidos para módulos próprios, preservando layout e comportamento.',
            'Verificador preventivo foi adaptado para validar a nova estrutura modular e impor limites de tamanho aos três arquivos principais.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.56',
          changes: [
            'Modo Bike ganhou alerta rápido de veículo se aproximando com TTC visual estimado pela variação da caixa na câmera traseira.',
            'O caminho rápido roda logo após a inferência principal, antes das varreduras auxiliares, histórico e gravação.',
            'O alerta de aproximação continua procurando automóveis no Bike mesmo quando o filtro normal do Monitor não inclui veículos.',
            'HUD mostra observação, aviso e crítico sobre o vídeo; áudio/voz é disparado com prioridade alta nos níveis de risco.',
            'Bike permite ajustar a antecedência do aviso entre 2,5 e 7 s e deixa claro que a câmera não mede distância real.',
            'Simulador ganhou cenário Veículo se aproximando para validar TTC, HUD e áudio sem ESP32 e sem teste de rua.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.55',
          changes: [
            'Interface adaptativa para retrato, paisagem e tablet, com navegação lateral nas telas largas.',
            'Home e Modo Bike usam duas colunas quando há espaço; Histórico e Configurações também aproveitam melhor telas largas.',
            'Monitor em celular deitado prioriza o vídeo e permite recolher o painel lateral; tablet mantém painel permanente.',
            'Vídeo ganhou Ajustar/Preencher com caixas da IA e áreas de vigilância sincronizadas ao mesmo recorte.',
            'Status da sessão usa diálogo largo e separa os dois celulares lado a lado em tablets/paisagem ampla.',
            'Corrigidos os dois lints unnecessary_non_null_assertion reportados pelo workflow da 1.0.54.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.54',
          changes: [
            'HUD transparente do Modo Bike agora aparece sobre o vídeo com velocidade e pressão dos pneus.',
            'Simulador interno permite testar cenários de sensores sem possuir ESP32, sempre identificado como SIMULAÇÃO.',
            'Alertas visuais cobrem pneu dianteiro/traseiro baixo, bateria de sensores e perda de conexão.',
            'Corrigido o lint use_null_aware_elements que interrompeu o flutter analyze da 1.0.53.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.53',
          changes: [
            'Corrigida a reprodução dos áudios padrão em aparelhos onde a URI android.resource falhava no MediaPlayer.',
            'Os M4A embarcados agora são copiados de res/raw para o cache privado e reproduzidos como arquivo local.',
            'Áudios personalizados continuam tendo prioridade e caem automaticamente para o padrão se o arquivo escolhido estiver inválido.',
            'Biblioteca de 78 áudios, layout da tela, Monitor, Bike imersivo e integração ESP32 permanecem sem alterações funcionais.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.52',
          changes: [
            'Pipeline da IA agora mede pré-processamento, inferência principal/auxiliar, pós-processamento, total e fim a fim.',
            'O painel mostra uso do orçamento, folga restante, maior custo local e quantas execuções do detector ocorreram no frame.',
            'Varreduras opcionais de detalhe são puladas quando poderiam estourar o intervalo de análise; a inferência principal continua obrigatória.',
            'Saúde da sessão também identifica quando o pipeline se aproxima ou ultrapassa o orçamento configurado.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.51',
          changes: [
            'Status da sessão ganhou saúde em tempo real: Saudável, Atenção, Instável ou Desconectado.',
            'Detecção automática de imagem atrasada/congelada, latência alta, inferência lenta e perdas reais por IA ocupada.',
            'O painel aponta o gargalo provável entre rede, captura, IA e recursos do aparelho e mantém ocorrências recentes da sessão.',
            'Frames ignorados pelo filtro de movimento ficam separados dos descartes por processamento e não geram falso alerta.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.50',
          changes: [
            'Buildfix do Status da sessão após validação real no Flutter 3.44.9.',
            'Removidas três interpolações com chaves desnecessárias que faziam o flutter analyze encerrar com código 1.',
            'Painel, telemetria, Monitor normal e preparação para o Modo Bike permanecem funcionalmente iguais à 1.0.49.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.49',
          changes: [
            'Novo painel Status da sessão em tempo real, reutilizável e preparado para o Modo Bike.',
            'Vídeo ganhou resumo compacto e painel próprio com FPS recebido/analisado, resolução, inferência, atraso, latência e frames descartados.',
            'Este celular e o celular remoto agora aparecem separados com bateria, carga, temperatura, brilho, CPU, RAM, armazenamento e conexão.',
            'Telemetria remota também funciona no Monitor normal; fluxo imersivo do Bike e ESP32 permanecem inalterados.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.48',
          changes: [
            'Corrigida a reprodução dos áudios padrão que falhava em alguns aparelhos Android.',
            'Biblioteca padrão convertida de WAV PCM para AAC/M4A mono 24 kHz para maior compatibilidade.',
            'Player nativo passou a abrir recursos Android por URI com atributos de áudio adequados para alertas falados.',
            'Ouvir, Trocar e Gravar agora permanecem lado a lado; Restaurar padrão foi movido para o cabeçalho do item personalizado.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.47',
          changes: [
            'APK release passa a usar assinatura permanente recriada a partir de GitHub Secrets.',
            'Workflow valida presença, conteúdo e alias da keystore antes de iniciar o build.',
            'Keystore não é armazenada no repositório nem no ZIP do projeto.',
            'Build release deixou de usar a assinatura debug, permitindo atualizações futuras com a mesma identidade de assinatura.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.46',
          changes: [
            'Buildfix da tela Áudios e voz após validação real no Flutter 3.44.9.',
            'Substituído um ícone Material inexistente que bloqueava o flutter analyze.',
            'Biblioteca de 78 áudios, importação, gravação, restauração e fallback TTS foram preservados.',
            'Verificação preventiva ampliada para impedir a reintrodução do ícone incompatível.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.45',
          changes: [
            'Biblioteca central com 78 áudios padrão, incluindo todos os avisos atuais e os futuros do Modo Bike/ESP32.',
            'Nova tela Áudios e voz em Configurações → Geral permite ouvir, trocar por arquivo, gravar pelo microfone e restaurar qualquer aviso.',
            'Áudios personalizados têm prioridade sobre o padrão e permanecem após atualizações normais do aplicativo.',
            'TTS continua disponível como fallback de segurança quando um áudio não puder ser reproduzido.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.44',
          changes: [
            'Modo Bike agora aparece como destino próprio Bike no menu principal inferior.',
            'A tela do Modo Bike mantém a barra principal visível para navegação consistente entre Início, Histórico, Monitor, Câmeras e Bike.',
            'O acesso deixou de depender de Configurações → Monitoramento; toda a lógica de economia, telemetria e painel remoto foi preservada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.43',
          changes: [
            'Buildfix da Etapa 3 do Modo Bike após validação no Flutter 3.44.9.',
            'Removidos dois casts desnecessários que faziam o flutter analyze encerrar o workflow.',
            'Painel remoto, telemetria, transmissão e alertas do Modo Bike foram preservados sem mudança funcional.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.42',
          changes: [
            'Etapa 3 do Modo Bike concluída: o celular da frente recebe e exibe a telemetria do aparelho traseiro.',
            'Novo painel remoto mostra bateria/carga, temperatura, brilho, CPU, memória, FPS da captura e latência da telemetria.',
            'O monitor Ao vivo ganhou atalho de bicicleta, resumo compacto sobre a imagem e avisos para condições importantes.',
            'Bateria baixa, aquecimento, CPU elevada, pouca RAM e telemetria atrasada são destacados sem interromper a imagem.',
            'O Modo Câmera informa também FPS e o limite configurado de bateria baixa, mantendo compatibilidade com o fluxo local existente.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.41',
          changes: [
            'Perfis do Modo Bike agora controlam o intervalo real de captura/análise e limitam a transmissão LAN.',
            'Economia e Economia extrema reduzem também resolução/qualidade do JPEG para poupar processamento e rede.',
            'Brilho do celular traseiro é reduzido durante a operação e restaurado ao parar.',
            'Telemetria local ganhou bateria/carga, temperatura, brilho, CPU e memória, já exposta no estado da transmissão.',
            'Modo Câmera também respeita o Modo Bike e o aviso local de bateria baixa passou a funcionar.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.40',
          changes: [
            'Primeira tela do Modo Bike criada, inicialmente acessível por Configurações → Monitoramento.',
            'Ativação do modo e perfil de energia ficam persistidos no aparelho.',
            'Perfis Normal, Economia e Economia extrema definem metas de análise e transmissão para as próximas integrações.',
            'Preferências para reduzir atividade da tela, telemetria remota e aviso de bateria baixa já fazem parte da configuração.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.39',
          changes: [
            'Compatibilidade da seleção de fonte atualizada para Flutter 3.44 sem APIs Radio obsoletas.',
            'Mantida a nova tela inicial de permissões com atalhos para câmera, notificações e rede local.',
            'Fonte de vídeo continua com explicações mais claras e leitura de QR do outro celular.',
            'Textos do monitor foram refinados e o título principal passou a usar Ao vivo.',
            'Memória visual complementar reduz falas repetidas e a detecção parcial de pessoa permanece ativa.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.38',
          changes: [
            'Pacote de voz personalizado fornecido pelo usuário foi separado e incorporado ao projeto.',
            'Entrada e saída agora usam slots específicos para pessoa, veículo e animal antes do fallback genérico/TTS.',
            'Áudios personalizados continuam opcionais: qualquer slot ausente cai automaticamente para a voz TTS.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.37',
          changes: [
            'Movimento passa a considerar diferença de cor RGB, detectando alterações que tons de cinza poderiam perder.',
            'Pessoa, animal e automóvel ganham assinatura visual leve por cores para manter a identidade entre frames e oclusões.',
            'Roupas usam pistas de cor do tronco/pernas e veículos usam a cor predominante apenas como apoio ao rastreamento.',
            'IDs sobrevivem a perdas temporárias e trocas de rótulo da mesma família, reduzindo alertas e falas repetidas.',
            'Áudios próprios podem substituir o TTS por slots opcionais em custom_audio, com fallback automático para a voz do Android.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.36',
          changes: [
            'Objetos pequenos e distantes ganham varredura multiescala controlada e reaquisicao localizada.',
            'Detector filtra classes monitoradas antes do limite de resultados, evitando que objetos irrelevantes escondam pessoa, animal ou automovel.',
            'Confianca passa a considerar tamanho do objeto, com confirmacao temporal mais rigorosa para candidatos pequenos.',
            'Movimentos separados recebem focos separados e rotulos sobrepostos da mesma familia sao mesclados.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.35',
          changes: [
            'Corrigido o único aviso restante do flutter analyze em SharedLocalCameraService.',
            'Removido import redundante de dart:typed_data sem alterar câmera compartilhada ou detecção.',
            'Verificador preventivo ampliado para impedir a regressão desse aviso em builds futuros.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.34',
          changes: [
            'Detecção principal com EfficientDet-Lite0 e fallback automático para SSD MobileNet V1.',
            'Pré-processamento por letterbox preserva a proporção da câmera e evita deformar pessoas, animais e veículos.',
            'Candidatas difíceis usam confiança adaptativa com confirmação temporal e retenção curta contra falhas de um frame.',
            'Modo por movimento mantém presença e faz segunda análise ampliada quando há movimento localizado sem objeto encontrado.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.33',
          changes: [
            'Câmera local compartilhada entre Monitor e Modo Câmera para impedir conflito CameraX por múltiplos controladores.',
            'Visualizador LAN com endereço limpo, sessão temporária, estado real dos frames e atualização por JPEG.',
            'Alertas mais rápidos, TTS sem fila obsoleta, watchdog menor e heartbeat real do segundo plano.',
            'Aplicativo edge-to-edge e telas de câmera em modo imersivo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.32',
          changes: [
            'Corrigida a expressão Kotlin de canRequest da permissão de rede local, que era interpretada como Pair antes do operador lógico &&.',
            'A cópia Android e o template de bootstrap foram mantidos idênticos para o workflow não reintroduzir o erro.',
            'Versão e verificação preventiva sincronizadas após o log Android APK 4.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.31',
          changes: [
            'Corrigida a codificação da chave na URL do visualizador LAN para usar %20 em espaços e percent-encoding seguro nos demais caracteres.',
            'O mesmo formato de chave agora é usado no endereço compartilhado e no stream MJPEG da página local.',
            'Versão e verificações preventivas sincronizadas após o log Android APK 3.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.30',
          changes: [
            'Corrigido erro de análise estática causado pela referência a CameraHealthState sem o import do modelo.',
            'Corrigida a inferência numérica do formatador de armazenamento para manter double em todos os caminhos.',
            'Versão e verificações preventivas sincronizadas após o log Android APK 2.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.29',
          changes: [
            'Diagnóstico exportável e compartilhável com snapshot único do estado exibido.',
            'Saúde do sistema separa serviço Android, câmera, frames, IA, LAN, clientes, permissões e segundo plano.',
            'Serviço ativo sem frames não é mais apresentado como monitoramento funcionando.',
            'Armazenamento formatado em KB, MB, GB ou TB e botões de ajuda adicionados às telas técnicas.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.28',
          changes: [
            'Identidade técnica migrada integralmente para vigiaia, sem hífen.',
            'Pareamento QR atualizado para vigiaia://pair.',
            'Pacote Dart, namespace/applicationId Android, canais nativos e artifact do APK atualizados.',
            'Corrigidos os dois avisos que faziam flutter analyze encerrar o workflow Android APK 26 com código 1.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.27',
          changes: [
            'Monitor ativo pode ser assistido por outro celular na mesma rede local pelo navegador.',
            'A transmissão reutiliza os frames do pipeline existente e não abre uma segunda câmera.',
            'Endereço local protegido por chave de sessão, com botão para copiar e contador de visualizadores.',
            'Servidor local encerra junto com o monitoramento e não publica o vídeo automaticamente na internet.',
            'Permissões de rede local preparadas para Android 16/17, com fallback seguro quando negadas.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.26',
          changes: [
            'Permissão da câmera solicitada na primeira abertura e revalidada antes de iniciar uma câmera local.',
            'Ao conceder a câmera pelo botão de iniciar, o monitoramento continua no mesmo fluxo sem exigir um segundo toque.',
            'Foreground Service agora usa o tipo Android correto para câmera e mantém notificação permanente quando o segundo plano está ativo.',
            'Modo Câmera também mantém serviço em primeiro plano durante transmissão local.',
            'Bloqueio/minimização preserva o fluxo quando permitido e inclui recuperação automática se os frames pararem.',
            'Serviço não reinicia sozinho sem o pipeline Flutter, evitando notificação órfã indicando monitoramento inexistente.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.25',
          changes: [
            'Novo nome público: Vigia IA.',
            'Tema Escuro passa a ser o padrão em novas instalações.',
            'Preferências de tema já salvas continuam sendo respeitadas.',
            'Versão, Manifest, notificações nativas e documentação sincronizados com a nova identidade.',
            'Identificador Android preservado para manter atualização e dados das instalações existentes.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.24',
          changes: [
            'IA organizada visualmente em Pessoas, Automóveis e Animais.',
            'Novo Histórico focado em quem ou o que passou na frente da câmera; eventos técnicos ficam no Diagnóstico.',
            'Navegação simplificada para Início, Histórico, Monitor e Câmeras, com uma única engrenagem para configurações.',
            'Tema Sistema, Claro ou Escuro e quatro cores principais persistentes.',
            'Multicâmera e entrada/saída permanecem independentes de qualquer contador.',
            'Corrigido o lint que bloqueava o Android APK 22.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.23',
          changes: [
            'Pareamento de outro celular por QR Code, mantendo a entrada manual como alternativa.',
            'QR usa formato próprio e versionado do Vigia IA, rejeitando códigos incompatíveis.',
            'A Central testa a conexão antes de salvar e atualiza cadastros existentes sem duplicar a câmera.',
            'Modo Câmera exibe QR com endereço e chave temporária da sessão para conexão na mesma rede.',
            'Seleção do endereço local prioriza IPv4 privado para reduzir pareamentos com interface de rede incorreta.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.22',
          changes: [
            'Central multicâmera em grade responsiva, com atualização automática de status a cada 15 segundos.',
            'Câmeras podem ser renomeadas, ativadas/desativadas e mostram latência e último evento.',
            'Eventos passam a guardar cameraId estável para continuar ligados à câmera mesmo após renomear.',
            'Celular remoto informa estado de reconexão e continua tentando recuperar a transmissão automaticamente.',
            'Testes ampliados e workflow passa a gerar cobertura durante flutter test.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.20',
          changes: [
            'Corrigida troca de IDs no primeiro cruzamento de objetos em sentidos opostos.',
            'Primeira velocidade observada agora inicializa diretamente a trajetória prevista.',
            'Suavização de velocidade continua ativa nas medições seguintes para reduzir jitter.',
            'Teste de regressão do cruzamento foi mantido sem relaxar a validação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.19',
          changes: [
            'Corrigidos erros de análise estática que bloqueavam o workflow Android APK 18.',
            'Detector de integridade da câmera agora mantém brilho e diferença de cena tipados como double.',
            'Câmera de outro celular passa a reportar corretamente o estado AO VIVO usando VideoSourceState.streaming.',
            'Tela de presets atualizada para remover uso da API RadioListTile depreciada.',
            'Imports redundantes removidos sem alterar o comportamento dos módulos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.18',
          changes: [
            'Clipes MP4 H.264 no Android, com GIF como fallback e duração configurável.',
            'Alertas combináveis por voz, som, vibração e notificação Android.',
            'Frases personalizadas por objeto, área, entrada, saída e integridade da câmera.',
            'Modo Câmera e Central multicâmera para celular local, RTSP e outro telefone na mesma rede.',
            'Rastreamento mais robusto e anti-repetição considerando o ID rastreado.',
            'Estatísticas, armazenamento, backup/exportação, Saúde do Sistema e presets.',
            'Credenciais RTSP protegidas pelo Android Keystore e recuperação assistida após reinício.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.17',
          changes: [
            'Home mais compacta e ação de iniciar sempre acessível.',
            'Monitor ao vivo com câmera dominante, HUD reduzido e detecções recolhíveis.',
            'Navegação principal com Início, Eventos, Monitor, Diagnóstico e Ajustes.',
            'Eventos com filtros compactos, agrupamento visual e exclusão por gesto/menu.',
            'Diagnóstico com feedback de alto contraste e estado vazio melhorado.',
            'Ajustes avançados mais compactos e melhor hierarquia de cores.',
            'Nova área Sobre, Mudanças e Doações com cópia da chave PIX.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.16',
          changes: [
            'Empacotamento do projeto-fonte corrigido para incluir workflow e arquivos ocultos.',
            'Preservação do monitoramento offline, histórico, áreas, rastreamento e segundo plano.',
          ],
        ),
      ],
    );
  }
}

class _ChangesPanel extends StatelessWidget {
  const _ChangesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ReleaseCard(
          version: '1.0.157',
          current: true,
          changes: [
            'Bicicleta, Moto, Carro e A pé agora aparecem em uma grade 2 × 2 mais compacta e visual.',
            'O último perfil utilizado fica salvo e volta selecionado por padrão na próxima navegação.',
            'O seletor respeita a área segura inferior do Android em navegação por gestos e por três botões.',
            'Os quatro modos continuam usando perfis reais e distintos no cálculo da rota.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.156',
          changes: [
            'Corrigido o Android-APK-119 no flutter analyze.',
            'O renderer MapLibre 3D agora importa diretamente a extensão usada para serializar o modo de transporte no diagnóstico.',
            'A correção preserva integralmente a estabilização e o fallback 2D → 3D da etapa anterior.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.155',
          changes: [
            'Corrigida a tela preta ao entrar na navegação MapLibre 3D.',
            'O FlutterMap 2D permanece visível até mapa, estilo, rota, câmera e primeiro render do 3D estarem prontos.',
            'Falhas e timeout do MapLibre acionam fallback automático para 2D e ficam registradas no diagnóstico e na telemetria.',
            'Offline continua usando automaticamente o mapa 2D/MBTiles.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.154',
          changes: [
            'Corrigido o Android-APK-117 no build release do MapLibre Android.',
            'O plugin Gradle ktlint exigido pelo maplibre_android 0.3.6 agora recebe uma versão explícita pelo pluginManagement.',
            'A correção é de infraestrutura de build e preserva a navegação 3D e o fallback 2D/offline.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.153',
          changes: [
            'Corrigido o bloqueio do Android-APK-116 no flutter analyze.',
            'Removidas assertions ! redundantes no destino da navegação 3D.',
            'A correção não altera o comportamento do mapa 3D, roteamento, modos de transporte ou fallback 2D.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.152',
          changes: [
            'Primeira etapa da navegação 3D: rotas online passam a usar um renderer MapLibre inclinado durante o acompanhamento.',
            'Antes de navegar, é possível escolher Bicicleta, Moto, Carro ou A pé.',
            'O perfil escolhido é enviado ao roteamento e persistido com o destino, preservando alternativas, voz e recálculo.',
            'O usuário pode voltar ao mapa 2D a qualquer momento; offline continua usando o renderer 2D existente.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.151',
          changes: [
            'Corrigido o aviso de análise estática que bloqueava o Android-APK-114.',
            'Removido o estado interno de erro offline que era gravado, mas nunca lido pela interface.',
            'Falhas de abertura de MBTiles continuam registradas no log técnico sem mudar o comportamento do mapa offline.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.150',
          changes: [
            'HUD do mapa reorganizado com engrenagem à esquerda, Perto/Região/Rota no topo e camadas em botão próprio.',
            'Velocidade, altitude, bússola e GPS agora usam cards quadrados mais legíveis.',
            'O botão de pontos próximos virou um marcador dedicado, a câmera ganhou atalho abaixo do card de locais e Gravar foi fixado no canto inferior direito.',
            'POIs abrem um card compacto com Detalhes/Navegar e o mapa volta a aceitar rotação manual por gesto.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.149',
          changes: [
            'Mapa e Bike passam a limpar juntos a rota local quando a navegação é encerrada fora da tela do mapa.',
            'TTC antigo deixa de aparecer quando perde validade ou quando câmera/IA deixa de estar pronta.',
            'POIs offline rejeitam pacotes distantes e categorias desativadas somem imediatamente da interface.',
            'O mini mapa automático permanece disponível durante uma navegação ativa, mesmo com a bicicleta parada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.148',
          changes: [
            'GPS do mapa reduz amostras redundantes sem perder a precisão necessária para navegação Bike.',
            'POIs continuam precisos para alertas, mas a interface deixa de reconstruir a cada ponto do GPS.',
            'Buscas automáticas de POIs ganham cooldown e câmeras remotas deduplicam estados repetidos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.147',
          changes: [
            'Buildfix do Android-APK-110: corrigida a nulabilidade na política de voz que bloqueava o flutter analyze.',
            'Suporte offline deixa de chamar setState diretamente pela extension, eliminando avisos de membro protegido.',
            'Removidos avisos estáticos redundantes sem alterar navegação, POIs, offline ou layout do mapa.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.146',
          changes: [
            'Navegação preserva a última rota viária conhecida quando a internet cai e deixa claro quando só há direção ao destino.',
            'POIs offline entram imediatamente durante perda de conexão e a busca online volta automaticamente após recuperação.',
            'O seletor de camada mostra Sem internet/Offline automático sem adicionar outra barra sobre o mapa.',
            'Controles, filtros, banner de navegação e PiPs foram compactados em retrato e paisagem para ampliar a área útil.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.145',
          changes: [
            'Avisos de POIs respeitam categorias escolhidas, distância configurada, direção do deslocamento e pacotes offline.',
            'Cooldown global e consumo de marcos já ultrapassados evitam sequências repetitivas de avisos próximos.',
            'Navegação por voz anuncia próxima manobra e distância em marcos progressivos, com prioridade perto da conversão.',
            'Saída da rota, recálculo, rota recalculada e chegada recebem avisos falados usando as preferências globais de áudio/TTS.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.144',
          changes: [
            'PiPs mostram IA ativa, IA desligada, aguardando frames, sem frames, analisando e possível erro da IA.',
            'Falhas da câmera local aparecem como Câmera indisponível; fontes de rede distinguem Conexão perdida.',
            'O estado Analisando só é permitido quando a IA está realmente habilitada e o detector está pronto.',
            'Câmeras abertas apenas para visualização deixam IA desligada explícita sem criar outro pipeline de análise.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.143',
          changes: [
            'PiP da câmera analisada no mapa passa a mostrar aproximação de veículos usando o mesmo estimador TTC do Modo Bike.',
            'O indicador diferencia veículo sem aproximação, atenção, risco alto e risco crítico sem bloquear informações da navegação.',
            'Novo sistema global de Novidades da atualização aparece uma única vez por versão instalada e funciona offline.',
            'A versão instalada é lida do Android e o histórico exibido é persistido localmente por versão + build.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.142',
          changes: [
            'Corrigido o Android-APK-107: o teste do painel de POI agora rola até a comodidade realmente ficar visível.',
            'A rolagem usa scrollUntilVisible e não depende mais de um deslocamento fixo que podia apenas expandir o painel.',
            'Nenhum comportamento de produção do mapa, painel de POI ou PiPs foi alterado neste buildfix.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.141',
          changes: [
            'Corrigido o Android-APK-106: o teste do painel de POI agora rola a lista antes de validar comodidades fora da área inicial.',
            'A correção não altera o painel nem o PiP em produção; apenas torna o teste compatível com a construção lazy do ListView.',
            'flutter analyze já havia passado sem avisos no build 106; a falha estava isolada em um único teste de widget.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.140',
          changes: [
            'PiPs lembram a visibilidade global e ganham atalho Mostrar câmera quando todas as janelas estiverem ocultas.',
            'Durante a navegação, câmeras grandes reduzem temporariamente para preservar rota e instruções sem perder o tamanho salvo.',
            'Encaixe automático evita duas câmeras no mesmo canto e mantém organização adequada em retrato e paisagem.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.139',
          changes: [
            'POI selecionado ganha painel completo com categoria, distância, origem, endereço, horário, telefone, site, operador e comodidades.',
            'Endereço, telefone, site e coordenadas podem ser copiados rapidamente sem sair do mapa.',
            'Ação principal passa a ser Ir até lá, mantendo Mostrar no mapa como ação secundária.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.138',
          changes: [
            'POIs preservam endereço, horário, telefone, site e comodidades quando essas informações estão disponíveis.',
            'Mapa ganha categorias próprias para camping, mirantes, cachoeiras e mercados, além de filtros Natureza e Bike/viagem.',
            'Pacotes offline preservam os dados enriquecidos e instalações antigas recebem as novas categorias sem reinstalação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.137',
          changes: [
            'Roteamento ciclável passa a solicitar até duas alternativas adicionais quando o servidor consegue fornecê-las.',
            'Mapa desenha as alternativas de forma secundária e mantém a rota ativa em destaque.',
            'Banner permite comparar distância e duração e trocar a rota ativa sem encerrar a navegação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.136',
          changes: [
            'Navegação guiada mostra instrução atual, próxima manobra, distância até a ação e progresso da rota.',
            'Saída confirmada da rota dispara recálculo automático a partir da posição atual, com proteção contra chamadas repetidas.',
            'Navegação restaurada recupera novamente a rota viária e mantém direção direta como fallback se o serviço falhar.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.135',
          changes: [
            'Corrige o Android-APK-102, que parava no flutter analyze antes dos testes e do build Android.',
            'Remove cinco assertions nulas redundantes no card do POI selecionado, eliminando os avisos unnecessary_non_null_assertion.',
            'Mantém inalterados a rota ciclável, o HUD de navegação e o fallback por direção direta da 1.0.134.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.134',
          changes: [
            'Mapa calcula rota viária real para bicicleta ao escolher um destino, desenhando o trajeto sobre as vias.',
            'HUD da navegação mostra distância e duração estimadas da rota ciclável.',
            'Se o roteamento online falhar, a navegação continua disponível por direção direta.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.133',
          changes: [
            'Refinamento visual do mapa após revisão em vídeo: POIs agora usam clustering, densidade por zoom e cores/ícones por categoria.',
            'HUD fica mais leve: telemetria prioriza velocidade/altitude, lateral mantém zoom/seguir/opções e tempo/distância migram para a barra compacta de percurso.',
            'PiPs ganham bolha minimizada, duplo toque para tamanho, arranjo automático da segunda câmera e troca direta entre câmera 1 e 2 para fontes abertas pelo mapa.',
            'Barras do Android recebem contraste próprio sobre mapas claros e o card do POI não fica duplicado quando ele já virou destino de navegação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.132',
          changes: [
            'Correção do Android-APK-99: MapMonitoringScreen volta a importar explicitamente OfflinePoiPackage, eliminando dois erros undefined_class no flutter analyze.',
            'MapRouteService remove import redundante de flutter/foundation.dart, eliminando o issue unnecessary_import do analyzer.',
            'Verificador preventivo passa a exigir o import do modelo de pacote offline e a bloquear a reintrodução do import redundante.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.131',
          changes: [
            'UX final do mapa: HUD responsivo em telas estreitas/paisagem, zoom consolidado e camadas acessíveis pelo chip superior sem duplicar controles.',
            'PiPs passam a respeitar zonas seguras do HUD e dos cards inferiores; persistência de posição foi corrigida e há ação para restaurar o layout.',
            'Ações do PiP foram condensadas em um menu para não cobrir a imagem em tamanhos pequenos; tela de GPS indisponível também segue o visual sem AppBar grande.',
            'Revisão final corrige atualização de pacotes offline para buscar dados novos pela internet sem apagar o cache salvo quando a atualização falha.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.130',
          changes: [
            'Mapa passa a gerenciar duas câmeras diretamente: fonte local/traseira, frontal, RTSP, celular remoto, ESP32 e câmeras já abertas pelo Monitor.',
            'PiPs podem trocar fonte, minimizar, ocultar, alternar tamanho e encaixar nos cantos; posição, tamanho e estado visual ficam persistidos.',
            'Fontes abertas só pelo mapa são suspensas ao minimizar, ocultar ou mandar o app ao fundo, sem interromper a câmera de IA já usada pelo Monitor.',
            'Desempenho do mapa melhora com cronômetro isolado, GPS por consumidores, recálculo de POIs apenas em GPS novo e redução visual de percursos muito longos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.129',
          changes: [
            'Mapa ganha camadas Padrão, Bike/Viagem, Terreno, Topográfico e Satélite, preservando OSM como opção gratuita e usando a chave Stadia existente apenas quando necessária.',
            'Controles são reorganizados: funções secundárias passam para Opções, reduzindo a coluna permanente sem esconder Próximos pontos, offline e configurações.',
            'Próximos pontos passa a usar pacotes offline regionais com nome, área, data e quantidade de locais, incluindo migração da antiga lista única.',
            'POI selecionado permanece destacado com card compacto e ações; atualização automática passa a considerar movimento, tempo, direção e borda da área mesmo sem gravar percurso.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.128',
          changes: [
            'Corrigido o Android-APK-95 que parava no flutter analyze por usar Icons.offline_map_rounded, inexistente no Flutter 3.44.9.',
            'O botão Mapas offline passa a usar download_for_offline_outlined, já compatível com a versão estável usada no workflow.',
            'Verificação preventiva passa a rejeitar o identificador de ícone inválido antes de uma nova tentativa de build.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.127',
          changes: [
            'Mapa ganha visão à frente: ao seguir o GPS, o usuário fica abaixo do centro para mostrar mais estrada no sentido do deslocamento.',
            'Novo controle alterna Norte fixo e acompanhamento por direção, com rotação suavizada por dead-zone e sem tremedeira quando parado.',
            'Atalhos Perto, Região e Rota mudam rapidamente o enquadramento; Rota ajusta a câmera ao percurso gravado e/ou destino ativo.',
            'Preferência de orientação e visão de acompanhamento é persistida, e o mapa deixa de recentralizar a câmera a cada tick do cronômetro.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.126',
          changes: [
            'GPS passa por filtro de precisão, ordem temporal, velocidade e deslocamento plausível antes de mover a posição do mapa.',
            'Gravação de percurso usa precisão mais rigorosa, suavização de posição/rumo e limiar contra jitter para evitar distância artificial.',
            'Gravar percurso fica separado de Navegar até: POIs podem virar destino persistente com distância e rumo direto.',
            'Persistência sobe para schema 3, preserva migração do estado anterior e corrige retomada após recriação do processo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.125',
          changes: [
            'Mapa completo passa a usar praticamente toda a tela, sem AppBar fixa, com controles flutuantes que respeitam notch e navegação.',
            'Próximos pontos agora aparece também no mapa como marcadores filtráveis, com lista, foco do ponto tocado, atualização e cache offline.',
            'Zoom, seguir GPS, câmeras, mapas offline, configurações e gravação de rota ficam acessíveis sobre o mapa em retrato e paisagem.',
            'Percursos quebram o segmento após saltos grandes de GPS e a busca no caminho se renova automaticamente durante rotas ativas.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.124',
          changes: [
            'Sensores e recursos passam a mostrar separadamente leitura ativa, detecção do firmware, espera por leitura e estado offline.',
            'Sensor novo informado pelo ESP32 aparece como detectado e não configurado, com atalho para revisar o wizard.',
            'Firmware legado pode ter Hall, pneus, temperatura, bateria e energia inferidos pelos valores reais recebidos, mesmo sem capabilities.',
            'Wi-Fi, endpoint, uptime, sequência e reconexão ficam em Conexão, sem misturar rede com valores dos sensores.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.123',
          changes: [
            'Nova capacidade Energia separa alimentação do módulo e bateria principal monitorada.',
            'Power bank/tomada funcionam sem bateria física; chumbo-ácido e LiFePO₄ ganham perfil próprio.',
            'INA219/INA226/divisor/BMS e entrada solar ficam preparados no wizard e no contrato de telemetria.',
            'Tela ESP32 diferencia bateria do módulo, bateria principal, corrente, potência e solar.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.122',
          changes: [
            'Novo assistente ESP32 em 5 etapas separa conexão, identificação, capacidades, ajustes e revisão.',
            'Busca guiada tenta 192.168.4.1/esp32.local e mantém endereço/chave manual somente quando necessário.',
            'Ajustes aparecem de acordo com os sensores escolhidos, e a tela vazia deixa de mostrar dois botões de conexão.',
            'Android-APK-90 corrigido com a remoção do import redundante apontado pelo flutter analyze.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.121',
          changes: [
            'Telemetria ESP32 passa a ser lida continuamente pelo app, com descoberta automática de endpoints novos e compatibilidade com /status legado.',
            'Cada módulo mantém estado próprio de conexão, latência, RSSI, firmware, protocolo, bateria, falhas e próxima tentativa de reconexão.',
            'Vários ESP32 podem contribuir para o HUD ao mesmo tempo sem alternar a fonte; sensores ausentes deixam de gerar alertas falsos.',
            'Reconexão automática usa backoff e o diagnóstico/exportação passa a incluir o estado detalhado dos módulos ESP32.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.120',
          changes: [
            'ESP32 passa a ser cadastrado como módulo independente; câmera vira uma capacidade opcional e continua aparecendo normalmente como fonte quando instalada.',
            'Cadastros antigos são migrados automaticamente e cada módulo pode guardar posição, capacidades, calibração, limites e intervalo de telemetria.',
            'A base já reconhece múltiplos moduleId e capacidades futuras como mmWave, térmico, ToF, ultrassom, GPS e atuadores.',
            'Timeout da telemetria acompanha o intervalo configurado e os limites de pressão/temperatura passam a controlar os alertas do HUD.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.119',
          changes: [
            'A Home passa a usar os novos ícones transparentes de Ao vivo, Transmissão, Remoto e ESP32 diretamente nos cards.',
            'Os filtros do Histórico foram refeitos para manter ícones e rótulos Todos, Pessoas, Veículos e Animais alinhados sem check duplicado.',
            'Em Câmeras, Monitorar fica compacto ao lado do nome da câmera; abrir com segunda câmera continua disponível no menu.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.118',
          changes: [
            'Perfis Bike passam a preservar mais informação visual: Economia usa 7 FPS/960 px/JPEG 76 e Economia extrema 5 FPS/800 px/JPEG 72.',
            'Áudios e voz ganhou controle por fala: cada aviso pode ser ativado ou silenciado individualmente, com ações para ativar ou silenciar todos.',
            'TTS de fallback fica desligado por padrão para evitar mistura de vozes; mensagens sem áudio integrado continuam configuráveis separadamente.',
            'As falas Bike/ESP32 deixam de ser marcadas como futuras e o emulador dispara áudios integrados para os cenários simulados.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.117',
          changes: [
            'Home reorganizada em quatro cards compactos: Ao vivo, Transmissão, Remoto e ESP32; os cinco acessos rápidos ficam na mesma linha no celular.',
            'Bike deixa de ser um modo inicial e passa a ser um perfil em Ajustes > Bike e economia, sem apagar as preferências existentes.',
            'O emulador de sensores foi movido para a engrenagem da tela ESP32 e continua reutilizando o mesmo contrato de telemetria.',
            'Transmissão ganhou engrenagem para alterar Bike/economia sem trocar de modo, bateria do aparelho atual e política de frames separada da frequência da IA.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.116',
          changes: [
            'Corrigido o Android-APK-84: os dois testes de layout compacto agora cabem sem RenderFlex overflow.',
            'Cards compactos da Home ganharam espaçamentos, ícones e tags mais densos sem remover título, descrição ou indicadores.',
            'Acessos rápidos foram reduzidos para manter Diagnóstico legível em células estreitas da grade responsiva.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.115',
          changes: [
            'Home compactada em grade 2x2 com Monitor ao vivo, Modo transmissão, Modo Bike e acesso dedicado ao ESP32.',
            'ESP32 saiu da lista geral de Monitoramento em Ajustes e abre diretamente sua tela existente de módulo, sensores e câmera.',
            'Configurações do mapa e percurso ficaram mais compactas, com categorias, alertas, distâncias e ações offline reduzidas sem duplicar serviços.',
            'Acessos rápidos passam a usar grade responsiva para evitar rótulos cortados em celulares estreitos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.114',
          changes: [
            'Corrigido o Android-APK-82: ButtonStyle usa minimumSize compatível com Flutter 3.44.9.',
            'Corrigidos delimitadores no monitor multicâmera que geravam a cascata de erros de parser no analyzer.',
            'Toggles da Home atualizam o estado por helper do próprio State e warnings privados sem uso foram removidos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.113',
          changes: [
            'Iniciado o redesign amplo com um design system compartilhado para tema, cards, botões, chips, painéis e navegação.',
            'A Home agora destaca Monitor ao vivo, Modo transmissão e Modo Bike, com acessos rápidos para Câmeras, Mapa, Histórico, Diagnóstico e Ajustes.',
            'Configurações técnicas do monitor foram preservadas e recolhidas em Preparar monitoramento para reduzir poluição visual sem remover funções.',
            'A navegação principal passa a incluir Ajustes como quinto destino e adota a mesma linguagem visual em retrato e paisagem.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.112',
          changes: [
            'Mapa abre diretamente Próximos pontos, com filtros rápidos, distância, categoria e origem Online/Offline.',
            'Configurações do mapa e percurso ficam separadas na engrenagem, incluindo raio, categorias, alertas, dados e mapas offline.',
            'Câmera permite Ligada, Desligada ou Mapa, que expande para ocupar a área principal da transmissão.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.111',
          changes: [
            'O botão Mapa passou a abrir o painel Mapa e percurso com busca por raio, lista de resultados e atalhos do mapa.',
            'A exploração consulta postos, restaurantes, paradas, oficinas, saúde, água/banheiro e rios/pontes.',
            'A lista pode ser salva para uso offline e alimentar alertas por fala e notificação.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.110',
          changes: [
            'A fileira fixa do monitor agora tem cinco ações: Câmera, Mapa, Áudio, Painel e Ajustes.',
            'O botão Mapa mostra ou oculta o mini mapa diretamente e destaca o estado quando ele está visível.',
            'Corrigido o Android-APK-78: o ZIP-fonte volta a preservar o .gitignore exigido pela verificação de segurança da assinatura.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.109',
          changes: [
            'O menu dos três pontinhos do monitor Ao vivo agora traz um atalho Mostrar mapa / Ocultar mapa, funcionando mesmo fora do modo bicicleta.',
            'Quando o mapa foi forçado ou ocultado, o mesmo menu oferece Mapa automático para voltar ao comportamento inteligente anterior.',
            'A preferência continua persistida no serviço de rota, então o estado escolhido é lembrado na próxima abertura do monitor.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.108',
          changes: [
            'Corrigido o Android-APK-76 restaurando ic_launcher, LaunchTheme e NormalTheme que faltavam no projeto Android versionado.',
            'Recursos nativos agora ficam preservados no ZIP-fonte e são verificados antes do build.',
            'A compilação única de universal + três ABIs, o cache e o paralelismo continuam ativos.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.107',
          changes: [
            'Android-APK-75 corrigido com o Gradle Android alinhado ao template do Flutter 3.44.9.',
            'Mantida a geração universal + três ABIs em uma única compilação, com cache e paralelismo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.106',
          changes: [
            'Build Android passa a gerar universal + três ABIs em uma única chamada Gradle, removendo a segunda compilação release.',
            'Gradle usa cache/paralelismo e o workflow reutiliza o diretório Android existente para melhorar builds seguintes.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.105',
          changes: [
            'Corrigido o Android-APK-73: removidos dois imports que bloqueavam o flutter analyze antes da compilação.',
            'Funcionalidades de mapa, Stadia e multicâmera da 1.0.104 foram preservadas.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.104',
          changes: [
            'Painel Stadia completo com Colar, Ver, Copiar, Testar, Trocar e Remover a API key.',
            'Seleção offline ganhou modos Mapa/Área e zoom − / z / +; mapa completo ganhou telemetria no topo e até duas câmeras flutuantes.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.103',
          changes: [
            'Mapas offline mostram créditos estimados e usam limite mensal local configurável para evitar consumo excessivo.',
            'Corrigido o Android-APK-71 sem alterar as demais funções do mapa.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.102',
          changes: [
            'Mapas offline explica como obter a API key da Stadia Maps e oferece link direto para o painel oficial.',
            'Também há acesso às instruções oficiais e fallback que copia o link quando o navegador não abre.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.101',
          changes: [
            'Planejamento offline limita raio, margem e zoom ao espaço seguro restante e oferece ajuste automático ao limite.',
            'Selecionar região ganhou quadro visual arrastável e redimensionável sobre o mapa.',
            'O mapa completo ganhou altitude, rumo, precisão GPS e estado Seguindo/Mapa livre.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.100',
          changes: [
            'Corrigidos quatro apontamentos do flutter analyze encontrados no Android-APK-68 sem alterar as funcionalidades da 1.0.99.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.99',
          changes: [
            'Mapas offline agora podem ser baixados diretamente por região ou corredor do trajeto usando uma fonte autorizada configurada pelo usuário.',
            'O download mostra progresso, tiles e bytes, respeita limite de cache, pode ser pausado/retomado ou cancelado e mantém importação/link MBTiles.',
            'A rota compartilhada ganhou Pausar/Continuar sem criar saltos de distância e pode ser exportada em GPX pelo seletor do Android.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.98',
          changes: [
            'O mapa do Monitor ganhou modos Automático, Sempre mostrar e Ocultar; no automático ele some em monitoramento doméstico e reaparece com Bike, rota ativa ou deslocamento por GPS.',
            'Mini-mapa e mapa completo agora compartilham uma única sessão de trajeto persistente, restaurada ao reabrir o app.',
            'Mapas offline agora permitem importar MBTiles do aparelho e planejar Região atual, Selecionar região ou Trajeto com estimativa de tamanho e espaço livre.',
            'O mapa completo identifica a fonte como Online, Offline ou Mapa local e mantém a câmera principal flutuante e arrastável.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.97',
          changes: [
            'Corrigido o teste de AppMetadata que ainda esperava a versão 1.0.95 e interrompia o workflow da 1.0.96.',
            'O verificador de sincronização agora confere também as expectativas de versão e build do teste de metadados.',
            'Nenhuma funcionalidade de mapa, câmera ou IA foi alterada nesta correção de build.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.96',
          changes: [
            'O mapa completo ganhou suporte a pacotes MBTiles baixados e armazenados no aparelho.',
            'Mapas offline oferece modos Automático, Online e Offline, com seleção, progresso e exclusão de pacotes.',
            'No modo Automático, o mapa local funciona como base/fallback enquanto a camada online atualiza os tiles quando houver rede.',
            'Ao abrir o mapa pelo Monitor, a câmera principal aparece em PiP flutuante e pode ser arrastada por toda a área útil da tela.',
            'O servidor público do OpenStreetMap continua restrito ao uso online normal; o app não faz download em massa dele.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.95',
          changes: [
            'Cards de velocidade, temperatura, pneus e distância ficaram mais estreitos para caber mais telemetria na mesma linha.',
            'O mapa vertical ficou ainda mais alto e qualquer toque na área útil abre a tela completa; o botão Abrir mapa foi substituído por Câmera.',
            'O botão Câmera centraliza fonte principal, modo com uma ou duas câmeras, frontal de teste, ESP32 e demais câmeras cadastradas.',
            'Áudio, Painel e Ajustes receberam contraste correto para não parecerem desabilitados, e os seis atalhos do painel passam a caber em uma linha quando houver largura.',
            'O botão de áudio superior e as entradas duplicadas de câmeras/Status da sessão foram removidos do menu superior.',
            'Duplo toque na área de vídeo entra em tela inteira; a identificação da principal foi reduzida para Local e o PiP da segunda câmera agora pode ser arrastado dentro da área de vídeo.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.94',
          changes: [
            'O mapa vertical ficou mais alto e o card Detectados foi deslocado para baixo sem esconder os quatro atalhos.',
            'Abrir mapa, Áudio, Painel e Ajustes agora ficam sempre na mesma linha com margens e altura menores.',
            'O mapa passa a mostrar altitude real do GPS em destaque menor, sem o rótulo Bike; a distância continua na telemetria superior.',
            'Cards de velocidade, temperatura e pneus ficaram mais compactos para caber mais telemetria do ESP32.',
            'Foi adicionado um teste temporário de segunda câmera frontal em janela PiP; a IA continua somente na câmera principal.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.93',
          changes: [
            'O bloco grande Detectados agora saiu da tela fixa e virou um resumo compacto tocável.',
            'Os detalhes das detecções agora sobem em um painel arrastável, liberando espaço vertical.',
            'O mini-mapa ganhou rótulos curtos, controles menores e organização mais limpa.',
            'A faixa de telemetria da bike ficou mais compacta para priorizar temperatura, pneus e câmera.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.92',
          changes: [
            'O aplicativo fica travado em retrato fora do modo Transmissão.',
            'O modo Transmissão acompanha livremente a posição física do celular, sem forçar paisagem.',
            'A tela inteira do Monitor permanece vertical e não altera mais a orientação do aparelho.',
            'A rotação dos frames continua usando a orientação do sensor e do dispositivo antes do envio.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.91',
          changes: [
            'Corrigido o lint unnecessary_underscores no separador horizontal da tela vertical do Ao vivo.',
            'O flutter analyze deixa de falhar nesse ponto sem mudança visual ou funcional no Monitor.',
            'A tela vertical com câmera maior, mapa e painel da 1.0.90 foi preservada integralmente.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.90',
          changes: [
            'Tela vertical do Ao vivo redesenhada com câmera maior, mapa do trajeto e ações mais organizadas.',
            'Mini-mapa foi integrado ao modo retrato com rota, distância e botão para abrir a tela completa.',
            'Atalhos avançados saíram da faixa fixa e agora ficam no botão Painel, liberando espaço para a câmera e as detecções.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.89',
          changes: [
            'Corrigidos quatro avisos invalid_use_of_protected_member do dashboard Ao vivo.',
            'A extensão do dashboard não chama mais setState diretamente; a atualização passa pela State do Monitor.',
            'Visual da 1.0.88 com câmera, mapa, telemetria e ações rápidas foi preservado.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.88',
          changes: [
            'Tela Ao vivo em paisagem redesenhada com câmera, mapa do trajeto, telemetria da bike e ações rápidas.',
            'Detecções da câmera única passam a abrir em painel dedicado sob demanda, liberando mais espaço para o vídeo.',
            'Mini-mapa usa o GPS local quando disponível e orienta o usuário quando a localização ainda não foi liberada.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.87',
          changes: [
            'Corrigida a ordem da diretiva part of no componente do Modo Bike.',
            'Eliminado o erro directive_after_declaration que bloqueava o flutter analyze no workflow.',
            'Mapa, GPS e registro de rota da 1.0.86 foram preservados sem alteração funcional.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.86',
          changes: [
            'Modo Bike ganha Mapa do monitoramento com OpenStreetMap e GPS local.',
            'Mapa mostra posição, precisão, velocidade, distância, tempo e última atualização.',
            'Rotas podem ser iniciadas e encerradas, preservando linha do trajeto e marcadores de início/fim durante a sessão.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.85',
          changes: [
            'Faixa de telemetria ESP32/Bike reorganizada em uma única linha horizontal rolável.',
            'Velocidade, temperatura, pneus, sensores/simulação e distância ficam mais compactos e liberam altura para a câmera.',
            'Diagnóstico compacta estados e deixa os botões de desempenho alinhados na mesma linha.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.84',
          changes: [
            'Corrigida a compilação dos rótulos adaptativos na Central de Câmeras.',
            'Configurações não mantém mais parâmetro interno de expansão sem uso.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.83',
          changes: [
            'Cadastro de celular e câmera RTSP agora explica o tipo de fonte antes da conexão.',
            'Central compacta ações e mostra modelo, resolução, FPS e bateria da câmera remota quando disponíveis.',
            'Alterar modo fica acessível sem apagar dados; Configurações e Histórico também foram reorganizados.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.82',
          changes: [
            'A Release passa a disponibilizar APKs diretos: universal, arm64-v8a, armeabi-v7a e x86_64.',
            'Cada arquivo inclui a versão no nome, facilitando escolher e identificar a instalação.',
            'Relatórios técnicos ficam separados do APK para o download não vir dentro de ZIP.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.81',
          changes: [
            'Monitor vertical reorganizado com status, modos, câmera, atalhos e detecções em áreas fixas.',
            'Detectados agora usa rolagem interna e não sobe mais sobre a câmera.',
          ],
        ),
      ],
    );
  }
}

class _DonationPanel extends StatelessWidget {
  const _DonationPanel({super.key, required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 38,
            color: scheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Apoie o desenvolvimento',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Se o aplicativo for útil para você, é possível apoiar o desenvolvimento por PIX.',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            ),
            child: const SelectableText(
              AppMetadata.pixKey,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('COPIAR CHAVE PIX'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.version,
    required this.changes,
    this.current = false,
  });

  final String version;
  final List<String> changes;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Versão $version',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (current) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ATUAL',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ...changes.map(
            (change) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(change)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
