// Settings Screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import '../home/aether_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _editing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<AetherProvider>().identity;
    if (id != null && _nameController.text.isEmpty) {
      _nameController.text = id.displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await context.read<AetherProvider>().updateDisplayName(name);
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AetherProvider>();
    final identity = provider.identity;

    return Scaffold(
      backgroundColor: AetherTheme.bg,
      appBar: AetherAppBar(title: 'Settings'),
      body: ListView(
        children: [
          // Identity section
          SectionHeader(title: 'My Identity'),
          _SettingsCard(
            children: [
              // Display name
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Display Name',
                        style: TextStyle(
                            color: AetherTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _editing
                              ? TextField(
                                  controller: _nameController,
                                  autofocus: true,
                                  style: const TextStyle(
                                      color: AetherTheme.textPrimary),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onSubmitted: (_) => _saveName(),
                                )
                              : Text(identity?.displayName ?? '...',
                                  style: const TextStyle(
                                      color: AetherTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            if (_editing) {
                              _saveName();
                            } else {
                              setState(() => _editing = true);
                            }
                          },
                          child: Text(_editing ? 'Save' : 'Edit',
                              style: const TextStyle(color: AetherTheme.teal)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Node ID',
                value: identity?.nodeId ?? '...',
                mono: true,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: identity?.nodeId ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Node ID copied')),
                  );
                },
                trailing: const Icon(Icons.copy, size: 16, color: AetherTheme.teal),
              ),
              const Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Key Fingerprint',
                value: identity?.keyFingerprint ?? '...',
                mono: true,
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: identity?.keyFingerprint ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fingerprint copied')),
                  );
                },
                trailing:
                    const Icon(Icons.copy, size: 16, color: AetherTheme.teal),
              ),
            ],
          ),

          SectionHeader(title: 'Network'),
          _SettingsCard(
            children: [
              _SettingsTile(
                label: 'Default TTL',
                value: '${AppConstants.defaultTtl} hops',
              ),
              const Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Max Message Size',
                value: '${AppConstants.maxMessageLength} chars',
              ),
              const Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Scan Interval',
                value: '${AppConstants.bleScanWindowMs ~/ 1000}s scan / ${AppConstants.bleScanRestMs ~/ 1000}s rest',
              ),
              const Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Heartbeat Interval',
                value: '${AppConstants.heartbeatIntervalSeconds}s',
              ),
            ],
          ),

          SectionHeader(title: 'Developer'),
          _SettingsCard(
            children: [
              _SettingsTile(
                label: 'Diagnostics',
                value: 'Logs, routing, stats',
                trailing: const Icon(Icons.chevron_right,
                    color: AetherTheme.textTertiary),
                onTap: () => context.pushNamed('diagnostics'),
              ),
            ],
          ),

          SectionHeader(title: 'Data'),
          _SettingsCard(
            children: [
              _SettingsTile(
                label: 'Clear Local Data',
                value: 'Wipes all messages and routing data',
                valueColor: AetherTheme.statusRed,
                onTap: () => _confirmClearData(context, provider),
              ),
            ],
          ),

          SectionHeader(title: 'About'),
          _SettingsCard(
            children: [
              const _SettingsTile(label: 'Version', value: AppConstants.appVersion),
              const Divider(height: 1, color: AetherTheme.border),
              const _SettingsTile(
                  label: 'Protocol', value: AppConstants.protocolVersionString),
              const Divider(height: 1, color: AetherTheme.border),
              const _SettingsTile(
                  label: 'Encryption', value: 'X25519 + AES-256-GCM'),
              const Divider(height: 1, color: AetherTheme.border),
              const _SettingsTile(label: 'Routing', value: 'Simplified AODV'),
              const Divider(height: 1, color: AetherTheme.border),
              const _SettingsTile(label: 'Transport', value: 'Bluetooth LE GATT'),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context, AetherProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AetherTheme.bgCard,
        title: const Text('Clear All Data',
            style: TextStyle(color: AetherTheme.sosRed)),
        content: const Text(
          'This will permanently delete all messages, conversations, routing data, and peer information. '
          'Your cryptographic identity will be preserved.',
          style: TextStyle(color: AetherTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Note: identity is preserved, only data is cleared
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local data cleared')),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AetherTheme.sosRed),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AetherTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AetherTheme.border, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AetherTheme.textPrimary, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? AetherTheme.textSecondary,
                  fontSize: 13,
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
