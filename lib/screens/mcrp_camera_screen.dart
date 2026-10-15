import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vlc_player/vlc_player.dart';

import '../services/mcrp_client.dart';
import '../services/native_platform_service.dart';
import '../services/object_detection_service.dart';
import '../sources/minha_camera_mjpeg_source.dart';
import '../core/video_source_status.dart';
import '../models/detection.dart';
import '../models/rgb_frame.dart';
import '../widgets/detection_overlay.dart';

/// Cliente independente para Minha Câmera. Não muda o fluxo de IA ou QR vigiaia://pair.
class McrpCameraScreen extends StatefulWidget {
  const McrpCameraScreen({super.key});
  @override
  State<McrpCameraScreen> createState() => _McrpCameraScreenState();
}

class _McrpCameraScreenState extends State<McrpCameraScreen> {
  final _input = TextEditingController();
  McrpClient? _client;
  Map<String, dynamic>? _info;
  Map<String, String> _status = {};
  List<McrpMediaItem> _media = [];
  Timer? _timer;
  bool _working = false;
  bool _showMedia = false;
  bool _analyze = false;
  bool _legacy = false;
  String? _error;
  int _streamRevision = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _client?.close();
    _input.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const _McrpQrScanner(),
    ));
    if (!mounted || value == null) return;
    _input.text = value;
    await _connect();
  }

  Future<void> _connect() async {
    if (_working) return;
    setState(() { _working = true; _error = null; });
    McrpClient? next;
    try {
      final address = McrpAddress.parse(_input.text);
      next = McrpClient(address);
      Map<String, dynamic>? info;
      var legacy = false;
      try {
        info = await next.info();
      } on HttpException catch (error) {
        // Minha Câmera 1.4.35 possui /status e MJPEG, mas não /mcrp/info.
        // Apenas HTTP 404 permite fallback; não ignorar erro de autorização.
        if (!McrpClient.supportsLegacyFallback(error)) {
          rethrow;
        }
        legacy = true;
      }
      final status = await next.status();
      if (legacy && status['x-stream-codec'] == null &&
          status['x-device-model'] == null) {
        throw const FormatException('Status do Minha Câmera incompatível.');
      }
      if (!mounted) { next.close(); return; }
      _timer?.cancel();
      _client?.close();
      setState(() {
        _client = next;
        _info = info;
        _legacy = legacy;
        _status = status;
        _streamRevision++;
        _showMedia = false;
        _media = [];
      });
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_refreshStatus()));
    } catch (error) {
      next?.close();
      if (mounted) setState(() => _error = error.toString());
    } finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _refreshStatus() async {
    final client = _client;
    if (client == null) return;
    try {
      final status = await client.status();
      if (!mounted || _client != client) return;
      final codecOld = _status['x-stream-codec'];
      setState(() {
        _status = status;
        if (codecOld != status['x-stream-codec']) _streamRevision++;
      });
    } catch (error) {
      if (mounted && _client == client) setState(() => _error = 'Estado remoto: $error');
    }
  }

  Future<void> _command(String action) async {
    final client = _client;
    if (client == null || _working) return;
    setState(() { _working = true; _error = null; });
    try {
      await client.command(action);
      await _refreshStatus();
      if (mounted && action.startsWith('codec/')) setState(() => _streamRevision++);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _loadMedia() async {
    final client = _client;
    if (client == null) return;
    setState(() { _working = true; _showMedia = true; _error = null; });
    try {
      final items = await client.media();
      if (mounted && _client == client) setState(() => _media = items);
    } catch (error) { if (mounted) setState(() => _error = 'Multimídia: $error'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _download(McrpMediaItem item) async {
    final client = _client;
    if (client == null || _working) return;
    setState(() { _working = true; _error = null; });
    try {
      final directory = Directory('${(await getApplicationDocumentsDirectory()).path}/MinhaCameraRecebidos');
      final file = await client.download(item, directory);
      String location = 'Pasta privada do Vigia IA: ${file.path}';
      if (item.mime.startsWith('image/') || item.mime.startsWith('video/')) {
        try {
          final published = await NativePlatformService.instance.publishCameraMedia(
            path: file.path, fileName: item.name, mimeType: item.mime,
          );
          if (published != null) location = published;
        } catch (_) {
          // Mantém o download íntegro na pasta privada para uma nova tentativa.
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Arquivo salvo em: $location'),
        duration: const Duration(seconds: 5),
      ));
    } catch (error) { if (mounted) setState(() => _error = 'Download: $error'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  void _openMedia(McrpMediaItem item) {
    final client = _client;
    if (client == null) return;
    final uri = client.address.mediaFile(item.id);
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 460,
        height: 270,
        child: item.mime.startsWith('video/')
            ? _McrpVlcView(key: ValueKey(uri.toString()), url: uri.toString(), h264: false)
            : item.mime.startsWith('image/')
                ? Image.network(uri.toString(), fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text('Não foi possível abrir a fotografia.'))
                : const Text('Prévia indisponível para este formato.'),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    ));
  }

  Widget _controls() {
    final recording = _status['x-recording'] == '1';
    final eco = _status['x-eco'] == '1';
    final codec = _status['x-stream-codec'] ?? 'mjpeg';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: _working ? null : () => _command('record/${recording ? 'stop' : 'start'}'),
          icon: Icon(recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record),
          label: Text(recording ? 'Parar REC' : 'Gravar')),
        OutlinedButton.icon(onPressed: _working ? null : () => _command('photo'),
          icon: const Icon(Icons.photo_camera), label: const Text('Foto')),
        OutlinedButton.icon(onPressed: _working ? null : () => _command('eco/${eco ? 'disable' : 'enable'}'),
          icon: const Icon(Icons.battery_saver), label: Text(eco ? 'Desativar Eco' : 'Eco')),
        OutlinedButton.icon(onPressed: _working ? null : () => _command('camera/${_status['x-camera-facing'] == '1' ? 'back' : 'front'}'),
          icon: const Icon(Icons.cameraswitch), label: const Text('Trocar câmera')),
        OutlinedButton.icon(onPressed: _working ? null : () => _command('codec/${codec == 'mjpeg' ? 'h264' : 'mjpeg'}'),
          icon: const Icon(Icons.swap_horiz), label: Text('Codec: ${codec.toUpperCase()}')),
        OutlinedButton.icon(onPressed: _working || _legacy ? null : _loadMedia,
          icon: const Icon(Icons.video_library_outlined), label: const Text('Multimídia')),
        OutlinedButton.icon(onPressed: _working || _legacy ? null : _showDiagnostic,
          icon: const Icon(Icons.bug_report_outlined), label: const Text('Diagnóstico')),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final q in [360, 480, 720, 768, 1080])
          ActionChip(label: Text('${q}p'), onPressed: _working ? null : () => _command('quality/$q')),
        for (final fps in [10, 15, 24, 30])
          ActionChip(label: Text('$fps FPS'), onPressed: _working ? null : () => _command('fps/$fps')),
      ]),
    ]);
  }

  Future<void> _showDiagnostic() async {
    final client = _client;
    if (client == null) return;
    try {
      final report = await client.diagnostic();
      if (!mounted) return;
      showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Diagnóstico do transmissor'),
        content: SizedBox(width: 480, height: 320, child: SingleChildScrollView(child: SelectableText(report))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ));
    } catch (error) { if (mounted) setState(() => _error = '$error'); }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final codec = _status['x-stream-codec'] ?? 'mjpeg';
    final model = (_info?['device'] is Map) ? (_info!['device'] as Map)['model']?.toString() : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Minha Câmera · MCRP v1')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Conecte o QR exibido pelo Minha Câmera ou informe a URL /live/ completa. Funciona pela rede Wi-Fi local, sem internet.'),
        const SizedBox(height: 12),
        TextField(controller: _input, keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'URL da câmera', hintText: 'http://192.168.1.2:8765/live/…', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _working ? null : _connect,
            icon: const Icon(Icons.wifi), label: const Text('Conectar'))),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _working ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner), label: const Text('QR')),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_working) const LinearProgressIndicator(),
        if (client != null) ...[
          const SizedBox(height: 12),
          if (_legacy) const Text('Conexão compatível com Minha Câmera 1.4.35. '
              'Biblioteca MCRP e diagnóstico avançado exigem transmissor 1.4.36 ou posterior.'),
          Text('${model ?? 'Celular remoto'}  ·  ${_status['x-resolution'] ?? 'Resolução desconhecida'}  ·  ${_status['x-fps-target'] ?? '?'} FPS',
            style: Theme.of(context).textTheme.titleMedium),
          Text('AO VIVO ${_status['x-transmission-seconds'] ?? '0'}s  ·  REC ${_status['x-recording-seconds'] ?? '0'}s  ·  Bateria ${_status['x-battery-level'] ?? '?'}%'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Analisar vídeo com IA no Vigia IA'),
            subtitle: Text(codec == 'h264'
                ? 'A IA local exige MJPEG. Alterne o codec para MJPEG.'
                : 'Desligado: apenas visualização. Ligado: detector local e caixas de objetos.'),
            value: _analyze,
            onChanged: codec == 'h264' ? null : (value) => setState(() => _analyze = value),
          ),
          const SizedBox(height: 10),
          AspectRatio(aspectRatio: 16 / 9, child: Container(
            color: Colors.black,
            child: codec == 'h264'
                ? _McrpVlcView(key: ValueKey('h264_$_streamRevision'), url: client.address.h264.toString(), h264: true)
                : _McrpMjpegView(key: ValueKey('mjpeg_$_streamRevision'),
                    url: client.address.liveUrl.toString(), analysisEnabled: _analyze),
          )),
          const SizedBox(height: 12),
          _controls(),
          if (_showMedia) ...[
            const Divider(height: 32),
            Row(children: [const Expanded(child: Text('Arquivos do transmissor', style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(onPressed: _loadMedia, icon: const Icon(Icons.refresh))]),
            if (_media.isEmpty) const Text('Nenhum arquivo retornado.'),
            for (final item in _media)
              ListTile(
                leading: Icon(item.mime.startsWith('image/') ? Icons.image_outlined : Icons.movie_outlined),
                title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${(item.size / 1024 / 1024).toStringAsFixed(1)} MB'),
                onTap: () => _openMedia(item),
                trailing: IconButton(tooltip: 'Baixar cópia', icon: const Icon(Icons.download),
                  onPressed: _working ? null : () => _download(item)),
              ),
          ],
        ],
      ]),
    );
  }
}

