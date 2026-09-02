import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ad_templates.dart';
import '../studio_watermark_settings.dart';
import 'editor_shared_widgets.dart';

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class TopBar extends ConsumerWidget {
  const TopBar({
    super.key,
    required this.template,
    this.activeSize,
    required this.canUndo,
    required this.canRedo,
    required this.showGrid,
    required this.snapEnabled,
    required this.isBusy,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleGrid,
    required this.onToggleSnap,
    required this.onSave,
    required this.onShare,
    required this.onSaveAs,
    required this.onResize,
  });

  final AdTemplate template;
  final AdSize? activeSize;
  final bool canUndo, canRedo, showGrid, snapEnabled, isBusy;
  final VoidCallback onUndo,
      onRedo,
      onToggleGrid,
      onToggleSnap,
      onSave,
      onShare,
      onSaveAs;
  final ValueChanged<AdSize> onResize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    final disabledColor = Theme.of(context).disabledColor;
    final previewEnabled = ref.watch(watermarkPreviewProvider);
    final sizeLabel = activeSize != null
        ? '${activeSize!.label} ${activeSize!.width.toInt()}×${activeSize!.height.toInt()}'
        : '${template.canvasWidth.toInt()}×${template.canvasHeight.toInt()}';
    return Container(
      color: kSurface,
      padding: EdgeInsets.fromLTRB(4, topPad + 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close editor',
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white70,
              size: 18,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sizeLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            icon: Icon(
              Icons.undo_rounded,
              color: canUndo ? Colors.white70 : disabledColor,
              size: 20,
            ),
            onPressed: canUndo ? onUndo : null,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: Icon(
              Icons.redo_rounded,
              color: canRedo ? Colors.white70 : disabledColor,
              size: 20,
            ),
            onPressed: canRedo ? onRedo : null,
          ),
          PopupMenuButton<String>(
            tooltip: 'More canvas tools',
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
            color: kSurface,
            onSelected: (value) {
              switch (value) {
                case 'size':
                  _showSizePicker(context);
                case 'grid':
                  onToggleGrid();
                case 'snap':
                  onToggleSnap();
                case 'watermark':
                  final current = ref.read(watermarkPreviewProvider);
                  ref.read(watermarkPreviewProvider.notifier).state = !current;
                case 'template':
                  onSaveAs();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'size',
                child: _CanvasMenuItem(
                  icon: Icons.aspect_ratio_rounded,
                  label: 'Canvas size',
                ),
              ),
              PopupMenuItem(
                value: 'grid',
                child: _CanvasMenuItem(
                  icon: Icons.grid_on_rounded,
                  label: showGrid ? 'Hide grid' : 'Show grid',
                  active: showGrid,
                ),
              ),
              PopupMenuItem(
                value: 'snap',
                child: _CanvasMenuItem(
                  icon: Icons.straighten_rounded,
                  label: 'Snap to guides',
                  active: snapEnabled,
                ),
              ),
              PopupMenuItem(
                value: 'watermark',
                child: _CanvasMenuItem(
                  icon: Icons.water_drop_rounded,
                  label: 'Watermark preview',
                  active: previewEnabled,
                ),
              ),
              const PopupMenuItem(
                value: 'template',
                child: _CanvasMenuItem(
                  icon: Icons.bookmark_add_rounded,
                  label: 'Save as template',
                ),
              ),
            ],
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kAccent),
                ),
              ),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, size: 17),
              label: const Text('Share'),
            ),
          IconButton(
            tooltip: 'Save design',
            onPressed: onSave,
            icon: const Icon(Icons.check_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showSizePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Choose canvas size',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Elements scale to fit the new size. Text stays readable.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: adSizes.length,
                itemBuilder: (_, i) {
                  final size = adSizes[i];
                  final isActive = activeSize?.label == size.label;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      size.icon,
                      color: isActive ? kAccent : Colors.white54,
                      size: 22,
                    ),
                    title: Text(
                      size.label,
                      style: TextStyle(
                        color: isActive ? kAccent : Colors.white,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${size.width.toInt()}×${size.height.toInt()}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isActive
                        ? const Icon(
                            Icons.check_rounded,
                            color: kAccent,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onResize(size);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CanvasMenuItem extends StatelessWidget {
  const _CanvasMenuItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: active ? kAccent : Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white)),
        if (active) ...[
          const Spacer(),
          const Icon(Icons.check_rounded, color: kAccent, size: 18),
        ],
      ],
    );
  }
}
