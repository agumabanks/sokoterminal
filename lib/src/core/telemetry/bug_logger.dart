import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Severity levels for bug reports
enum BugSeverity {
  low,       // Minor UI glitches, non-blocking issues
  medium,    // Feature not working but workaround exists
  high,      // Feature broken, affects workflow
  critical,  // App crash, data loss, blocks business operations
}

/// Categories for bug classification
enum BugCategory {
  ui,           // Visual/layout issues
  sync,         // Sync and network issues
  database,     // Local database errors
  payment,      // Payment processing issues
  printing,     // Thermal printer issues
  scanner,      // Barcode scanner issues
  auth,         // Authentication/authorization issues
  performance,  // Slow operations, memory issues
  crash,        // App crashes
  other,        // Uncategorized
}

/// A structured bug report entry
class BugReport {
  BugReport({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    this.stackTrace,
    this.context,
    this.deviceInfo,
    this.networkStatus,
    this.resolved = false,
    this.resolution,
  });

  final String id;
  final DateTime timestamp;
  final BugSeverity severity;
  final BugCategory category;
  final String title;
  final String description;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? deviceInfo;
  final String? networkStatus;
  final bool resolved;
  final String? resolution;

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'severity': severity.name,
    'category': category.name,
    'title': title,
    'description': description,
    if (stackTrace != null) 'stackTrace': stackTrace,
    if (context != null) 'context': context,
    if (deviceInfo != null) 'deviceInfo': deviceInfo,
    if (networkStatus != null) 'networkStatus': networkStatus,
    'resolved': resolved,
    if (resolution != null) 'resolution': resolution,
  };

  factory BugReport.fromJson(Map<String, dynamic> json) => BugReport(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    severity: BugSeverity.values.firstWhere(
      (e) => e.name == json['severity'],
      orElse: () => BugSeverity.medium,
    ),
    category: BugCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => BugCategory.other,
    ),
    title: json['title'] as String,
    description: json['description'] as String,
    stackTrace: json['stackTrace'] as String?,
    context: json['context'] as Map<String, dynamic>?,
    deviceInfo: json['deviceInfo'] as Map<String, dynamic>?,
    networkStatus: json['networkStatus'] as String?,
    resolved: json['resolved'] as bool? ?? false,
    resolution: json['resolution'] as String?,
  );
}

/// Production bug logger for tracking issues
class BugLogger {
  BugLogger._();

  static const String _logFileName = 'production_bugs.jsonl';
  static const String _summaryFileName = 'bug_summary.json';
  
  static BugLogger? _instance;
  static File? _logFile;
  static File? _summaryFile;

  static BugLogger get instance {
    _instance ??= BugLogger._();
    return _instance!;
  }

  /// Initialize the bug logger
  static Future<void> init() async {
    if (_logFile != null) return;

    final dir = await _getLogDirectory();
    _logFile = File('${dir.path}/$_logFileName');
    _summaryFile = File('${dir.path}/$_summaryFileName');
    
    await _logFile!.create(recursive: true);
    await _summaryFile!.create(recursive: true);
    
    debugPrint('[BugLogger] Initialized at: ${_logFile!.path}');
  }

