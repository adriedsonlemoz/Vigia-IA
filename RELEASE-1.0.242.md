# Vigia IA 1.0.242+242 • Minha Câmera no Vigia

## Entrega

O Vigia IA recebe o QR gerado pelo Minha Câmera 1.4.35 e consome o vídeo MJPEG pela rede local, sem internet. Na tela Modo Monitor há um controle para escolher entre receber e analisar localmente ou apenas visualizar. O Redmi A3 continua responsável por capturar/transmitir a imagem; a IA roda no Vigia IA, no dispositivo receptor.

## Fluxo para testar

1. No Minha Câmera 1.4.35, inicie a transmissão e selecione **MJPEG** (H.264 não suportado neste receptor inicial). Use Wi-Fi/hotspot com os dois aparelhos na mesma rede.
2. No Vigia IA, abra **Modo Monitor > Escanear QR do transmissor** e aponte para o QR mostrado no Redmi A3. O endereço e a chave serão preenchidos automaticamente.
3. Mantenha **Analisar vídeo com IA neste aparelho** ativado para usar o detector instalado do Vigia; ou desligue para usar apenas vídeo ao vivo. Toque em **Receber e analisar**.
4. O vídeo é exibido ao vivo, e a fonte principal com análise ligada envia quadros amostrados ao detector local. O controle desligado evita enviar quadros dessa fonte para IA.
5. Também é possível escanear o QR usando as telas pré-existentes para outro celular e a Central multicâmera. A Central lê o status correto do Minha Câmera.

## Limitações / validação

- QR é um segredo de sessão: não compartilhar URLs/tokens; o endereço é salvo para permitir reconexão, não é incluído em exportações não sensíveis.
- MJPEG apenas nesta etapa; se o transmissor estiver usando H.264, selecionar MJPEG nele antes de conectar.
- Análise requer que o detector de IA do Vigia esteja inicializado e que haja quadros recebidos. Os modelos instalados determinam quais classes de objetos são reconhecidas.
- Testes Flutter e APK ainda dependem do GitHub Actions; uso contínuo, latência e bateria dependem de testes físicos.
