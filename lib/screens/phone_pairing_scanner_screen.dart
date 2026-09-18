import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/remote_camera_pairing_service.dart';

class PhonePairingScannerScreen extends StatefulWidget {
  const PhonePairingScannerScreen({super.key});

  @override
  State<PhonePairingScannerScreen> createState() => _PhonePairingScannerScreenState();
}

class _PhonePairingScannerScreenState extends State<PhonePairingScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  bool _handled = false;
  String? _scanMessage;
  String? _lastRejectedRaw;

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handled) return;
    final values = <String>[
      for (final barcode in capture.barcodes)
        if ((barcode.rawValue?.trim().isNotEmpty ?? false)) barcode.rawValue!.trim(),
    ];
    if (values.isEmpty) return;
    final raw = values.first;
    try {
      RemoteCameraPairingService.decode(raw);
    } on FormatException catch (error) {
      if (raw != _lastRejectedRaw && mounted) {
        setState(() {
          _lastRejectedRaw = raw;
          _scanMessage = error.message.toString();
        });
      }
      return;
    }
    _handled = true;
    await _controller.stop();
    if (!mounted) return;
    Navigator.pop(context, raw);
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear celular'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 252,
                height: 252,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          if (_scanMessage != null)
            Align(
              alignment: const Alignment(0, 0.58),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _scanMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Aponte para o QR exibido em Modo Câmera no outro celular.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
