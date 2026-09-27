import 'dart:async';

import 'package:flutter/material.dart';

import '../services/update_news_service.dart';
import 'update_news_dialog.dart';

class UpdateNewsHost extends StatefulWidget {
  const UpdateNewsHost({
    super.key,
    required this.child,
    this.service,
    this.onHandled,
  });

  final Widget child;
  final UpdateNewsService? service;
  final VoidCallback? onHandled;

  @override
  State<UpdateNewsHost> createState() => _UpdateNewsHostState();
}

class _UpdateNewsHostState extends State<UpdateNewsHost> {
  UpdateNewsService get _service => widget.service ?? UpdateNewsService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  Future<void> _check() async {
    try {
      final decision = await _service.evaluate();
      if (!mounted) return;
      if (decision.shouldShow) {
        final acknowledged = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdateNewsDialog(decision: decision),
        );
        if (acknowledged == true) await _service.markShown(decision);
      }
    } catch (_) {
      // Novidades são informativas: qualquer falha deve liberar o app.
    } finally {
      if (mounted) widget.onHandled?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
