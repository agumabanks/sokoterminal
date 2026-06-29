import 'package:flutter/material.dart';

import 'ad_templates.dart';
import '../../core/theme/design_tokens.dart';

/// Canva-style "Create a design" sheet — pick a social format or start blank.
Future<AdTemplate?> showStudioCreateSheet(BuildContext context) {
  return showModalBottomSheet<AdTemplate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.brandPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _StudioCreateSheet(),
  );
}

class _StudioCreateSheet extends StatelessWidget {
  const _StudioCreateSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a design',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a format — like Canva, Instagram, TikTok, and more',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
              children: [
                _SizeCard(
                  label: 'Blank canvas',
                  subtitle: 'Start from scratch',
                  icon: Icons.add_rounded,
                  accent: DesignTokens.brandAccent,
                  onTap: () => Navigator.pop(
                    context,
                    blankCanvas(adSizes.first),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Social & marketing formats',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                ...adSizes.map(
                  (size) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SizeCard(
                      label: size.label,
                      subtitle:
                          '${size.width.toInt()} × ${size.height.toInt()} px',
                      icon: size.icon,
                      previewRatio: size.aspectRatio,
                      onTap: () => Navigator.pop(
                        context,
                        blankCanvas(size, name: size.label),
                      ),
                    ),
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

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent,
    this.previewRatio,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;
  final double? previewRatio;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFF6366f1);
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: previewRatio != null
                    ? Center(
                        child: Container(
                          width: previewRatio! >= 1 ? 28 : 18,
                          height: previewRatio! >= 1 ? 18 : 28,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: color, width: 1.5),
                          ),
                        ),
                      )
                    : Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}