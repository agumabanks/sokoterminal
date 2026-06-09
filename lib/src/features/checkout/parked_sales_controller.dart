import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart' as db;
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
  final db.Customer? customer;

  double get total => lines.fold(0, (sum, line) => sum + line.total);
}

final parkedSalesProvider =
    StateNotifierProvider<ParkedSalesController, List<ParkedSale>>((ref) {
      final database = ref.watch(appDatabaseProvider);
      return ParkedSalesController(database: database);
    });

class ParkedSalesController extends StateNotifier<List<ParkedSale>> {
  ParkedSalesController({required db.AppDatabase database})
    : _db = database,
      super(const []) {
    unawaited(_restoreFromDb());
  }

  final db.AppDatabase _db;
  final _uuid = const Uuid();

  Future<void> _restoreFromDb() async {
    try {
      final rows = await _db.getNamedParkedSales();
      final restored = <ParkedSale>[];
      for (final row in rows) {
        final sale = await _rowToParkedSale(row);
        if (sale != null) restored.add(sale);
      }
      state = restored;
    } catch (e, st) {
      debugPrint('[ParkedSales] Failed to restore: $e\n$st');
    }
  }

  Future<ParkedSale?> _rowToParkedSale(db.ParkedSale row) async {
    try {
      final List<dynamic> decoded = jsonDecode(row.linesJson);
      final lines = decoded
          .map(
            (json) => CartLine(
              id: json['id'] as String,
              title: json['title'] as String,
              price: (json['price'] as num).toDouble(),
              itemId: json['itemId'] as String?,
              serviceId: json['serviceId'] as String?,
              variant: json['variant'] as String?,
              availableStock: json['availableStock'] as int?,
              quantity: json['quantity'] as int,
            ),
          )
          .toList();
      db.Customer? customer;
      if (row.customerId != null) {
        customer = await _db.getCustomerById(row.customerId!);
      }
      return ParkedSale(
        id: row.id,
        label: row.label ?? 'Parked sale',
        createdAt: row.createdAt,
        lines: lines,
        notes: row.notes,
        customer: customer,
      );
    } catch (e, st) {
      debugPrint('[ParkedSales] Skipping corrupt row ${row.id}: $e\n$st');
      return null;
    }
  }

  Future<String> parkSale(CartState cart, {String? label}) async {
    if (cart.lines.isEmpty) return '';
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final sale = ParkedSale(
      id: id,
      label: label?.isEmpty ?? true ? 'Parked sale' : label!,
      createdAt: now,
      lines: List<CartLine>.from(cart.lines),
      notes: cart.notes,
      customer: cart.customer,
    );
    state = [sale, ...state];
    await _persistSale(sale);
    return id;
  }

  Future<void> _persistSale(ParkedSale sale) async {
    try {
      final linesJson = jsonEncode(
        sale.lines
            .map(
              (l) => {
                'id': l.id,
                'title': l.title,
                'price': l.price,
                'itemId': l.itemId,
                'serviceId': l.serviceId,
                'variant': l.variant,
                'availableStock': l.availableStock,
                'quantity': l.quantity,
              },
            )
            .toList(),
      );
      await _db.saveNamedParkedSale(
        id: sale.id,
        label: sale.label,
        linesJson: linesJson,
        notes: sale.notes,
        customerId: sale.customer?.id,
        createdAt: sale.createdAt,
        updatedAt: sale.createdAt,
      );
    } catch (e, st) {
      debugPrint('[ParkedSales] Failed to persist ${sale.id}: $e\n$st');
    }
  }

  CartState? resume(String id) {
    final idx = state.indexWhere((s) => s.id == id);
    if (idx == -1) return null;
    final sale = state[idx];
    state = [...state]..removeAt(idx);
    unawaited(_db.deleteNamedParkedSale(id));
    return CartState(
      lines: sale.lines,
      notes: sale.notes,
      customer: sale.customer,
    );
  }

  void clear(String id) {
    state = state.where((s) => s.id != id).toList();
    unawaited(_db.deleteNamedParkedSale(id));
  }
}