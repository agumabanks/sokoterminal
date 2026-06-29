import 'package:flutter/material.dart';

import '../../ad_templates.dart';
import '../../canvas_background.dart';
import '../editor_shared_widgets.dart';
import '../../../../core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Background panel
// ---------------------------------------------------------------------------

class BackgroundPanel extends StatefulWidget {
  const BackgroundPanel({
    super.key,
    required this.current,
    required this.brandColors,
    required this.onSolid,
    required this.onGradient,
  });
  final String current;
  final List<Color> brandColors;
  final ValueChanged<String> onSolid;
  final void Function(({String id, String label, List<Color> colors})) onGradient;

  @override
  State<BackgroundPanel> createState() => _BackgroundPanelState();
}

class _BackgroundPanelState extends State<BackgroundPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PanelWrap(
      height: 180,
      child: Column(
        children: [
          TabBar(
            controller: _tc,
            labelColor: kAccent,
            unselectedLabelColor: Colors.white38,
            indicatorColor: kAccent,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 11),
            tabs: const [
              Tab(text: 'Solid'),
              Tab(text: 'Gradient'),
              Tab(text: 'Magic'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      ...widget.brandColors.map((c) {
                        final hex = colorToHex(c);
                        return GestureDetector(
                          onTap: () => widget.onSolid(hex),
                          child: Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.current == hex
                                    ? kAccent
                                    : Colors.white24,
                                width: widget.current == hex ? 2.5 : 1.5,
                              ),
                            ),
                            child: widget.current == hex
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }),
                      ...colorPalette.map((c) {
                        final hex = colorToHex(c);
                        return GestureDetector(
                          onTap: () => widget.onSolid(hex),
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.current == hex
                                    ? kAccent
                                    : Colors.white12,
                                width: widget.current == hex ? 2.5 : 1,
                              ),
                            ),
                            child: widget.current == hex
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: gradientPresets.map((g) {
                      final isSel = widget.current == 'gradient:${g.id}';
                      return GestureDetector(
                        onTap: () => widget.onGradient(g),
                        child: Container(
                          width: 64, height: 64,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: g.colors,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? kAccent : Colors.transparent, width: 2),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(g.label,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      ...patternBackgroundIds.map((id) {
                        final bg = 'pattern:$id';
                        final isSel = widget.current == bg;
                        return GestureDetector(
                          onTap: () => widget.onSolid(bg),
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: DesignTokens.brandPrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? kAccent : Colors.white12,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: buildCanvasBackground(background: bg),
                            ),
                          ),
                        );
                      }),
                      ...meshBackgroundPresets.map((m) {
                        final bg = 'gradient:${m.id}';
                        final isSel = widget.current == bg;
                        return GestureDetector(
                          onTap: () => widget.onGradient((
                            id: m.id,
                            label: m.label,
                            colors: m.colors,
                          )),
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: m.begin,
                                end: m.end,
                                colors: m.colors,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? kAccent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  m.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(blurRadius: 4, color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
