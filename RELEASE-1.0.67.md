# Vigia IA 1.0.67+67 — Detecção, áudio e tela inteira

Base: 1.0.66+66. Entrega: 2026-09-21. Este pacote contém o código-fonte; não inclui APK compilado.

## O que mudou

| Problema | Correção | Como conferir |
|---|---|---|
| Identificação lenta | Conversão direta YUV/BGRA, tensor plano reutilizável, resize/letterbox fundidos, XNNPACK solicitado com fallback CPU e troca para modelo leve quando há lentidão persistente | Exportar desempenho; comparar tempo fim a fim, FPS e modelo efetivamente usado |
| Confirmação recomeçava entre análises lentas | Janela baseada no intervalo observado entre capturas analisadas | Candidato fraco precisa reaparecer; evidência forte passa pela confirmação genérica sem um frame extra |
| Recortes extras acumulavam atraso | Todos os recortes auxiliares passam pelo orçamento | `auxiliaryInferenceRuns` permanece zero quando não há orçamento |
| Áudio integrado falhava ou interrompia outros avisos | Volume de mídia, preparação assíncrona, foco transitório, prioridade, fila curta e retorno de falhas assíncronas para TTS | Testar áudio e exportar `audioDiagnostics.events` |
| Paisagem não ocupava a tela | Botão visível de tela inteira horizontal, ocultação nativa de barras e preenchimento proporcional | AppBar e painéis comuns somem; o vídeo ocupa a área da tela |
| Preview tentava usar câmera descartada | Preview acompanha o serviço; remoção da árvore precede dispose; geração invalida frames antigos | Alternar orientação, sair/voltar e trocar fonte sem erro de CameraController |

As 78 gravações padrão foram preservadas, sem reconversão. A identidade permanece `com.vigiaia.app`, com protocolo `vigiaia://pair`. Instalação de atualização requer a mesma assinatura já usada pelo projeto; os arquivos de configuração e o workflow de assinatura foram preservados.

## Regras e limites

- O modelo principal continua sendo EfficientDet-Lite0. A primeira execução é tratada como aquecimento. Três execuções seguintes consecutivas acima de 1.200 ms solicitam o SSD MobileNet V1 na próxima análise. Não há alternância contínua entre modelos.
- A tentativa de substituição mantém o detector anterior se a inicialização do substituto falhar. XNNPACK solicitado não significa que todos os operadores do modelo foram delegados.
- A janela temporal usa duas vezes o intervalo observado, mais 250 ms, limitada entre 1,5 e 30 segundos. Movimento, áreas e permanência continuam valendo. O último objeto ausente não é desenhado por toda essa janela.
- Para não anunciar uma aproximação com imagem antiga, o caminho urgente Bike exige frame de até 1,5 segundo. Novos alertas de objetos e suas falas exigem frame de até 5 segundos. A tela informa quando a análise está atrasada; aumentar a janela de confirmação não torna um frame antigo atual.
- A fila de voz mantém no máximo a próxima mensagem normal. Mensagens pendentes acima de três segundos são descartadas. Alta prioridade interrompe a normal; desligar voz ou encerrar a fonte cancela solicitações.
- `true` no retorno do áudio nativo significa **tratado**: concluído ou suprimido/cancelado intencionalmente. `false` permite fallback. Consulte eventos para distinguir esses casos. O início de reprodução no software não comprova que o som foi ouvido.
- Frases dinâmicas de aproximação Bike continuam dependendo de TTS em português. Slots de sensores marcados como futuros continuam sem integração física nova.
- Sem cliente LAN ativo, a imagem de boas-vindas é renovada a cada dois segundos; ao conectar cliente, volta a valer a cadência configurada.
- Preencher corta as bordas para ocupar a tela, sem deformar a imagem. Ajustar preserva a imagem completa e pode mostrar faixas. Caixas de detecção e áreas usam a mesma transformação.
- A orientação horizontal é solicitada ao Android. Em ambientes que restringem orientação, como determinados modos de janela/tablet, o sistema pode manter a orientação disponível. O layout de tela inteira continua adaptativo.

## Uso e teste no celular

