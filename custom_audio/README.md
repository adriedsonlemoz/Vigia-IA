# Biblioteca de áudios do Vigia IA

A pasta `custom_audio/` contém os áudios padrão embarcados no aplicativo. O catálogo central possui 78 slots: 14 usados pelo monitor atual e 64 reservados para a evolução do Modo Bike/ESP32. Desde a 1.0.48, os arquivos padrão são AAC/M4A mono em 24 kHz. Na 1.0.53, a reprodução passou a materializar o recurso `res/raw` no cache privado antes de entregá-lo ao `MediaPlayer`, evitando incompatibilidades com URI de recurso em alguns aparelhos Android.

## Reprodução desde 1.0.67

O player usa o **volume de mídia** do Android. Aumente esse volume para testar; o app não muda o volume do aparelho automaticamente. A tela avisa quando a mídia está muda/zerada e aguarda a conclusão do teste antes de aceitar outro toque.

A preparação é assíncrona. O cache de cada áudio padrão é criado uma vez por atualização do APK. Arquivo personalizado inválido tenta o padrão; falha do padrão, inclusive depois de iniciar, é devolvida à camada de voz para tentativa de TTS. Cancelamento/supressão por prioridade não ressuscita uma fala antiga.

Alertas de maior prioridade interrompem os normais. A fila comporta apenas a próxima mensagem normal, descartada se envelhecer; desligar a voz cancela arquivo e TTS. No Diagnóstico, `started` registra início efetivo do MediaPlayer, volume, rota disponível e falhas; conclusão de software não comprova som audível no ambiente.

As frases dinâmicas de aproximação Bike continuam em TTS: o catálogo não contém um áudio específico para esse aviso. Ter um áudio em um slot marcado **Futuro** não conecta o sensor correspondente.


## Prioridade em tempo de execução

Para cada slot, o aplicativo tenta nesta ordem:

1. áudio gravado ou escolhido pelo usuário em **Configurações → Geral → Áudios e voz**;
2. áudio padrão embarcado nesta pasta;
3. TTS do Android, quando o evento possui frase dinâmica e nenhum áudio pôde ser reproduzido.

Os áudios personalizados ficam no armazenamento interno do app e sobrevivem a atualizações normais do APK. Desinstalar o aplicativo remove esses arquivos junto com os demais dados privados do app.

## Personalização no aplicativo

A tela **Áudios e voz** permite, individualmente para cada slot:

- ouvir o áudio efetivo;
- escolher um arquivo de áudio do aparelho;
- gravar uma nova fala pelo microfone;
- restaurar o áudio padrão;
- restaurar todos os padrões de uma vez.

Arquivos importados aceitos pelo Android incluem WAV, MP3, OGG, M4A/AAC e MP4 de áudio. Gravações feitas pelo app usam AAC/M4A mono.

## Grupos

- Monitoramento: detecção, entrada/saída e integridade da câmera;
- Bike · Pneus e sensores: pressão, temperatura, TPMS/Hall e velocidade;
- Bike · ESP32: conexão, comunicação e bateria do módulo;
- Bike · Celular traseiro: bateria, temperatura, conexão e câmera;
- Bike · Operação: ativação e início/fim do monitoramento;
- Bike · Iluminação: faróis, lanterna e sensor de luz;
- Bike · Freios e setas: luz de freio, freios, setas e pisca-alerta;
- Bike · Sistema e energia: sensores gerais, bateria auxiliar e estado do sistema.

Os slots Bike marcados como **Futuro** já possuem áudio e interface, mas só serão disparados quando as futuras integrações ESP32/TPMS/Hall/iluminação/freios forem conectadas ao aplicativo.

## Build

`tool/bootstrap_android.sh` copia automaticamente os arquivos desta pasta para `android/app/src/main/res/raw/`. Os nomes dos slots usam apenas letras minúsculas, números e sublinhado.
