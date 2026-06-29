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
  final VoidCallback onUndo, onRedo, onToggleGrid, onToggleSnap, onSave, onShare, onSaveAs;
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
      padding: EdgeInsets.fromLTRB(4, topPad + 2, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close editor',
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 18),
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
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
          // Canvas size picker
          IconButton(
            tooltip: 'Change canvas size',
            icon: const Icon(Icons.aspect_ratio_rounded,
                color: Colors.white70, size: 20),
            onPressed: () => _showSizePicker(context),
          ),
          // Undo / Redo
          IconButton(
            tooltip: 'Undo',
            icon: Icon(Icons.undo_rounded,
                color: canUndo ? Colors.white70 : disabledColor, size: 20),
            onPressed: canUndo ? onUndo : null,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: Icon(Icons.redo_rounded,
                color: canRedo ? Colors.white70 : disabledColor, size: 20),
            onPressed: canRedo ? onRedo : null,
          ),
          // Grid toggle
          IconButton(
            tooltip: showGrid ? 'Hide grid' : 'Show grid',
            icon: Icon(
              Icons.grid_on_rounded,
              color: showGrid ? kAccent : Colors.white38, size: 20),
            onPressed: onToggleGrid,
          ),
          // Snap toggle
          IconButton(
            icon: Icon(
              Icons.straighten_rounded,
              color: snapEnabled ? kAccent : Colors.white38, size: 20),
            onPressed: onToggleSnap,
            tooltip: 'Snap to guides',
          ),
          // Watermark preview toggle
          IconButton(
            tooltip: previewEnabled ? 'Hide watermark preview' : 'Show watermark preview',
            icon: Icon(
              Icons.water_drop_rounded,
              color: previewEnabled ? kAccent : Colors.white38,
              size: 20,
            ),
            onPressed: () {
              final current = ref.read(watermarkPreviewProvider);
              ref.read(watermarkPreviewProvider.notifier).state = !current;
            },
          ),
          // Save as
          IconButton(
            tooltip: 'Save as template',
            icon: const Icon(Icons.bookmark_add_rounded, color: Colors.white70, size: 20),
            onPressed: onSaveAs,
          ),
          // Share
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kAccent)),
              ),
            )
          else
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white70, size: 20),
              onPressed: onShare,
            ),
          // Save (green pill)
          Tooltip(
            message: 'Save design',
            child: GestureDetector(
              onTap: onSave,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Save',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
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
                    leading: Icon(size.icon,
                        color: isActive ? kAccent : Colors.white54, size: 22),
                    title: Text(
                      size.label,
                      style: TextStyle(
                        color: isActive ? kAccent : Colors.white,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${size.width.toInt()}×${size.height.toInt()}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_rounded, color: kAccent, size: 20)
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