1. Atualize o APK gerado pelo workflow e confirme **Sobre → Mudanças → 1.0.67+67**.
2. Em **Ao vivo**, toque em **Tela inteira horizontal**. Confira as duas posições horizontais, ocultação das barras e ausência de esticamento. Toque na imagem para revelar controles; eles somem após quatro segundos.
3. Alterne **Ajustar/Preencher**, confira alinhamento das caixas e use **Voltar**. O primeiro Voltar deve sair da tela inteira, mantendo a câmera; o próximo segue a navegação normal.
4. Em **Configurações → Geral → Áudios e voz**, teste uma gravação padrão com volume de mídia acima de zero. Confira também uma gravação personalizada e o aviso ao zerar a mídia. Teste saída pelo alto-falante e por fone/Bluetooth, se usado.
5. Durante um alerta, desligue a voz. Não deve aparecer uma fala antiga depois. Em aparelho de desenvolvimento, teste arquivo personalizado inválido: deve tentar o padrão, e uma falha de reprodução deve constar no diagnóstico.
6. Com iluminação semelhante à do teste anterior, apresente pessoa, veículo e animal. Confira confiança, regra de movimento e permanência. Compare a primeira identificação visível e o início da fala em cada tentativa.
7. Em **Mais opções → Status da sessão**, confira o modelo e os tempos. Exporte também **Diagnóstico 60 s**. Repita no mesmo aparelho, com condições semelhantes de carga, temperatura, resolução e regras.
8. Conecte um visualizador LAN e confirme que a imagem atualiza. Saia/volte ao monitor e alterne retrato/paisagem diversas vezes; o diagnóstico não deve registrar preview com controller descartado.

## Como interpretar a telemetria nova

`telemetria.json` usa `schemaVersion: 2`. `liteRtMs` passa a medir somente o tempo de `invoke`; `tensorTransferMs` mede o restante da chamada da API, incluindo cópias de entrada e saída. Somar os dois permite uma comparação mais próxima da medição antiga em torno de `runForMultipleInputs`, embora o pré-processamento também tenha mudado.

`alertContext` contém timestamp de captura, decisão, confiança, movimento, número de confirmações e regras de permanência. `alertEvents` registra coordenação e callbacks de TTS. `audioDiagnostics.events` registra preparo, início, conclusão, erro e supressão no Android, além do volume e da rota quando conhecida. Esses históricos são limitados e não armazenam imagens ou gravações.

A captura profunda é um subconjunto da telemetria normal, podendo repetir frames presentes em `samples`. `summaryScope` informa o conjunto usado nos percentis; não some os dois arrays. Comparações entre exportações da mesma sessão também precisam eliminar frames repetidos pelo timestamp.

Nos logs anteriores havia análises de aproximadamente 11 a 20 segundos. Esta entrega remove custos e bloqueios identificados no código, mas não apresenta benchmark posterior no celular. FPS, precisão, ganho de tempo e comportamento do áudio devem ser confirmados com o APK novo.

## Build e documentação

O workflow existente executa bootstrap Android, obtenção dos dois modelos, `flutter pub get`, verificação preventiva, `flutter analyze`, testes e build release. Os modelos no ZIP continuam como marcadores de código-fonte e são baixados por `tool/fetch_model.sh`; não compile esses marcadores como se fossem modelos válidos.

`tool/bootstrap_android.sh` copia os novos arquivos `AlertAudioPlayer.kt` e `MonitorSystemUi.kt`, além dos componentes nativos existentes e dos 78 áudios. A configuração de assinatura permanente não foi alterada.

Veja [VALIDATION.md](VALIDATION.md) para a situação dos testes desta entrega, [ARCHITECTURE.md](ARCHITECTURE.md) para os contratos e [custom_audio/README.md](custom_audio/README.md) para a biblioteca de voz.

Referências técnicas consultadas: [Interpreter nativo](https://pub.dev/documentation/flutter_litert/latest/native/Interpreter-class.html), [XNNPACK](https://pub.dev/documentation/flutter_litert/latest/native/XNNPackDelegate-class.html) e [barras do sistema no Android](https://developer.android.com/develop/ui/views/layout/immersive).
