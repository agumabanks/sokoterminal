import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/error_page.dart';
import '../receipts/receipt_template_editor.dart';

/// State for receipt templates list
class TemplatesState {
  const TemplatesState({
    this.loading = false,
    this.templates = const [],
    this.error,
  });

  final bool loading;
  final List<ReceiptTemplate> templates;
  final String? error;

  TemplatesState copyWith({
    bool? loading,
    List<ReceiptTemplate>? templates,
    String? error,
  }) =>
      TemplatesState(
        loading: loading ?? this.loading,
        templates: templates ?? this.templates,
        error: error,
      );
}

final receiptTemplatesProvider =
    StateNotifierProvider<ReceiptTemplatesController, TemplatesState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReceiptTemplatesController(db)..load();
});

class ReceiptTemplatesController extends StateNotifier<TemplatesState> {
  ReceiptTemplatesController(this._db) : super(const TemplatesState());

  final AppDatabase _db;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final templates = await (_db.select(_db.receiptTemplates)
            ..orderBy([(t) => OrderingTerm.desc(t.isActive)]))
          .get();
      state = state.copyWith(loading: false, templates: templates);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> setActive(String templateId) async {
    try {
      // Deactivate all
      await (_db.update(_db.receiptTemplates))
          .write(const ReceiptTemplatesCompanion(isActive: Value(false)));
      // Activate selected
      await (_db.update(_db.receiptTemplates)
            ..where((t) => t.id.equals(templateId)))
          .write(const ReceiptTemplatesCompanion(isActive: Value(true)));
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> delete(String templateId) async {
    try {
      await (_db.delete(_db.receiptTemplates)
            ..where((t) => t.id.equals(templateId)))
          .go();
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

class ReceiptTemplatesScreen extends ConsumerStatefulWidget {
  const ReceiptTemplatesScreen({super.key});

  @override
  ConsumerState<ReceiptTemplatesScreen> createState() => _ReceiptTemplatesScreenState();
}

class _ReceiptTemplatesScreenState extends ConsumerState<ReceiptTemplatesScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptTemplatesProvider);
    final controller = ref.read(receiptTemplatesProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Receipt Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createTemplate(controller),
          ),
        ],
      ),
      body: _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TemplatesState state,
    ReceiptTemplatesController controller,
  ) {
    if (state.loading && state.templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.templates.isEmpty) {
      return ErrorPage(
        title: 'Failed to Load Templates',
        message: state.error,
        onRetry: controller.load,
      );
    }

    if (state.templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: DesignTokens.grayMedium),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('No templates yet', style: DesignTokens.textBody),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              'Create a template to customize your receipts',
              style:
                  DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            AppButton(
              label: 'Create Template',
              onPressed: () => _createTemplate(ref.read(receiptTemplatesProvider.notifier)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        padding: DesignTokens.paddingScreen,
        itemCount: state.templates.length,
        itemBuilder: (context, index) {
          final template = state.templates[index];
          return _TemplateCard(
            template: template,
            onTap: () => _editTemplate(template),
            onSetActive: () => controller.setActive(template.id),
            onDelete: () => _confirmDelete(context, controller, template),
          );
        },
      ),
    );
  }

  void _createTemplate(ReceiptTemplatesController controller) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptTemplateEditor()),
    );
    // Refresh list if template was saved
    if (result == true) {
      controller.load();
    }
  }

  void _editTemplate(ReceiptTemplate template) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptTemplateEditor(templateId: template.id),
      ),
    );
    // Refresh list if template was saved
    if (result == true) {
      ref.read(receiptTemplatesProvider.notifier).load();
    }
  }

  void _confirmDelete(
    BuildContext context,
    ReceiptTemplatesController controller,
    ReceiptTemplate template,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: DesignTokens.error),
            onPressed: () {
              controller.delete(template.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    this.onTap,
    this.onSetActive,
    this.onDelete,
  });

  final ReceiptTemplate template;
  final VoidCallback? onTap;
  final VoidCallback? onSetActive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          child: Row(
            children: [
              // Preview
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: template.colorHex != null
                      ? _parseColor(template.colorHex!)
                      : DesignTokens.grayLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DesignTokens.grayLight),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt,
                      size: 24,
                      color: DesignTokens.grayMedium,
                    ),
                    if (template.showLogo)
                      Icon(Icons.image, size: 12, color: DesignTokens.grayMedium),
                  ],
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(template.name, style: DesignTokens.textBodyBold),
                        if (template.isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: DesignTokens.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: DesignTokens.textSmall.copyWith(
                                color: DesignTokens.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.style.toUpperCase(),
                      style: DesignTokens.textSmall.copyWith(
                        color: DesignTokens.grayMedium,
                      ),
                    ),
                    if (template.headerText != null &&
                        template.headerText!.isNotEmpty)
                      Text(
                        template.headerText!,
                        style: DesignTokens.textSmall.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'activate') onSetActive?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (ctx) => [
                  if (!template.isActive)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 8),
                          Text('Set Active'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return DesignTokens.grayLight;
    }
  }
}
