import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ad_templates.dart';
import '../editor_shared_widgets.dart';

// ---------------------------------------------------------------------------
// Font panel
// ---------------------------------------------------------------------------

class FontPanel extends StatelessWidget {
  const FontPanel({
    super.key,
    required this.selectedFont,
    required this.onSelect,
    this.element,
  });
  final String selectedFont;
  final ValueChanged<String> onSelect;
  final CanvasElement? element;

  @override
  Widget build(BuildContext context) {
    final showHint = element == null;
    return PanelWrap(
      height: showHint ? 160 : 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHint) const _SelectElementHint(),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: studioFonts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final name = studioFonts.keys.elementAt(i);
                final pkgName = studioFonts.values.elementAt(i);
                final desc = fontDescriptors[name];
                final isSel = selectedFont == name;

                TextStyle style;
                try {
                  style = GoogleFonts.getFont(pkgName,
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: isSel ? kAccent : Colors.white);
                } catch (_) {
                  style = TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: isSel ? kAccent : Colors.white);
                }

                return GestureDetector(
                  onTap: () => onSelect(name),
                  child: Container(
                    width: 88,
                    decoration: BoxDecoration(
                      color: isSel ? kAccent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSel ? kAccent : Colors.white10),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(desc?.sample ?? 'Aa', style: style),
                        const SizedBox(height: 3),
                        Text(name,
                            style: TextStyle(color: isSel ? kAccent : Colors.white38,
                                fontSize: 8, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        if (desc != null)
                          Text(desc.vibe,
                              style: const TextStyle(color: Colors.white24, fontSize: 7),
                              textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectElementHint extends StatelessWidget {
  const _SelectElementHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: Colors.white38, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap an element on the canvas to edit it.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
