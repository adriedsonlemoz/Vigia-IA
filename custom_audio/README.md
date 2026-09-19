# Áudios personalizados do Vigia IA

Esta pasta é opcional. Se nenhum arquivo estiver presente, o Vigia IA continua
usando a voz TTS do Android como hoje.

Para substituir a voz por gravações próprias, coloque **um único arquivo por
slot**, usando exatamente um dos nomes abaixo e extensão `.wav`, `.mp3` ou
`.ogg`:

- `person_detected.wav` — pessoa detectada;
- `vehicle_detected.wav` — automóvel detectado;
- `animal_detected.wav` — animal detectado;
- `object_detected.wav` — fallback para outro objeto;
- `object_entered.wav` — objeto entrou na área;
- `object_exited.wav` — objeto saiu da área;
- `camera_obstructed.wav` — câmera obstruída;
- `camera_moved.wav` — câmera deslocada.

Pode usar `.mp3` ou `.ogg` no lugar de `.wav`, mantendo o mesmo nome-base.
Não coloque duas extensões para o mesmo slot no mesmo build.

No workflow Android, `tool/bootstrap_android.sh` copia automaticamente esses
arquivos para `android/app/src/main/res/raw/`. O app procura o áudio pelo nome em
tempo de execução. Se um slot não existir, ele cai automaticamente para o TTS.

Recomendação prática: áudio mono, curto (aprox. 0,5–4 s) e sem silêncio longo no
início. Nomes de arquivo Android devem usar apenas letras minúsculas, números e
sublinhado.
