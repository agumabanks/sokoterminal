import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local analytics for Studio usage.
/// Tracks counts of exports, shares, edits, and template uses.
class StudioCampaignStats {
  const StudioCampaignStats({
    this.totalExports = 0,
    this.totalShares = 0,
    this.totalEdits = 0,
    this.totalTemplateUses = 0,
    this.lastExportAt,
    this.lastShareAt,
    this.lastEditAt,
    this.weeklyExports = 0,
  });

  final int totalExports;
  final int totalShares;
  final int totalEdits;
  final int totalTemplateUses;
  final DateTime? lastExportAt;
  final DateTime? lastShareAt;
  final DateTime? lastEditAt;
  final int weeklyExports;

  StudioCampaignStats copyWith({
    int? totalExports,
    int? totalShares,
    int? totalEdits,
    int? totalTemplateUses,
    DateTime? lastExportAt,
    DateTime? lastShareAt,
    DateTime? lastEditAt,
    int? weeklyExports,
  }) =>
      StudioCampaignStats(
        totalExports: totalExports ?? this.totalExports,
        totalShares: totalShares ?? this.totalShares,
        totalEdits: totalEdits ?? this.totalEdits,
        totalTemplateUses: totalTemplateUses ?? this.totalTemplateUses,
        lastExportAt: lastExportAt ?? this.lastExportAt,
        lastShareAt: lastShareAt ?? this.lastShareAt,
        lastEditAt: lastEditAt ?? this.lastEditAt,
        weeklyExports: weeklyExports ?? this.weeklyExports,
      );

  Map<String, dynamic> toJson() => {
        'total_exports': totalExports,
        'total_shares': totalShares,
        'total_edits': totalEdits,
        'total_template_uses': totalTemplateUses,
        'last_export_at': lastExportAt?.toIso8601String(),
        'last_share_at': lastShareAt?.toIso8601String(),
        'last_edit_at': lastEditAt?.toIso8601String(),
        'weekly_exports': weeklyExports,
      };

  factory StudioCampaignStats.fromJson(Map<String, dynamic> j) {
    DateTime? parse(String key) {
      final raw = j[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return StudioCampaignStats(
      totalExports: (j['total_exports'] as num?)?.toInt() ?? 0,
      totalShares: (j['total_shares'] as num?)?.toInt() ?? 0,
      totalEdits: (j['total_edits'] as num?)?.toInt() ?? 0,
      totalTemplateUses: (j['total_template_uses'] as num?)?.toInt() ?? 0,
      lastExportAt: parse('last_export_at'),
      lastShareAt: parse('last_share_at'),
      lastEditAt: parse('last_edit_at'),
      weeklyExports: (j['weekly_exports'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudioCampaignAnalytics extends StateNotifier<StudioCampaignStats> {
  StudioCampaignAnalytics(this._prefs) : super(const StudioCampaignStats()) {
    _load();
  }

  static const _key = 'studio_campaign_analytics_v1';
  final SharedPreferences _prefs;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = StudioCampaignStats.fromJson(json);
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  bool _isThisWeek(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return dt.isAfter(start);
  }

  Future<void> recordExport() async {
    final now = DateTime.now();
    final weekly = _isThisWeek(state.lastExportAt) ? state.weeklyExports + 1 : 1;
    state = state.copyWith(
      totalExports: state.totalExports + 1,
      lastExportAt: now,
      weeklyExports: weekly,
    );
    await _persist();
  }

  Future<void> recordShare() async {
    state = state.copyWith(
      totalShares: state.totalShares + 1,
      lastShareAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> recordEdit() async {
    state = state.copyWith(
      totalEdits: state.totalEdits + 1,
      lastEditAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> recordTemplateUse() async {
    state = state.copyWith(
      totalTemplateUses: state.totalTemplateUses + 1,
    );
    await _persist();
  }
}
