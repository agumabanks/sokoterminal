import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/db/app_database.dart';
import '../../ad_templates.dart';
import '../../brand_kit_screen.dart';
import '../../studio_variable_utils.dart';
import '../editor_shared_widgets.dart';

// ---------------------------------------------------------------------------
// Text panel
// ---------------------------------------------------------------------------

class TextPanel extends StatefulWidget {
  const TextPanel({
    super.key,
    required this.element,
    required this.kit,
    required this.product,
    required this.productLink,
    required this.brandColors,
    required this.onUpdate,
    required this.onAddText,
  });
  final CanvasElement? element;
  final BrandKit kit;
  final Item? product;
  final String productLink;
  final List<Color> brandColors;
  final ValueChanged<CanvasElement> onUpdate;
  final VoidCallback onAddText;

  @override
  State<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<TextPanel>
    with SingleTickerProviderStateMixin {
  late TextEditingController _ctrl;
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _ctrl = TextEditingController(text: widget.element?.text ?? '');
  }

  @override
  void didUpdateWidget(TextPanel old) {
    super.didUpdateWidget(old);
    if (old.element?.id != widget.element?.id) {
      _ctrl.text = widget.element?.text ?? '';
    }
  }

  @override
  void dispose() {
    _tc.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final el = widget.element;
    return PanelWrap(
      height: 340,
      child: el == null || el.type != 'text'
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SelectElementHint(),
                PanelAction(
                  icon: Icons.add_circle_rounded,
                  label: 'Add Text',
                  color: kAccent,
                  onTap: widget.onAddText,
                ),
              ],
            )
          : Column(
              children: [
                // Live preview strip
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    resolveStudioVariables(
                      _ctrl.text,
                      kit: widget.kit,
                      product: widget.product,
                      productLink: widget.productLink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: el.align == 'center'
                        ? TextAlign.center
                        : el.align == 'right'
                            ? TextAlign.right
                            : TextAlign.left,
                    style: _previewStyle(el),
                  ),
                ),
                TabBar(
                  controller: _tc,
                  labelColor: kAccent,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: kAccent,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(fontSize: 11),
                  tabs: const [Tab(text: 'Content'), Tab(text: 'Style')],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tc,
                    children: [
                      // Content tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tap variables from your shop & product',
                              style: TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            DarkField(
                              ctrl: _ctrl,
                              hint: 'Type your text…',
                              maxLines: 4,
                              onChanged: (v) => widget.onUpdate(el.copyWith(text: v)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: studioVariableChips.map((chip) {
                                return GestureDetector(
                                  onTap: () {
                                    final t = _ctrl.text + chip.token;
                                    _ctrl.text = t;
                                    widget.onUpdate(el.copyWith(text: t));
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: kAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      chip.label,
                                      style: const TextStyle(
                                        color: kAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      // Style tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Font size
                            Row(children: [
                              const Text('Size', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Expanded(
                                child: Slider(
                                  value: (el.fontSize ?? 24).clamp(8, 200),
                                  min: 8, max: 200,
                                  activeColor: kAccent, inactiveColor: Colors.white12,
                                  onChanged: (v) => widget.onUpdate(el.copyWith(fontSize: v)),
                                ),
                              ),
                              Text('${(el.fontSize ?? 24).toInt()}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),

                            // Letter spacing
                            Row(children: [
                              const Text('Spacing', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Expanded(
                                child: Slider(
                                  value: (el.letterSpacing ?? 0).clamp(-5, 20),
                                  min: -5, max: 20,
                                  activeColor: kAccent, inactiveColor: Colors.white12,
                                  onChanged: (v) => widget.onUpdate(el.copyWith(letterSpacing: v)),
                                ),
                              ),
                              Text((el.letterSpacing ?? 0).toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),

                            // Line height
                            Row(children: [
                              const Text('Line H.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Expanded(
                                child: Slider(
                                  value: (el.lineHeight ?? 1.2).clamp(0.8, 3.0),
                                  min: 0.8, max: 3.0,
                                  activeColor: kAccent, inactiveColor: Colors.white12,
                                  onChanged: (v) => widget.onUpdate(el.copyWith(lineHeight: v)),
                                ),
                              ),
                              Text((el.lineHeight ?? 1.2).toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),

                            // Alignment + bold + italic + underline row
                            Row(children: [
                              for (final a in [
                                ('left', Icons.format_align_left_rounded),
                                ('center', Icons.format_align_center_rounded),
                                ('right', Icons.format_align_right_rounded),
                              ])
                                ToggleBtn(
                                  icon: a.$2,
                                  active: el.align == a.$1,
                                  onTap: () => widget.onUpdate(el.copyWith(align: a.$1)),
                                ),
                              const Spacer(),
                              ToggleBtn(
                                label: 'B',
                                bold: true,
                                active: el.fontWeight == 'bold' || el.fontWeight == '700',
                                onTap: () => widget.onUpdate(el.copyWith(
                                    fontWeight: el.fontWeight == 'bold' ? '400' : 'bold')),
                              ),
                              ToggleBtn(
                                label: 'I',
                                bold: true,
                                active: el.fontStyle == 'italic',
                                onTap: () => widget.onUpdate(el.copyWith(
                                    fontStyle: el.fontStyle == 'italic' ? 'normal' : 'italic')),
                              ),
                              ToggleBtn(
                                label: 'U',
                                underline: true,
                                active: el.textDecoration == 'underline',
                                onTap: () => widget.onUpdate(CanvasElement(
                                  id: el.id, type: el.type, text: el.text,
                                  x: el.x, y: el.y, width: el.width, height: el.height,
                                  fontSize: el.fontSize, fontWeight: el.fontWeight,
                                  fontFamily: el.fontFamily, fill: el.fill, align: el.align,
                                  opacity: el.opacity, rotation: el.rotation, zIndex: el.zIndex,
                                  letterSpacing: el.letterSpacing, lineHeight: el.lineHeight,
                                  shadowColor: el.shadowColor, strokeColor: el.strokeColor,
                                  strokeWidth: el.strokeWidth,
                                  fontStyle: el.fontStyle,
                                  textDecoration: el.textDecoration == 'underline'
                                      ? null
                                      : 'underline',
                                )),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            // Text transform chips
                            const Text('Case',
                                style: TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                ('none', 'Aa'),
                                ('uppercase', 'AA'),
                                ('lowercase', 'aa'),
                                ('capitalize', 'Aa Aa'),
                              ].map((t) {
                                final active = el.textTransform == t.$1 ||
                                    (t.$1 == 'none' && el.textTransform == null);
                                return GestureDetector(
                                  onTap: () => widget.onUpdate(el.copyWith(
                                      textTransform: t.$1 == 'none' ? null : t.$1)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: active ? kAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: active ? kAccent : Colors.white24,
                                      ),
                                    ),
                                    child: Text(
                                      t.$2,
                                      style: TextStyle(
                                        color: active ? kAccent : Colors.white54,
                                        fontSize: 11,
                                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            // Color row
                            const SizedBox(height: 8),
                            if (widget.brandColors.isNotEmpty) ...[
                              const Text('Brand colors',
                                  style: TextStyle(color: Colors.white38, fontSize: 10)),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: widget.brandColors.map((c) {
                                    final hex = colorToHex(c);
                                    final isSel = el.fill == hex;
                                    return GestureDetector(
                                      onTap: () =>
                                          widget.onUpdate(el.copyWith(fill: hex)),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSel ? kAccent : Colors.white24,
                                            width: isSel ? 2.5 : 1,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: colorPalette.take(25).map((c) {
                                  final hex = colorToHex(c);
                                  final isSel = el.fill == hex;
                                  return GestureDetector(
                                    onTap: () => widget.onUpdate(el.copyWith(fill: hex)),
                                    child: Container(
                                      width: 28, height: 28,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: c, shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSel ? kAccent : Colors.white12,
                                          width: isSel ? 2.5 : 1,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
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

  TextStyle _previewStyle(CanvasElement el) {
    var style = TextStyle(
      fontSize: (el.fontSize ?? 24).clamp(14, 28),
      fontWeight: el.fontWeight == 'bold' ? FontWeight.bold : FontWeight.w500,
      color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
      height: el.lineHeight ?? 1.2,
    );
    if (el.fontFamily != null && studioFonts.containsKey(el.fontFamily)) {
      try {
        style = GoogleFonts.getFont(studioFonts[el.fontFamily!]!, textStyle: style);
      } catch (_) {}
    }
    return style;
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
