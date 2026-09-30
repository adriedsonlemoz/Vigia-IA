import 'package:flutter/material.dart';

/// Breakpoints used by the main Vigia IA surfaces.
///
/// The app intentionally distinguishes a phone rotated to landscape from a
/// large tablet: both can use lateral navigation, but only screens with enough
/// useful width receive permanent split panes.
class AdaptiveLayout {
  const AdaptiveLayout._();

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isLandscape(BuildContext context) {
    final size = sizeOf(context);
    return size.width > size.height;
  }

  static bool isTablet(BuildContext context) {
    final size = sizeOf(context);
    return size.shortestSide >= 600;
  }

  static bool useNavigationRail(BuildContext context) {
    final size = sizeOf(context);
    return size.width >= 720 && (size.width > size.height || isTablet(context));
  }

  static bool useTwoPaneContent(BuildContext context, {double minWidth = 820}) {
    final size = sizeOf(context);
    return size.width >= minWidth && size.height >= 330;
  }

  static bool usePermanentSidePanel(BuildContext context) {
    final size = sizeOf(context);
    return isTablet(context) && size.width >= 980;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final tablet = isTablet(context);
    return EdgeInsets.symmetric(
      horizontal: tablet ? 22 : 16,
      vertical: tablet ? 16 : 10,
    );
  }

  static double maxContentWidth(BuildContext context) => isTablet(context) ? 1320 : 1120;
}
