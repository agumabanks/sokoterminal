import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import 'cart_controller.dart';

class ParkedSale {
  ParkedSale({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.lines,
    this.notes,
    this.customer,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final List<CartLine> lines;
  final String? notes;
  final Customer? customer;

  double get total => lines.fold(0, (sum, line) => sum + line.total);
}

final parkedSalesProvider =
    StateNotifierProvider<ParkedSalesController, List<ParkedSale>>((ref) {
  return ParkedSalesController();
});

class ParkedSalesController extends StateNotifier<List<ParkedSale>> {
  ParkedSalesController() : super(const []);

  final _uuid = const Uuid();

  String parkSale(CartState cart, {String? label}) {
    if (cart.lines.isEmpty) return '';
    final sale = ParkedSale(
      id: _uuid.v4(),
      label: label?.isEmpty ?? true ? 'Parked sale' : label!,
      createdAt: DateTime.now(),
      lines: List<CartLine>.from(cart.lines),
      notes: cart.notes,
      customer: cart.customer,
    );
    state = [sale, ...state];
    return sale.id;
  }

  CartState? resume(String id) {
    final idx = state.indexWhere((s) => s.id == id);
    if (idx == -1) return null;
    final sale = state[idx];
    state = [...state]..removeAt(idx);
    return CartState(lines: sale.lines, notes: sale.notes, customer: sale.customer);
  }

  void clear(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}
