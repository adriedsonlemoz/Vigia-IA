import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_metadata.dart';

enum AppInfoSection { about, changes, donations }

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({
    super.key,
    this.initialSection = AppInfoSection.about,
  });

  final AppInfoSection initialSection;

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  late AppInfoSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  Future<void> _copyPix() async {
    await Clipboard.setData(const ClipboardData(text: AppMetadata.pixKey));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chave PIX copiada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informações do aplicativo')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                SegmentedButton<AppInfoSection>(
                  segments: const [
                    ButtonSegment(
                      value: AppInfoSection.about,
                      icon: Icon(Icons.info_outline_rounded),
                      label: Text('Sobre'),
                    ),
                    ButtonSegment(
                      value: AppInfoSection.changes,
                      icon: Icon(Icons.history_rounded),
                      label: Text('Mudanças'),
                    ),
                    ButtonSegment(
                      value: AppInfoSection.donations,
                      icon: Icon(Icons.volunteer_activism_outlined),
                      label: Text('Doações'),
                    ),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) =>
                      setState(() => _section = value.first),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (_section) {
                    AppInfoSection.about => const _AboutPanel(
                        key: ValueKey('about'),
                      ),
                    AppInfoSection.changes => const _ChangesPanel(
                        key: ValueKey('changes'),
                      ),
                    AppInfoSection.donations => _DonationPanel(
                        key: const ValueKey('donations'),
                        onCopy: _copyPix,
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 2),
                    Text('Vigilância local com IA offline'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _InfoRow(label: 'Versão', value: '${AppMetadata.version}+${AppMetadata.build}'),
          const _InfoRow(label: 'Desenvolvedor', value: AppMetadata.developer),
          const Divider(height: 28),
          const Text(
            'O Vigia IA usa a câmera do dispositivo ou uma fonte RTSP para analisar objetos localmente, registrar eventos e emitir alertas sem depender de serviços de nuvem para a IA.',
          ),
        ],
      ),
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
          version: '1.0.39',
          current: true,
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
          Icon(Icons.volunteer_activism_outlined, size: 38, color: scheme.primary),
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
  const _ReleaseCard({required this.version, required this.changes, this.current = false});

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
              Text('Versão $version', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              if (current) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('ATUAL', style: TextStyle(color: scheme.primary, fontSize: 10, fontWeight: FontWeight.w900)),
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
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
