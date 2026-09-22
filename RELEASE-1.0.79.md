# Vigia IA 1.0.79+79

Correção do Android-APK-47 e simplificação do menu principal.

## Buildfix

O workflow parava no `flutter analyze` antes dos testes e do APK. Foram corrigidos:

- oito avisos `invalid_use_of_protected_member` nos módulos multicâmera;
- um erro `unqualified_reference_to_static_member_of_extended_type` na Central multicâmera.

As extensões agora solicitam atualização visual por métodos privados das classes `State`, mantendo os arquivos separados sem ignorar regras do analisador.

## Navegação

- menu inferior e barra lateral: Início, Histórico, Monitor e Câmeras;
- Bike removido dos destinos compartilhados e dos manipuladores de índice;
- Modo Bike preservado na seleção inicial;
- acesso direto adicionado em Configurações > Monitoramento > Modo Bike;
- tela Bike ganhou engrenagem para Configurações e mantém a ação de abrir o Monitor para testar o HUD.

## Validação

O verificador preventivo confere que os quatro destinos permanecem sincronizados, que Bike não retorna ao menu principal e que os padrões exatos encontrados no Android-APK-47 não reaparecem.
