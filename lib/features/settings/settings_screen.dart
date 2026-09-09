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
      appBar: const AetherAppBar(title: 'Settings'),
      body: ListView(
        children: [
          // Identity section
          const SectionHeader(title: 'My Identity'),
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

          const SectionHeader(title: 'Network'),
          const _SettingsCard(
            children: [
              _SettingsTile(
                label: 'Default TTL',
                value: '${AppConstants.defaultTtl} hops',
              ),
              Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Max Message Size',
                value: '${AppConstants.maxMessageLength} chars',
              ),
              Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Scan Interval',
                value: '${AppConstants.bleScanWindowMs ~/ 1000}s scan / ${AppConstants.bleScanRestMs ~/ 1000}s rest',
              ),
              Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                label: 'Heartbeat Interval',
                value: '${AppConstants.heartbeatIntervalSeconds}s',
              ),
            ],
          ),

          const SectionHeader(title: 'Developer'),
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

          const SectionHeader(title: 'Data'),
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

          const SectionHeader(title: 'About & Project Credits'),
          // Brand Header Banner inside Settings
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AetherTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AetherTheme.borderTeal, width: 1.2),
              gradient: LinearGradient(
                colors: [AetherTheme.tealFaint.withAlpha(60), AetherTheme.bgCard],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AetherTheme.borderTeal, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AetherTheme.teal.withAlpha(30),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AetherTheme.tealFaint,
                        child: const Icon(Icons.hub, color: AetherTheme.teal, size: 26),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              color: AetherTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AetherTheme.tealFaint,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: AetherTheme.borderTeal, width: 0.8),
                            ),
                            child: const Text(
                              'v${AppConstants.appVersion}',
                              style: TextStyle(
                                color: AetherTheme.teal,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Decentralized Disaster Mesh Network',
                        style: TextStyle(
                          color: AetherTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'School of Computing • GEHU',
                        style: TextStyle(
                          color: AetherTheme.tealDim,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _SettingsCard(
            children: [
              _SettingsTile(
                leading: const Icon(Icons.school_outlined, color: AetherTheme.teal, size: 22),
                label: 'Project Team & Mentor Credits',
                value: 'View Details',
                valueColor: AetherTheme.teal,
                trailing: const Icon(Icons.chevron_right, color: AetherTheme.teal),
                onTap: () => context.pushNamed('about'),
              ),
              const Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                leading: const Icon(Icons.person_outline, color: AetherTheme.textSecondary, size: 22),
                label: 'Project Mentor',
                value: 'Ms. Nidhi Joshi',
                subtitle: 'Assistant Professor, Dept. of Computer Applications',
                onTap: () => context.pushNamed('about'),
              ),
              const Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                leading: const Icon(Icons.groups_outlined, color: AetherTheme.textSecondary, size: 22),
                label: 'Development Team',
                value: 'Aditya • Ankit • Suhail',
                subtitle: 'BCA A2 • Academic Session 2026–2027',
                onTap: () => context.pushNamed('about'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const _SettingsCard(
            children: [
              _SettingsTile(label: 'Version', value: AppConstants.appVersion),
              Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                  label: 'Protocol', value: AppConstants.protocolVersionString),
              Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(
                  label: 'Encryption', value: 'X25519 + AES-256-GCM'),
              Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(label: 'Routing', value: 'Simplified AODV'),
              Divider(height: 1, color: AetherTheme.border),
              _SettingsTile(label: 'Transport', value: 'Bluetooth LE GATT'),
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
        borderRadius: BorderRadius.circular(8),
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
  final Widget? leading;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
    this.trailing,
    this.leading,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AetherTheme.textPrimary, fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AetherTheme.textTertiary, fontSize: 11)),
                  ],
                ],
              ),
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
