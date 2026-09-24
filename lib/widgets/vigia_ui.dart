import 'package:flutter/material.dart';

import '../core/vigia_design.dart';

class VigiaSectionHeading extends StatelessWidget {
  const VigiaSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

class VigiaSurfaceCard extends StatelessWidget {
  const VigiaSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VigiaSpacing.md),
    this.onTap,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: backgroundColor ?? scheme.surface,
      borderRadius: BorderRadius.circular(VigiaRadii.medium),
      border: Border.all(
        color: borderColor ?? scheme.outline.withValues(alpha: 0.16),
      ),
    );
    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class VigiaStatusPill extends StatelessWidget {
  const VigiaStatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VigiaRadii.pill),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class VigiaModeCard extends StatelessWidget {
  const VigiaModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.tags = const <String>[],
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final List<String> tags;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VigiaRadii.large),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.24),
              accent.withValues(alpha: 0.08),
              scheme.surface,
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.38)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VigiaRadii.large),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 36 : 46,
                      height: compact ? 36 : 46,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(compact ? 12 : 15),
                      ),
                      child: Icon(
                        icon,
                        color: accent,
                        size: compact ? 21 : 25,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: compact ? 28 : 34,
                      height: compact ? 28 : 34,
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: compact ? 16 : 19,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 18),
                Text(
                  title,
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: compact ? 15 : 19,
                    fontWeight: FontWeight.w900,
                    height: compact ? 1.1 : null,
                  ),
                ),
                SizedBox(height: compact ? 3 : 5),
                Text(
                  subtitle,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: compact ? 1.2 : 1.35,
                        fontSize: compact ? 10.5 : null,
                      ),
                ),
                if (tags.isNotEmpty) ...[
                  SizedBox(height: compact ? 8 : 14),
                  Wrap(
                    spacing: compact ? 4 : 6,
                    runSpacing: compact ? 4 : 6,
                    children: [
                      for (final tag in tags)
                        VigiaStatusPill(label: tag, color: accent),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VigiaQuickAction extends StatelessWidget {
  const VigiaQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: scheme.primary, size: 21),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