  /// Log a bug with full context
  Future<String> logBug({
    required BugSeverity severity,
    required BugCategory category,
    required String title,
    required String description,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final id = _generateId();
    final networkStatus = await _getNetworkStatus();
    
    final report = BugReport(
      id: id,
      timestamp: DateTime.now(),
      severity: severity,
      category: category,
      title: title,
      description: description,
      stackTrace: stackTrace?.toString() ?? (error != null ? StackTrace.current.toString() : null),
      context: {
        if (context != null) ...context,
        if (error != null) 'error': error.toString(),
      },
      deviceInfo: _getDeviceInfo(),
      networkStatus: networkStatus,
    );

    await _writeReport(report);
    await _updateSummary();
    
    // Also print to console for immediate visibility
    debugPrint('🐛 [BUG-${severity.name.toUpperCase()}] $title');
    if (error != null) debugPrint('   Error: $error');
    
    return id;
  }

  /// Log a sync error
  Future<String> logSyncError({
    required String operation,
    required String endpoint,
    Object? error,
    StackTrace? stackTrace,
    int? statusCode,
    int? retryCount,
  }) async {
    return logBug(
      severity: retryCount != null && retryCount > 3 
          ? BugSeverity.high 
          : BugSeverity.medium,
      category: BugCategory.sync,
      title: 'Sync failed: $operation',
      description: 'Failed to sync with endpoint: $endpoint',
      error: error,
      stackTrace: stackTrace,
      context: {
        'operation': operation,
        'endpoint': endpoint,
        if (statusCode != null) 'statusCode': statusCode,
        if (retryCount != null) 'retryCount': retryCount,
      },
    );
  }

  /// Log a database error
  Future<String> logDatabaseError({
    required String operation,
    required String table,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    return logBug(
      severity: BugSeverity.high,
      category: BugCategory.database,
      title: 'Database error: $operation on $table',
      description: 'Database operation failed',
      error: error,
      stackTrace: stackTrace,
      context: {
        'operation': operation,
        'table': table,
      },
    );
  }

  /// Log a payment error
  Future<String> logPaymentError({
    required String method,
    required double amount,
    Object? error,
    StackTrace? stackTrace,
    String? transactionId,
  }) async {
    return logBug(
      severity: BugSeverity.critical,
      category: BugCategory.payment,
      title: 'Payment failed: $method',
      description: 'Payment of ${amount.toStringAsFixed(0)} UGX failed',
      error: error,
      stackTrace: stackTrace,
      context: {
        'method': method,
        'amount': amount,
        if (transactionId != null) 'transactionId': transactionId,
      },
    );
  }

  /// Log a printer error
  Future<String> logPrinterError({
    required String operation,
    Object? error,
    StackTrace? stackTrace,
    String? printerAddress,
  }) async {
    return logBug(
      severity: BugSeverity.medium,
      category: BugCategory.printing,
      title: 'Printer error: $operation',
      description: 'Thermal printer operation failed',
      error: error,
      stackTrace: stackTrace,
      context: {
        'operation': operation,
        if (printerAddress != null) 'printerAddress': printerAddress,
      },
    );
  }

  /// Log an app crash
  Future<String> logCrash({
    required Object error,
    required StackTrace stackTrace,
    String? screen,
    String? action,
  }) async {
    return logBug(
      severity: BugSeverity.critical,
      category: BugCategory.crash,
      title: 'App crash',
      description: 'Application crashed${screen != null ? ' on $screen' : ''}',
      error: error,
      stackTrace: stackTrace,
      context: {
        if (screen != null) 'screen': screen,
        if (action != null) 'action': action,
      },
    );
  }

  /// Get all unresolved bugs
  Future<List<BugReport>> getUnresolvedBugs() async {
    final bugs = await _readAllBugs();
    return bugs.where((b) => !b.resolved).toList();
  }

  /// Get bug summary statistics
  Future<Map<String, dynamic>> getSummary() async {
    if (_summaryFile == null) await init();
    
    try {
      final content = await _summaryFile!.readAsString();
      if (content.trim().isEmpty) return _emptyStats();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return _emptyStats();
    }
  }

  /// Export bugs to a shareable format
  Future<String> exportBugsReport() async {
    final bugs = await _readAllBugs();
    final summary = await getSummary();
    
    final buffer = StringBuffer();
    buffer.writeln('# Soko Seller Terminal - Bug Report');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    
    buffer.writeln('## Summary');
    buffer.writeln('- Total bugs: ${summary['total'] ?? 0}');
    buffer.writeln('- Critical: ${summary['bySeverity']?['critical'] ?? 0}');
    buffer.writeln('- High: ${summary['bySeverity']?['high'] ?? 0}');
    buffer.writeln('- Medium: ${summary['bySeverity']?['medium'] ?? 0}');
    buffer.writeln('- Low: ${summary['bySeverity']?['low'] ?? 0}');
    buffer.writeln('- Unresolved: ${summary['unresolved'] ?? 0}');
    buffer.writeln();
    
    buffer.writeln('## Bugs by Category');
    final byCategory = summary['byCategory'] as Map<String, dynamic>? ?? {};
    for (final entry in byCategory.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
    buffer.writeln();
    
    buffer.writeln('## Detailed Bug List');
    buffer.writeln();
    
    for (final bug in bugs) {
      buffer.writeln('### [${bug.severity.name.toUpperCase()}] ${bug.title}');
      buffer.writeln('- **ID**: ${bug.id}');
      buffer.writeln('- **Time**: ${bug.timestamp.toLocal()}');
      buffer.writeln('- **Category**: ${bug.category.name}');
      buffer.writeln('- **Status**: ${bug.resolved ? 'Resolved' : 'Open'}');
      buffer.writeln('- **Description**: ${bug.description}');
      if (bug.networkStatus != null) {
        buffer.writeln('- **Network**: ${bug.networkStatus}');
      }
      if (bug.context != null && bug.context!.isNotEmpty) {
        buffer.writeln('- **Context**: ${jsonEncode(bug.context)}');
      }
      if (bug.stackTrace != null) {
        buffer.writeln('```');
        buffer.writeln(bug.stackTrace!.split('\n').take(10).join('\n'));
        buffer.writeln('```');
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// Mark a bug as resolved
  Future<void> resolveBug(String id, String resolution) async {
    // Read all bugs, update the one with matching id, write back
    final bugs = await _readAllBugs();
    final updatedBugs = bugs.map((b) {
      if (b.id == id) {
        return BugReport(
          id: b.id,
          timestamp: b.timestamp,
          severity: b.severity,
          category: b.category,
          title: b.title,
          description: b.description,
          stackTrace: b.stackTrace,
          context: b.context,
          deviceInfo: b.deviceInfo,
          networkStatus: b.networkStatus,
          resolved: true,
          resolution: resolution,
        );
      }
      return b;
    }).toList();
    
    await _writeAllBugs(updatedBugs);
    await _updateSummary();
  }

  /// Clear all bugs (for testing)
  Future<void> clearAll() async {
    if (_logFile == null) await init();
    await _logFile!.writeAsString('');
    await _updateSummary();
  }

  // Private methods

  String _generateId() {
    final now = DateTime.now();
    return 'BUG-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  }

  Future<String> _getNetworkStatus() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.wifi)) return 'wifi';
      if (result.contains(ConnectivityResult.mobile)) return 'mobile';
      if (result.contains(ConnectivityResult.ethernet)) return 'ethernet';
      return 'none';
    } catch (_) {
      return 'unknown';
    }
  }

  Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
    };
  }

  Future<void> _writeReport(BugReport report) async {
    if (_logFile == null) await init();
    
    try {
      final line = jsonEncode(report.toJson());
      await _logFile!.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('[BugLogger] Failed to write bug report: $e');
    }
  }

  Future<List<BugReport>> _readAllBugs() async {
    if (_logFile == null) await init();
    
    try {
      final content = await _logFile!.readAsString();
      if (content.trim().isEmpty) return [];
      
      return content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            try {
              return BugReport.fromJson(jsonDecode(line) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<BugReport>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAllBugs(List<BugReport> bugs) async {
    if (_logFile == null) await init();
    
    final lines = bugs.map((b) => jsonEncode(b.toJson())).join('\n');
    await _logFile!.writeAsString(lines.isEmpty ? '' : '$lines\n');
  }

  Future<void> _updateSummary() async {
    if (_summaryFile == null) await init();
    
    try {
      final bugs = await _readAllBugs();
      
      final bySeverity = <String, int>{};
      final byCategory = <String, int>{};
      int unresolved = 0;
      
      for (final bug in bugs) {
        bySeverity[bug.severity.name] = (bySeverity[bug.severity.name] ?? 0) + 1;
        byCategory[bug.category.name] = (byCategory[bug.category.name] ?? 0) + 1;
        if (!bug.resolved) unresolved++;
      }
      
      final summary = {
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
        'total': bugs.length,
        'unresolved': unresolved,
        'resolved': bugs.length - unresolved,
        'bySeverity': bySeverity,
        'byCategory': byCategory,
      };
      
      await _summaryFile!.writeAsString(jsonEncode(summary));
    } catch (e) {
      debugPrint('[BugLogger] Failed to update summary: $e');
    }
  }

  Map<String, dynamic> _emptyStats() => {
    'lastUpdated': DateTime.now().toUtc().toIso8601String(),
    'total': 0,
    'unresolved': 0,
    'resolved': 0,
    'bySeverity': <String, int>{},
    'byCategory': <String, int>{},
  };

  static Future<Directory> _getLogDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getTemporaryDirectory();
    }
  }

  /// Get the log file for external access
  static Future<File> getLogFile() async {
    if (_logFile == null) await init();
    return _logFile!;
  }
}
