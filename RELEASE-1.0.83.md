# Vigia IA 1.0.83+83

Organização de fontes, câmeras, modos e Configurações.

## Fontes e Câmeras

- O cadastro manual agora abre como `Adicionar celular remoto` ou `Adicionar câmera RTSP`, explicando o papel da fonte antes de pedir endereço e chave.
- A Central de Câmeras usa botões menores em grade para QR, celular, RTSP e ESP32.
- Celulares transmissores identificam modelo, resolução efetiva do vídeo, FPS e bateria sempre que esses dados forem enviados por `/status`.
- ESP32 continua exibindo o estado da câmera e os sensores configurados, sem inventar resolução antes de o módulo informar esse dado.

## Troca de modo

Normal, Monitor, Bike e Transmissão exibem `Alterar modo` no topo. A troca apenas altera o modo inicial salvo; câmeras, eventos, configurações e dados locais permanecem preservados.

## Organização

- Histórico usa filtros menores em uma linha quando há espaço.
- Preferências reúne áudio e aparência.
- Sistema reúne permissões, saúde e IA avançada.
- Sobre é o último grupo das Configurações e exibe somente as cinco últimas alterações.
