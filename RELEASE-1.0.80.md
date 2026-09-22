# Vigia IA 1.0.80+80

Revisão do Histórico, integração inicial do ESP32, gerenciamento de fontes e melhoria do artefato Android.

## Histórico

- filtros adaptativos com ícones ficam em uma linha quando a largura permite;
- câmera, horário e tipo de registro usam metadados compactos e alinhados;
- o detalhe oferece `Salvar` para exportar foto/vídeo pelo destino configurado;
- `Excluir` sempre pede confirmação e remove também a mídia associada.

## ESP32 e câmeras

- painel em Configurações > Monitoramento > ESP32 e sensores;
- cadastro de endereço local, chave, nome, sensores Hall/temperatura/pneus, calibrações, limites, telemetria e câmera instalada;
- teste por `/status` e aplicação do contrato por `POST /config`;
- fonte ESP32 disponível na Home, durante o Monitor e como segunda câmera;
- página Câmeras identifica Local, RTSP, Celular remoto e ESP32 e oferece gerenciamento direto;
- a IA continua somente na câmera principal e no celular receptor.

## APK e tamanho

- APK interno do artefato: `VigiaIA-v1.0.80.apk`;
- caches de Gradle e modelos de IA reduzem trabalho repetido do build;
- upload usa compressão zero porque o APK já é um arquivo compactado;
- `apk-size-report.txt` mostra tamanho por diretório e os 30 maiores arquivos internos;
- `flutter-dependencies.txt` e `gradle-release-dependencies.txt` registram as árvores usadas no APK release;
- auditoria identificou VLC/LiteRT/Flutter por múltiplas ABIs, modelos TFLite e áudios como candidatos prováveis; nada foi removido sem medição do APK assinado.

## Validação pendente no workflow

O ambiente local desta entrega não contém Flutter, Dart ou Android SDK. O workflow incluído deve confirmar `flutter analyze`, testes, assinatura, tamanho real e geração do APK.
