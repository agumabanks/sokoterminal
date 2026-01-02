import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/app_providers.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';

final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) {
    final db = ref.watch(appDatabaseProvider);
    final sync = ref.watch(syncServiceProvider);
    final storage = ref.watch(secureStorageProvider);
    return CartController(db: db, syncService: sync, secureStorage: storage);
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
    this.variant,
    this.availableStock,
    this.quantity = 1,
  });

  final String id;
  final String title;
  final double price;
  final String? itemId;
  final String? serviceId;
  final String? variant;
  final int? availableStock;
  final int quantity;

  double get total => price * quantity;

  CartLine copyWith({int? quantity, double? price, int? availableStock}) {
    return CartLine(
      id: id,
      title: title,
      price: price ?? this.price,
      itemId: itemId,
      serviceId: serviceId,
      variant: variant,
      availableStock: availableStock ?? this.availableStock,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController({
    required AppDatabase db,
    required SyncService syncService,
    required SecureStorage secureStorage,
  })  : _db = db,
        _syncService = syncService,
        _storage = secureStorage,
        super(const CartState());

  final AppDatabase _db;
  final SyncService _syncService;
  final SecureStorage _storage;
  final _uuid = const Uuid();

  String? addItem({required Item item, int quantity = 1, int? availableStock}) {
    final enforceStock = item.stockEnabled;
    final maxQty = enforceStock ? (availableStock ?? item.stockQty) : null;
    if (maxQty != null && maxQty <= 0) {
      return 'Out of stock: ${item.name}';
    }
    final existingIndex = state.lines.indexWhere(
      (line) => line.itemId == item.id && (line.variant ?? '') == '',
    );
    if (existingIndex != -1) {
      final updated = List<CartLine>.from(state.lines);
      final current = updated[existingIndex];
      final requested = current.quantity + quantity;
      final nextQty = maxQty != null ? requested.clamp(0, maxQty) : requested;
      if (nextQty <= 0) {
        updated.removeAt(existingIndex);
        state = state.copyWith(lines: updated);
        return 'Out of stock: ${item.name}';
      }
      updated[existingIndex] = current.copyWith(
        quantity: nextQty,
        availableStock: maxQty ?? current.availableStock,
      );
      state = state.copyWith(lines: updated);
      if (maxQty != null && requested > maxQty) {
        return 'Only $maxQty in stock for ${item.name}';
      }
      return null;
    } else {
      final nextQty = maxQty != null ? quantity.clamp(0, maxQty) : quantity;
      if (nextQty <= 0) {
        return 'Out of stock: ${item.name}';
      }
      state = state.copyWith(
        lines: [
          ...state.lines,
          CartLine(
            id: _uuid.v4(),
            title: item.name,
            price: item.price,
            itemId: item.id,
            variant: '',
            availableStock: maxQty,
            quantity: nextQty,
          ),
        ],
      );
      if (maxQty != null && quantity > maxQty) {
        // This shouldn't happen given clamp above, but keep message defensive.
        return 'Only $maxQty in stock for ${item.name}';
      }
      return null;
    }
  }

  String? addItemVariant({
    required Item item,
    required String variant,
    required double price,
    int quantity = 1,
    int? availableStock,
  }) {
    final normalized = variant.trim();
    final enforceStock = item.stockEnabled;
    final maxQty = enforceStock ? (availableStock ?? 0) : null;
    if (maxQty != null && maxQty <= 0) {
      return 'Out of stock: ${item.name}${normalized.isEmpty ? '' : ' • $normalized'}';
    }
    final existingIndex = state.lines.indexWhere(
      (line) => line.itemId == item.id && (line.variant ?? '') == normalized,
    );
    if (existingIndex != -1) {
      final updated = List<CartLine>.from(state.lines);
      final current = updated[existingIndex];
      final requested = current.quantity + quantity;
      final nextQty = maxQty != null ? requested.clamp(0, maxQty) : requested;
      if (nextQty <= 0) {
        updated.removeAt(existingIndex);
        state = state.copyWith(lines: updated);
        return 'Out of stock: ${item.name}${normalized.isEmpty ? '' : ' • $normalized'}';
      }
      updated[existingIndex] = current.copyWith(
        quantity: nextQty,
        availableStock: maxQty ?? current.availableStock,
      );
      state = state.copyWith(lines: updated);
      if (maxQty != null && requested > maxQty) {
        return 'Only $maxQty in stock for ${item.name}${normalized.isEmpty ? '' : ' • $normalized'}';
      }
      return null;
    }
    final nextQty = maxQty != null ? quantity.clamp(0, maxQty) : quantity;
    if (nextQty <= 0) {
      return 'Out of stock: ${item.name}${normalized.isEmpty ? '' : ' • $normalized'}';
    }
    state = state.copyWith(
      lines: [
        ...state.lines,
        CartLine(
          id: _uuid.v4(),
          title: normalized.isEmpty ? item.name : '${item.name} • $normalized',
          price: price,
          itemId: item.id,
          variant: normalized,
          availableStock: maxQty,
          quantity: nextQty,
        ),
      ],
    );
    if (maxQty != null && quantity > maxQty) {
      return 'Only $maxQty in stock for ${item.name}${normalized.isEmpty ? '' : ' • $normalized'}';
    }
    return null;
  }

  /// Add a service to the cart. If variant is provided, uses variant price.
  /// Deduplicates: same serviceId + same variant increments quantity.
  void addService({
    required Service service,
    String? variant,
    double? variantPrice,
    int quantity = 1,
  }) {
    final normalized = (variant ?? '').trim();
    final effectivePrice = variantPrice ?? service.price;
    final displayTitle = normalized.isEmpty
        ? service.title
        : '${service.title} • $normalized';

    // Check for existing line with same service + variant
    final existingIndex = state.lines.indexWhere(
      (line) =>
          line.serviceId == service.id &&
          (line.variant ?? '') == normalized,
    );

    if (existingIndex != -1) {
      // Increment quantity on existing line
      final updated = List<CartLine>.from(state.lines);
      final current = updated[existingIndex];
      updated[existingIndex] = current.copyWith(
        quantity: current.quantity + quantity,
      );
      state = state.copyWith(lines: updated);
      return;
    }

    // Add new line
    state = state.copyWith(
      lines: [
        ...state.lines,
        CartLine(
          id: _uuid.v4(),
          title: displayTitle,
          price: effectivePrice,
          serviceId: service.id,
          variant: normalized.isEmpty ? null : normalized,
          quantity: quantity,
        ),
      ],
    );
  }

  String? updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeLine(id);
      return null;
    }
    CartLine? line;
    for (final l in state.lines) {
      if (l.id == id) {
        line = l;
        break;
      }
    }
    final maxQty = line?.availableStock;
    final nextQty = maxQty != null ? quantity.clamp(0, maxQty) : quantity;
    if (nextQty <= 0) {
      removeLine(id);
      return 'Out of stock';
    }
    state = state.copyWith(
      lines: state.lines
          .map(
            (line) =>
                line.id == id ? line.copyWith(quantity: nextQty) : line,
          )
          .toList(),
    );
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'checkout_cart_qty_changed',
          props: {
            'line_id': id,
            'quantity': nextQty,
            'lines_count': state.lines.length,
            'subtotal': state.subtotal,
          },
        ),
      );
    }
    if (maxQty != null && quantity > maxQty) {
      return 'Only $maxQty in stock';
    }
    return null;
  }

  Future<String?> updateQuantityWithFreshStock(String id, int quantity) async {
    if (quantity <= 0) {
      removeLine(id);
      return null;
    }

    CartLine? current;
    for (final l in state.lines) {
      if (l.id == id) {
        current = l;
        break;
      }
    }
    if (current == null) return null;

    int? maxQty = current.availableStock;
    final itemId = current.itemId;
    if (itemId != null && itemId.isNotEmpty) {
      final item = await _db.getItemById(itemId);
      if (item != null && item.stockEnabled) {
        final variant = (current.variant ?? '').trim();
        final stockRow = await (_db.select(_db.itemStocks)
              ..where(
                (t) =>
                    t.itemId.equals(itemId) & t.variant.equals(variant),
              ))
            .getSingleOrNull();
        if (stockRow != null) {
          maxQty = stockRow.stockQty;
        } else {
          maxQty = variant.isEmpty ? item.stockQty : 0;
        }
      } else {
        maxQty = null;
      }
    }

    final nextQty = maxQty != null ? quantity.clamp(0, maxQty) : quantity;
    if (nextQty <= 0) {
      removeLine(id);
      return maxQty == null ? null : 'Out of stock';
    }

    state = state.copyWith(
      lines: state.lines
          .map(
            (line) => line.id == id
                ? line.copyWith(quantity: nextQty, availableStock: maxQty)
                : line,
          )
          .toList(),
    );

    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'checkout_cart_qty_changed',
          props: {
            'line_id': id,
            'quantity': nextQty,
            'lines_count': state.lines.length,
            'subtotal': state.subtotal,
          },
        ),
      );
    }

    if (maxQty != null && quantity > maxQty) {
      return 'Only $maxQty in stock';
    }
    return null;
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
    var resolvedCustomer = customer ?? state.customer;
    
    // Auto-assign walk-in customer if cart has services but no customer
    final hasServiceLine = state.lines.any((l) => l.serviceId != null && l.serviceId!.isNotEmpty);
    if (hasServiceLine && resolvedCustomer == null) {
      resolvedCustomer = await _db.getOrCreateWalkInCustomerForDate(DateTime.now());
    }
    
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

    final stockShortages = <String>[];
    for (final line in state.lines) {
      final itemId = line.itemId;
      if (itemId == null || itemId.isEmpty) continue;
      final item = await _db.getItemById(itemId);
      if (item == null) continue;
      if (!item.stockEnabled) continue;

      final variant = (line.variant ?? '').trim();
      var available = variant.isEmpty ? item.stockQty : 0;
      final stockRow = await (_db.select(_db.itemStocks)
            ..where((t) => t.itemId.equals(itemId) & t.variant.equals(variant)))
          .getSingleOrNull();
      if (stockRow != null) {
        available = stockRow.stockQty;
      }
      if (available < line.quantity) {
        final label = variant.isEmpty ? item.name : '${item.name} • $variant';
        stockShortages.add(
          '$label (stock $available, requested ${line.quantity})',
        );
      }
    }
    if (stockShortages.isNotEmpty) {
      throw StateError(
        'Insufficient stock: ${stockShortages.join(', ')}',
      );
    }

    final transactionId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final occurredAt = DateTime.now().toUtc();

    final outletId = (await _db.getPrimaryOutlet())?.id;
    final staffIdInt = await _storage.readPosSessionStaffId();
    final staffId = staffIdInt?.toString();
    final staffName = await _storage.readPosSessionStaffName();
    if (staffId != null && staffName != null && staffName.trim().isNotEmpty) {
      await _db.upsertStaff(
        StaffCompanion.insert(
          id: Value(staffId),
          name: staffName.trim(),
          roleId: const Value.absent(),
          active: const Value(true),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }

    final lines = state.lines
        .map(
          (line) => LedgerLinesCompanion.insert(
            entryId: transactionId,
            itemId: Value(line.itemId),
            serviceId: Value(line.serviceId),
            title: line.title,
            variant: Value(line.variant),
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

    // Get next sequential receipt number
    final receiptNumber = await _db.getNextReceiptNumber();

    await _db.saveLedgerEntry(
      entry: LedgerEntriesCompanion.insert(
        id: Value(transactionId),
        receiptNumber: Value(receiptNumber),
        idempotencyKey: idempotencyKey,
        type: 'sale',
        subtotal: Value(total),
        discount: const Value(0),
        tax: const Value(0),
        total: Value(total),
        note: Value(notes),
        staffId: Value(staffId),
        outletId: Value(outletId),
        customerId: Value(resolvedCustomer?.id),
        createdAt: Value(occurredAt),
      ),
      lines: lines,
      payments: paymentRows,
    );

    // Update local stock immediately (offline-first). Server reconciliation will
    // happen via delta pull; this keeps POS inventory accurate while offline.
    for (final line in state.lines) {
      final itemId = line.itemId;
      if (itemId == null || itemId.isEmpty) continue;
      await _db.recordInventoryMovement(
        itemId: itemId,
        delta: -line.quantity,
        note: 'sale',
        variant: line.variant ?? '',
      );
    }

    // Create local booking records for service lines (unified booking history)
    for (final line in state.lines) {
      final serviceId = line.serviceId;
      if (serviceId == null || serviceId.isEmpty) continue;
      await _db.createLocalBooking(
        serviceId: serviceId,
        variantName: line.variant,
        customerId: resolvedCustomer?.id,
        ledgerEntryId: transactionId,
        price: line.total,
        completedAt: occurredAt,
      );
    }

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
              if (e.variant != null && e.variant!.trim().isNotEmpty)
                'variation': e.variant,
              'price': e.price,
              'quantity': e.quantity,
              'subtotal': e.total,
            },
          )
          .toList(),
    });
    unawaited(_syncService.syncNow());

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
