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
          version: '1.0.83',
          current: true,
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
          version: '1.0.83',
          current: true,
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
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.80',
          changes: [
            'Histórico reorganizado e detalhe da captura ganhou salvar e excluir com confirmação.',
            'Painel ESP32 integra sensores e uma futura câmera como fonte do Monitor.',
          ],
        ),
        SizedBox(height: 10),
        _ReleaseCard(
          version: '1.0.79',
          changes: [
            'Menu principal simplificado para Início, Histórico, Monitor e Câmeras.',
            'Modo Bike continua disponível pela seleção inicial e por Configurações.',
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
