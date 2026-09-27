import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<Map<String, dynamic>> wholesaleRanges(String? source) {
  if (source == null) return [];
  try {
    return (jsonDecode(source) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return [];
  }
}

double wholesaleUnitPrice(double retail, String? source, int quantity) {
  for (final range in wholesaleRanges(source)) {
    final min = int.tryParse('${range['min_qty']}') ?? 0;
    final max = int.tryParse('${range['max_qty']}') ?? 0;
    final price = double.tryParse('${range['price']}');
    if (quantity >= min &&
        quantity <= max &&
        price != null &&
        price.isFinite &&
        price > 0) {
      return price;
    }
  }
  return retail;
}

String? validateWholesaleRanges(List<Map<String, dynamic>> ranges) {
  if (ranges.isEmpty) return 'Add at least one wholesale range.';
  final sorted = [...ranges]
    ..sort(
      (a, b) => (int.tryParse('${a['min_qty']}') ?? 0).compareTo(
        int.tryParse('${b['min_qty']}') ?? 0,
      ),
    );
  var previousMax = 0;
  for (final range in sorted) {
    final min = int.tryParse('${range['min_qty']}') ?? 0;
    final max = int.tryParse('${range['max_qty']}') ?? 0;
    final price = double.tryParse('${range['price']}');
    if (min < 1 || max <= min) {
      return 'Each range needs a minimum of 1 or more and a larger maximum.';
    }
    if (price == null || !price.isFinite || price <= 0) {
      return 'Enter a positive price per item for every range.';
    }
    if (min <= previousMax) return 'Quantity ranges must not overlap.';
    previousMax = max;
  }
  return null;
}

class WholesaleEditor extends StatelessWidget {
  const WholesaleEditor({
    super.key,
    required this.enabled,
    required this.ranges,
    required this.onToggle,
    required this.onChanged,
  });
  final bool enabled;
  final List<Map<String, dynamic>> ranges;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Wholesale pricing'),
          subtitle: const Text('Set lower prices for larger orders.'),
          value: enabled,
          onChanged: onToggle,
        ),
        if (enabled) ...[
          const Text(
            'Price is per item. Orders outside these ranges use your normal selling price.',
          ),
          for (var i = 0; i < ranges.length; i++)
            Padding(
              key: ObjectKey(ranges[i]),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Range ${i + 1}')),
                      IconButton(
                        tooltip: 'Remove range',
                        onPressed: () {
                          ranges.removeAt(i);
                          onChanged();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      for (final key in ['min_qty', 'max_qty'])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextFormField(
                              initialValue: '${ranges[i][key] ?? ''}',
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Color(0xFFF5F7F6),
                                border: OutlineInputBorder(),
                                labelText: key == 'min_qty'
                                    ? 'From quantity'
                                    : 'To quantity',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (v) =>
                                  ranges[i][key] = int.tryParse(v),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: '${ranges[i]['price'] ?? ''}',
                    decoration: const InputDecoration(
                      labelText: 'Price per item (UGX)',
                      filled: true,
                      fillColor: Color(0xFFF5F7F6),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (v) => ranges[i]['price'] = double.tryParse(v),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () {
              ranges.add({});
              onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add quantity range'),
          ),
        ],
      ],
    ),
  );
}
