import 'package:flutter/material.dart';

import 'editor_shared_widgets.dart';

// ---------------------------------------------------------------------------
// Bottom toolbar
// ---------------------------------------------------------------------------

class BottomToolbar extends StatelessWidget {
  const BottomToolbar({
    super.key,
    required this.activePanel,
    required this.hasSelection,
    required this.onTool,
  });

  final String? activePanel;
  final bool hasSelection;
  final ValueChanged<String> onTool;

  static final _tools = [
    ('text', Icons.title_rounded, 'Text'),
    ('image', Icons.image_rounded, 'Image'),
    ('photo', Icons.photo_filter_rounded, 'Photo'),
    ('elements', Icons.auto_awesome_rounded, 'Creatives'),
    ('background', Icons.layers_rounded, 'Background'),
    ('fonts', Icons.font_download_outlined, 'Fonts'),
    ('effects', Icons.auto_fix_high_rounded, 'Effects'),
    ('layers', Icons.layers_outlined, 'Layers'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      color: kSurface,
      padding: EdgeInsets.fromLTRB(0, 4, 0, bottomPad + 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _tools.map((t) {
            final active = activePanel == t.$1;
            return Semantics(
              label: t.$3,
              button: true,
              selected: active,
              child: Tooltip(
                message: t.$3,
                child: GestureDetector(
                  onTap: () => onTool(t.$1),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? kAccent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? kAccent : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.$2,
                            size: 20,
                            color: active ? kAccent : Colors.white38),
                        const SizedBox(height: 2),
                        Text(t.$3,
                            style: TextStyle(
                              color: active ? kAccent : Colors.white38,
                              fontSize: 9,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
