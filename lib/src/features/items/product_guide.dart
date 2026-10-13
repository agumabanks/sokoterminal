import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_providers.dart';

/// Short, replayable help. It never blocks a seller from using the catalog.
class ProductGuide extends ConsumerStatefulWidget {
  const ProductGuide({this.replay = false, super.key});
  final bool replay;
  @override
  ConsumerState<ProductGuide> createState() => _ProductGuideState();
}

class _ProductGuideState extends ConsumerState<ProductGuide> {
  bool _expanded = false;
  static const _key = 'product_guide_seen_v2';
  @override
  void initState() {
    super.initState();
    _expanded =
        widget.replay ||
        ref.read(sharedPreferencesProvider).getBool(_key) != true;
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 200),
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffedf7f2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Your products, made simple',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: _expanded ? 'Close help' : 'Show product help',
                icon: Icon(_expanded ? Icons.close : Icons.help_outline),
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                  if (!_expanded) {
                    ref.read(sharedPreferencesProvider).setBool(_key, true);
                  }
                },
              ),
            ],
          ),
          if (_expanded) ...[
            const _GuideLine(
              Icons.add_circle_outline,
              'Add a product',
              'Start with a name, prices and quantity.',
            ),
            const _GuideLine(
              Icons.photo_camera_outlined,
              'Show what you sell',
              'Add a cover photo. Online buyers also need 3–6 extra views.',
            ),
            const _GuideLine(
              Icons.swipe_left_outlined,
              'Swipe a product left',
              'Edit, change stock or open More. You can also tap the three dots.',
            ),
            const _GuideLine(
              Icons.public,
              'Choose who can buy',
              'Publish online when ready. Set your selling area in Delivery settings.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ref.read(sharedPreferencesProvider).setBool(_key, true);
                  setState(() => _expanded = false);
                },
                child: const Text('Got it'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _GuideLine extends StatelessWidget {
  const _GuideLine(this.icon, this.title, this.detail);
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(detail),
            ],
          ),
        ),
      ],
    ),
  );
}
