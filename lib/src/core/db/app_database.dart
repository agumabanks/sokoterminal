import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

const _uuid = Uuid();

class Items extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  RealColumn get cost => real().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  BoolColumn get stockEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get publishedOnline =>
      boolean().withDefault(const Constant(false))();
  // Marketplace fields
  TextColumn get categoryId => text().nullable()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get brandId => text().nullable()();
  TextColumn get brandName => text().nullable()();
  TextColumn get unit => text().nullable()(); // pc, kg, set, etc.
  RealColumn get weight => real().nullable()(); // in kg
  IntColumn get minPurchaseQty => integer().withDefault(const Constant(1))();
  TextColumn get tags => text().nullable()(); // comma-separated
  TextColumn get description => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get thumbnailUploadId => integer().nullable()();
  TextColumn get galleryUrls => text().nullable()(); // JSON array
  TextColumn get galleryUploadIds => text().nullable()(); // JSON array of ints
  RealColumn get discount => real().nullable()();
  TextColumn get discountType => text().nullable()(); // flat, percent
  IntColumn get shippingDays => integer().nullable()();
  RealColumn get shippingFee => real().nullable()();
  BoolColumn get refundable => boolean().withDefault(const Constant(false))();
  BoolColumn get cashOnDelivery => boolean().withDefault(const Constant(true))();
  IntColumn get lowStockWarning => integer().nullable()();
  // Meta
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ItemStocks extends Table {
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get variant => text()(); // '' for simple products, or 'Red-L' etc
  IntColumn get remoteStockId => integer().nullable()();
  RealColumn get price => real()();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  TextColumn get sku => text().nullable()();
  IntColumn get imageUploadId => integer().nullable()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>>? get primaryKey => {itemId, variant};
}

class Services extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  RealColumn get price => real()();
  IntColumn get durationMinutes => integer().nullable()();
  BoolColumn get publishedOnline =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().nullable()();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get remoteId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Suppliers extends Table {
  IntColumn get id => integer()(); // remote supplier id (server)
  TextColumn get name => text()();
  TextColumn get contactName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get status => text().withDefault(const Constant('paid'))();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  BoolColumn get isOffline => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class TransactionLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId => text().nullable().references(Items, #id)();
  TextColumn get serviceId => text().nullable().references(Services, #id)();
  TextColumn get title => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get price => real()();
  RealColumn get total => real()();
}

class Receipts extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get receiptNumber => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class SyncOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opType => text()(); // e.g., item_create, transaction_push
  TextColumn get payload => text()(); // JSON payload
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get lastTriedAt => dateTime().nullable()();
}

class PrintJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobType => text()(); // receipt
  TextColumn get referenceId => text()(); // ledger entry id
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, printed, cancelled
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get lastTriedAt => dateTime().nullable()();
  DateTimeColumn get printedAt => dateTime().nullable()();
}

class SyncCursors extends Table {
  TextColumn get key => text()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();
  @override
  Set<Column<Object>>? get primaryKey => {key};
}

class CachedOrders extends Table {
  IntColumn get orderId => integer()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {orderId};
}

class CachedServiceBookings extends Table {
  IntColumn get bookingId => integer()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {bookingId};
}

class InventoryLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get delta => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get canRefund => boolean().withDefault(const Constant(false))();
  BoolColumn get canVoid => boolean().withDefault(const Constant(false))();
  BoolColumn get canPriceOverride =>
      boolean().withDefault(const Constant(false))();
}

