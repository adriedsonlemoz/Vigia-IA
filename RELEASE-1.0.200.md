# Vigia IA 1.0.200+200

Correções sobre a integração do Google Maps introduzida na 1.0.199 e restauração de uma rotina de recuperação de rede que estava inativa.

## Mapa

- `google_maps_flutter` não expõe o motivo do movimento de câmera (`CameraMoveStartedReason` não existe no pacote); o app agora usa um controle interno para saber se o movimento foi disparado pelo próprio app (focar ponto, seguir posição, ajustar aos limites da rota) ou por um gesto do usuário, preservando o comportamento de desligar o "seguir posição" apenas quando o usuário mexe o mapa manualmente.
- Corrigido um possível acesso a valor nulo ao montar o texto de distância de um marcador de ponto de interesse no Google Maps.

## Conectividade e navegação

- Restaurada a recuperação automática de navegação: existia um handler de mudança de conectividade duplicado, e a versão vazia (que só atualizava a tela) tinha prioridade sobre a versão completa, que recalcula rota, atualiza pontos de interesse online e aplica a política de fallback offline. Agora existe um único handler, e o comportamento completo volta a funcionar.

## Compatibilidade

- Nenhuma tela, serviço ou preferência foi removida. O provedor de mapa (`Mapa atual` ou `Google Maps`) e sua persistência continuam como na 1.0.199.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- `flutter analyze`
- `flutter test`
- Workflow Android de release
