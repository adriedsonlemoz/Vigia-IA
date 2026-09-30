import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_platform_service.dart';

class SystemUiService {
  const SystemUiService._();

  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// Estilo explícito para superfícies edge-to-edge com conteúdo visual sob as
  /// barras do sistema. O mapa usa scrims próprios para manter contraste tanto
  /// em tiles claros quanto escuros.
  static const SystemUiOverlayStyle mapOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0x33000000),
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static Future<void> edgeToEdge() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
    await NativePlatformService.instance.setMonitorFullscreen(false);
  }

  static Future<void> immersive() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await NativePlatformService.instance.setMonitorFullscreen(true);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  }
}
