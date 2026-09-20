import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_metadata.dart';

part 'app_info_screen_components.dart';

enum AppInfoSection { about, changes, donations }

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({
    super.key,
    this.initialSection = AppInfoSection.about,
  });

  final AppInfoSection initialSection;

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  late AppInfoSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  Future<void> _copyPix() async {
    await Clipboard.setData(const ClipboardData(text: AppMetadata.pixKey));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chave PIX copiada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informações do aplicativo')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                SegmentedButton<AppInfoSection>(
                  segments: const [
                    ButtonSegment(
                      value: AppInfoSection.about,
                      icon: Icon(Icons.info_outline_rounded),
                      label: Text('Sobre'),
                    ),
                    ButtonSegment(
                      value: AppInfoSection.changes,
                      icon: Icon(Icons.history_rounded),
                      label: Text('Mudanças'),
                    ),
                    ButtonSegment(
                      value: AppInfoSection.donations,
                      icon: Icon(Icons.volunteer_activism_outlined),
                      label: Text('Doações'),
                    ),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) =>
                      setState(() => _section = value.first),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (_section) {
                    AppInfoSection.about => const _AboutPanel(
                        key: ValueKey('about'),
                      ),
                    AppInfoSection.changes => const _ChangesPanel(
                        key: ValueKey('changes'),
                      ),
                    AppInfoSection.donations => _DonationPanel(
                        key: const ValueKey('donations'),
                        onCopy: _copyPix,
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
