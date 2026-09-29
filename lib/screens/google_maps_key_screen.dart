import 'dart:async';

import 'package:flutter/material.dart';

import '../services/google_maps_key_service.dart';
import '../services/native_platform_service.dart';

/// Permite que cada pessoa use a própria chave do Google Maps Platform.
class GoogleMapsKeyScreen extends StatefulWidget {
  const GoogleMapsKeyScreen({super.key});

  @override
  State<GoogleMapsKeyScreen> createState() => _GoogleMapsKeyScreenState();
}

class _GoogleMapsKeyScreenState extends State<GoogleMapsKeyScreen> {
  final GoogleMapsKeyService _service = GoogleMapsKeyService.instance;
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  String? _savedKey;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _service.refresh();
    final key = _service.status.isUserKey ? await _service.reveal() : null;
    if (!mounted) return;
    setState(() {
      _savedKey = key;
      if (key != null) _controller.text = key;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = GoogleMapsKeyService.validate(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await _service.save(_controller.text);
      if (!mounted) return;
      setState(() => _savedKey = _controller.text.trim());
      _showMessage(
        'Chave salva. Se o mapa Google já estiver aberto, feche e abra o app '
        'para aplicar.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível salvar a chave: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover chave?'),
        content: const Text(
          'O mapa Google ficará indisponível até você cadastrar outra chave. '
          'O mapa atual continua funcionando normalmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _service.save('');
      if (!mounted) return;
      setState(() {
        _savedKey = null;
        _controller.clear();
        _error = null;
      });
      _showMessage('Chave removida.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível remover a chave: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final status = _service.status;
        final sourceLabel = switch (status.source) {
          'user' => 'Sua chave (guardada de forma criptografada)',
          'build' => 'Chave embutida neste APK',
          _ => 'Nenhuma chave configurada',
        };
        return Scaffold(
          appBar: AppBar(title: const Text('Chave do Google Maps')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: status.configured
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(status.configured
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sourceLabel,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (status.configured)
                              Text(status.masked)
                            else
                              const Text(
                                'Sem chave, o Google Maps não abre. O mapa atual continua disponível.',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Chave da API (Maps SDK for Android)',
                  hintText: 'AIza...',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => unawaited(_save()),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salvar chave'),
                    ),
                  ),
                  if (_savedKey != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => unawaited(_remove()),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remover'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text('Como obter uma chave',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                '1. Acesse console.cloud.google.com e crie um projeto.\n'
                '2. Ative o faturamento (o Google exige, mas há cota gratuita mensal).\n'
                '3. Em APIs e serviços, ative "Maps SDK for Android".\n'
                '4. Em Credenciais, crie uma chave de API.\n'
                '5. Restrinja a chave a apps Android: pacote com.vigiaia.app e a '
                'impressão digital SHA-1 do certificado que assinou este APK.\n'
                '6. Cole a chave acima e salve.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => unawaited(NativePlatformService.instance
                    .openExternalUrl('https://console.cloud.google.com/google/maps-apis')),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir Google Maps Platform'),
              ),
              const SizedBox(height: 16),
              Text(
                'A chave fica só neste aparelho e é usada apenas pelo mapa Google. '
                'O custo de uso, se houver, é da sua conta Google Cloud.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