class _McrpQrScanner extends StatefulWidget {
  const _McrpQrScanner();
  @override
  State<_McrpQrScanner> createState() => _McrpQrScannerState();
}
class _McrpQrScannerState extends State<_McrpQrScanner> {
  final scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool done = false;
  @override void dispose() { unawaited(scanner.dispose()); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ler QR do Minha Câmera')),
    body: MobileScanner(controller: scanner, onDetect: (capture) {
      if (done) return;
      for (final code in capture.barcodes) {
        final raw = code.rawValue;
        if (raw == null) continue;
        try { McrpAddress.parse(raw); } on FormatException { continue; }
        done = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }),
  );
}

class _McrpVlcView extends StatefulWidget {
  const _McrpVlcView({super.key, required this.url, required this.h264});
  final String url;
  final bool h264;
  @override State<_McrpVlcView> createState() => _McrpVlcViewState();
}
class _McrpVlcViewState extends State<_McrpVlcView> {
  late final VlcPlayerController controller;
  @override void initState() {
    super.initState();
    controller = VlcPlayerController(
      mediaSource: VlcMediaSource(uri: Uri.parse(widget.url), mediaOptions: [
        ':network-caching=220', ':no-audio', if (widget.h264) ':demux=h264',
      ]),
      autoPlay: true,
      options: const ['--no-audio'],
    );
  }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => VlcPlayer(controller: controller, fit: VlcVideoFit.contain);
}

/// Usa o MESMO receptor MJPEG do Modo Monitor (com reconexão e parser
/// limitado em memória). Quadros RGB amostrados são inferidos somente no Vigia.
/// Uma única conexão atende prévia e análise, sem carga extra no transmissor.
class _McrpMjpegView extends StatefulWidget {
  const _McrpMjpegView({super.key, required this.url, required this.analysisEnabled});
  final String url;
  final bool analysisEnabled;

