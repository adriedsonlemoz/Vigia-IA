import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<T?> showMapCenteredDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
  double maxHeightFactor = 0.86,
  bool expand = false,
  String barrierLabel = 'Fechar painel',
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final media = MediaQuery.of(dialogContext);
      final availableHeight = math.max(
        240.0,
        media.size.height - media.padding.vertical -
            media.viewInsets.bottom - 36,
      ).toDouble();
      final panelHeight = availableHeight *
          maxHeightFactor.clamp(0.35, 1.0).toDouble();
      final content = builder(dialogContext);
      return AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          14,
          media.padding.top + 18,
          14,
          math.max(18.0,
              media.padding.bottom + media.viewInsets.bottom + 12).toDouble(),
        ),
        child: Center(
          child: Material(
            color: Theme.of(dialogContext).colorScheme.surface,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(22),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: panelHeight,
              ),
              child: expand
                  ? SizedBox(width: maxWidth, height: panelHeight, child: content)
                  : content,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
