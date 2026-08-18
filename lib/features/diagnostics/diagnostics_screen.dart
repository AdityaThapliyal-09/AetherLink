// Diagnostics Screen — Developer tools: logs, routing table, packet stats.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/logging/logger.dart';
import '../../domain/entities/route_entry.dart';
import '../../services/bluetooth/network_manager.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import '../home/aether_provider.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _logEntries = <LogEntry>[];
  StreamSubscription? _logSub;
  LogCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _logEntries.addAll(logger.entries);
    _logSub = logger.logStream.listen((entry) {
      if (mounted) {
        setState(() {
          _logEntries.add(entry);
          if (_logEntries.length > 500) _logEntries.removeAt(0);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _logSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherTheme.bg,
      appBar: AppBar(
        backgroundColor: AetherTheme.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AetherTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Diagnostics',
            style: TextStyle(color: AetherTheme.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () { logger.clear(); setState(() => _logEntries.clear()); },
            child: const Text('Clear', style: TextStyle(color: AetherTheme.tealDim)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AetherTheme.textTertiary, size: 20),
            onPressed: _copyLogs,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AetherTheme.teal,
          unselectedLabelColor: AetherTheme.textTertiary,
          indicatorColor: AetherTheme.teal,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AetherTheme.border,
          tabs: const [
            Tab(text: 'Logs'),
            Tab(text: 'Routes'),
            Tab(text: 'Network'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LogsTab(entries: _logEntries, filterCategory: _filterCategory,
              onFilter: (cat) => setState(() => _filterCategory = cat)),
          _RoutesTab(),
          _NetworkTab(),
        ],
      ),
    );
  }

  void _copyLogs() {
    final text = _logEntries.map((e) => e.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }
}

class _LogsTab extends StatelessWidget {
  final List<LogEntry> entries;
  final LogCategory? filterCategory;
  final ValueChanged<LogCategory?> onFilter;

  const _LogsTab({
    required this.entries,
    required this.filterCategory,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filterCategory == null
        ? entries
        : entries.where((e) => e.category == filterCategory).toList();

    return Column(
      children: [
        // Category filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _FilterChip(label: 'All', selected: filterCategory == null,
                  onTap: () => onFilter(null)),
              ...LogCategory.values.map((cat) => _FilterChip(
                  label: cat.name.toUpperCase(),
                  selected: filterCategory == cat,
                  onTap: () => onFilter(filterCategory == cat ? null : cat))),
            ],
          ),
        ),
        Container(height: 1, color: AetherTheme.border),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No log entries',
                      style: TextStyle(color: AetherTheme.textTertiary)))
              : ListView.builder(
                  reverse: true,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final entry = filtered[filtered.length - 1 - i];
                    return _LogLine(entry: entry);
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AetherTheme.tealFaint : AetherTheme.bgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? AetherTheme.teal : AetherTheme.border,
              width: 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AetherTheme.teal : AetherTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry entry;
  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.error   => AetherTheme.statusRed,
      LogLevel.warning => AetherTheme.statusYellow,
      LogLevel.info    => AetherTheme.textSecondary,
      LogLevel.debug   => AetherTheme.textTertiary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.timestamp.hour.toString().padLeft(2,'0')}:'
            '${entry.timestamp.minute.toString().padLeft(2,'0')}.'
            '${entry.timestamp.second.toString().padLeft(2,'0')}',
            style: const TextStyle(
                color: AetherTheme.textTertiary,
                fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(3)),
            child: Text(entry.categoryLabel,
                style: TextStyle(color: color, fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(entry.message,
                style: TextStyle(color: color, fontSize: 11,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _RoutesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final routes = context.watch<AetherProvider>().getRoutingTable();

    if (routes.isEmpty) {
      return const EmptyState(
        icon: Icons.route,
        title: 'No routes',
        subtitle: 'Routes will appear here after peer discovery.',
      );
    }

    return ListView.builder(
      itemCount: routes.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (ctx, i) {
        final r = routes[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AetherTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AetherTheme.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('DST: ${r.destinationId}',
                        style: const TextStyle(
                            color: AetherTheme.teal,
                            fontSize: 12, fontFamily: 'monospace',
                            fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: r.state == RouteState.active
                          ? AetherTheme.statusGreen.withAlpha(25)
                          : AetherTheme.bgElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(r.state.label,
                        style: TextStyle(
                            color: r.state == RouteState.active
                                ? AetherTheme.statusGreen
                                : AetherTheme.textTertiary,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('NXT: ${r.nextHopId}',
                  style: const TextStyle(
                      color: AetherTheme.textSecondary,
                      fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              Text(
                'Hops: ${r.hopCount}  |  Seq: ${r.sequenceNumber}  |  '
                'Updated: ${DateTime.now().difference(r.lastUpdated).inSeconds}s ago',
                style: const TextStyle(
                    color: AetherTheme.textTertiary, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NetworkTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AetherProvider>();
    final peers = provider.activePeers;
    final ready = provider.readyPeers;
    final routes = provider.getRoutingTable();
    final alerts = provider.alerts;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'Network Stats'),
        _StatRow('Network State', provider.networkState.label),
        _StatRow('Active Peers', '${peers.length}'),
        _StatRow('Ready Peers', '${ready.length}'),
        _StatRow('Known Routes', '${routes.length}'),
        _StatRow('Active Routes',
            '${routes.where((r) => r.state == RouteState.active).length}'),
        _StatRow('Alerts Received', '${alerts.length}'),
        _StatRow('Pending Messages', '${provider.pendingMessages}'),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Connected Peers'),
        ...ready.map((p) => _StatRow(p.displayName,
            '${p.nodeId} · ${p.isDirect ? 'Direct' : '${p.hopCount} hops'}')),
        if (ready.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No ready peers',
                  style: TextStyle(color: AetherTheme.textTertiary)),
            ),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AetherTheme.border, width: 1))),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AetherTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AetherTheme.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w500,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
