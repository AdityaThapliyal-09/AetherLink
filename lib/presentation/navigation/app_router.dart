// AetherLink App Router using go_router.
// Defines all routes and the bottom navigation bar shell.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/chat_detail_screen.dart';
import '../../features/chat/conversations_screen.dart';
import '../../features/diagnostics/diagnostics_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/network/network_screen.dart';
import '../../features/peers/peer_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/about_credits_screen.dart';
import '../../features/sos/sos_screen.dart';
import '../../features/home/aether_provider.dart';
import '../theme/aether_theme.dart';
import '../widgets/in_app_notification_overlay.dart';
import 'package:provider/provider.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (ctx, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chats',
              name: 'chats',
              builder: (ctx, state) => const ConversationsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sos',
              name: 'sos',
              builder: (ctx, state) => const SosScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/network',
              name: 'network',
              builder: (ctx, state) => const NetworkScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (ctx, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // Non-tab routes (full screen)
    GoRoute(
      path: '/chat/:peerId',
      name: 'chat',
      builder: (ctx, state) {
        final peerId = state.pathParameters['peerId']!;
        final peerName = state.uri.queryParameters['name'] ?? 'Unknown';
        return ChatDetailScreen(peerId: peerId, peerName: peerName);
      },
    ),
    GoRoute(
      path: '/peer/:peerId',
      name: 'peerDetail',
      builder: (ctx, state) {
        final peerId = state.pathParameters['peerId']!;
        return PeerDetailScreen(peerId: peerId);
      },
    ),
    GoRoute(
      path: '/diagnostics',
      name: 'diagnostics',
      builder: (ctx, state) => const DiagnosticsScreen(),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (ctx, state) => const AboutCreditsScreen(),
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _ScaffoldWithNav({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return InAppNotificationOverlay(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: _AetherBottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: (i) => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}

class _AetherBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AetherBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AetherProvider>().totalUnreadCount;

    return Container(
      decoration: const BoxDecoration(
        color: AetherTheme.bg, // Spotify near-black #121212
        border: Border(top: BorderSide(color: AetherTheme.border, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.hub_outlined,
                activeIcon: Icons.hub,
                label: 'Network',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Chats',
                index: 1,
                currentIndex: currentIndex,
                badgeCount: currentIndex != 1 ? unread : 0,
                onTap: onTap,
              ),
              _SosNavItem(currentIndex: currentIndex, onTap: onTap),
              _NavItem(
                icon: Icons.device_hub_outlined,
                activeIcon: Icons.device_hub,
                label: 'Topology',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                index: 4,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final int badgeCount;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    color: isActive ? AetherTheme.textPrimary : AetherTheme.textSecondary,
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -10,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AetherTheme.teal, // Spotify Green
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x661ED760),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Color(0xFF000000), // Black on green
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AetherTheme.textPrimary : AetherTheme.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SOS button gets a special centered treatment
class _SosNavItem extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _SosNavItem({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive ? AetherTheme.sosRed : const Color(0xFF281416),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AetherTheme.sosRed : AetherTheme.sosRedDim,
                  width: 1.2,
                ),
                boxShadow: isActive ? AetherTheme.shadowHeavy : null,
              ),
              child: Icon(
                Icons.emergency,
                color: isActive ? Colors.white : AetherTheme.sosRed,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'SOS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? AetherTheme.sosRed : AetherTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
