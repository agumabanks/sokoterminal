import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/telemetry/telemetry.dart';
import 'ad_templates.dart';

/// Sanaa cloud basic tier — 2 GB per seller.
const sanaaCloudQuotaBytes = 2147483648;

const _designsFolder = 'SokoStudio/Your Designs';

/// Cloud quota snapshot from `/v2/seller/studio/cloud-storage`.
class StudioCloudQuota {
  const StudioCloudQuota({
    required this.bytesUsed,
    required this.quotaBytes,
    required this.designCount,
    this.label = 'Sanaa Cloud',
    this.tier = 'basic',
  });

  final int bytesUsed;
  final int quotaBytes;
  final int designCount;
  final String label;
  final String tier;

  double get usedFraction =>
      quotaBytes <= 0 ? 0 : (bytesUsed / quotaBytes).clamp(0.0, 1.0);

  String get usedLabel {
    if (bytesUsed < 1024 * 1024) {
      return '${(bytesUsed / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytesUsed / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get quotaLabel => '${(quotaBytes / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB';

  factory StudioCloudQuota.fromJson(Map<String, dynamic> j) => StudioCloudQuota(
        bytesUsed: (j['bytes_used'] as num?)?.toInt() ?? 0,
        quotaBytes: (j['quota_bytes'] as num?)?.toInt() ?? sanaaCloudQuotaBytes,
        designCount: (j['design_count'] as num?)?.toInt() ?? 0,
        label: j['label']?.toString() ?? 'Sanaa Cloud',
        tier: j['tier']?.toString() ?? 'basic',
      );

  static const fallback = StudioCloudQuota(
    bytesUsed: 0,
    quotaBytes: sanaaCloudQuotaBytes,
    designCount: 0,
  );
}

final studioDesignStorageProvider = Provider<StudioDesignStorage>((ref) {
  return StudioDesignStorage(ref.read(sellerApiProvider));
});

final yourDesignsProvider =
    StateNotifierProvider<YourDesignsNotifier, YourDesignsState>((ref) {
  return YourDesignsNotifier(ref);
});

class YourDesignsState {
  const YourDesignsState({
    this.designs = const [],
    this.quota = StudioCloudQuota.fallback,
    this.syncing = false,
    this.lastSyncedAt,
  });

  final List<AdTemplate> designs;
  final StudioCloudQuota quota;
  final bool syncing;
  final DateTime? lastSyncedAt;

  YourDesignsState copyWith({
    List<AdTemplate>? designs,
    StudioCloudQuota? quota,
    bool? syncing,
    DateTime? lastSyncedAt,
  }) =>
      YourDesignsState(
        designs: designs ?? this.designs,
        quota: quota ?? this.quota,
        syncing: syncing ?? this.syncing,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}

class YourDesignsNotifier extends StateNotifier<YourDesignsState> {
  YourDesignsNotifier(this._ref) : super(const YourDesignsState()) {
    _bootstrap();
  }

  final Ref _ref;

  StudioDesignStorage get _storage => _ref.read(studioDesignStorageProvider);

  Future<void> _bootstrap() async {
    final local = await _storage.loadLocalDesigns();
    state = state.copyWith(designs: local);
    await refreshCloud();
  }

  Future<void> refreshCloud() async {
    state = state.copyWith(syncing: true);
    try {
      final quota = await _storage.fetchCloudQuota();
      final merged = await _storage.pullFromCloud();
      state = state.copyWith(
        designs: merged,
        quota: quota,
        syncing: false,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e, st) {
      state = state.copyWith(syncing: false);
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_refresh_cloud'));
      }
    }
  }

  Future<bool> saveDesign(AdTemplate template) async {
    await _storage.saveLocal(template);
    state = state.copyWith(
      designs: [
        template,
        ...state.designs.where((d) => d.id != template.id),
      ],
    );
    try {
      await _storage.pushToCloud(template);
      await refreshCloud();
      return true;
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_save_design_cloud'));
      }
      return false;
    }
  }

  Future<bool> deleteDesign(String id) async {
    await _storage.deleteLocal(id);
    var cloudOk = true;
    try {
      await _storage.deleteFromCloud(id);
    } catch (e, st) {
      cloudOk = false;
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_delete_design_cloud'));
      }
    }
    state = state.copyWith(
      designs: state.designs.where((d) => d.id != id).toList(),
    );
    await refreshCloud();
    return cloudOk;
  }
}

class StudioDesignStorage {
  StudioDesignStorage(this._api);

  final SellerApi _api;

  Future<Directory> designsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/$_designsFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> saveLocal(AdTemplate template) async {
    final dir = await designsDirectory();
    final file = File('${dir.path}/${template.id}.json');
    await file.writeAsString(jsonEncode(template.toJson()));
  }

  Future<List<AdTemplate>> loadLocalDesigns() async {
    final dir = await designsDirectory();
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

    final designs = <AdTemplate>[];
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        designs.add(AdTemplate.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (e, st) {
        final telemetry = Telemetry.instance;
        if (telemetry != null) {
          unawaited(telemetry.recordError(e, st, hint: 'studio_load_local_design'));
        }
      }
    }
    return designs;
  }

  Future<void> deleteLocal(String id) async {
    final dir = await designsDirectory();
    final jsonFile = File('${dir.path}/$id.json');
    if (await jsonFile.exists()) await jsonFile.delete();
    final pngFile = File('${dir.path}/$id.png');
    if (await pngFile.exists()) await pngFile.delete();
  }

  Future<void> pushToCloud(AdTemplate template) async {
    await _api.saveStudioTemplate(template.toJson());
  }

  Future<List<AdTemplate>> pullFromCloud() async {
    final res = await _api.fetchStudioSavedTemplates();
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      return loadLocalDesigns();
    }

    final data = body['data'];
    if (data is! List) return loadLocalDesigns();

    final cloud = <AdTemplate>[];
    for (final item in data) {
      if (item is! Map) continue;
      try {
        final map = Map<String, dynamic>.from(item);
        map.remove('_synced_id');
        map.remove('_updated_at');
        final tpl = AdTemplate.fromJson(map);
        cloud.add(tpl);
        await saveLocal(tpl);
      } catch (e, st) {
        final telemetry = Telemetry.instance;
        if (telemetry != null) {
          unawaited(telemetry.recordError(e, st, hint: 'studio_pull_cloud_design'));
        }
      }
    }

    if (cloud.isEmpty) return loadLocalDesigns();

    final local = await loadLocalDesigns();
    final byId = {for (final d in local) d.id: d};
    for (final c in cloud) {
      byId[c.id] = c;
    }
    return byId.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<void> deleteFromCloud(String id) async {
    await _api.deleteStudioTemplate(id);
  }

  Future<StudioCloudQuota> fetchCloudQuota() async {
    try {
      final res = await _api.fetchStudioCloudStorage();
      final body = res.data;
      if (body is Map && body['success'] == true && body['data'] is Map) {
        return StudioCloudQuota.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
      }
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_fetch_cloud_quota'));
      }
    }
    return StudioCloudQuota.fallback;
  }
}