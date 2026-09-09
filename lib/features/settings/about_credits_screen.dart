// AetherLink About & Project Credits Screen
// Showcases application branding, academic metadata, project team, and mentor attribution.

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';

class AboutCreditsScreen extends StatelessWidget {
  const AboutCreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherTheme.bg,
      appBar: const AetherAppBar(
        title: 'About & Credits',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Hero Branding Header ──────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AetherTheme.teal, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AetherTheme.teal.withAlpha(60),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.hub,
                        size: 48,
                        color: AetherTheme.teal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: AetherTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AetherTheme.tealFaint,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: AetherTheme.borderTeal, width: 1),
                  ),
                  child: const Text(
                    'Version 1.0.0 (Build 1) • Release',
                    style: TextStyle(
                      color: AetherTheme.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Decentralized Disaster Communication Network',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AetherTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• 100% Offline Mesh • Zero Internet • P2P Bluetooth LE •',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AetherTheme.tealDim,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Academic Affiliation ──────────────────────────────────────────
          const SectionHeader(title: 'Institution & Department'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AetherTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AetherTheme.border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AetherTheme.tealFaint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AetherTheme.borderTeal, width: 1),
                  ),
                  child: const Icon(Icons.account_balance, color: AetherTheme.teal, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School of Computing',
                        style: TextStyle(
                          color: AetherTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Graphic Era Hill University (GEHU)',
                        style: TextStyle(
                          color: AetherTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Department of Computer Applications • 2026–2027',
                        style: TextStyle(
                          color: AetherTheme.tealDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Project Mentorship ────────────────────────────────────────────
          const SectionHeader(title: 'Project Mentor'),
          Container(
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
                    color: AetherTheme.tealFaint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AetherTheme.teal, width: 1.5),
                  ),
                  child: const Icon(Icons.school, color: AetherTheme.teal, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ms. Nidhi Joshi',
                        style: TextStyle(
                          color: AetherTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Assistant Professor',
                        style: TextStyle(
                          color: AetherTheme.teal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Department of Computer Applications\nSchool of Computing, GEHU',
                        style: TextStyle(
                          color: AetherTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Development Team ──────────────────────────────────────────────
          const SectionHeader(
            title: 'Project Development Team',
            trailing: Text(
              'BCA A2',
              style: TextStyle(
                color: AetherTheme.tealDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AetherTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AetherTheme.border, width: 1),
            ),
            child: const Column(
              children: [
                _TeamMemberTile(
                  name: 'Aditya Thapliyal',
                  role: 'Team Leader • Architecture & Core Protocol',
                  rollNo: '2421057',
                  section: 'BCA A2',
                  isLeader: true,
                ),
                Divider(height: 1, color: AetherTheme.border),
                _TeamMemberTile(
                  name: 'Ankit Singh Rawat',
                  role: 'Mesh Networking & AODV Routing',
                  rollNo: '2421112',
                  section: 'BCA A2',
                ),
                Divider(height: 1, color: AetherTheme.border),
                _TeamMemberTile(
                  name: 'Suhail',
                  role: 'Security, Cryptography & Hardware Interface',
                  rollNo: '2421614',
                  section: 'BCA A2',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Technical Architecture & Protocol ─────────────────────────────
          const SectionHeader(title: 'Protocol & System Specs'),
          Container(
            decoration: BoxDecoration(
              color: AetherTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AetherTheme.border, width: 1),
            ),
            child: const Column(
              children: [
                _SpecRow(label: 'Protocol Specification', value: 'AETH-v1 Binary + JSON'),
                Divider(height: 1, color: AetherTheme.border),
                _SpecRow(label: 'Routing Algorithm', value: 'Ad-hoc On-Demand Distance Vector (AODV)'),
                Divider(height: 1, color: AetherTheme.border),
                _SpecRow(label: 'Key Agreement', value: 'Curve25519 (X25519 ECDH)'),
                Divider(height: 1, color: AetherTheme.border),
                _SpecRow(label: 'Symmetric Encryption', value: 'AES-256-GCM (Authenticated)'),
                Divider(height: 1, color: AetherTheme.border),
                _SpecRow(label: 'Integrity & Fingerprint', value: 'SHA-256 (Truncated 16-hex)'),
                Divider(height: 1, color: AetherTheme.border),
                _SpecRow(label: 'Physical Transport', value: 'BLE GATT Central + Peripheral'),
                Divider(height: 1, color: AetherTheme.border),
                _SpecRow(label: 'Local Persistence', value: 'SQLite Encrypted Store'),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Bottom Academic Dedication ────────────────────────────────────
          const Center(
            child: Column(
              children: [
                Icon(Icons.shield_outlined, color: AetherTheme.tealDim, size: 28),
                SizedBox(height: 8),
                Text(
                  'AetherLink • Disaster Communication Mesh',
                  style: TextStyle(
                    color: AetherTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Academic Project • School of Computing, GEHU • 2026–2027\nEngineered for zero-infrastructure humanitarian crisis response.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AetherTheme.textTertiary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  final String name;
  final String role;
  final String rollNo;
  final String section;
  final bool isLeader;

  const _TeamMemberTile({
    required this.name,
    required this.role,
    required this.rollNo,
    required this.section,
    this.isLeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLeader ? AetherTheme.tealFaint : AetherTheme.bgElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: isLeader ? AetherTheme.teal : AetherTheme.border,
                width: 1.2,
              ),
            ),
            child: Center(
              child: isLeader
                  ? const Icon(Icons.star, color: AetherTheme.teal, size: 20)
                  : const Icon(Icons.person_outline, color: AetherTheme.textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AetherTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isLeader) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AetherTheme.tealFaint,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: AetherTheme.borderTeal, width: 0.8),
                        ),
                        child: const Text(
                          'Leader',
                          style: TextStyle(
                            color: AetherTheme.teal,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  role,
                  style: const TextStyle(
                    color: AetherTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Roll No: $rollNo • $section',
                  style: const TextStyle(
                    color: AetherTheme.tealDim,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AetherTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AetherTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
