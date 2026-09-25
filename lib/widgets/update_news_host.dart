import 'dart:async';

import 'package:flutter/material.dart';

import '../services/update_news_service.dart';
import 'update_news_dialog.dart';

class UpdateNewsHost extends StatefulWidget {
  const UpdateNewsHost({
    super.key,
    required this.child,
    this.service,
  });

  final Widget child;
  final UpdateNewsService? service;

  @override
  State<UpdateNewsHost> createState() => _UpdateNewsHostState();
}

class _UpdateNewsHostState extends State<UpdateNewsHost> {
  bool _ready = false;

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
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => UpdateNewsDialog(decision: decision),
        );
        await _service.markShown(decision);
      }
    } catch (_) {
      // Novidades são informativas: qualquer falha deve liberar o app.
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
