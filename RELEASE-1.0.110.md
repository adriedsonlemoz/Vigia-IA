# Vigia IA 1.0.110+110

## Resumo

Esta entrega adiciona o botão **Mapa** à fileira fixa de ações do monitor e corrige a falha de empacotamento identificada no Android-APK-78.

## Alterações

- fileira fixa agora contém **Câmera, Mapa, Áudio, Painel e Ajustes**;
- o botão **Mapa** mostra/oculta o mini mapa e indica visualmente quando está ativo;
- o controle funciona independentemente do modo Bike e reutiliza a preferência persistida do `MapRouteService`;
- `.gitignore` foi restaurado com proteção de arquivos de assinatura;
- o ZIP é gerado pelo empacotador oficial, que valida a presença do `.gitignore` antes da entrega.

## Versão

- `1.0.110+110`
