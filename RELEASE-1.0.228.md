# Vigia IA — Release 1.0.228+228

Data: 12/10/2026 · versionCode 228 · primeira versão do ciclo de quatro

## Entrega

- Indicador de contexto Explorar, Pedalar, Navegar ou Gravar, com REC explícito durante navegação+gravação.
- Telemetria recolhida por padrão em Explorar e Navegar; expandida por padrão em Pedalar ou ao Gravar sem navegação. Usuário pode alternar a qualquer momento.
- POIs e zoom secundários não se sobrepõem continuamente ao mapa; busca, recentralização, créditos e painel de navegação permanecem acessíveis.
- Câmera, rádio, áudio e Bike continuam alcançáveis via Configurações do mapa; atalhos aparecem sob demanda/alerta. Nenhum recurso de fundo é iniciado pelo novo HUD.
- Política de apresentação e widget extraídos da tela grande, preservando navegação e gravação reais.

## Testes e limites

- `tool/verify_project.sh` e contratos Python: ver relatório de validação.
- Testes Dart de política e widget para 320/360/412 dp e texto 1,0/1,5x incluídos, sem execução local por falta do SDK Flutter.
- Compilação e assinatura Android dependem de novo workflow; não declarar APK pronto antes da aprovação do CI.
- Teste manual acumulado programado para a 1.0.231, antes da refatoração progressiva da 1.0.232+.
