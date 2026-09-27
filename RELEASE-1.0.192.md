# Vigia IA 1.0.192+192

Esta entrega corrige a falha encontrada pelo `flutter analyze` no build 153. O HUD compacto usava `compactHud` antes de essa variável existir no escopo, porque os cálculos do banner dockado haviam sido posicionados fora do `LayoutBuilder`. Agora `showDockedNavigationBanner` e `floatingCardBottomInset` são calculados depois de `compactHud`, dentro do mesmo builder.

Também foi removida a asserção nula redundante de `navigationTarget` apontada pelo analisador. A mudança não altera o visual aprovado: a instrução de navegação minimizada continua encaixada ao lado do botão **Gravar** e o painel completo continua disponível ao expandir.
