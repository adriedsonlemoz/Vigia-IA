import 'package:flutter/material.dart';

import '../screens/error_center_screen.dart';
import '../services/error_log_service.dart';

class ErrorCenterButton extends StatefulWidget {
  const ErrorCenterButton({super.key});

  @override
  State<ErrorCenterButton> createState() => _ErrorCenterButtonState();
}

class _ErrorCenterButtonState extends State<ErrorCenterButton> {
  final ErrorLogService _logs = ErrorLogService.instance;

  @override
  void initState() {
    super.initState();
    _logs.addListener(_refresh);
  }

  @override
  void dispose() {
    _logs.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count = _logs.problemCount;
    return IconButton(
      tooltip: 'Diagnóstico',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ErrorCenterScreen()),
        );
      },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.health_and_safety_outlined),
      ),
    );
  }
}
