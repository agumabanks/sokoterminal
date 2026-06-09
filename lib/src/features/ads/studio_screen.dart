import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../checkout/checkout_screen.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'full_studio_webview_screen.dart';
import 'studio_create_sheet.dart';
import 'studio_editor_launcher.dart';
import 'studio_hub_shell.dart';
import 'studio_providers.dart';
import 'studio_theme.dart';

// ---------------------------------------------------------------------------
// Saved templates (stored in SharedPreferences as JSON list)
// ---------------------------------------------------------------------------

final savedTemplatesProvider =
    StateNotifierProvider<SavedTemplatesNotifier, List<AdTemplate>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SavedTemplatesNotifier(prefs);
});

class SavedTemplatesNotifier extends StateNotifier<List<AdTemplate>> {
  SavedTemplatesNotifier(this._prefs) : super([]) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _key = 'studio_saved_templates_v1';

  void _load() {
    final raw = _prefs.getStringList(_key) ?? [];
    state = raw.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return AdTemplate(
          id: m['id'] as String,
          name: m['name'] as String,
          category: m['category'] as String,
          canvasWidth: (m['canvasWidth'] as num).toDouble(),
          canvasHeight: (m['canvasHeight'] as num).toDouble(),
          background: m['background'] as String,
          elements: (m['elements'] as List)
              .map((e) => CanvasElement.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      } catch (_) {
        return null;
      }
    }).whereType<AdTemplate>().toList();
  }

  Future<void> save(AdTemplate tpl) async {
    if (state.any((t) => t.id == tpl.id)) {
      state = [for (final t in state) if (t.id == tpl.id) tpl else t];
    } else {
      state = [...state, tpl];
    }
    await _persist();
  }

  Future<void> delete(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final raw = state.map((t) => jsonEncode({
      'id': t.id,
      'name': t.name,
      'category': t.category,
      'canvasWidth': t.canvasWidth,
      'canvasHeight': t.canvasHeight,
      'background': t.background,
      'elements': t.elements.map((e) => e.toJson()).toList(),
    })).toList();
    await _prefs.setStringList(_key, raw);
  }
}

// ---------------------------------------------------------------------------
// Studio Screen
// ---------------------------------------------------------------------------

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedItem = ref.watch(studioProductProvider);
    final items = ref.watch(itemsStreamProvider);
    final kit = ref.watch(brandKitProvider);

    final theme = ref.watch(studioThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffold,
      body: StudioHubShell(
        selectedItem: selectedItem,
        items: items,
        kit: kit,
        onItemSelected: (item) =>
            ref.read(studioProductProvider.notifier).state = item,
        onOpenFullStudio: () => _openFullStudio(selectedItem),
        onEditTemplate: _openEditor,
        onCreateDesign: _createDesign,
      ),
    );
  }

  Future<void> _createDesign() async {
    final tpl = await showStudioCreateSheet(context);
    if (tpl != null && mounted) {
      await _openEditor(tpl);
    }
  }

  Future<void> _openFullStudio(Item? selectedItem, {String openPanel = 'smart-ads'}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.studioWebEntry(
        productId: selectedItem?.remoteId,
        editorMode: 'design',
        openPanel: openPanel,
      );
      final body = res.data;
      if (body is! Map) {
        throw StateError('Invalid studio web-entry response');
      }
      final url = body['url']?.toString();
      if (url == null || url.isEmpty) {
        throw StateError('Studio web-entry URL missing');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullStudioWebViewScreen(initialUrl: url),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open Full Studio: $e'),
          backgroundColor: DesignTokens.error,
        ),
      );
    }
  }

  Future<void> _openEditor(AdTemplate tpl) async {
    final item = ref.read(studioProductProvider);
    await launchStudioEditor(
      context,
      ref,
      template: tpl,
      product: item,
    );
  }
}