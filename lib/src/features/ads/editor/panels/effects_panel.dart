import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ad_templates.dart';
import '../editor_shared_widgets.dart';
import '../editor_state.dart';

// ---------------------------------------------------------------------------
// Effects panel (shadow, stroke, opacity, rotation)
// ---------------------------------------------------------------------------

class EffectsPanel extends StatelessWidget {
  const EffectsPanel({
    super.key,
    required this.element,
    required this.onUpdate,
    this.onAlign,
  });
  final CanvasElement? element;
  final ValueChanged<CanvasElement>? onUpdate;
  final ValueChanged<AlignMode>? onAlign;

  @override
  Widget build(BuildContext context) {
    final el = element;
    if (el == null || onUpdate == null) {
      return const PanelWrap(
        child: Center(
          child: _SelectElementHint(),
        ),
      );
    }

    return PanelWrap(
      height: 280,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opacity
            Row(children: [
              const Text('Opacity', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: el.opacity.clamp(0.0, 1.0),
                  min: 0.0, max: 1.0,
                  activeColor: kAccent, inactiveColor: Colors.white12,
                  onChanged: (v) => onUpdate!(el.copyWith(opacity: v)),
                ),
              ),
              Text('${(el.opacity * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),

            // Rotation (degrees)
            Row(children: [
              const Text('Rotation', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: (el.rotation * 180 / math.pi).clamp(-180, 180),
                  min: -180, max: 180,
                  activeColor: kAccent, inactiveColor: Colors.white12,
                  onChanged: (v) => onUpdate!(el.copyWith(rotation: v * math.pi / 180)),
                ),
              ),
              Text('${(el.rotation * 180 / math.pi).toStringAsFixed(0)}°',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),

            // Alignment helpers
            if (onAlign != null) ...[
              const SizedBox(height: 10),
              const Text('Align to canvas',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  (Icons.align_horizontal_left_rounded, 'Left', AlignMode.left),
                  (Icons.align_horizontal_center_rounded, 'Center', AlignMode.centerH),
                  (Icons.align_horizontal_right_rounded, 'Right', AlignMode.right),
                  (Icons.align_vertical_top_rounded, 'Top', AlignMode.top),
                  (Icons.align_vertical_center_rounded, 'Middle', AlignMode.centerV),
                  (Icons.align_vertical_bottom_rounded, 'Bottom', AlignMode.bottom),
                ].map((a) {
                  return GestureDetector(
                    onTap: () => onAlign!(a.$3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a.$1, color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Text(a.$2,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Shadow toggle + color
            Row(children: [
              const Text('Shadow', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const Spacer(),
              if (el.hasShadow)
                GestureDetector(
                  onTap: () async {
                    final color = await _pickColor(context, parseHexColor(el.shadowColor ?? '#000000'));
                    if (color != null) {
                      onUpdate!(el.copyWith(shadowColor: colorToHex(color)));
                    }
                  },
                  child: Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: parseHexColor(el.shadowColor ?? '#000000'),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
              Switch(
                value: el.hasShadow,
                activeThumbColor: kAccent,
                onChanged: (v) => onUpdate!(el.copyWith(
                  shadowColor: v ? '#000000' : null,
                )),
              ),
            ]),
            if (el.hasShadow) ...[
              Row(children: [
                const Text('Blur', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Expanded(
                  child: Slider(
                    value: el.shadowBlur.clamp(0, 40),
                    min: 0, max: 40,
                    activeColor: kAccent, inactiveColor: Colors.white12,
                    onChanged: (v) => onUpdate!(el.copyWith(shadowBlur: v)),
                  ),
                ),
                Text(el.shadowBlur.round().toString(),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
              Row(children: [
                const Text('X', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Expanded(
                  child: Slider(
                    value: el.shadowDx.clamp(-40, 40),
                    min: -40, max: 40,
                    activeColor: kAccent, inactiveColor: Colors.white12,
                    onChanged: (v) => onUpdate!(el.copyWith(shadowDx: v)),
                  ),
                ),
                Text(el.shadowDx.round().toString(),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
              Row(children: [
                const Text('Y', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Expanded(
                  child: Slider(
                    value: el.shadowDy.clamp(-40, 40),
                    min: -40, max: 40,
                    activeColor: kAccent, inactiveColor: Colors.white12,
                    onChanged: (v) => onUpdate!(el.copyWith(shadowDy: v)),
                  ),
                ),
                Text(el.shadowDy.round().toString(),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
            ],

            // Stroke
            Row(children: [
              const Text('Stroke', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const Spacer(),
              if (el.hasStroke)
                GestureDetector(
                  onTap: () async {
                    final color = await _pickColor(context, parseHexColor(el.strokeColor ?? '#ffffff'));
                    if (color != null) {
                      onUpdate!(el.copyWith(strokeColor: colorToHex(color)));
                    }
                  },
                  child: Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: parseHexColor(el.strokeColor ?? '#ffffff'),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
              Switch(
                value: el.hasStroke,
                activeThumbColor: kAccent,
                onChanged: (v) => onUpdate!(el.copyWith(
                  strokeColor: v ? '#ffffff' : null,
                  strokeWidth: v ? 2.0 : null,
                )),
              ),
            ]),
            if (el.hasStroke)
              Row(children: [
                const Text('Width', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Expanded(
                  child: Slider(
                    value: (el.strokeWidth ?? 2).clamp(0.5, 20),
                    min: 0.5, max: 20,
                    activeColor: kAccent, inactiveColor: Colors.white12,
                    onChanged: (v) => onUpdate!(el.copyWith(strokeWidth: v)),
                  ),
                ),
                Text((el.strokeWidth ?? 2).toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
          ],
        ),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color initial) async {
    Color selected = initial;
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Pick color', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...colorPalette.take(30),
              Colors.black,
              Colors.white,
            ].map((c) => GestureDetector(
              onTap: () {
                selected = c;
                Navigator.pop(ctx, selected);
              },
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
