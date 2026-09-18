import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  }

  static Future<void> immersive() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  }
}
