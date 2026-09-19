# Áudios personalizados do Vigia IA

Esta pasta contém os áudios opcionais usados pelo Android no lugar do TTS. Se um
slot não existir, o Vigia IA continua usando automaticamente a voz TTS do
Android para aquele evento.

## Slots suportados

Detecção:

- `person_detected.wav` — pessoa detectada;
- `vehicle_detected.wav` — automóvel detectado;
- `animal_detected.wav` — animal detectado;
- `object_detected.wav` — fallback para outro objeto.

Entrada/saída por categoria:

- `person_entered.wav` / `person_exited.wav`;
- `vehicle_entered.wav` / `vehicle_exited.wav`;
- `animal_entered.wav` / `animal_exited.wav`;
- `object_entered.wav` / `object_exited.wav` — fallback para outra classe.

Integridade da câmera:

- `camera_obstructed.wav` — câmera obstruída;
- `camera_moved.wav` — câmera deslocada.

Pode usar `.mp3` ou `.ogg` no lugar de `.wav`, mantendo o mesmo nome-base. Não
coloque duas extensões para o mesmo slot no mesmo build.

## Áudio incluído nesta versão

O arquivo único fornecido em 19/09/2026 foi separado em dez falas e incluído
nesta pasta: detecção de pessoa/veículo/animal/objeto, entrada e saída de pessoa
e veículo, câmera obstruída e câmera deslocada.

A gravação recebida não contém as duas frases `Animal entrou na área` e
`Animal saiu da área`. Por isso `animal_entered` e `animal_exited` continuam
caindo automaticamente para TTS até esses dois arquivos serem adicionados.

## Build

`tool/bootstrap_android.sh` copia automaticamente os arquivos desta pasta para
`android/app/src/main/res/raw/`. O app procura o áudio pelo nome em tempo de
execução. Nomes Android devem usar apenas letras minúsculas, números e
sublinhado.

Recomendação prática: áudio mono, curto (aprox. 0,5–4 s), sem silêncio longo no
início e com volume consistente.
