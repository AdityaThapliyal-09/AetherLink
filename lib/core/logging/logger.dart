// AetherLink structured logging service.
// Provides categorized, timestamped log entries stored in memory and SQLite.
// Categories map to the functional layers of AetherLink.

import 'dart:async';
import 'dart:collection';

enum LogCategory {
  network,
  bluetooth,
  routing,
  crypto,
  database,
  ui,
  broadcast,
  sos,
  error,
  system,
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final LogCategory category;
  final LogLevel level;
  final String message;
  final String? details;

  const LogEntry({
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
    this.details,
  });

  String get categoryLabel => '[${category.name.toUpperCase()}]';
  String get levelLabel => level.name.toUpperCase();

  @override
  String toString() {
    final ts = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    final detail = details != null ? ' | $details' : '';
    return '$ts $categoryLabel [$levelLabel] $message$detail';
  }
}

/// Singleton structured logger for AetherLink.
/// Keeps a bounded in-memory ring buffer of recent log entries
/// and broadcasts new entries via a stream for the diagnostics UI.
class AetherLogger {
  static final AetherLogger _instance = AetherLogger._internal();
  factory AetherLogger() => _instance;
  AetherLogger._internal();

  static const int _maxEntries = 500;

  final Queue<LogEntry> _entries = Queue();
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  /// Stream of new log entries for live UI updates.
  Stream<LogEntry> get logStream => _controller.stream;

  /// Snapshot of current log entries (most recent last).
  List<LogEntry> get entries => List.unmodifiable(_entries.toList());

  void _log(LogCategory cat, LogLevel level, String msg, {String? details}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: cat,
      level: level,
      message: msg,
      details: details,
    );
    _entries.addLast(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    _controller.add(entry);
    // Also print to console in debug mode
    assert(() {
      // ignore: avoid_print
      print(entry.toString());
      return true;
    }());
  }

  // --- Convenience methods per category ---

  void network(String msg, {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.network, level, msg, details: details);

  void bluetooth(String msg,
          {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.bluetooth, level, msg, details: details);

  void routing(String msg, {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.routing, level, msg, details: details);

  void crypto(String msg, {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.crypto, level, msg, details: details);

  void database(String msg, {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.database, level, msg, details: details);

  void ui(String msg, {String? details, LogLevel level = LogLevel.debug}) =>
      _log(LogCategory.ui, level, msg, details: details);

  void broadcast(String msg,
          {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.broadcast, level, msg, details: details);

  void sos(String msg, {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.sos, level, msg, details: details);

  void error(String msg, {String? details}) =>
      _log(LogCategory.error, LogLevel.error, msg, details: details);

  void system(String msg, {String? details, LogLevel level = LogLevel.info}) =>
      _log(LogCategory.system, level, msg, details: details);

  void clear() {
    _entries.clear();
    system('Log cleared');
  }

  void dispose() {
    _controller.close();
  }
}

/// Global logger instance for convenient access throughout the app.
final logger = AetherLogger();
