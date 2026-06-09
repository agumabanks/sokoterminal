import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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
  BoolColumn get cashOnDelivery =>
      boolean().withDefault(const Constant(true))();
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
  TextColumn get imageUrl => text().nullable()();
  IntColumn get coverUploadId => integer().nullable()();
  TextColumn get galleryUrls => text().nullable()(); // JSON array
  TextColumn get galleryUploadIds => text().nullable()(); // JSON array of ints
  RealColumn get price => real()();
  RealColumn get cost => real().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  BoolColumn get publishedOnline =>
      boolean().withDefault(const Constant(false))();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get serviceType => text().nullable()();
  TextColumn get deliveryTimeframe => text().nullable()();
  TextColumn get moderationStatus => text().nullable()();
  TextColumn get slug => text().nullable()();
  TextColumn get pricingPackages => text().nullable()(); // JSON array of tiers
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().nullable()();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ServiceJobSessions extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get bookingId => text().nullable()();
  TextColumn get serviceId => text().references(Services, #id)();
  TextColumn get clientName => text().nullable()();
  TextColumn get clientPhone => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get materialsCost => real().withDefault(const Constant(0))();
  RealColumn get laborCharge => real().withDefault(const Constant(0))();
  RealColumn get finalCharge => real().withDefault(const Constant(0))();
  TextColumn get photosJson => text().nullable()();
  TextColumn get pipelineStage => text().withDefault(const Constant('booked'))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
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
  BoolColumn get isWalkIn => boolean().withDefault(const Constant(false))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class DeviceContacts extends Table {
  TextColumn get deviceId => text()(); // stable OS contact id
  TextColumn get displayName => text()();
  TextColumn get primaryPhoneE164 => text().nullable()();
  TextColumn get primaryEmail => text().nullable()();
  TextColumn get phonesJson =>
      text().nullable()(); // JSON array of E.164 phones
  TextColumn get emailsJson => text().nullable()(); // JSON array of emails
  TextColumn get linkedCustomerId =>
      text().nullable().references(Customers, #id)();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>>? get primaryKey => {deviceId};
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
  TextColumn get variant => text().withDefault(const Constant(''))();
  IntColumn get delta => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class StockAlerts extends Table {
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get variant =>
      text()(); // '' for simple products, or variant label
  IntColumn get threshold => integer()();
  IntColumn get stockQty => integer()();
  BoolColumn get acknowledged => boolean().withDefault(const Constant(false))();
  DateTimeColumn get firstTriggeredAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get lastTriggeredAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>>? get primaryKey => {itemId, variant};
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

class BusinessProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get sellerId => text().nullable()();
  TextColumn get sellerName => text().nullable()();
  TextColumn get sellerEmail => text().nullable()();
  TextColumn get sellerPhone => text().nullable()();
  TextColumn get shopId => text().nullable()();
  TextColumn get shopName => text()();
  TextColumn get shopAddress => text().nullable()();
  TextColumn get shopPhone => text().nullable()();
  IntColumn get logoUploadId => integer().nullable()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get metaTitle => text().nullable()();
  TextColumn get metaDescription => text().nullable()();
  IntColumn get thermalPrinterWidth => integer().nullable()();
  RealColumn get shippingCost => real().nullable()();
  BoolColumn get selfDeliveryActive =>
      boolean().withDefault(const Constant(false))();
  RealColumn get deliveryRadiusKm => real().nullable()();
  RealColumn get deliveryPickupLatitude => real().nullable()();
  RealColumn get deliveryPickupLongitude => real().nullable()();
  BoolColumn get cashOnDeliveryEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get bankPaymentEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get mobileMoneyEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get bankName => text().nullable()();
  TextColumn get bankAccName => text().nullable()();
  TextColumn get bankAccNo => text().nullable()();
  TextColumn get bankRoutingNo => text().nullable()();
  TextColumn get mtnMerchantCode => text().nullable()();
  TextColumn get airtelMerchantCode => text().nullable()();
  TextColumn get paybillNumber => text().nullable()();
  TextColumn get receiptPaymentMethodsJson => text().nullable()();
  TextColumn get deliveryProfileJson => text().nullable()();
  IntColumn get verificationStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>>? get primaryKey => {key};
}

class LedgerEntries extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get receiptNumber =>
      integer().nullable()(); // Sequential receipt number
  TextColumn get idempotencyKey => text()();
  TextColumn get type => text()(); // sale, refund, void, adjustment
  TextColumn get originalEntryId =>
      text().nullable()(); // For refunds: links to original sale
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
  IntColumn get remoteId => integer().nullable()();
  TextColumn get idempotencyKey => text().nullable()();
  TextColumn get outletId => text().nullable().references(Outlets, #id)();
  TextColumn get staffId => text().nullable().references(Staff, #id)();
  TextColumn get type => text()(); // open, close, float, withdrawal
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  TextColumn get linkedExpenseId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class Expenses extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get remoteId => integer().nullable()(); // server expense id
  TextColumn get outletId => text().nullable().references(Outlets, #id)();
  TextColumn get staffId => text().nullable().references(Staff, #id)();
  TextColumn get method =>
      text()(); // cash, bank_transfer, mobile_money, card, other
  TextColumn get category => text()(); // utilities, rent, supplier, etc
  IntColumn get supplierId => integer().nullable()(); // remote supplier id
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
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
  TextColumn get serviceId =>
      text().references(Services, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get price => real()();
  TextColumn get unit => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Quotations extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get number => text()();
  DateTimeColumn get date =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
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
  TextColumn get quotationId =>
      text().references(Quotations, #id, onDelete: KeyAction.cascade)();
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
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
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
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

/// Local bookings table for walk-in service sales (unified booking history).
class LocalBookings extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get serviceId => text().references(Services, #id)();
  TextColumn get variantId => text().nullable()();
  TextColumn get variantName => text().nullable()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get ledgerEntryId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get price => real().withDefault(const Constant(0))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

/// Service packages (bundle definitions)
class ServicePackages extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get serviceId => text().nullable().references(Services, #id)();
  TextColumn get name => text()();
  IntColumn get totalSessions => integer()();
  RealColumn get price => real()();
  IntColumn get validityDays => integer().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

/// Customer package purchases
class CustomerPackages extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get packageId =>
      text().references(ServicePackages, #id, onDelete: KeyAction.cascade)();
  TextColumn get customerId => text().references(Customers, #id)();
  IntColumn get remainingSessions => integer()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

/// Package redemption log
class PackageRedemptions extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get customerPackageId =>
      text().references(CustomerPackages, #id, onDelete: KeyAction.cascade)();
  TextColumn get ledgerEntryId => text().nullable()();
  IntColumn get sessionsUsed => integer().withDefault(const Constant(1))();
  TextColumn get note => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

/// Customer memberships (discount tier)
class CustomerMemberships extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get tierName => text()();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  DateTimeColumn get validFrom => dateTime().nullable()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()(); // remote id
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('expense'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class AvailabilitySchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayOfWeek => integer()(); // 0=Sun … 6=Sat
  TextColumn get startTime => text()(); // HH:MM
  TextColumn get endTime => text()(); // HH:MM
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class AvailabilityExceptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get date => text()(); // YYYY-MM-DD
  BoolColumn get isAvailable => boolean().withDefault(const Constant(false))();
  TextColumn get startTime => text().nullable()(); // HH:MM
  TextColumn get endTime => text().nullable()(); // HH:MM
  TextColumn get reason => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

@DriftDatabase(
  tables: [
    Items,
    ItemStocks,
    Services,
    ServiceJobSessions,
    Customers,
    DeviceContacts,
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
    StockAlerts,
    Roles,
    Staff,
    Outlets,
    BusinessProfiles,
    AppSettings,
    LedgerEntries,
    LedgerLines,
    Payments,
    CashMovements,
    Expenses,
    Shifts,
    AuditLogs,
    ServiceVariants,
    Quotations,
    QuotationLines,
    ReceiptTemplates,
    QuotationTemplates,
    LocalBookings,
    ServicePackages,
    CustomerPackages,
    PackageRedemptions,
    CustomerMemberships,
    ExpenseCategories,
    AvailabilitySchedules,
    AvailabilityExceptions,
    ParkedSales,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.executor);

  static Future<AppDatabase> make() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'seller_terminal.db'));
    return AppDatabase._internal(NativeDatabase.createInBackground(file));
  }

  /// Creates an in-memory database for testing.
  factory AppDatabase.forTesting(QueryExecutor executor) = AppDatabase._internal;

  @override
  int get schemaVersion => 36;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      try {
        await _runSchemaUpgrade(migrator, from, to);
      } catch (e, st) {
        debugPrint(
          '[AppDatabase] Migration failed upgrading from v$from to v$to: $e\n$st',
        );
        rethrow;
      }
    },
  );

  Future<void> _runSchemaUpgrade(Migrator migrator, int from, int to) async {
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
      if (from < 19) {
        await migrator.createTable(expenses);
        await migrator.addColumn(cashMovements, cashMovements.linkedExpenseId);
      }
      if (from < 20) {
        await migrator.createTable(deviceContacts);
      }
      if (from < 21) {
        await migrator.createTable(stockAlerts);
      }
      if (from < 22) {
        await migrator.addColumn(customers, customers.isWalkIn);
      }
      if (from < 23) {
        await migrator.createTable(localBookings);
      }
      if (from < 24) {
        await migrator.createTable(servicePackages);
        await migrator.createTable(customerPackages);
        await migrator.createTable(packageRedemptions);
      }
      if (from < 25) {
        await migrator.createTable(customerMemberships);
      }
      if (from < 26) {
        await migrator.createTable(expenseCategories);
      }
      if (from < 27) {
        // Schema version 27 intentionally has no table mutation.
      }
      if (from < 28) {
        await migrator.addColumn(cashMovements, cashMovements.remoteId);
        await migrator.addColumn(cashMovements, cashMovements.idempotencyKey);
      }
      if (from < 29) {
        await migrator.addColumn(services, services.imageUrl);
      }
      if (from < 30) {
        await migrator.createTable(businessProfiles);
      }
      if (from < 31) {
        await migrator.createTable(appSettings);
      }
      if (from < 32) {
        await migrator.createTable(availabilitySchedules);
        await migrator.createTable(availabilityExceptions);
      }
      if (from < 33) {
        await migrator.createTable(parkedSales);
      }
      if (from < 34) {
        await migrator.addColumn(services, services.coverUploadId);
        await migrator.addColumn(services, services.galleryUrls);
        await migrator.addColumn(services, services.galleryUploadIds);
      }
      if (from < 35) {
        await migrator.addColumn(services, services.categoryId);
        await migrator.addColumn(services, services.summary);
        await migrator.addColumn(services, services.serviceType);
        await migrator.addColumn(services, services.deliveryTimeframe);
        await migrator.addColumn(services, services.moderationStatus);
        await migrator.addColumn(services, services.slug);
        await migrator.addColumn(services, services.pricingPackages);
      }
      if (from < 36) {
        await migrator.addColumn(parkedSales, parkedSales.label);
        await migrator.addColumn(parkedSales, parkedSales.saleKind);
      }
  }

  // Expense Categories
  Future<List<ExpenseCategory>> getAllExpenseCategories() =>
      (select(expenseCategories)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Stream<List<ExpenseCategory>> watchExpenseCategories() =>
      (select(expenseCategories)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<void> upsertExpenseCategory(
    ExpenseCategoriesCompanion companion,
  ) async {
    await into(expenseCategories).insertOnConflictUpdate(companion);
  }

  /// Seeds built-in expense categories if the table is empty.
  /// Safe to call on every boot — no-ops if categories already exist.
  Future<void> seedExpenseCategoriesIfEmpty() async {
    final count = await (select(expenseCategories)).get();
    if (count.isNotEmpty) return;
    const seeds = _expenseCategorySeeds;
    for (int i = 0; i < seeds.length; i++) {
      await into(expenseCategories).insertOnConflictUpdate(
        ExpenseCategoriesCompanion.insert(name: seeds[i]),
      );
    }
  }

  Future<void> deleteLocalTemporaryCategory(String name) async {
    await (delete(
      expenseCategories,
    )..where((t) => t.name.equals(name) & t.id.isSmallerThanValue(0))).go();
  }

  // Items
  Future<List<Item>> getAllItems() => select(items).get();
  Future<Item?> getItemById(String id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  Stream<Item?> watchItemById(String id) =>
      (select(items)..where((t) => t.id.equals(id))).watchSingleOrNull();
  Future<Item?> getItemByRemoteId(int remoteId) => (select(
    items,
  )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();
  Stream<List<Item>> watchItems() =>
      (select(items)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  Future<void> upsertItem(ItemsCompanion companion) async {
    await into(items).insertOnConflictUpdate(companion);
  }

  /// Save item and enqueue sync atomically.
  Future<void> saveItemAndEnqueueSync({
    required ItemsCompanion item,
    required Map<String, dynamic> syncPayload,
    required String opType,
  }) async {
    await transaction(() async {
      await into(items).insertOnConflictUpdate(item);
      await enqueueSync(opType, jsonEncode(syncPayload));
    });
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
  Stream<List<ItemStock>> watchItemStocksForItem(String itemId) =>
      (select(itemStocks)..where((t) => t.itemId.equals(itemId))).watch();

  Future<List<ItemStock>> getItemStocksForItem(String itemId) =>
      (select(itemStocks)..where((t) => t.itemId.equals(itemId))).get();

  Future<void> upsertItemStock(ItemStocksCompanion companion) async {
    await into(itemStocks).insertOnConflictUpdate(companion);
  }

  Future<void> deleteItemStocksNotIn(
    String itemId,
    List<String> variants,
  ) async {
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
  Future<List<Service>> getAllServices() => select(services).get();
  Future<Service?> getServiceById(String id) =>
      (select(services)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<Service?> getServiceByRemoteId(int remoteId) => (select(
    services,
  )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();
  Future<void> upsertService(ServicesCompanion companion) async {
    await into(services).insertOnConflictUpdate(companion);
  }

  Future<void> updateServiceFields(String id, ServicesCompanion companion) async {
    await (update(services)..where((tbl) => tbl.id.equals(id))).write(companion);
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

  Future<void> deleteService(String id) async {
    await (delete(services)..where((t) => t.id.equals(id))).go();
  }

  Future<void> pruneSyncedRemoteServicesNotIn(Iterable<String> keepIds) async {
    final keep = keepIds.toSet();
    final candidates =
        await (select(services)
              ..where((t) => t.remoteId.isNotNull() & t.synced.equals(true)))
            .get();

    for (final service in candidates) {
      if (keep.contains(service.id)) continue;
      final bookings = await (select(
        localBookings,
      )..where((t) => t.serviceId.equals(service.id))).get();

      if (bookings.isEmpty) {
        await transaction(() async {
          await (update(transactionLines)
                ..where((t) => t.serviceId.equals(service.id)))
              .write(const TransactionLinesCompanion(serviceId: Value(null)));
          await (update(ledgerLines)
                ..where((t) => t.serviceId.equals(service.id)))
              .write(const LedgerLinesCompanion(serviceId: Value(null)));
          await (update(servicePackages)
                ..where((t) => t.serviceId.equals(service.id)))
              .write(const ServicePackagesCompanion(serviceId: Value(null)));
          await (delete(services)..where((t) => t.id.equals(service.id))).go();
        });
        continue;
      }

      await (update(services)..where((t) => t.id.equals(service.id))).write(
        ServicesCompanion(
          publishedOnline: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  // Service Job Sessions
  Stream<List<ServiceJobSession>> watchJobSessions() => (select(
    serviceJobSessions,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<List<ServiceJobSession>> getAllJobSessions() =>
      (select(serviceJobSessions)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<List<ServiceJobSession>> getJobSessionsForService(String serviceId) =>
      (select(serviceJobSessions)
            ..where((t) => t.serviceId.equals(serviceId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<ServiceJobSession?> getActiveJobSession() =>
      (select(serviceJobSessions)
            ..where((t) => t.endedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> upsertJobSession(ServiceJobSessionsCompanion companion) async {
    await into(serviceJobSessions).insertOnConflictUpdate(companion);
  }

  Future<void> deleteJobSession(String id) async {
    await (delete(serviceJobSessions)..where((t) => t.id.equals(id))).go();
  }

  // Inventory Logs (read)
  Future<List<InventoryLog>> getInventoryLogsForItem(String itemId) =>
      (select(inventoryLogs)
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<InventoryLog>> watchInventoryLogsForItem(String itemId) =>
      (select(inventoryLogs)
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  // Service Variants
  Stream<List<ServiceVariant>> watchServiceVariants(String serviceId) =>
      (select(serviceVariants)
            ..where((tbl) => tbl.serviceId.equals(serviceId))
            ..orderBy([(t) => OrderingTerm.asc(t.price)]))
          .watch();

  Future<void> upsertServiceVariant(ServiceVariantsCompanion companion) async {
    await into(serviceVariants).insertOnConflictUpdate(companion);
  }

  Future<void> deleteServiceVariant(String id) async {
    await (delete(serviceVariants)..where((t) => t.id.equals(id))).go();
  }

  Future<void> pruneSyncedServiceVariantsNotIn(Iterable<String> keepIds) async {
    final keep = keepIds.toSet();
    final candidates =
        await (select(serviceVariants)
              ..where((t) => t.synced.equals(true)))
            .get();
    for (final variant in candidates) {
      if (keep.contains(variant.id)) continue;
      await (delete(serviceVariants)..where((t) => t.id.equals(variant.id))).go();
    }
  }

  Future<void> unsetDefaultVariants(String serviceId) async {
    await (update(serviceVariants)..where((t) => t.serviceId.equals(serviceId)))
        .write(const ServiceVariantsCompanion(isDefault: Value(false)));
  }

  /// Get all variants for a service (for checkout picker).
  Future<List<ServiceVariant>> getServiceVariantsForService(String serviceId) =>
      (select(serviceVariants)
            ..where((t) => t.serviceId.equals(serviceId))
            ..orderBy([(t) => OrderingTerm.asc(t.price)]))
          .get();

  /// Get the default variant for a service (if any).
  Future<ServiceVariant?> getDefaultVariantForService(String serviceId) =>
      (select(serviceVariants)
            ..where(
              (t) => t.serviceId.equals(serviceId) & t.isDefault.equals(true),
            )
            ..limit(1))
          .getSingleOrNull();

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
    ])..orderBy([OrderingTerm.desc(quotations.date)]);

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

  Future<List<QuotationLine>> getQuotationLinesByQuotationId(
    String quotationId,
  ) {
    return (select(
      quotationLines,
    )..where((t) => t.quotationId.equals(quotationId))).get();
  }

  Future<void> upsertQuotationWithLines({
    required String quotationId,
    required QuotationsCompanion header,
    required List<QuotationLinesCompanion> lines,
  }) async {
    await transaction(() async {
      await into(quotations).insertOnConflictUpdate(header);
      await (delete(
        quotationLines,
      )..where((t) => t.quotationId.equals(quotationId))).go();
      for (final line in lines) {
        await into(quotationLines).insert(line);
      }
    });
  }

  // Receipt Templates
  Future<void> upsertReceiptTemplate(
    ReceiptTemplatesCompanion companion,
  ) async {
    await into(receiptTemplates).insertOnConflictUpdate(companion);
  }

  Future<void> pruneSyncedServicePackagesNotIn(
    Iterable<String> keepIds,
  ) async {
    final keep = keepIds.toSet();
    final candidates =
        await (select(servicePackages)
              ..where((t) => t.synced.equals(true)))
            .get();
    for (final package in candidates) {
      if (keep.contains(package.id)) continue;
      await (delete(servicePackages)..where((t) => t.id.equals(package.id))).go();
    }
  }

  Future<void> pruneSyncedCustomerPackagesNotIn(
    Iterable<String> keepIds,
  ) async {
    final keep = keepIds.toSet();
    final candidates =
        await (select(customerPackages)
              ..where((t) => t.synced.equals(true)))
            .get();
    for (final customerPackage in candidates) {
      if (keep.contains(customerPackage.id)) continue;
      await (delete(
        customerPackages,
      )..where((t) => t.id.equals(customerPackage.id))).go();
    }
  }

  Future<void> pruneSyncedPackageRedemptionsNotIn(
    Iterable<String> keepIds,
  ) async {
    final keep = keepIds.toSet();
    final candidates =
        await (select(packageRedemptions)
              ..where((t) => t.synced.equals(true)))
            .get();
    for (final redemption in candidates) {
      if (keep.contains(redemption.id)) continue;
      await (delete(
        packageRedemptions,
      )..where((t) => t.id.equals(redemption.id))).go();
    }
  }

  Future<ReceiptTemplate?> getLatestReceiptTemplate() async {
    // First try to get the active template
    final active =
        await (select(receiptTemplates)
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
  Future<Customer?> getCustomerByRemoteId(String remoteId) => (select(
    customers,
  )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

  Future<Customer?> getCustomerByPhoneE164(String phoneE164) => (select(
    customers,
  )..where((t) => t.phone.equals(phoneE164))).getSingleOrNull();

  Future<Customer?> getCustomerByEmail(String email) =>
      (select(customers)
            ..where((t) => t.email.equals(email.toLowerCase().trim())))
          .getSingleOrNull();

  Future<void> upsertCustomer(CustomersCompanion companion) async {
    await into(customers).insertOnConflictUpdate(companion);
  }

  Stream<List<Customer>> watchCustomers() => (select(
    customers,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  /// Get or create a daily "Walk-in YYYY-MM-DD" placeholder customer.
  Future<Customer> getOrCreateWalkInCustomerForDate(DateTime date) async {
    final datePart =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final name = 'Walk-in $datePart';

    // Try to find existing walk-in customer for this date
    final existing =
        await (select(customers)
              ..where((t) => t.name.equals(name) & t.isWalkIn.equals(true)))
            .getSingleOrNull();

    if (existing != null) return existing;

    // Create new walk-in customer
    final id = _uuid.v4();
    final companion = CustomersCompanion.insert(
      id: Value(id),
      name: name,
      isWalkIn: const Value(true),
      synced: const Value(false),
    );
    await into(customers).insert(companion);
    return (await (select(
      customers,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  /// Create a local booking record for a service sale (walk-in or linked).
  Future<void> createLocalBooking({
    required String serviceId,
    String? variantId,
    String? variantName,
    String? customerId,
    String? ledgerEntryId,
    required double price,
    DateTime? completedAt,
  }) async {
    final now = DateTime.now().toUtc();
    await into(localBookings).insert(
      LocalBookingsCompanion.insert(
        serviceId: serviceId,
        variantId: Value(variantId),
        variantName: Value(variantName),
        customerId: Value(customerId),
        ledgerEntryId: Value(ledgerEntryId),
        status: const Value('completed'),
        completedAt: Value(completedAt ?? now),
        price: Value(price),
        synced: const Value(false),
      ),
    );
  }

  /// Watch local bookings (for unified booking history).
  Stream<List<LocalBooking>> watchLocalBookings() => (select(
    localBookings,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  // ─────────────────────────────────────────────────────────────────────────
  // Service Packages (session bundles)
  // ─────────────────────────────────────────────────────────────────────────

  /// Watch all active service packages.
  Stream<List<ServicePackage>> watchServicePackages() =>
      (select(servicePackages)
            ..where((t) => t.active.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  /// Get active customer packages (with remaining sessions > 0 and not expired).
  Future<List<CustomerPackage>> getActivePackagesForCustomer(
    String customerId,
  ) async {
    final now = DateTime.now().toUtc();
    final query = select(customerPackages)
      ..where(
        (t) =>
            t.customerId.equals(customerId) &
            t.remainingSessions.isBiggerThanValue(0),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.expiresAt)]);
    final all = await query.get();
    // Filter expired packages
    return all
        .where((p) => p.expiresAt == null || p.expiresAt!.isAfter(now))
        .toList();
  }

  /// Purchase a package for a customer (creates CustomerPackage).
  Future<String> purchasePackage({
    required String packageId,
    required String customerId,
    required int totalSessions,
    int? validityDays,
  }) async {
    final id = _uuid.v4();
    final expiresAt = validityDays != null
        ? DateTime.now().toUtc().add(Duration(days: validityDays))
        : null;
    await into(customerPackages).insert(
      CustomerPackagesCompanion.insert(
        id: Value(id),
        packageId: packageId,
        customerId: customerId,
        remainingSessions: totalSessions,
        expiresAt: Value(expiresAt),
        synced: const Value(false),
      ),
    );
    return id;
  }

  /// Redeem a session from a customer package (decrements remainingSessions, logs redemption).
  Future<bool> redeemPackage({
    required String customerPackageId,
    String? ledgerEntryId,
    int sessionsUsed = 1,
    String? note,
  }) async {
    final pkg = await (select(
      customerPackages,
    )..where((t) => t.id.equals(customerPackageId))).getSingleOrNull();
    if (pkg == null) return false;
    if (pkg.remainingSessions < sessionsUsed) return false;

    // Check expiry
    if (pkg.expiresAt != null &&
        pkg.expiresAt!.isBefore(DateTime.now().toUtc())) {
      return false;
    }

    // Decrement sessions
    await (update(
      customerPackages,
    )..where((t) => t.id.equals(customerPackageId))).write(
      CustomerPackagesCompanion(
        remainingSessions: Value(pkg.remainingSessions - sessionsUsed),
        synced: const Value(false),
      ),
    );

    // Log redemption
    await into(packageRedemptions).insert(
      PackageRedemptionsCompanion.insert(
        customerPackageId: customerPackageId,
        ledgerEntryId: Value(ledgerEntryId),
        sessionsUsed: Value(sessionsUsed),
        note: Value(note),
        synced: const Value(false),
      ),
    );
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Customer Memberships (discount tier)
  // ─────────────────────────────────────────────────────────────────────────

  /// Get active membership discount for a customer.
  /// Returns null if no active membership found.
  Future<CustomerMembership?> getActiveMembershipForCustomer(
    String customerId,
  ) async {
    final now = DateTime.now().toUtc();
    final query = select(customerMemberships)
      ..where((t) => t.customerId.equals(customerId) & t.active.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.discountPercent)]);
    final all = await query.get();

    // Filter by validity dates
    for (final m in all) {
      final validFrom = m.validFrom;
      final validUntil = m.validUntil;
      if (validFrom != null && validFrom.isAfter(now)) continue;
      if (validUntil != null && validUntil.isBefore(now)) continue;
      return m; // Return first valid membership (highest discount)
    }
    return null;
  }

  // Device Contacts (local-only cache)
  Future<void> upsertDeviceContact(DeviceContactsCompanion companion) async {
    await into(deviceContacts).insertOnConflictUpdate(companion);
  }

  Stream<List<DeviceContact>> watchDeviceContacts() => (select(
    deviceContacts,
  )..orderBy([(t) => OrderingTerm.asc(t.displayName)])).watch();

  Future<List<DeviceContact>> getDeviceContacts() => (select(
    deviceContacts,
  )..orderBy([(t) => OrderingTerm.asc(t.displayName)])).get();

  Future<void> linkDeviceContactToCustomer({
    required String deviceId,
    required String customerId,
  }) async {
    await (update(deviceContacts)..where((t) => t.deviceId.equals(deviceId)))
        .write(DeviceContactsCompanion(linkedCustomerId: Value(customerId)));
  }

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

  Future<StaffData?> getStaffByPin(String pin) async {
    return (select(staff)
          ..where((t) => t.pin.equals(pin) & t.active.equals(true)))
        .getSingleOrNull();
  }

  Future<StaffData?> getStaffById(String id) async {
    return (select(staff)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> deleteAllStaff() async {
    return delete(staff).go();
  }

  Future<void> upsertOutlet(OutletsCompanion companion) async {
    await into(outlets).insertOnConflictUpdate(companion);
  }

  Future<Outlet?> getOutletById(String id) async {
    return (select(
      outlets,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<Outlet?> getPrimaryOutlet() async {
    return (select(outlets)
          ..where((tbl) => tbl.active.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertBusinessProfile(
    BusinessProfilesCompanion companion,
  ) async {
    await into(businessProfiles).insertOnConflictUpdate(companion);
  }

  Future<BusinessProfile?> getBusinessProfile() {
    return (select(
      businessProfiles,
    )..where((t) => t.id.equals('primary'))).getSingleOrNull();
  }

  Stream<BusinessProfile?> watchBusinessProfile() {
    return (select(
      businessProfiles,
    )..where((t) => t.id.equals('primary'))).watchSingleOrNull();
  }

  Future<void> upsertAppSetting(AppSettingsCompanion companion) async {
    await into(appSettings).insertOnConflictUpdate(companion);
  }

  Future<AppSetting?> getAppSetting(String key) {
    return (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
  }

  Stream<List<AppSetting>> watchAppSettings() =>
      (select(appSettings)..orderBy([(t) => OrderingTerm.asc(t.key)])).watch();

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

  /// Atomic sale checkout: validates stock, saves ledger, and decrements stock
  /// all inside a single Drift transaction. No race conditions between validation
  /// and write.
  Future<int> checkoutSale({
    required LedgerEntriesCompanion entry,
    required List<LedgerLinesCompanion> lines,
    required List<PaymentsCompanion> payments,
    required List<({String itemId, int quantity, String? variant})> stockDeltas,
  }) async {
    return await transaction(() async {
      // 1. Re-read and validate stock inside the transaction
      final shortages = <String>[];
      for (final delta in stockDeltas) {
        final item = await (select(items)
              ..where((tbl) => tbl.id.equals(delta.itemId)))
            .getSingleOrNull();
        if (item == null || !item.stockEnabled) continue;

        final variant = (delta.variant ?? '').trim();
        var available = variant.isEmpty ? item.stockQty : 0;
        final stockRow = await (select(itemStocks)
              ..where((t) => t.itemId.equals(delta.itemId) & t.variant.equals(variant)))
            .getSingleOrNull();
        if (stockRow != null) {
          available = stockRow.stockQty;
        }
        if (available < delta.quantity) {
          final label = variant.isEmpty ? item.name : '${item.name} • $variant';
          shortages.add('$label (stock $available, requested ${delta.quantity})');
        }
      }
      if (shortages.isNotEmpty) {
        throw StateError('Insufficient stock: ${shortages.join(', ')}');
      }

      // 2. Save ledger entry
      await into(ledgerEntries).insert(entry);
      for (final line in lines) {
        await into(ledgerLines).insert(line);
      }
      for (final pay in payments) {
        await into(this.payments).insert(pay);
      }

      // 3. Decrement stock inside the same transaction
      final now = DateTime.now().toUtc();
      for (final delta in stockDeltas) {
        final item = await (select(items)
              ..where((tbl) => tbl.id.equals(delta.itemId)))
            .getSingleOrNull();
        if (item == null || !item.stockEnabled) continue;

        await into(inventoryLogs).insert(
          InventoryLogsCompanion.insert(
            itemId: delta.itemId,
            delta: -delta.quantity,
            note: const Value('sale'),
          ),
        );

        final updatedQty = item.stockQty - delta.quantity;
        await (update(items)
              ..where((tbl) => tbl.id.equals(delta.itemId)))
            .write(
          ItemsCompanion(stockQty: Value(updatedQty), updatedAt: Value(now)),
        );

        final variant = (delta.variant ?? '').trim();
        if (variant.isNotEmpty) {
          final row = await (select(itemStocks)
                ..where((t) => t.itemId.equals(delta.itemId) & t.variant.equals(variant)))
              .getSingleOrNull();
          if (row != null) {
            final nextVariantQty = row.stockQty - delta.quantity;
            await (update(itemStocks)
                  ..where((t) => t.itemId.equals(delta.itemId) & t.variant.equals(variant)))
                .write(
              ItemStocksCompanion(
                stockQty: Value(nextVariantQty),
                updatedAt: Value(now),
              ),
            );
          }
        }
      }

      return entry.receiptNumber.value ?? 0;
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

  /// Net units moved for an item in a time window (sales - refunds - voids).
  ///
  /// This is used for lightweight “fast moving” indicators in the catalog.
  Stream<int> watchNetUnitsMovedForItemSince(String itemId, DateTime since) {
    final q = customSelect(
      'SELECT COALESCE(SUM(CASE e.type '
      "WHEN 'sale' THEN l.quantity "
      "WHEN 'refund' THEN -l.quantity "
      "WHEN 'void' THEN -l.quantity "
      'ELSE 0 END), 0) AS qty '
      'FROM ledger_lines l '
      'JOIN ledger_entries e ON e.id = l.entry_id '
      'WHERE l.item_id = ? AND e.created_at >= ?',
      variables: [Variable.withString(itemId), Variable.withDateTime(since)],
      readsFrom: {ledgerLines, ledgerEntries},
    );
    return q.watchSingle().map((row) => row.read<int>('qty'));
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

  Future<LedgerEntry?> findVoidForSale(String saleEntryId) {
    return (select(ledgerEntries)
          ..where(
            (t) =>
                t.type.equals('void') & t.originalEntryId.equals(saleEntryId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<bool> isSaleVoided(String saleEntryId) async {
    final row =
        await (select(ledgerEntries)
              ..where(
                (t) =>
                    t.type.equals('void') &
                    t.originalEntryId.equals(saleEntryId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
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
      await (delete(
        ledgerLines,
      )..where((t) => t.entryId.equals(entry.id.value))).go();
      await (delete(
        this.payments,
      )..where((t) => t.entryId.equals(entry.id.value))).go();

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

  Future<List<SyncOp>> pendingSyncOps({int? limit}) {
    final query = select(syncOps)
      ..where((tbl) => tbl.status.equals('pending'))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    if (limit != null && limit > 0) {
      query.limit(limit);
    }
    return query.get();
  }

  Stream<int> watchPendingSyncOpsCount() {
    final count = syncOps.id.count();
    return (selectOnly(syncOps)
          ..addColumns([count])
          ..where(syncOps.status.equals('pending')))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Stream<int> watchBlockedSyncOpsCount() {
    final count = syncOps.id.count();
    return (selectOnly(syncOps)
          ..addColumns([count])
          ..where(syncOps.status.equals('blocked')))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Stream<AppSetting?> watchAppSetting(String key) {
    return (select(appSettings)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<List<SyncOp>> blockedSyncOps() =>
      (select(syncOps)
            ..where((tbl) => tbl.status.equals('blocked'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Watch the most recent sync op for a given local_id.
  /// Used to show per-item/service sync status badges.
  Stream<SyncOp?> watchSyncOpForLocalId(String localId) {
    return (select(syncOps)
          ..where(
            (tbl) => tbl.payload.like('%"local_id":"$localId"%'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

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
      const SyncOpsCompanion(
        status: Value('pending'),
        lastTriedAt: Value(null),
      ),
    );
  }

  /// Reset all pending sync operations to retry immediately (clears retry count and backoff)
  Future<int> resetAllPendingSyncOps() async {
    final updated =
        await (update(syncOps)..where(
              (t) => t.status.equals('pending') | t.status.equals('blocked'),
            ))
            .write(
              const SyncOpsCompanion(
                status: Value('pending'),
                retryCount: Value(0),
                lastTriedAt: Value(null),
                lastError: Value(null),
              ),
            );
    return updated;
  }

  /// Reset only stale pending/blocked sync ops — those that have never been tried
  /// or whose last try is older than [minAge]. This preserves exponential backoff
  /// for ops that recently failed (e.g. HTTP 429) while still allowing long-stuck
  /// ops to retry when the user explicitly requests a sync.
  Future<int> resetStalePendingSyncOps(Duration minAge) async {
    final threshold = DateTime.now().toUtc().subtract(minAge);
    final updated =
        await (update(syncOps)..where(
              (t) =>
                  (t.status.equals('pending') | t.status.equals('blocked')) &
                  (t.lastTriedAt.isNull() | t.lastTriedAt.isSmallerThanValue(threshold)),
            ))
            .write(
              const SyncOpsCompanion(
                status: Value('pending'),
                retryCount: Value(0),
                lastTriedAt: Value(null),
                lastError: Value(null),
              ),
            );
    return updated;
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
        ItemsCompanion(stockQty: Value(updatedQty), updatedAt: Value(now)),
      );

      if (variant != null) {
        final v = variant.trim();
        final row =
            await (select(itemStocks)
                  ..where((t) => t.itemId.equals(itemId) & t.variant.equals(v)))
                .getSingleOrNull();
        if (row != null) {
          final nextVariantQty = row.stockQty + delta;
          await (update(
            itemStocks,
          )..where((t) => t.itemId.equals(itemId) & t.variant.equals(v))).write(
            ItemStocksCompanion(
              stockQty: Value(nextVariantQty),
              updatedAt: Value(now),
            ),
          );
        }
      }

      // Low stock alerting (local-first). Variants use their own stock if we
      // can read it; otherwise fall back to overall item stock.
      if (item.stockEnabled) {
        final threshold = item.lowStockWarning ?? 5;
        final v = (variant ?? '').trim();
        final row =
            await (select(itemStocks)
                  ..where((t) => t.itemId.equals(itemId) & t.variant.equals(v)))
                .getSingleOrNull();
        final effectiveQty = row?.stockQty ?? (v.isEmpty ? updatedQty : 0);
        await _upsertOrResolveStockAlert(
          itemId: itemId,
          variant: v,
          stockQty: effectiveQty,
          threshold: threshold,
          now: now,
        );
      }
    });
  }

  Future<void> _upsertOrResolveStockAlert({
    required String itemId,
    required String variant,
    required int stockQty,
    required int threshold,
    required DateTime now,
  }) async {
    final existing =
        await (select(stockAlerts)..where(
              (t) => t.itemId.equals(itemId) & t.variant.equals(variant),
            ))
            .getSingleOrNull();

    final isLow = stockQty <= threshold;
    if (isLow) {
      if (existing == null) {
        await into(stockAlerts).insert(
          StockAlertsCompanion.insert(
            itemId: itemId,
            variant: variant,
            threshold: threshold,
            stockQty: stockQty,
            acknowledged: const Value(false),
            firstTriggeredAt: Value(now),
            lastTriggeredAt: Value(now),
            resolvedAt: const Value.absent(),
            updatedAt: Value(now),
          ),
        );
        return;
      }
      await (update(stockAlerts)
            ..where((t) => t.itemId.equals(itemId) & t.variant.equals(variant)))
          .write(
            StockAlertsCompanion(
              threshold: Value(threshold),
              stockQty: Value(stockQty),
              lastTriggeredAt: Value(now),
              resolvedAt: const Value(null),
              // If stock dips again after resolution, require attention again.
              acknowledged: existing.resolvedAt == null
                  ? const Value.absent()
                  : const Value(false),
              updatedAt: Value(now),
            ),
          );
      return;
    }

    if (existing == null || existing.resolvedAt != null) return;
    await (update(
      stockAlerts,
    )..where((t) => t.itemId.equals(itemId) & t.variant.equals(variant))).write(
      StockAlertsCompanion(resolvedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // Stock Alerts
  Stream<List<StockAlertWithItem>> watchOpenStockAlertsWithItem() {
    final query =
        select(
            stockAlerts,
          ).join([innerJoin(items, items.id.equalsExp(stockAlerts.itemId))])
          ..where(stockAlerts.resolvedAt.isNull())
          ..orderBy([OrderingTerm.desc(stockAlerts.lastTriggeredAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => StockAlertWithItem(
              alert: r.readTable(stockAlerts),
              item: r.readTable(items),
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<int> watchOpenStockAlertsCount() {
    final countExp = stockAlerts.itemId.count();
    final query = selectOnly(stockAlerts)
      ..addColumns([countExp])
      ..where(stockAlerts.resolvedAt.isNull());
    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  Future<void> acknowledgeStockAlert({
    required String itemId,
    required String variant,
  }) async {
    await (update(
      stockAlerts,
    )..where((t) => t.itemId.equals(itemId) & t.variant.equals(variant))).write(
      StockAlertsCompanion(
        acknowledged: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> upsertOrResolveStockAlert({
    required String itemId,
    required String variant,
    required int stockQty,
    required int threshold,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now().toUtc();
    await _upsertOrResolveStockAlert(
      itemId: itemId,
      variant: variant.trim(),
      stockQty: stockQty,
      threshold: threshold,
      now: ts,
    );
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
      await (delete(itemStocks)..where((tbl) => tbl.itemId.equals(itemId))).go();
      await (delete(stockAlerts)..where((tbl) => tbl.itemId.equals(itemId))).go();
      await (delete(
        inventoryLogs,
      )..where((tbl) => tbl.itemId.equals(itemId))).go();
      await (delete(items)..where((tbl) => tbl.id.equals(itemId))).go();
    });
  }

  Future<void> pruneSyncedRemoteItemsNotIn(Iterable<String> keepIds) async {
    final keep = keepIds.toSet();
    final candidates =
        await (select(items)
              ..where((t) => t.remoteId.isNotNull() & t.synced.equals(true)))
            .get();
    for (final item in candidates) {
      if (keep.contains(item.id)) continue;
      await deleteItemAndDetach(item.id);
    }
  }

  Future<void> deletePendingServiceOps(String localServiceId) async {
    final ops = await pendingSyncOps();
    for (final op in ops) {
      if (op.opType != 'service_create' &&
          op.opType != 'service_update' &&
          op.opType != 'service_variant_push' &&
          op.opType != 'service_variant_create' &&
          op.opType != 'service_variant_update' &&
          op.opType != 'service_variant_delete') {
        continue;
      }
      try {
        final payload = jsonDecode(op.payload);
        if (payload is! Map<String, dynamic>) continue;
        final localId = payload['local_id']?.toString();
        final serviceId =
            payload['service_id']?.toString() ?? payload['serviceId']?.toString();
        if (localId == localServiceId || serviceId == localServiceId) {
          await (delete(syncOps)..where((tbl) => tbl.id.equals(op.id))).go();
        }
      } catch (_) {
        // Ignore malformed payloads.
      }
    }
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
    String? linkedExpenseId,
    DateTime? occurredAt,
  }) async {
    final occurred = occurredAt ?? DateTime.now().toUtc();
    final id = await into(cashMovements).insert(
      CashMovementsCompanion.insert(
        remoteId: const Value.absent(),
        outletId: Value(outletId),
        staffId: Value(staffId),
        type: type,
        amount: amount,
        note: Value(note),
        linkedExpenseId: Value(linkedExpenseId),
        createdAt: Value(occurred),
      ),
    );

    final key = 'cash_movement_$id';
    await (update(cashMovements)..where((t) => t.id.equals(id))).write(
      CashMovementsCompanion(idempotencyKey: Value(key)),
    );
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

  Future<CashMovement?> getCashMovementByRemoteId(int remoteId) =>
      (select(cashMovements)
            ..where((t) => t.remoteId.equals(remoteId))
            ..limit(1))
          .getSingleOrNull();

  Future<CashMovement?> getCashMovementByIdempotencyKey(String key) =>
      (select(cashMovements)
            ..where((t) => t.idempotencyKey.equals(key))
            ..limit(1))
          .getSingleOrNull();

  Future<void> updateCashMovement(
    int id,
    CashMovementsCompanion companion,
  ) async {
    await (update(
      cashMovements,
    )..where((t) => t.id.equals(id))).write(companion);
  }

  // Expenses
  Stream<List<Expense>> watchExpenses({int limit = 200}) =>
      (select(expenses)
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(limit))
          .watch();

  Future<Expense?> getExpenseById(String id) =>
      (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Expense?> getExpenseByRemoteId(int remoteId) => (select(
    expenses,
  )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

  Future<void> upsertExpense(ExpensesCompanion companion) async {
    await into(expenses).insertOnConflictUpdate(companion);
  }

  Future<void> markExpenseSynced(String expenseId, int remoteId) async {
    await (update(expenses)..where((t) => t.id.equals(expenseId))).write(
      ExpensesCompanion(
        synced: const Value(true),
        remoteId: Value(remoteId),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<String> recordExpense({
    required double amount,
    required String method,
    required String category,
    int? supplierId,
    String? note,
    String? outletId,
    String? staffId,
    DateTime? occurredAt,
  }) async {
    final expenseId = _uuid.v4();
    final occurred = occurredAt ?? DateTime.now().toUtc();

    await into(expenses).insert(
      ExpensesCompanion.insert(
        id: Value(expenseId),
        remoteId: const Value.absent(),
        outletId: Value(outletId),
        staffId: Value(staffId),
        amount: amount,
        method: method.trim(),
        category: category.trim(),
        supplierId: Value(supplierId),
        note: Value(note),
        occurredAt: Value(occurred),
        synced: const Value(false),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );

    await enqueueSync(
      'expense_push',
      jsonEncode({
        // Backend stores this as client_expense_id for idempotent reconciliation.
        'client_expense_id': expenseId,
        'expense_id': expenseId, // legacy alias kept for older backend versions
        'amount': amount,
        'method': method.trim(),
        'category': category.trim(),
        if (outletId != null) 'outlet_id': outletId,
        if (staffId != null) 'staff_id': staffId,
        if (supplierId != null) 'supplier_id': supplierId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'occurred_at': occurred.toIso8601String(),
        'idempotency_key': 'expense_$expenseId',
      }),
    );

    await recordAuditLog(
      actorStaffId: staffId,
      action: 'expense_create',
      payload: {
        'expense_id': expenseId,
        'amount': amount,
        'method': method.trim(),
        'category': category.trim(),
        if (supplierId != null) 'supplier_id': supplierId,
        if (note != null) 'note': note,
        'occurred_at': occurred.toIso8601String(),
      },
    );

    return expenseId;
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

  Future<CachedOrder?> getCachedOrder(int orderId) => (select(
    cachedOrders,
  )..where((t) => t.orderId.equals(orderId))).getSingleOrNull();

  Stream<List<CachedOrder>> watchCachedOrders() => (select(
    cachedOrders,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  // Service bookings cache
  Future<void> upsertCachedServiceBooking(
    int bookingId,
    String payloadJson,
  ) async {
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

  Stream<List<CachedServiceBooking>> watchCachedServiceBookings() => (select(
    cachedServiceBookings,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  // Availability schedules
  Future<List<AvailabilitySchedule>> getAllAvailabilitySchedules() => (select(
    availabilitySchedules,
  )..orderBy([(t) => OrderingTerm.asc(t.dayOfWeek)])).get();

  Stream<List<AvailabilitySchedule>> watchAvailabilitySchedules() => (select(
    availabilitySchedules,
  )..orderBy([(t) => OrderingTerm.asc(t.dayOfWeek)])).watch();

  Future<void> upsertAvailabilitySchedule(
    AvailabilitySchedulesCompanion companion,
  ) async {
    await into(availabilitySchedules).insertOnConflictUpdate(companion);
  }

  Future<void> deleteAllAvailabilitySchedules() async {
    await delete(availabilitySchedules).go();
  }

  // Availability exceptions
  Future<List<AvailabilityException>> getAllAvailabilityExceptions() => (select(
    availabilityExceptions,
  )..orderBy([(t) => OrderingTerm.asc(t.date)])).get();

  Stream<List<AvailabilityException>> watchAvailabilityExceptions() => (select(
    availabilityExceptions,
  )..orderBy([(t) => OrderingTerm.asc(t.date)])).watch();

  Future<void> upsertAvailabilityException(
    AvailabilityExceptionsCompanion companion,
  ) async {
    await into(availabilityExceptions).insertOnConflictUpdate(companion);
  }

  Future<void> deleteAvailabilityException(int id) async {
    await (delete(availabilityExceptions)
      ..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAllAvailabilityExceptions() async {
    await delete(availabilityExceptions).go();
  }

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

  // SyncOps (outbox)
  Stream<List<SyncOp>> watchPendingSyncOps() =>
      (select(syncOps)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

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

  /// Compute local POS stats for a walk-in/offline customer by their local DB id.
  /// Returns a record with totalOrders, totalRevenue, and avgOrderValue
  /// derived entirely from [LedgerEntries] rows where customerId matches.
  Future<({int totalOrders, double totalRevenue, double avgOrderValue, DateTime? lastPurchaseAt})>
      getLocalCustomerStats(String customerId) async {
    final rows = await (select(ledgerEntries)
          ..where(
            (e) => e.customerId.equals(customerId) & e.type.equals('sale'),
          ))
        .get();

    final totalOrders = rows.length;
    final totalRevenue = rows.fold<double>(0, (sum, e) => sum + e.total);
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    final lastPurchaseAt = rows.isNotEmpty
        ? rows.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    return (
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      avgOrderValue: avgOrderValue,
      lastPurchaseAt: lastPurchaseAt,
    );
  }

  // ── Atomic DB + Sync operations (WhatsApp-grade durability) ──

  /// Adjust stock, mark item unsynced, and enqueue sync atomically.
  /// Crash between DB write and sync enqueue = orphan data. This prevents that.
  Future<void> adjustStockAndEnqueueSync({
    required String itemId,
    required int delta,
    String? note,
    String? variant,
    required Map<String, dynamic> syncPayload,
  }) async {
    await transaction(() async {
      await recordInventoryMovement(
        itemId: itemId,
        delta: delta,
        note: note,
        variant: variant,
      );
      await updateItemFields(
        itemId,
        const ItemsCompanion(synced: Value(false)),
      );
      await enqueueSync('stock_adjust', jsonEncode(syncPayload));
    });
  }

  /// Delete item and enqueue remote delete atomically.
  Future<void> deleteItemAndEnqueueSync({
    required String itemId,
    int? remoteId,
  }) async {
    await transaction(() async {
      await deletePendingItemOps(itemId);
      await deleteItemAndDetach(itemId);
      if (remoteId != null) {
        await enqueueSync(
          'item_delete',
          jsonEncode({'remote_id': remoteId}),
        );
      }
    });
  }

  /// Save service and enqueue sync atomically.
  Future<void> saveServiceAndEnqueueSync({
    required ServicesCompanion service,
    required Map<String, dynamic> syncPayload,
    required String opType,
  }) async {
    await transaction(() async {
      await into(services).insertOnConflictUpdate(service);
      await enqueueSync(opType, jsonEncode(syncPayload));
    });
  }

  /// Delete service and enqueue remote delete atomically.
  Future<void> deleteServiceAndEnqueueSync({
    required String serviceId,
    int? remoteId,
  }) async {
    await transaction(() async {
      await deletePendingServiceOps(serviceId);
      await deleteService(serviceId);
      if (remoteId != null) {
        await enqueueSync(
          'service_delete',
          jsonEncode({'local_id': serviceId, 'remote_id': remoteId}),
        );
      }
    });
  }

  /// Save booking and enqueue sync atomically.
  Future<void> saveBookingAndEnqueueSync({
    required LocalBookingsCompanion booking,
    required Map<String, dynamic> syncPayload,
  }) async {
    await transaction(() async {
      await into(localBookings).insertOnConflictUpdate(booking);
      await enqueueSync('booking_create', jsonEncode(syncPayload));
    });
  }

  /// Clears ALL data from the database.
  /// This is called on logout to ensure complete data isolation between
  /// different sellers using the same device.
  Future<void> clearAllData() async {
    await transaction(() async {
      // Clear all tables in reverse dependency order to avoid foreign key violations
      await delete(packageRedemptions).go();
      await delete(customerPackages).go();
      await delete(servicePackages).go();
      await delete(customerMemberships).go();
      await delete(localBookings).go();
      await delete(quotationLines).go();
      await delete(quotations).go();
      await delete(serviceVariants).go();
      await delete(auditLogs).go();
      await delete(shifts).go();
      await delete(expenses).go();
      await delete(cashMovements).go();
      await delete(payments).go();
      await delete(ledgerLines).go();
      await delete(ledgerEntries).go();
      await delete(printJobs).go();
      await delete(stockAlerts).go();
      await delete(inventoryLogs).go();
      await delete(cachedServiceBookings).go();
      await delete(cachedOrders).go();
      await delete(syncCursors).go();
      await delete(appSettings).go();
      await delete(syncOps).go();
      await delete(receipts).go();
      await delete(transactionLines).go();
      await delete(transactions).go();
      await delete(itemStocks).go();
      await delete(items).go();
      await delete(services).go();
      await delete(deviceContacts).go();
      await delete(customers).go();
      await delete(staff).go();
      await delete(roles).go();
      await delete(businessProfiles).go();
      await delete(outlets).go();
      await delete(suppliers).go();
      await delete(expenseCategories).go();
      await delete(receiptTemplates).go();
      await delete(quotationTemplates).go();
      await delete(parkedSales).go();
    });
  }

  // Analytics Helpers
  Future<List<LedgerEntry>> ledgerEntriesBetween(DateTime start, DateTime end) {
    return (select(ledgerEntries)
          ..where(
            (t) =>
                t.createdAt.isBiggerOrEqualValue(start) &
                t.createdAt.isSmallerOrEqualValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<LedgerLine>> getLinesForEntries(List<String> entryIds) {
    return (select(ledgerLines)..where((t) => t.entryId.isIn(entryIds))).get();
  }

  Future<List<Item>> allProducts() => select(items).get();

  // ── Parked Sales (active cart + named parked sales) ──
  static const activeCartSaleId = 'active-cart';
  static const activeCartSaleKind = 'active_cart';
  static const namedParkedSaleKind = 'parked';

  Future<void> saveParkedSale(ParkedSalesCompanion companion) async {
    await into(parkedSales).insertOnConflictUpdate(companion);
  }

  Future<void> clearParkedSales() async {
    await delete(parkedSales).go();
  }

  Future<void> clearActiveCartSale() async {
    await (delete(parkedSales)..where(
          (t) => t.id.equals(activeCartSaleId) | t.saleKind.equals(activeCartSaleKind),
        ))
        .go();
  }

  Future<ParkedSale?> getLatestParkedSale() async {
    return (select(parkedSales)
          ..where(
            (t) =>
                t.id.equals(activeCartSaleId) |
                t.saleKind.equals(activeCartSaleKind),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<ParkedSale>> getNamedParkedSales() {
    return (select(parkedSales)
          ..where((t) => t.saleKind.equals(namedParkedSaleKind))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<void> saveNamedParkedSale({
    required String id,
    required String label,
    required String linesJson,
    String? notes,
    String? customerId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    await into(parkedSales).insertOnConflictUpdate(
      ParkedSalesCompanion.insert(
        id: Value(id),
        label: Value(label),
        saleKind: const Value(namedParkedSaleKind),
        linesJson: linesJson,
        notes: Value(notes),
        customerId: Value(customerId),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> deleteNamedParkedSale(String id) async {
    await (delete(parkedSales)..where(
          (t) => t.id.equals(id) & t.saleKind.equals(namedParkedSaleKind),
        ))
        .go();
  }

  /// Comprehensive data import for multi-device migration.
  /// Overwrites current local data with the provided backup map.
  Future<void> importBackupData(Map<String, dynamic> data) async {
    await transaction(() async {
      // 1. Clear existing data
      await clearAllData();

      // 2. Import items (products)
      final products = data['products'] as List<dynamic>? ?? [];
      for (final p in products) {
        await into(items).insert(
          ItemsCompanion.insert(
            id: Value(p['id'].toString()),
            name: p['name']?.toString() ?? 'Unnamed',
            price: (p['unit_price'] as num?)?.toDouble() ?? 0.0,
            sku: Value(p['sku']?.toString()),
            stockQty: Value((p['current_stock'] as num?)?.toInt() ?? 0),
            lowStockWarning: Value((p['min_qty'] as num?)?.toInt()),
            categoryId: Value(p['category_id']?.toString()),
            brandId: Value(p['brand_id']?.toString()),
            imageUrl: Value(p['thumbnail_img']?.toString()),
            stockEnabled: Value(true),
            publishedOnline: Value(
              p['published'] == 1 || p['published'] == true,
            ),
            updatedAt: Value(
              DateTime.tryParse(p['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }

      // 3. Import customers (note: Customers schema has limited fields)
      final customersData = data['customers'] as List<dynamic>? ?? [];
      for (final c in customersData) {
        await into(customers).insert(
          CustomersCompanion.insert(
            id: Value(c['id'].toString()),
            name: c['name']?.toString() ?? 'Customer',
            phone: Value(c['phone']?.toString()),
            email: Value(c['email']?.toString()),
            note: Value(c['address']?.toString()), // Map address to note field
          ),
        );
      }

      // 4. Import transactions (ledger entries)
      final transactions = data['transactions'] as List<dynamic>? ?? [];
      for (final t in transactions) {
        final txId = t['id']?.toString() ?? _uuid.v4();
        await into(ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: Value(txId),
            idempotencyKey: 'backup_$txId',
            type: t['type']?.toString() ?? 'sale',
            total: Value((t['grand_total'] as num?)?.toDouble() ?? 0.0),
            createdAt: Value(
              DateTime.tryParse(t['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }
    });
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

class StockAlertWithItem {
  const StockAlertWithItem({required this.alert, required this.item});

  final StockAlert alert;
  final Item item;
}

class ParkedSales extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get linesJson => text()(); // JSON array of CartLine
  TextColumn get notes => text().nullable()();
  TextColumn get customerId => text().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get saleKind =>
      text().withDefault(const Constant('parked'))(); // active_cart | parked
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}


// ─── Built-in expense category seeds ──────────────────────────────────────────
const _expenseCategorySeeds = <String>[
  'Shop Rent', 'Office Rent', 'Electricity Bill', 'Water Bill', 'Internet / WiFi',
  'Phone Bill', 'Generator Fuel', 'Generator Maintenance', 'Cleaning & Sanitation',
  'Waste Disposal', 'Security Guard', 'CCTV / Alarm Service', 'Premises Insurance',
  'Property Taxes', 'Repairs & Maintenance', 'Plumbing Repairs', 'Electrical Repairs',
  'Pest Control', 'Air Conditioning Service', 'Fire Extinguisher Refill',
  'Staff Salaries', 'Staff Wages (Daily)', 'Casual Labour', 'Staff Overtime',
  'Staff Bonuses', 'Staff Commission', 'Staff Allowances', 'Staff Transport',
  'Staff Uniforms', 'Staff Meals / Lunch', 'Staff Training', 'Staff Medical',
  'Staff Loan Advance', 'NSSF Contributions', 'PAYE Tax', 'Recruitment Costs',
  'Stock Purchase', 'Raw Materials', 'Packaging Materials', 'Bags & Wrapping',
  'Labels & Stickers', 'Spoilage / Wastage', 'Stock Insurance', 'Cold Storage',
  'Fumigation',
  'Fuel', 'Vehicle Hire', 'Boda Boda / Taxi', 'Bus Fare', 'Delivery Costs',
  'Courier Fees', 'Customs & Import Duties', 'Clearing Charges', 'Freight / Shipping',
  'Vehicle Maintenance', 'Vehicle Insurance', 'Car Wash', 'Parking Fees', 'Toll Fees',
  'Loading / Offloading',
  'Advertising (Online)', 'Facebook / Instagram Ads', 'Google Ads', 'TikTok Ads',
  'Radio Advertising', 'TV Advertising', 'Newspaper Adverts', 'Flyers & Brochures',
  'Banners & Signage', 'Business Cards', 'Branded T-Shirts', 'Promotional Items',
  'Sponsorships', 'Event Costs', 'Photography & Videography', 'Content Creation',
  'Social Media Management', 'Website / App Costs', 'Domain & Hosting',
  'SMS Marketing', 'WhatsApp Marketing',
  'Equipment Purchase', 'Equipment Hire / Rental', 'Equipment Maintenance',
  'Computer / Laptop', 'Printer', 'Printer Ink & Toner', 'POS Machine',
  'POS Machine Maintenance', 'Software Subscription', 'Accounting Software',
  'Phone / Tablet Purchase', 'UPS / Inverter', 'Cloud Storage',
  'Bank Charges', 'Mobile Money Charges', 'ATM Withdrawal Fees', 'Loan Repayment',
  'Loan Interest', 'Credit Card Fees', 'Payment Gateway Fees', 'Insurance Premium',
  'Business License', 'Trade License', 'Health License', 'URA Tax Payment',
  'VAT Filing Costs', 'KCCA Fees', 'Local Council Fees', 'Accountant / Audit Fees',
  'Legal Fees', 'Company Registration',
  'Office Supplies', 'Pens & Stationery', 'Books & Notebooks', 'Printing (Office)',
  'Photocopying', 'Postage / Courier',
  'Client Entertainment', 'Client Gifts', 'Tea & Coffee (Office)', 'Staff Refreshments',
  'Business Lunch', 'Business Dinner', 'Hotel Accommodation', 'Travel Expenses', 'Airfare',
  'Medical Expenses', 'First Aid Supplies', 'Safety Equipment', 'Protective Gear (PPE)',
  'Medical Insurance',
  'Cooking Gas / LPG', 'Cooking Oil', 'Charcoal', 'Firewood', 'Food Ingredients',
  'Disposable Plates & Cups', 'Food Containers', 'Market Fees', 'Health Inspection Fee',
  'Beauty Products Stock', 'Hair Extensions', 'Wigs & Weaves', 'Nail Products',
  'Salon Equipment',
  'Building Materials', 'Cement & Bricks', 'Iron Sheets', 'Sand & Gravel',
  'Paint & Varnish', 'Labour (Construction)', 'Scaffold Hire', 'Machinery Hire',
  'Seeds', 'Fertiliser', 'Pesticides', 'Farm Labour', 'Land Hire', 'Veterinary Costs',
  'Animal Feed', 'Livestock Purchase', 'Farm Equipment',
  'Motorcycle Service', 'Tyre Replacement', 'Road Licence Renewal',
  'Third Party Insurance',
  'Petty Cash', 'Miscellaneous', 'Fines / Penalties', 'Donations / Charity',
  'Association Dues', 'Trade Fair Costs', 'Consultancy Fees', 'Subscription Services',
  'Bad Debts Written Off', 'Other Expenses',
];