  @override
  State<_McrpMjpegView> createState() => _McrpMjpegViewState();
}

class _McrpMjpegViewState extends State<_McrpMjpegView> {
  late MinhaCameraMjpegSource _source;
  StreamSubscription<RgbFrame>? _frames;
  StreamSubscription<VideoSourceStatus>? _statuses;
  ObjectDetectionService? _detector;
  List<Detection> _detections = const [];
  VideoSourceStatus? _status;
  bool _aiReady = false;
  bool _processing = false;
  String? _aiError;
  double? _aspectRatio;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _McrpMjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.analysisEnabled != oldWidget.analysisEnabled) {
      _stop();
      _start();
    }
  }

  void _start() {
    final generation = ++_generation;
    _source = MinhaCameraMjpegSource(
      liveUrl: widget.url,
      emitFrames: widget.analysisEnabled,
      analysisInterval: const Duration(milliseconds: 800),
    );
    final source = _source;
    _frames = source.frames.listen((frame) => _onFrame(frame, generation));
    _statuses = source.statuses.listen((status) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _status = status;
        if (status.state != VideoSourceState.streaming) _detections = const [];
      });
    });
    unawaited(_startSource(source, generation));
    if (widget.analysisEnabled) unawaited(_startAi(generation));
  }

  Future<void> _startSource(MinhaCameraMjpegSource source, int generation) async {
    try {
      await source.start();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _aiError = 'Não foi possível iniciar a transmissão MJPEG.');
      }
    }
  }

  Future<void> _startAi(int generation) async {
    final detector = ObjectDetectionService();
    _detector = detector;
    try {
      await detector.initialize();
      if (!mounted || generation != _generation) return;
      setState(() => _aiReady = true);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _aiError = 'Modelo de IA indisponível. Vídeo continua ativo.');
      }
    }
  }

  Future<void> _onFrame(RgbFrame frame, int generation) async {
    final detector = _detector;
    if (!widget.analysisEnabled || !_aiReady || _processing ||
        detector == null || generation != _generation) return;
    _processing = true;
    try {
      final detections = await detector.detect(
        frame, threshold: 0.55, maxResults: 10,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _detections = detections;
        _aspectRatio = frame.width / frame.height;
        _aiError = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _aiError = 'Falha na inferência local; vídeo preservado.');
      }
    } finally {
      if (generation == _generation) _processing = false;
    }
  }

  void _stop() {
    _generation++;
    unawaited(_frames?.cancel());
    unawaited(_statuses?.cancel());
    unawaited(_source.dispose());
    final detector = _detector;
    _detector = null;
    if (detector != null) unawaited(detector.dispose());
    _detections = const [];
    _aspectRatio = null;
    _status = null;
    _aiReady = false;
    _processing = false;
    _aiError = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      _source.buildPreview(),
      if (widget.analysisEnabled && _detections.isNotEmpty)
        DetectionOverlay(
          detections: _detections,
          previewAspectRatio: _aspectRatio,
        ),
      if (_status?.state == VideoSourceState.reconnecting ||
          _status?.state == VideoSourceState.connecting)
        Positioned(left: 8, bottom: 8, child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black87,
            borderRadius: BorderRadius.circular(8)),
          child: const Padding(padding: EdgeInsets.all(6),
            child: Text('Conectando / reconectando…',
              style: TextStyle(color: Colors.white))),
        )),
      if (widget.analysisEnabled)
        Positioned(right: 8, top: 8, child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black87,
            borderRadius: BorderRadius.circular(8)),
          child: Padding(padding: const EdgeInsets.all(6),
            child: Text(_aiReady ? 'IA local · ${_detections.length} objetos'
                : _aiError ?? 'Preparando IA local…',
              style: const TextStyle(color: Colors.white))),
        )),
      if (_status?.state == VideoSourceState.error ||
          (!widget.analysisEnabled && _aiError != null))
        Positioned(left: 8, right: 8, bottom: 8, child: Text(
          _status?.message ?? _aiError ?? 'Transmissão indisponível',
          style: const TextStyle(color: Colors.orangeAccent),
        )),
    ]);
  }
}
