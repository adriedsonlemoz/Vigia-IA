import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_platform_service.dart';

class SystemUiService {
  const SystemUiService._();

  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
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
