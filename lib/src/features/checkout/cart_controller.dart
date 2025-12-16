import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/app_providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';

final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) {
    final db = ref.watch(appDatabaseProvider);
    final sync = ref.watch(syncServiceProvider);
    return CartController(db: db, syncService: sync);
  },
);

class CartState {
  const CartState({this.lines = const [], this.notes, this.customer});
  final List<CartLine> lines;
  final String? notes;
  final Customer? customer;

  double get subtotal => lines.fold(0, (sum, line) => sum + line.total);

  CartState copyWith({
    List<CartLine>? lines,
    String? notes,
    Customer? customer,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
      customer: customer ?? this.customer,
    );
  }
}

class CartLine {
  CartLine({
    required this.id,
    required this.title,
    required this.price,
    this.itemId,
    this.serviceId,
    this.quantity = 1,
  });

  final String id;
  final String title;
  final double price;
  final String? itemId;
  final String? serviceId;
  final int quantity;

  double get total => price * quantity;

  CartLine copyWith({int? quantity, double? price}) {
    return CartLine(
      id: id,
      title: title,
      price: price ?? this.price,
      itemId: itemId,
      serviceId: serviceId,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController({required AppDatabase db, required SyncService syncService})
    : _db = db,
      _syncService = syncService,
      super(const CartState());

  final AppDatabase _db;
  final SyncService _syncService;
  final _uuid = const Uuid();

  void addItem({required Item item, int quantity = 1}) {
    final existingIndex = state.lines.indexWhere(
      (line) => line.itemId == item.id,
    );
    if (existingIndex != -1) {
      final updated = List<CartLine>.from(state.lines);
      final current = updated[existingIndex];
      updated[existingIndex] = current.copyWith(
        quantity: current.quantity + quantity,
      );
      state = state.copyWith(lines: updated);
    } else {
      state = state.copyWith(
        lines: [
          ...state.lines,
          CartLine(
            id: _uuid.v4(),
            title: item.name,
            price: item.price,
            itemId: item.id,
            quantity: quantity,
          ),
        ],
      );
    }
  }

  void addService({required Service service, int quantity = 1}) {
    state = state.copyWith(
      lines: [
        ...state.lines,
        CartLine(
          id: _uuid.v4(),
          title: service.title,
          price: service.price,
          serviceId: service.id,
          quantity: quantity,
        ),
      ],
    );
  }

  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeLine(id);
      return;
    }
    state = state.copyWith(
      lines: state.lines
          .map(
            (line) => line.id == id ? line.copyWith(quantity: quantity) : line,
          )
          .toList(),
    );
  }

  void updatePrice(String id, double price) {
    if (price <= 0) return;
    state = state.copyWith(
      lines: state.lines
          .map((l) => l.id == id ? l.copyWith(price: price) : l)
          .toList(),
    );
  }

  void removeLine(String id) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.id != id).toList(),
    );
  }

  void clear() => state = const CartState();

  CartState snapshot() => CartState(
    lines: List<CartLine>.from(state.lines),
    notes: state.notes,
    customer: state.customer,
  );

  void apply(CartState next) => state = next;

  void setCustomer(Customer? customer) =>
      state = state.copyWith(customer: customer);

  Future<String> checkout({
    required List<CheckoutPayment> payments,
    String? notes,
    Customer? customer,
  }) async {
    final resolvedCustomer = customer ?? state.customer;
    if (payments.isEmpty) {
      throw ArgumentError.value(
        payments,
        'payments',
        'At least one payment is required.',
      );
    }
    final total = state.subtotal;
    final paid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    if ((paid - total).abs() > 0.01) {
      throw ArgumentError(
        'Payments must add up to UGX ${total.toStringAsFixed(0)} (got ${paid.toStringAsFixed(0)}).',
      );
    }
    if (payments.any((p) => p.amount <= 0)) {
      throw ArgumentError('Payment amounts must be greater than 0.');
    }

    final transactionId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final occurredAt = DateTime.now().toUtc();

    final lines = state.lines
        .map(
          (line) => LedgerLinesCompanion.insert(
            entryId: transactionId,
            itemId: Value(line.itemId),
            serviceId: Value(line.serviceId),
            title: line.title,
            quantity: line.quantity,
            unitPrice: line.price,
            lineTotal: line.total,
          ),
        )
        .toList();

    final paymentRows = payments
        .map(
          (p) => PaymentsCompanion.insert(
            entryId: transactionId,
            method: p.method,
            amount: p.amount,
            externalRef: Value(p.externalRef),
          ),
        )
        .toList();

    await _db.saveLedgerEntry(
      entry: LedgerEntriesCompanion.insert(
        id: Value(transactionId),
        idempotencyKey: idempotencyKey,
        type: 'sale',
        subtotal: Value(total),
        discount: const Value(0),
        tax: const Value(0),
        total: Value(total),
        note: Value(notes),
        staffId: const Value(null),
        outletId: const Value(null),
        customerId: Value(resolvedCustomer?.id),
        createdAt: Value(occurredAt),
      ),
      lines: lines,
      payments: paymentRows,
    );

    await _syncService.enqueue('ledger_push', {
      'entry_id': transactionId,
      'idempotency_key': idempotencyKey,
      'type': 'sale',
      'subtotal': total,
      'discount': 0,
      'tax': 0,
      'total': total,
      'note': notes,
      'occurred_at': occurredAt.toIso8601String(),
      'customer_id': resolvedCustomer?.id,
      'payments': payments
          .map(
            (p) => {
              'method': p.method,
              'amount': p.amount,
              if (p.externalRef != null) 'external_ref': p.externalRef,
            },
          )
          .toList(),
      'lines': state.lines
          .map(
            (e) => {
              'product_id': e.itemId,
              'service_id': e.serviceId,
              'name': e.title,
              'price': e.price,
              'quantity': e.quantity,
              'subtotal': e.total,
            },
          )
          .toList(),
    });

    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'checkout_complete',
          props: {
            'entry_id': transactionId,
            'total': total,
            'lines_count': state.lines.length,
            'has_customer': resolvedCustomer != null,
            'customer_id': resolvedCustomer?.id,
            'payment_methods': payments.map((p) => p.method).toList(),
          },
        ),
      );
    }

    clear();
    return transactionId;
  }
}

class CheckoutPayment {
  CheckoutPayment({
    required this.method,
    required this.amount,
    this.externalRef,
  });

  final String method;
  final double amount;
  final String? externalRef;
}
