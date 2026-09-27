import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/db/app_database.dart';
import '../../core/util/formatters.dart';
import '../items/wholesale_pricing.dart';

class ProductSaleSelection {
  const ProductSaleSelection(this.stock, this.quantity);
  final ItemStock? stock;
  final int quantity;
}

class ProductSaleSheet extends StatefulWidget {
  const ProductSaleSheet({super.key, required this.item, required this.stocks});
  final Item item;
  final List<ItemStock> stocks;
  @override
  State<ProductSaleSheet> createState() => _ProductSaleSheetState();
}

class _ProductSaleSheetState extends State<ProductSaleSheet> {
  final quantity = TextEditingController(text: '1');
  ItemStock? selected;
  @override
  void initState() {
    super.initState();
    selected =
        widget.stocks
            .where((s) => !widget.item.stockEnabled || s.stockQty > 0)
            .firstOrNull ??
        widget.stocks.firstOrNull;
  }

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(quantity.text) ?? 0;
    final stock = selected?.stockQty ?? widget.item.stockQty;
    final valid = count > 0 && (!widget.item.stockEnabled || count <= stock);
    final price = wholesaleUnitPrice(
      selected?.price ?? widget.item.price,
      widget.item.wholesaleRangesJson,
      count,
    );
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (widget.stocks.isNotEmpty) ...[
                const Text(
                  'Choose the option you are selling',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final s in widget.stocks)
                  Card(
                    color: selected == s
                        ? const Color(0xFFE8F5E9)
                        : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: selected == s
                            ? const Color(0xFF146C43)
                            : Colors.black12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        selected == s
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: const Color(0xFF146C43),
                      ),
                      title: Text(
                        s.variant.isEmpty
                            ? 'Standard item'
                            : s.variant.replaceAll('-', ' · '),
                      ),
                      subtitle: Text(
                        '${s.price.toUgx()} each${widget.item.stockEnabled ? ' · ${s.stockQty} available' : ''}',
                      ),
                      enabled: !widget.item.stockEnabled || s.stockQty > 0,
                      onTap: () => setState(() => selected = s),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  helperText: widget.item.stockEnabled
                      ? '$stock available'
                      : 'Enter the number of items',
                  errorText: valid
                      ? null
                      : 'Enter a quantity within available stock',
                ),
                onChanged: (_) => setState(() {}),
              ),
              Wrap(
                spacing: 8,
                children: [1, 10, 50, 100]
                    .map(
                      (q) => ActionChip(
                        label: Text('$q'),
                        onPressed: widget.item.stockEnabled && q > stock
                            ? null
                            : () => setState(() => quantity.text = '$q'),
                      ),
                    )
                    .toList(),
              ),
              if (wholesaleRanges(widget.item.wholesaleRangesJson).isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(
                    'Wholesale prices apply automatically',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              for (final r in wholesaleRanges(widget.item.wholesaleRangesJson))
                Text(
                  '${r['min_qty']}–${r['max_qty']} items · ${(double.tryParse('${r['price']}') ?? 0).toUgx()} each',
                ),
              const SizedBox(height: 12),
              Text(
                '${price.toUgx()} each · ${(price * count).toUgx()} total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(
                        context,
                        ProductSaleSelection(selected, count),
                      )
                    : null,
                child: Text('Add $count to sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