class Staff extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  TextColumn get pin => text().nullable()();
  IntColumn get roleId => integer().nullable().references(Roles, #id)();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Outlets extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class LedgerEntries extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get receiptNumber => integer().nullable()(); // Sequential receipt number
  TextColumn get idempotencyKey => text()();
  TextColumn get type => text()(); // sale, refund, void, adjustment
  TextColumn get originalEntryId => text().nullable()(); // For refunds: links to original sale
  TextColumn get outletId => text().nullable().references(Outlets, #id)();
  TextColumn get staffId => text().nullable().references(Staff, #id)();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteAck => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class LedgerLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId =>
      text().references(LedgerEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId => text().nullable().references(Items, #id)();
  TextColumn get serviceId => text().nullable().references(Services, #id)();
  TextColumn get title => text()();
  TextColumn get variant => text().nullable()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get lineTotal => real()();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId =>
      text().references(LedgerEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get method => text()();
  RealColumn get amount => real()();
  TextColumn get externalRef => text().nullable()();
}

class CashMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get outletId => text().nullable().references(Outlets, #id)();
  TextColumn get staffId => text().nullable().references(Staff, #id)();
  TextColumn get type => text()(); // open, close, float, withdrawal
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class Shifts extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get outletId => text().nullable().references(Outlets, #id)();
  TextColumn get staffId => text().nullable().references(Staff, #id)();
  DateTimeColumn get openedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get closedAt => dateTime().nullable()();
  RealColumn get openingFloat => real().withDefault(const Constant(0))();
  RealColumn get closingFloat => real().withDefault(const Constant(0))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actorStaffId => text().nullable().references(Staff, #id)();
  TextColumn get action => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class ServiceVariants extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get serviceId => text().references(Services, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get price => real()();
  TextColumn get unit => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Quotations extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get number => text()();
  DateTimeColumn get date => dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get validUntil => dateTime().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class QuotationLines extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get quotationId => text().references(Quotations, #id, onDelete: KeyAction.cascade)();
  TextColumn get description => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ReceiptTemplates extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text().withDefault(const Constant('Default'))();
  TextColumn get style => text().withDefault(const Constant('minimal'))();
  TextColumn get headerText => text().nullable()();
  TextColumn get footerText => text().nullable()();
  BoolColumn get showLogo => boolean().withDefault(const Constant(true))();
  BoolColumn get showQr => boolean().withDefault(const Constant(true))();
  TextColumn get colorHex => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class QuotationTemplates extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text().withDefault(const Constant('Default'))();
  TextColumn get style => text().withDefault(const Constant('minimal'))();
  TextColumn get headerText => text().nullable()();
  TextColumn get footerText => text().nullable()();
  BoolColumn get showLogo => boolean().withDefault(const Constant(true))();
  BoolColumn get showQr => boolean().withDefault(const Constant(true))();
  TextColumn get colorHex => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Items,
    ItemStocks,
    Services,
    Customers,
    Suppliers,
    Transactions,
    TransactionLines,
    Receipts,
    SyncOps,
    PrintJobs,
    SyncCursors,
    CachedOrders,
    CachedServiceBookings,
    InventoryLogs,
    Roles,
    Staff,
    Outlets,
    LedgerEntries,
    LedgerLines,
    Payments,
    CashMovements,
    Shifts,
    AuditLogs,
    ServiceVariants,
    Quotations,
    QuotationLines,
    ReceiptTemplates,
    QuotationTemplates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.executor);

  static Future<AppDatabase> make() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'seller_terminal.db'));
    return AppDatabase._internal(NativeDatabase.createInBackground(file));
  }

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(roles);
        await migrator.createTable(staff);
        await migrator.createTable(outlets);
        await migrator.createTable(ledgerEntries);
        await migrator.createTable(ledgerLines);
        await migrator.createTable(payments);
        await migrator.createTable(cashMovements);
        await migrator.createTable(shifts);
        await migrator.createTable(auditLogs);
      }
      if (from < 3) {
        await migrator.createTable(syncCursors);
      }
      if (from < 4) {
        await migrator.createTable(cachedOrders);
      }
      if (from < 5) {
        await migrator.addColumn(syncOps, syncOps.lastError);
        await migrator.addColumn(ledgerEntries, ledgerEntries.customerId);
        await migrator.createTable(printJobs);
      }
      if (from < 6) {
        await migrator.addColumn(services, services.category);
      }
      if (from < 7) {
        await migrator.createTable(serviceVariants);
        await migrator.createTable(quotations);
        await migrator.createTable(quotationLines);
        await migrator.createTable(receiptTemplates);
      }
      if (from < 8) {
        await migrator.addColumn(items, items.imageUrl);
      }
      if (from < 9) {
        // Add remoteId mapping columns
        await migrator.addColumn(items, items.remoteId);
        await migrator.addColumn(services, services.remoteId);
        await migrator.addColumn(customers, customers.remoteId);
        await migrator.addColumn(customers, customers.synced);
        // Add receipt template alignment columns
        await migrator.addColumn(receiptTemplates, receiptTemplates.name);
        await migrator.addColumn(receiptTemplates, receiptTemplates.style);
        await migrator.addColumn(receiptTemplates, receiptTemplates.isActive);
      }
      if (from < 10) {
        await migrator.addColumn(ledgerEntries, ledgerEntries.originalEntryId);
      }
      if (from < 11) {
        await migrator.createTable(quotationTemplates);
      }
      if (from < 12) {
        await migrator.addColumn(ledgerEntries, ledgerEntries.receiptNumber);
      }
      if (from < 13) {
        // Marketplace fields for Items
        await migrator.addColumn(items, items.categoryId);
        await migrator.addColumn(items, items.categoryName);
        await migrator.addColumn(items, items.brandId);
        await migrator.addColumn(items, items.brandName);
        await migrator.addColumn(items, items.unit);
        await migrator.addColumn(items, items.weight);
        await migrator.addColumn(items, items.minPurchaseQty);
        await migrator.addColumn(items, items.tags);
        await migrator.addColumn(items, items.description);
        await migrator.addColumn(items, items.thumbnailUrl);
        await migrator.addColumn(items, items.galleryUrls);
        await migrator.addColumn(items, items.discount);
        await migrator.addColumn(items, items.discountType);
        await migrator.addColumn(items, items.shippingDays);
        await migrator.addColumn(items, items.shippingFee);
        await migrator.addColumn(items, items.refundable);
        await migrator.addColumn(items, items.cashOnDelivery);
        await migrator.addColumn(items, items.lowStockWarning);
      }
      if (from < 14) {
        await migrator.addColumn(items, items.thumbnailUploadId);
        await migrator.addColumn(items, items.galleryUploadIds);
      }
      if (from < 15) {
        await migrator.createTable(itemStocks);
      }
      if (from < 16) {
        await migrator.addColumn(ledgerLines, ledgerLines.variant);
      }
      if (from < 17) {
        await migrator.createTable(cachedServiceBookings);
      }
      if (from < 18) {
        await migrator.createTable(suppliers);
      }
    },
  );

  // Items
  Future<List<Item>> getAllItems() => select(items).get();
  Future<Item?> getItemById(String id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<Item?> getItemByRemoteId(int remoteId) =>
      (select(items)..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();
  Stream<List<Item>> watchItems() =>
      (select(items)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  Future<void> upsertItem(ItemsCompanion companion) async {
    await into(items).insertOnConflictUpdate(companion);
  }

  Future<void> updateItemFields(String id, ItemsCompanion companion) async {
    await (update(items)..where((tbl) => tbl.id.equals(id))).write(companion);
  }

  Future<void> markItemSynced(String id) async {
    await (update(items)..where((tbl) => tbl.id.equals(id))).write(
      ItemsCompanion(
        synced: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markItemSyncedWithRemoteId(String id, int remoteId) async {
    await (update(items)..where((tbl) => tbl.id.equals(id))).write(
      ItemsCompanion(
        remoteId: Value(remoteId),
        synced: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // Item Stocks (variants)
  Stream<List<ItemStock>> watchItemStocksForItem(String itemId) => (select(
        itemStocks,
      )..where((t) => t.itemId.equals(itemId))).watch();

  Future<List<ItemStock>> getItemStocksForItem(String itemId) => (select(
        itemStocks,
      )..where((t) => t.itemId.equals(itemId))).get();

  Future<void> upsertItemStock(ItemStocksCompanion companion) async {
    await into(itemStocks).insertOnConflictUpdate(companion);
  }

  Future<void> deleteItemStocksNotIn(String itemId, List<String> variants) async {
    if (variants.isEmpty) {
      await (delete(itemStocks)..where((t) => t.itemId.equals(itemId))).go();
      return;
    }
    await (delete(itemStocks)
          ..where((t) => t.itemId.equals(itemId) & t.variant.isNotIn(variants)))
        .go();
  }

  // Services
  Stream<List<Service>> watchServices() => (select(
    services,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  Future<Service?> getServiceById(String id) =>
      (select(services)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<Service?> getServiceByRemoteId(int remoteId) => (select(services)
        ..where((t) => t.remoteId.equals(remoteId)))
      .getSingleOrNull();
  Future<void> upsertService(ServicesCompanion companion) async {
    await into(services).insertOnConflictUpdate(companion);
  }

  Future<void> markServiceSynced(String id) async {
    await (update(services)..where((tbl) => tbl.id.equals(id))).write(
      ServicesCompanion(
        synced: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markServiceSyncedWithRemoteId(String id, int remoteId) async {
    await (update(services)..where((tbl) => tbl.id.equals(id))).write(
      ServicesCompanion(
        remoteId: Value(remoteId),
        synced: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // Service Variants
  Stream<List<ServiceVariant>> watchServiceVariants(String serviceId) =>
      (select(serviceVariants)..where((tbl) => tbl.serviceId.equals(serviceId))
        ..orderBy([(t) => OrderingTerm.asc(t.price)]))
      .watch();
  
  Future<void> upsertServiceVariant(ServiceVariantsCompanion companion) async {
    await into(serviceVariants).insertOnConflictUpdate(companion);
  }

  Future<void> deleteServiceVariant(String id) async {
    await (delete(serviceVariants)..where((t) => t.id.equals(id))).go();
  }

  Future<void> unsetDefaultVariants(String serviceId) async {
    await (update(serviceVariants)..where((t) => t.serviceId.equals(serviceId)))
        .write(const ServiceVariantsCompanion(isDefault: Value(false)));
  }

  // Quotations
  Future<void> saveQuotation({
    required QuotationsCompanion header,
    required List<QuotationLinesCompanion> lines,
  }) async {
    await transaction(() async {
      await into(quotations).insert(header);
      for (final line in lines) {
        await into(quotationLines).insert(line);
      }
    });
  }

  Stream<List<QuotationWithCustomer>> watchQuotationsWithCustomer() {
    final query = select(quotations).join([
      leftOuterJoin(customers, customers.id.equalsExp(quotations.customerId)),
    ])
      ..orderBy([OrderingTerm.desc(quotations.date)]);

    return query.watch().map((rows) {
      return rows
          .map(
            (row) => QuotationWithCustomer(
              quotation: row.readTable(quotations),
              customer: row.readTableOrNull(customers),
            ),
          )
          .toList();
    });
  }

  Future<List<QuotationLine>> getQuotationLinesByQuotationId(String quotationId) {
    return (select(quotationLines)
          ..where((t) => t.quotationId.equals(quotationId)))
        .get();
  }

  Future<void> upsertQuotationWithLines({
    required String quotationId,
    required QuotationsCompanion header,
    required List<QuotationLinesCompanion> lines,
  }) async {
    await transaction(() async {
      await into(quotations).insertOnConflictUpdate(header);
      await (delete(quotationLines)
            ..where((t) => t.quotationId.equals(quotationId)))
          .go();
      for (final line in lines) {
        await into(quotationLines).insert(line);
      }
    });
  }

  // Receipt Templates
  Future<void> upsertReceiptTemplate(ReceiptTemplatesCompanion companion) async {
    await into(receiptTemplates).insertOnConflictUpdate(companion);
  }

  Future<ReceiptTemplate?> getLatestReceiptTemplate() async {
    // First try to get the active template
    final active = await (select(receiptTemplates)
          ..where((t) => t.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    if (active != null) return active;
    
    // Fallback to most recent if none active
    return (select(receiptTemplates)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  // Customers
  Future<Customer?> getCustomerByRemoteId(String remoteId) => (select(customers)
        ..where((t) => t.remoteId.equals(remoteId)))
      .getSingleOrNull();

  Future<void> upsertCustomer(CustomersCompanion companion) async {
    await into(customers).insertOnConflictUpdate(companion);
  }

  Stream<List<Customer>> watchCustomers() => (select(
    customers,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  // Suppliers
  Stream<List<Supplier>> watchSuppliers({bool activeOnly = true}) {
    final q = select(suppliers)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (activeOnly) {
      q.where((t) => t.active.equals(true));
    }
    return q.watch();
  }

  Future<void> upsertSupplier(SuppliersCompanion companion) async {
    await into(suppliers).insertOnConflictUpdate(companion);
  }

  // Transactions and lines
  Future<void> saveTransaction({
    required TransactionsCompanion header,
    required List<TransactionLinesCompanion> lines,
    ReceiptsCompanion? receipt,
  }) async {
    await transaction(() async {
      await into(transactions).insert(header);
      for (final line in lines) {
        await into(transactionLines).insert(line);
      }
      if (receipt != null) {
        await into(receipts).insert(receipt);
      }
    });
  }

  Stream<List<Transaction>> watchTransactions() => (select(
    transactions,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<void> markTransactionSynced(String id) async {
    await (update(transactions)..where((tbl) => tbl.id.equals(id))).write(
      TransactionsCompanion(synced: const Value(true)),
    );
  }

  Future<List<TransactionWithLines>> fetchTransactionWithLines(
    String id,
  ) async {
    final header = await (select(
      transactions,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    final itemsLines = await (select(
      transactionLines,
    )..where((tbl) => tbl.transactionId.equals(id))).get();
    return [TransactionWithLines(header, itemsLines)];
  }

  // Roles & Staff
  Future<void> upsertRole(RolesCompanion companion) async {
    await into(roles).insertOnConflictUpdate(companion);
  }

  Future<void> upsertStaff(StaffCompanion companion) async {
    await into(staff).insertOnConflictUpdate(companion);
  }

  Future<void> upsertOutlet(OutletsCompanion companion) async {
    await into(outlets).insertOnConflictUpdate(companion);
  }

  Future<Outlet?> getOutletById(String id) async {
    return (select(outlets)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Outlet?> getPrimaryOutlet() async {
    return (select(outlets)
          ..where((tbl) => tbl.active.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  // Ledger
  /// Get the next sequential receipt number
  Future<int> getNextReceiptNumber() async {
    final maxQuery = selectOnly(ledgerEntries)
      ..addColumns([ledgerEntries.receiptNumber.max()]);
    final result = await maxQuery.getSingleOrNull();
    final maxNum = result?.read(ledgerEntries.receiptNumber.max()) ?? 0;
    return maxNum + 1;
  }
  Future<void> saveLedgerEntry({
    required LedgerEntriesCompanion entry,
    required List<LedgerLinesCompanion> lines,
    required List<PaymentsCompanion> payments,
  }) async {
    await transaction(() async {
      await into(ledgerEntries).insert(entry);
      for (final line in lines) {
        await into(ledgerLines).insert(line);
      }
      for (final pay in payments) {
        await into(this.payments).insert(pay);
      }
    });
  }

  Future<void> markLedgerSynced(String id, String ack) async {
    await (update(ledgerEntries)..where((tbl) => tbl.id.equals(id))).write(
      LedgerEntriesCompanion(synced: const Value(true), remoteAck: Value(ack)),
    );
  }

  Stream<List<LedgerEntry>> watchLedgerEntries() => (select(
    ledgerEntries,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  /// Watch ledger entries since a given date (or all if null)
  Stream<List<LedgerEntry>> watchLedgerEntriesSince(DateTime? since) {
    final query = select(ledgerEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (since != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(since));
    }
    return query.watch();
  }

  Future<LedgerEntryBundle?> fetchLedgerEntryBundle(String id) async {
    final entry = await (select(
      ledgerEntries,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (entry == null) return null;
    final lines = await (select(
      ledgerLines,
    )..where((tbl) => tbl.entryId.equals(id))).get();
    final payments = await (select(
      this.payments,
    )..where((tbl) => tbl.entryId.equals(id))).get();
    return LedgerEntryBundle(entry: entry, lines: lines, payments: payments);
  }

  Future<List<LedgerEntry>> pendingLedgerEntries() =>
      (select(ledgerEntries)..where((tbl) => tbl.synced.equals(false))).get();

  Future<void> upsertLedgerEntryFromSync({
    required LedgerEntriesCompanion entry,
    required List<LedgerLinesCompanion> lines,
    required List<PaymentsCompanion> payments,
  }) async {
    await transaction(() async {
      await into(ledgerEntries).insertOnConflictUpdate(entry);
      // Replace lines and payments
      await (delete(ledgerLines)..where((t) => t.entryId.equals(entry.id.value))).go();
      await (delete(this.payments)..where((t) => t.entryId.equals(entry.id.value))).go();

      for (final line in lines) {
        await into(ledgerLines).insert(line);
      }
      for (final pay in payments) {
        await into(this.payments).insert(pay);
      }
    });
  }

  // Sync
  Future<int> enqueueSync(String type, String payloadJson) async {
    return into(
      syncOps,
    ).insert(SyncOpsCompanion.insert(opType: type, payload: payloadJson));
  }

  Future<List<SyncOp>> pendingSyncOps() =>
      (select(syncOps)
            ..where((tbl) => tbl.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<List<SyncOp>> blockedSyncOps() =>
      (select(syncOps)
            ..where((tbl) => tbl.status.equals('blocked'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<void> markSynced(int id) async {
    final now = DateTime.now().toUtc();
    await (update(syncOps)..where((tbl) => tbl.id.equals(id))).write(
      SyncOpsCompanion(
        status: const Value('synced'),
        lastTriedAt: Value(now),
        lastError: const Value(null),
      ),
    );
  }

  Future<void> markSyncFailed(
    int id, {
    required int retryCount,
    String? lastError,
  }) async {
    final now = DateTime.now().toUtc();
    await (update(syncOps)..where((tbl) => tbl.id.equals(id))).write(
      SyncOpsCompanion(
        retryCount: Value(retryCount),
        lastTriedAt: Value(now),
        lastError: Value(lastError),
      ),
    );
  }

  Future<void> markSyncBlocked(
    int id, {
    required int retryCount,
    String? lastError,
  }) async {
    final now = DateTime.now().toUtc();
    await (update(syncOps)..where((tbl) => tbl.id.equals(id))).write(
      SyncOpsCompanion(
        status: const Value('blocked'),
        retryCount: Value(retryCount),
        lastTriedAt: Value(now),
        lastError: Value(lastError),
      ),
    );
  }

  Future<void> deleteSyncOp(int id) async {
    await (delete(syncOps)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setSyncOpPending(int id) async {
    await (update(syncOps)..where((t) => t.id.equals(id))).write(
      const SyncOpsCompanion(status: Value('pending')),
    );
  }

  Future<void> retrySyncOpNow(int id) async {
    await (update(syncOps)..where((t) => t.id.equals(id))).write(
      const SyncOpsCompanion(status: Value('pending'), lastTriedAt: Value(null)),
    );
  }

  Future<DateTime?> getLastPulledAt(String key) async {
    final row = await (select(
      syncCursors,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.lastPulledAt;
  }

  Future<void> setLastPulledAt(String key, DateTime timestamp) async {
    await into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(key: key, lastPulledAt: Value(timestamp)),
    );
  }

  Future<void> recordInventoryMovement({
    required String itemId,
    required int delta,
    String? note,
    String? variant,
  }) async {
    await transaction(() async {
      await into(inventoryLogs).insert(
        InventoryLogsCompanion.insert(
          itemId: itemId,
          delta: delta,
          note: Value(note),
        ),
      );

      final now = DateTime.now().toUtc();
      final item = await (select(
        items,
      )..where((tbl) => tbl.id.equals(itemId))).getSingle();
      final updatedQty = item.stockQty + delta;
      await (update(items)..where((tbl) => tbl.id.equals(itemId))).write(
        ItemsCompanion(
          stockQty: Value(updatedQty),
          updatedAt: Value(now),
        ),
      );

      if (variant != null) {
        final v = variant.trim();
        final row = await (select(itemStocks)
              ..where((t) => t.itemId.equals(itemId) & t.variant.equals(v)))
            .getSingleOrNull();
        if (row != null) {
          await (update(itemStocks)
                ..where((t) => t.itemId.equals(itemId) & t.variant.equals(v)))
              .write(
            ItemStocksCompanion(
              stockQty: Value(row.stockQty + delta),
              updatedAt: Value(now),
            ),
          );
        }
      }
    });
  }

  Future<void> recordAuditLog({
    String? actorStaffId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final logId = await into(auditLogs).insert(
      AuditLogsCompanion.insert(
        actorStaffId: Value(actorStaffId),
        action: action,
        payloadJson: jsonEncode(payload),
      ),
    );

    // Best-effort: enqueue audit log push for privileged actions.
    final key = 'audit_log_$logId';
    await enqueueSync(
      'audit_log_push',
      jsonEncode({
        'idempotency_key': key,
        'action': action,
        'payload': payload,
      }),
    );
  }

  // Items (safe delete: detach from immutable history)
  Future<void> deleteItemAndDetach(String itemId) async {
    await transaction(() async {
      await (update(transactionLines)
            ..where((tbl) => tbl.itemId.equals(itemId)))
          .write(const TransactionLinesCompanion(itemId: Value(null)));
      await (update(ledgerLines)..where((tbl) => tbl.itemId.equals(itemId)))
          .write(const LedgerLinesCompanion(itemId: Value(null)));
      await (delete(
        inventoryLogs,
      )..where((tbl) => tbl.itemId.equals(itemId))).go();
      await (delete(items)..where((tbl) => tbl.id.equals(itemId))).go();
    });
  }

  Future<void> deletePendingItemOps(String localItemId) async {
    final ops = await pendingSyncOps();
    for (final op in ops) {
      if (op.opType != 'item_create' &&
          op.opType != 'item_update' &&
          op.opType != 'stock_adjust') {
        continue;
      }
      try {
        final payload = jsonDecode(op.payload);
        if (payload is Map<String, dynamic> &&
            payload['local_id']?.toString() == localItemId) {
          await (delete(syncOps)..where((tbl) => tbl.id.equals(op.id))).go();
        }
      } catch (_) {
        // Ignore malformed payloads.
      }
    }
  }

  // Shifts + cash movements
  Stream<Shift?> watchOpenShift() =>
      (select(shifts)
            ..where((tbl) => tbl.closedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
            ..limit(1))
          .watch()
          .map((rows) => rows.isEmpty ? null : rows.first);

  Future<Shift?> getOpenShift() async {
    final rows =
        await (select(shifts)
              ..where((tbl) => tbl.closedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> openShift({
    required double openingFloat,
    String? outletId,
    String? staffId,
    DateTime? openedAt,
  }) async {
    final shiftId = _uuid.v4();
    await into(shifts).insert(
      ShiftsCompanion.insert(
        id: Value(shiftId),
        outletId: Value(outletId),
        staffId: Value(staffId),
        openedAt: Value(openedAt ?? DateTime.now().toUtc()),
        openingFloat: Value(openingFloat),
        synced: const Value(false),
      ),
    );
    return shiftId;
  }

  Future<void> closeShift({
    required String shiftId,
    required double closingFloat,
    DateTime? closedAt,
  }) async {
    await (update(shifts)..where((tbl) => tbl.id.equals(shiftId))).write(
      ShiftsCompanion(
        closedAt: Value(closedAt ?? DateTime.now().toUtc()),
        closingFloat: Value(closingFloat),
        synced: const Value(false),
      ),
    );
  }

  Stream<List<CashMovement>> watchCashMovements({int limit = 50}) =>
      (select(cashMovements)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  Future<int> recordCashMovement({
    String? outletId,
    String? staffId,
    required String type,
    required double amount,
    String? note,
    DateTime? occurredAt,
  }) async {
    final occurred = occurredAt ?? DateTime.now().toUtc();
    final id = await into(cashMovements).insert(
      CashMovementsCompanion.insert(
        outletId: Value(outletId),
        staffId: Value(staffId),
        type: type,
        amount: amount,
        note: Value(note),
        createdAt: Value(occurred),
      ),
    );

    final key = 'cash_movement_$id';
    await enqueueSync(
      'cash_movement_push',
      jsonEncode({
        'movement_id': id.toString(),
        'type': type,
        'amount': amount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'occurred_at': occurred.toIso8601String(),
        'idempotency_key': key,
      }),
    );
    return id;
  }

  Future<double> computeCashSalesSince(DateTime since) async {
    final joinQuery =
        select(payments).join([
            innerJoin(
              ledgerEntries,
              ledgerEntries.id.equalsExp(payments.entryId),
            ),
          ])
          ..where(payments.method.equals('cash'))
          ..where(ledgerEntries.createdAt.isBiggerOrEqualValue(since));

    final rows = await joinQuery.get();
    double total = 0;
    for (final row in rows) {
      final entry = row.readTable(ledgerEntries);
      final pay = row.readTable(payments);
      if (entry.type == 'refund') {
        total -= pay.amount;
      } else if (entry.type == 'sale') {
        total += pay.amount;
      }
    }
    return total;
  }

  Future<double> computeCashMovementsNetSince(DateTime since) async {
    final rows = await (select(
      cashMovements,
    )..where((t) => t.createdAt.isBiggerOrEqualValue(since))).get();
    double net = 0;
    for (final m in rows) {
      if (m.type == 'float') net += m.amount;
      if (m.type == 'withdrawal') net -= m.amount;
    }
    return net;
  }

  // Marketplace order cache
  Future<void> upsertCachedOrder(int orderId, String payloadJson) async {
    await into(cachedOrders).insertOnConflictUpdate(
      CachedOrdersCompanion(
        orderId: Value(orderId),
        payloadJson: Value(payloadJson),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<List<CachedOrder>> getCachedOrders() => (select(
    cachedOrders,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();

  // Service bookings cache
  Future<void> upsertCachedServiceBooking(int bookingId, String payloadJson) async {
    await into(cachedServiceBookings).insertOnConflictUpdate(
      CachedServiceBookingsCompanion(
        bookingId: Value(bookingId),
        payloadJson: Value(payloadJson),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<List<CachedServiceBooking>> getCachedServiceBookings() => (select(
    cachedServiceBookings,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();

  // Print queue
  Future<int> enqueueReceiptPrintJob(String entryId) async {
    final existing =
        await (select(printJobs)
              ..where(
                (t) =>
                    t.jobType.equals('receipt') &
                    t.referenceId.equals(entryId) &
                    t.status.equals('pending'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    return into(printJobs).insert(
      PrintJobsCompanion.insert(jobType: 'receipt', referenceId: entryId),
    );
  }

  Stream<List<PrintJob>> watchPrintJobs({int limit = 100}) =>
      (select(printJobs)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  Future<List<PrintJob>> pendingPrintJobs() =>
      (select(printJobs)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> markPrintJobPrinted(int id) async {
    final now = DateTime.now().toUtc();
    await (update(printJobs)..where((t) => t.id.equals(id))).write(
      PrintJobsCompanion(
        status: const Value('printed'),
        printedAt: Value(now),
        lastTriedAt: Value(now),
        lastError: const Value(null),
      ),
    );
  }

  Future<void> markPrintJobFailed(
    int id, {
    required int retryCount,
    required String lastError,
  }) async {
    final now = DateTime.now().toUtc();
    await (update(printJobs)..where((t) => t.id.equals(id))).write(
      PrintJobsCompanion(
        retryCount: Value(retryCount),
        lastTriedAt: Value(now),
        lastError: Value(lastError),
      ),
    );
  }

  Future<void> retryPrintJob(int id) async {
    await (update(printJobs)..where((t) => t.id.equals(id))).write(
      const PrintJobsCompanion(
        retryCount: Value(0),
        lastTriedAt: Value(null),
        lastError: Value(null),
        status: Value('pending'),
      ),
    );
  }

  Future<void> cancelPrintJob(int id) async {
    await (update(printJobs)..where((t) => t.id.equals(id))).write(
      const PrintJobsCompanion(status: Value('cancelled')),
    );
  }

  Future<int> clearPrintedJobs() async {
    return (delete(printJobs)..where((t) => t.status.equals('printed'))).go();
  }

  Future<Customer?> getCustomerById(String id) async {
    return (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }
}

class TransactionWithLines {
  TransactionWithLines(this.transaction, this.lines);
  final Transaction transaction;
  final List<TransactionLine> lines;
}

class QuotationWithCustomer {
  QuotationWithCustomer({required this.quotation, required this.customer});

  final Quotation quotation;
  final Customer? customer;
}

class LedgerEntryBundle {
  LedgerEntryBundle({
    required this.entry,
    required this.lines,
    required this.payments,
  });

  final LedgerEntry entry;
  final List<LedgerLine> lines;
  final List<Payment> payments;
}
