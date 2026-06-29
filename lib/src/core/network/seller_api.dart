import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_client.dart';
import '../../features/bnpl/models/bnpl_seller_status.dart';
import '../../features/bnpl/models/product_bnpl_payload.dart';
import '../../features/bnpl/models/service_bnpl_payload.dart';

class SellerApi {
  SellerApi({
    required this.client,
    required this.config,
    required this.storage,
  });

  final ApiClient client;
  final AppConfig config;
  final SecureStorage storage;

  // Orders
  Future<Response<dynamic>> pushTransaction(Map<String, dynamic> payload) {
    // Seller POS order creation.
    return client.post('/v2/seller/pos/order-place', data: payload);
  }

  Future<Response<dynamic>> fetchOrders() {
    return client.get('/v2/seller/orders');
  }

  Future<Response<dynamic>> createPosTransaction(Map<String, dynamic> payload) {
    return client.post('/v2/seller/pos/sales', data: payload);
  }

  Future<Response<dynamic>> fetchReceiptDetails(int receiptId) {
    return client.get('/v2/seller/pos/transactions/$receiptId');
  }

  Future<Response<dynamic>> fetchOrderItems(int orderId) {
    return client.post('/v2/seller/orders/items/$orderId');
  }

  Future<Response<dynamic>> fetchOrderDetails(int orderId) {
    return client.get('/v2/seller/orders/details/$orderId');
  }

  Future<Response<dynamic>> updateOrderDeliveryStatus({
    required int orderId,
    required String status,
  }) {
    return client.post(
      '/v2/seller/orders/update-delivery-status',
      data: {'order_id': orderId, 'status': status},
    );
  }

  Future<Response<dynamic>> updateOrderPaymentStatus({
    required int orderId,
    required String status,
  }) {
    return client.post(
      '/v2/seller/orders/update-payment-status',
      data: {'order_id': orderId, 'status': status},
    );
  }

  Future<Response<dynamic>> requestSokoDelivery(int orderId) {
    return client.post(
      '/v2/seller/request-soko-delivery',
      data: {'order_id': orderId},
    );
  }

  // Refund requests (marketplace)
  Future<Response<dynamic>> fetchRefundRequests({int page = 1}) {
    return client.get('/v2/seller/refunds', query: {'page': page});
  }

  Future<Response<dynamic>> approveRefundRequest({required int refundId}) {
    return client.post(
      '/v2/seller/refunds/approve',
      data: {'refund_id': refundId},
    );
  }

  Future<Response<dynamic>> rejectRefundRequest({
    required int refundId,
    String? reason,
  }) {
    return client.post(
      '/v2/seller/refunds/reject',
      data: {
        'refund_id': refundId,
        if (reason != null) 'reject_reason': reason,
      },
    );
  }

  // Products
  Future<Response<dynamic>> createProduct(Map<String, dynamic> payload) {
    return client.post('/v2/seller/products/add', data: payload);
  }

  Future<Response<dynamic>> updateProduct(
    String productId,
    Map<String, dynamic> payload,
  ) {
    return client.post('/v2/seller/products/update/$productId', data: payload);
  }

  Future<Response<dynamic>> fetchCategories() {
    return client.get('/v2/seller/products/categories');
  }

  Future<Response<dynamic>> createCategory(Map<String, dynamic> payload) {
    return client.post('/v2/seller/products/categories', data: payload);
  }

  Future<Response<dynamic>> fetchBrands() {
    return client.get('/v2/seller/products/brands');
  }

  Future<Response<dynamic>> deleteProduct(String productId) {
    // Use staff-friendly POS catalog endpoint (works with staff:pos tokens).
    return client.delete('/v2/seller/pos/catalog/products/$productId');
  }

  Future<Response<dynamic>> fetchProducts({int page = 1}) {
    return client.get('/v2/seller/products/all', query: {'page': page});
  }

  Future<Response<dynamic>> fetchProductDetails(int productId) {
    return client.get('/v2/seller/products/edit/$productId');
  }

  // Uploads
  Future<Response<dynamic>> fetchSellerFiles({
    String? type,
    String sort = 'newest',
    int page = 1,
    String? search,
  }) {
    final q = <String, dynamic>{'sort': sort, 'page': page};
    if (type != null) q['type'] = type;
    if (search != null && search.isNotEmpty) q['search'] = search;
    return client.get('/v2/seller/file/all', query: q);
  }

  Future<Response<dynamic>> uploadSellerFile(File file) async {
    final form = FormData.fromMap({
      'aiz_file': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
    });
    return client.post(
      '/v2/seller/file/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Services (service-provider addon)
  Future<Response<dynamic>> createService(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) {
    return client.post(
      '/v2/service-provider/offerings',
      data: payload,
      options: idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> updateService(
    String id,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) {
    return client.patch(
      '/v2/service-provider/offerings/$id',
      data: payload,
      options: idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> deleteService(String id) {
    return client.delete('/v2/service-provider/offerings/$id');
  }

  Future<Response<dynamic>> fetchMyServices() {
    return client.get('/v2/service-provider/my/offerings');
  }

  Future<Response<dynamic>> fetchServiceDetails(int serviceId) {
    return client.get('/v2/service-provider/offerings/$serviceId');
  }

  Future<Response<dynamic>> fetchServiceCategories() {
    return client.get('/v2/service-provider/catalog/categories');
  }

  Future<Response<dynamic>> fetchServiceBookings() {
    return client.get('/v2/service-provider/provider/bookings');
  }

  Future<Response<dynamic>> confirmServiceBooking(int bookingId) {
    return client.post(
      '/v2/service-provider/provider/bookings/$bookingId/confirm',
    );
  }

  Future<Response<dynamic>> completeServiceBooking(int bookingId) {
    return client.post(
      '/v2/service-provider/provider/bookings/$bookingId/complete',
    );
  }

  Future<Response<dynamic>> cancelServiceBooking(
    int bookingId, {
    String? reason,
  }) {
    return client.post(
      '/v2/service-provider/provider/bookings/$bookingId/cancel',
      data: {if (reason != null) 'reason': reason},
    );
  }

  Future<Response<dynamic>> createServiceBooking(Map<String, dynamic> data) {
    return client.post('/v2/service-provider/provider/bookings', data: data);
  }

  Future<Response<dynamic>> rescheduleServiceBooking(int id, Map<String, dynamic> data) {
    return client.post('/v2/service-provider/provider/bookings/$id/reschedule', data: data);
  }

  // Time Logs
  Future<Response<dynamic>> fetchServiceTimeLogs() {
    return client.get('/v2/service-provider/provider/time-logs');
  }

  Future<Response<dynamic>> createServiceTimeLog(Map<String, dynamic> data) {
    return client.post('/v2/service-provider/provider/time-logs', data: data);
  }

  // Clients
  Future<Response<dynamic>> fetchServiceClients({String? search}) {
    return client.get(
      '/v2/service-provider/provider/clients',
      query: {if (search != null && search.isNotEmpty) 'search': search},
    );
  }

  Future<Response<dynamic>> fetchServiceClientDetail(int clientId) {
    return client.get('/v2/service-provider/provider/clients/$clientId');
  }

  Future<Response<dynamic>> fetchServiceClientHistory(int clientId) {
    return client.get('/v2/service-provider/provider/clients/$clientId/history');
  }

  Future<Response<dynamic>> updateServiceClientNotes(int clientId, String notes) {
    return client.post(
      '/v2/service-provider/provider/clients/$clientId/notes',
      data: {'notes': notes},
    );
  }

  // Availability
  Future<Response<dynamic>> fetchAvailability() {
    return client.get('/v2/service-provider/provider/availability');
  }

  Future<Response<dynamic>> updateAvailability(List<Map<String, dynamic>> schedules) {
    return client.post('/v2/service-provider/provider/availability', data: {'schedules': schedules});
  }

  Future<Response<dynamic>> fetchAvailabilityExceptions() {
    return client.get('/v2/service-provider/provider/availability/exceptions');
  }

  Future<Response<dynamic>> addAvailabilityException(Map<String, dynamic> data) {
    return client.post('/v2/service-provider/provider/availability/exceptions', data: data);
  }

  Future<Response<dynamic>> deleteAvailabilityException(int id) {
    return client.delete('/v2/service-provider/provider/availability/exceptions/$id');
  }

  Future<Response<dynamic>> fetchAvailableSlots({
    required int offeringId,
    required String date,
    String? timezone,
  }) {
    return client.get(
      '/v2/service-provider/provider/available-slots',
      query: {
        'offering_id': offeringId,
        'date': date,
        if (timezone != null) 'timezone': timezone,
      },
    );
  }

  // POS / Ledger
  Future<Response<dynamic>> pushLedgerEntry(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/ledger-entries',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> pullPosSync({required DateTime since}) {
    return client.get(
      '/v2/seller/pos/sync/pull',
      query: {'since': since.toUtc().toIso8601String()},
    );
  }

  // POS Catalog Products (offline-first upsert)
  Future<Response<dynamic>> upsertPosCatalogProduct(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/catalog/products',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  /// Upload terminal bug / crash reports captured offline.
  Future<Response<dynamic>> submitTerminalFeedbackBatch(
    List<Map<String, dynamic>> reports,
  ) {
    return client.post(
      '/v2/seller/pos/feedback/batch',
      data: {'reports': reports},
    );
  }

  Future<Response<dynamic>> fetchPosCustomers() {
    return client.get('/v2/seller/pos/get-customers');
  }

  Future<Response<dynamic>> fetchPosConfig() {
    return client.get('/v2/seller/pos/configuration');
  }

  // Procurement & inventory control (Phase 7)
  Future<Response<dynamic>> fetchSuppliers() {
    return client.get('/v2/seller/pos/suppliers');
  }

  Future<Response<dynamic>> createSupplier(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/suppliers',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> updateSupplier(
    int supplierId,
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.put(
      '/v2/seller/pos/suppliers/$supplierId',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> deleteSupplier(
    int supplierId, {
    required String idempotencyKey,
  }) {
    return client.delete(
      '/v2/seller/pos/suppliers/$supplierId',
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> fetchPurchaseOrders() {
    return client.get('/v2/seller/pos/purchase-orders');
  }

  Future<Response<dynamic>> fetchPurchaseOrderDetails(int purchaseOrderId) {
    return client.get('/v2/seller/pos/purchase-orders/$purchaseOrderId');
  }

  Future<Response<dynamic>> createPurchaseOrder(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/purchase-orders',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> cancelPurchaseOrder(
    int purchaseOrderId, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/purchase-orders/$purchaseOrderId/cancel',
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> markPurchaseOrderSent(
    int purchaseOrderId, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/purchase-orders/$purchaseOrderId/mark-sent',
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> fetchGoodsReceivedNotes() {
    return client.get('/v2/seller/pos/goods-received-notes');
  }

  Future<Response<dynamic>> pushGoodsReceivedNote(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/goods-received-notes',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> fetchStocktakes() {
    return client.get('/v2/seller/pos/stocktakes');
  }

  Future<Response<dynamic>> pushStocktake(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/stocktakes',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> updateDeviceToken(String token) {
    return client.post(
      '/v2/profile/update-device-token',
      data: {'device_token': token, 'platform': 'flutter'},
    );
  }

  // Notifications (new unified notification system)
  Future<Response<dynamic>> fetchNotifications({
    int perPage = 20,
    int page = 1,
  }) {
    return client.get(
      '/v2/seller/notifications',
      query: {'per_page': perPage, 'page': page},
    );
  }

  Future<Response<dynamic>> fetchUnreadNotificationCount() {
    return client.get('/v2/seller/notifications/unread-count');
  }

  Future<Response<dynamic>> markNotificationRead(String notificationId) {
    return client.post('/v2/seller/notifications/$notificationId/read');
  }

  Future<Response<dynamic>> markAllNotificationsRead() {
    return client.post('/v2/seller/notifications/read-all');
  }

  Future<Response<dynamic>> deleteNotification(String notificationId) {
    return client.delete('/v2/seller/notifications/$notificationId');
  }

  Future<Response<dynamic>> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
    String? appVersion,
  }) {
    return client.post(
      '/v2/seller/notifications/device-token',
      data: {
        'token': token,
        'platform': platform,
        if (deviceId != null) 'device_id': deviceId,
        if (appVersion != null) 'app_version': appVersion,
      },
    );
  }

  Future<Response<dynamic>> removeDeviceToken(String token) {
    return client.delete(
      '/v2/seller/notifications/device-token',
      data: {'token': token},
    );
  }

  Future<Response<dynamic>> fetchNotificationPreferences() {
    return client.get('/v2/seller/notifications/preferences');
  }

  Future<Response<dynamic>> updateNotificationPreferences({
    required String category,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
  }) {
    return client.post(
      '/v2/seller/notifications/preferences',
      data: {
        'category': category,
        if (pushEnabled != null) 'push_enabled': pushEnabled,
        if (emailEnabled != null) 'email_enabled': emailEnabled,
        if (smsEnabled != null) 'sms_enabled': smsEnabled,
      },
    );
  }

  // Seller SMS module
  Future<Response<dynamic>> fetchSmsDashboard() {
    return client.get('/v2/seller/sms/dashboard');
  }

  Future<Response<dynamic>> fetchSmsCampaigns({
    int perPage = 20,
    int page = 1,
  }) {
    return client.get(
      '/v2/seller/sms/campaigns',
      query: {'per_page': perPage, 'page': page},
    );
  }

  Future<Response<dynamic>> createSmsCampaign(Map<String, dynamic> payload) {
    return client.post('/v2/seller/sms/campaigns', data: payload);
  }

  Future<Response<dynamic>> sendSmsCampaign(int campaignId) {
    return client.post('/v2/seller/sms/campaigns/$campaignId/send');
  }

  Future<Response<dynamic>> fetchSmsTemplates() {
    return client.get('/v2/seller/sms/templates');
  }

  Future<Response<dynamic>> createSmsTemplate(Map<String, dynamic> payload) {
    return client.post('/v2/seller/sms/templates', data: payload);
  }

  Future<Response<dynamic>> sendSingleSms(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/sms/send',
      data: payload,
      options: idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // Seller wallet and in-house purchases
  Future<Response<dynamic>> fetchSellerWalletDashboard() {
    return client.get('/v2/seller/wallet');
  }

  Future<Response<dynamic>> createSellerWalletTopup(
    double amount, {
    String? idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/wallet/topups',
      data: {'amount': amount},
      options: idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> fetchSellerWalletTopupStatus(int topupId) {
    return client.get('/v2/seller/wallet/topups/$topupId');
  }

  Future<Response<dynamic>> createSellerWalletPurchase({
    required String type,
    int? quantity,
    Map<String, dynamic>? extra,
    String? idempotencyKey,
  }) {
    final payload = <String, dynamic>{
      'type': type,
      if (quantity != null) 'quantity': quantity,
      if (extra != null) ...extra,
    };
    return client.post(
      '/v2/seller/wallet/purchases',
      data: payload,
      options: idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // Coupons
  Future<Response<dynamic>> fetchCoupons() {
    return client.get('/v2/seller/coupon/all');
  }

  Future<Response<dynamic>> createCoupon(Map<String, dynamic> payload) {
    return client.post('/v2/seller/coupon/create', data: payload);
  }

  Future<Response<dynamic>> updateCoupon(
    int couponId,
    Map<String, dynamic> payload,
  ) {
    return client.post('/v2/seller/coupon/update/$couponId', data: payload);
  }

  Future<Response<dynamic>> deleteCoupon(int couponId) {
    return client.get('/v2/seller/coupon/delete/$couponId');
  }

  // Conversations
  Future<Response<dynamic>> fetchConversations() {
    return client.get('/v2/seller/conversations');
  }

  Future<Response<dynamic>> fetchConversationMessages(int conversationId) {
    return client.get('/v2/seller/conversations/show/$conversationId');
  }

  Future<Response<dynamic>> sendConversationMessage({
    required int conversationId,
    required String message,
  }) {
    return client.post(
      '/v2/seller/conversations/message/store',
      data: {'conversation_id': conversationId, 'message': message},
    );
  }

  // Auctions
  Future<Response<dynamic>> fetchAuctionProducts({int page = 1}) {
    return client.get('/v2/seller/auction-products', query: {'page': page});
  }

  Future<Response<dynamic>> fetchAuctionProductBids(
    int productId, {
    int page = 1,
  }) {
    return client.get(
      '/v2/seller/auction-product-bids/edit/$productId',
      query: {'page': page},
    );
  }

  Future<Response<dynamic>> deleteAuctionBid(int bidId) {
    return client.get('/v2/seller/auction-product-bids/destroy/$bidId');
  }

  // Wholesale & digital products
  Future<Response<dynamic>> fetchWholesaleProducts({int page = 1}) {
    return client.get('/v2/seller/wholesale-products', query: {'page': page});
  }

  Future<Response<dynamic>> fetchDigitalProducts({int page = 1}) {
    return client.get('/v2/seller/digital-products', query: {'page': page});
  }

  // Shop / profile
  Future<Response<dynamic>> fetchShopInfo() {
    return client.get('/v2/seller/shop/info');
  }

  Future<Response<dynamic>> updateShopInfo(Map<String, dynamic> payload) {
    return _updateShopInfoWithFallback(payload);
  }

  Future<Response<dynamic>> _updateShopInfoWithFallback(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await client.post('/v2/seller/shop-update', data: payload);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 405) {
        return client.post('/v2/seller/shop/update', data: payload);
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> fetchSellerProfile() {
    return client.get('/v2/seller/profile');
  }

  Future<Response<dynamic>> updateProfile(Map<String, dynamic> payload) {
    return client.post('/v2/profile/update', data: payload);
  }

  // Seller delivery profile (local delivery)
  Future<Response<dynamic>> fetchDeliveryProfile() {
    return client.get('/v2/seller/delivery-profile');
  }

  Future<Response<dynamic>> upsertDeliveryProfile(
    Map<String, dynamic> payload,
  ) {
    return client.post('/v2/seller/delivery-profile', data: payload);
  }

  // POS configuration (printer width)
  Future<Response<dynamic>> updatePosConfig(Map<String, dynamic> payload) {
    return client.post('/v2/seller/pos/configuration/update', data: payload);
  }

  // POS business profile (outlet + payment settings)
  Future<Response<dynamic>> fetchPosBusinessProfile() {
    return client.get('/v2/seller/pos/business/profile');
  }

  Future<Response<dynamic>> updatePosBusinessProfile(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.patch(
      '/v2/seller/pos/business/profile',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> fetchPosOutlets() {
    return client.get('/v2/seller/pos/outlets');
  }

  // Verification form
  Future<Response<dynamic>> fetchVerificationForm() {
    return client.get('/v2/seller/shop-verify-form');
  }

  Future<Response<dynamic>> submitVerification(FormData formData) {
    return client.post(
      '/v2/seller/shop-verify-info-store',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Seller packages
  Future<Response<dynamic>> fetchSellerPackages() {
    return client.get('/v2/seller/seller-packages-list');
  }

  Future<Response<dynamic>> purchaseSellerPackageFree({
    required int packageId,
    String paymentOption = 'free',
    double? amount,
  }) {
    return client.post(
      '/v2/seller/seller-package/free-package',
      data: {
        'package_id': packageId,
        'payment_option': paymentOption,
        if (amount != null) 'amount': amount,
      },
    );
  }

  Future<Response<dynamic>> purchaseSellerPackageOffline({
    required int packageId,
    required String paymentOption,
    String? trxId,
    String? photoBase64,
  }) {
    return client.post(
      '/v2/seller/seller-package/offline-payment',
      data: {
        'package_id': packageId,
        'payment_option': paymentOption,
        if (trxId != null && trxId.trim().isNotEmpty) 'trx_id': trxId.trim(),
        if (photoBase64 != null && photoBase64.trim().isNotEmpty)
          'photo': photoBase64.trim(),
      },
    );
  }

  // POS v2: Cash movements + audit logs (idempotent)
  Future<Response<dynamic>> pushCashMovement(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/cash-movements',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> pushAuditLog(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/audit-logs',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // POS Expenses
  Future<Response<dynamic>> fetchExpenses({DateTime? since}) {
    return client.get(
      '/v2/seller/pos/expenses',
      query: {if (since != null) 'since': since.toUtc().toIso8601String()},
    );
  }

  Future<Response<dynamic>> pushExpense(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/expenses',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // POS Quotations
  Future<Response<dynamic>> fetchQuotations({int page = 1}) {
    return client.get('/v2/seller/pos/quotations', query: {'page': page});
  }

  Future<Response<dynamic>> fetchQuotationDetails(String quotationId) {
    return client.get('/v2/seller/pos/quotations/$quotationId');
  }

  Future<Response<dynamic>> pushQuotation(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/quotations',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // POS Receipt Templates
  Future<Response<dynamic>> fetchReceiptTemplates() {
    return client.get('/v2/seller/pos/receipt-templates');
  }

  Future<Response<dynamic>> pushReceiptTemplate(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/receipt-templates',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // POS Expense Categories
  Future<Response<dynamic>> fetchExpenseCategories() {
    return client.get('/v2/seller/pos/expense-categories');
  }

  Future<Response<dynamic>> pushExpenseCategory(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/expense-categories',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> deleteExpenseCategory(String id) {
    return client.delete('/v2/seller/pos/expense-categories/$id');
  }

  // POS Customers (seller-scoped CRM contacts)
  Future<Response<dynamic>> fetchSellerCustomers({
    int page = 1,
    DateTime? since,
  }) {
    return client.get(
      '/v2/seller/pos/customers',
      query: {
        'page': page,
        if (since != null) 'updated_since': since.toUtc().toIso8601String(),
      },
    );
  }

  Future<Response<dynamic>> fetchSellerCustomerDetails(String customerId) {
    return client.get('/v2/seller/pos/customers/$customerId');
  }

  Future<Response<dynamic>> pushCustomer(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/customers',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> deleteCustomer(String customerId) {
    return client.delete('/v2/seller/pos/customers/$customerId');
  }

  // POS Sessions (staff PIN login)
  Future<Response<dynamic>> startPosSession({required String pin}) {
    return client.post('/v2/seller/pos/sessions/start', data: {'pin': pin});
  }

  Future<Response<dynamic>> endPosSession() {
    return client.post('/v2/seller/pos/sessions/end');
  }

  Future<Response<dynamic>> posSessionMe() {
    return client.get('/v2/seller/pos/sessions/me');
  }

  // CRM Contacts
  Future<Response<dynamic>> batchUpsertCrmContacts(
    List<Map<String, dynamic>> contacts,
  ) {
    return client.post(
      '/v2/seller/crm/contacts/batch',
      data: {'contacts': contacts},
    );
  }

  Future<Response<dynamic>> fetchCrmContacts({
    String? updatedSince,
    String? q,
    int perPage = 100,
    int page = 1,
  }) {
    return client.get(
      // Fixed: was /v2/crm/contacts (missing /seller prefix), now routed correctly
      '/v2/seller/crm/contacts',
      query: {
        if (updatedSince != null) 'updated_since': updatedSince,
        if (q != null && q.isNotEmpty) 'q': q,
        'per_page': perPage,
        'page': page,
      },
    );
  }

  // CRM Contact Notes
  Future<Response<dynamic>> fetchContactNotes(String contactId) {
    return client.get('/v2/seller/crm/contacts/$contactId/notes');
  }

  Future<Response<dynamic>> createContactNote(
    String contactId, {
    required String body,
    String type = 'note',
    Map<String, dynamic>? meta,
    bool isPinned = false,
    String? clientNoteId,
  }) {
    return client.post(
      '/v2/seller/crm/contacts/$contactId/notes',
      data: {
        'body': body,
        'type': type,
        if (meta != null) 'meta': meta,
        'is_pinned': isPinned,
        if (clientNoteId != null) 'client_note_id': clientNoteId,
      },
    );
  }

  Future<Response<dynamic>> deleteContactNote(String contactId, String noteId) {
    return client.delete('/v2/seller/crm/contacts/$contactId/notes/$noteId');
  }

  Future<Response<dynamic>> toggleContactNotePin(String contactId, String noteId) {
    return client.patch('/v2/seller/crm/contacts/$contactId/notes/$noteId/pin', data: {});
  }

  // CRM Marketing
  Future<Response<dynamic>> createCrmCampaign(Map<String, dynamic> payload) {
    return client.post('/v2/seller/crm/campaigns', data: payload);
  }

  Future<Response<dynamic>> runCrmCampaign(String campaignId) {
    return client.post('/v2/seller/crm/campaigns/$campaignId/run');
  }

  // POS Staff
  Future<Response<dynamic>> fetchStaff() {
    return client.get('/v2/seller/pos/staff');
  }

  Future<Response<dynamic>> createStaff(Map<String, dynamic> payload) {
    return client.post('/v2/seller/pos/staff', data: payload);
  }

  Future<Response<dynamic>> updateStaff(int id, Map<String, dynamic> payload) {
    return client.put('/v2/seller/pos/staff/$id', data: payload);
  }

  Future<Response<dynamic>> deleteStaff(int id) {
    return client.delete('/v2/seller/pos/staff/$id');
  }

  Future<Response<dynamic>> bootstrapStaff(Map<String, dynamic> payload) {
    return client.post('/v2/seller/pos/staff/bootstrap', data: payload);
  }

  // POS Service Variants
  Future<Response<dynamic>> pushServiceVariant(Map<String, dynamic> payload) {
    return client.post('/v2/seller/pos/service-variants', data: payload);
  }

  Future<Response<dynamic>> deleteServiceVariant(String id) {
    return client.delete('/v2/seller/pos/service-variants/$id');
  }

  // POS Templates Sync
  Future<Response<dynamic>> batchUpsertTemplates({
    required List<Map<String, dynamic>> receiptTemplates,
    required List<Map<String, dynamic>> quotationTemplates,
  }) {
    return client.post(
      '/v2/seller/pos/templates/batch',
      data: {
        'receipt_templates': receiptTemplates,
        'quotation_templates': quotationTemplates,
      },
    );
  }

  // Server Exports (PR14)
  Future<Response<dynamic>> requestExport({
    required String type,
    int? outletId,
  }) {
    return client.post(
      '/v2/seller/pos/exports',
      data: {'type': type, if (outletId != null) 'outlet_id': outletId},
    );
  }

  // Support Bundles (PR15)
  Future<Response<dynamic>> uploadSupportBundle({
    required Map<String, dynamic> metadata,
    String? fileUrl,
  }) {
    return client.post(
      '/v2/seller/pos/support/bundles',
      data: {'metadata': metadata, if (fileUrl != null) 'file_url': fileUrl},
    );
  }

  // POS Shifts
  Future<Response<dynamic>> fetchShifts({DateTime? since}) {
    return client.get(
      '/v2/seller/pos/shifts',
      query: {if (since != null) 'since': since.toUtc().toIso8601String()},
    );
  }

  Future<Response<dynamic>> pushShift(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/shifts',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> closeShift(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/shifts/close',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // POS Settings
  Future<Response<dynamic>> fetchSettings() {
    return client.get('/v2/seller/pos/settings');
  }

  Future<Response<dynamic>> pushSetting(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/settings',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> batchPushSettings(
    List<Map<String, dynamic>> settings, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/settings/batch',
      data: {'settings': settings},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  // Staff Phone Login (for multi-device access)
  Future<Response<dynamic>> staffLogin({
    required String phone,
    required String pin,
  }) {
    return client.post(
      '/v2/seller/pos/staff/login',
      data: {'phone': phone, 'pin': pin},
    );
  }

  Future<Response<dynamic>> staffMe() {
    return client.get('/v2/seller/pos/staff/me');
  }

  // Customer Packages & Redemptions
  Future<Response<dynamic>> pushPackagePurchase(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/customer-packages',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<Response<dynamic>> pushPackageRedemption(
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) {
    return client.post(
      '/v2/seller/pos/package-redemptions',
      data: payload,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  /// Register a new seller with shop
  Future<Response<dynamic>> fetchSellerRegistrationPlans() async {
    final publicDio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    return publicDio.get('/v2/seller/register/plans');
  }

  Future<Response<dynamic>> registerSeller({
    required String name,
    String? email,
    required String phone,
    required String pin,
    required String shopName,
    String? address,
    double? latitude, // Shop business location
    double? longitude, // Shop business location
    double? registrationLatitude, // User's GPS at signup (analytics)
    double? registrationLongitude, // User's GPS at signup (analytics)
    String? category,
    double? deliveryRadiusKm,
    int? planId,
    String? planSlug,
  }) {
    // Use the public Dio instance (no auth token required)
    final publicDio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    publicDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('[HTTP:public] -> ${options.method} ${options.uri}');
          if (options.data != null) {
            debugPrint(
              '[HTTP:public]    data: ${_redactSensitive(options.data)}',
            );
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '[HTTP:public] <- ${response.statusCode} ${response.requestOptions.uri}',
          );
          if (response.data != null) {
            debugPrint(
              '[HTTP:public]    data: ${_redactSensitive(response.data)}',
            );
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint(
            '[HTTP:public] !! ${error.requestOptions.uri} ${error.message}',
          );
          if (error.response?.data != null) {
            debugPrint(
              '[HTTP:public]    data: ${_redactSensitive(error.response?.data)}',
            );
          }
          return handler.next(error);
        },
      ),
    );

    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'pin': pin,
      'shop_name': shopName,
      if (address != null && address.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      // User's registration location (GPS at signup) - separate from shop location
      if (registrationLatitude != null)
        'registration_latitude': registrationLatitude,
      if (registrationLongitude != null)
        'registration_longitude': registrationLongitude,
      if (category != null) 'category': category,
      if (deliveryRadiusKm != null) 'delivery_radius_km': deliveryRadiusKm,
      if (planId != null) 'plan_id': planId,
      if (planSlug != null && planSlug.isNotEmpty) 'plan_slug': planSlug,
    };

    Future<Response<dynamic>> send(Map<String, dynamic> body) {
      return publicDio.post('/v2/seller/register', data: body);
    }

    return send(payload).catchError((error) async {
      if (error is DioException) {
        final msg = _extractErrorMessage(error.response?.data);
        if (msg.contains("Unknown column 'latitude'") ||
            msg.contains("Unknown column 'longitude'")) {
          final retry = Map<String, dynamic>.from(payload)
            ..remove('latitude')
            ..remove('longitude')
            ..remove('registration_latitude')
            ..remove('registration_longitude');
          debugPrint('[HTTP:public] retry register without coordinates');
          return send(retry);
        }
      }
      throw error;
    });
  }

  static dynamic _redactSensitive(dynamic data) {
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final normalized = key.toString().toLowerCase();
        if (normalized.contains('password') ||
            normalized.contains('pin') ||
            normalized.contains('token') ||
            normalized.contains('authorization') ||
            normalized.contains('otp')) {
          result[key.toString()] = '***';
        } else {
          result[key.toString()] = value;
        }
      });
      return result;
    }
    if (data is List) {
      return data.map(_redactSensitive).toList();
    }
    return data;
  }

  // ─── Soko Studio (AI Ad Generation) ───────────────────────────

  Future<Response<dynamic>> studioRemoveBackground({
    required String imageUrl,
    bool edgeSmoothing = true,
  }) {
    return client.post('/v2/seller/studio/remove-bg', data: {
      'image_url': imageUrl,
      'edge_smoothing': edgeSmoothing,
    });
  }

  Future<Response<dynamic>> studioWebEntry({
    int? productId,
    int? serviceId,
    String? quotationId,
    int? receiptId,
    bool brandKit = false,
    String editorMode = 'design',
    String openPanel = 'smart-ads',
  }) {
    final q = <String, dynamic>{
      'editor_mode': editorMode,
      'open_panel': openPanel,
      'skip_home': 1,
    };
    if (productId != null) q['product_id'] = productId;
    if (serviceId != null) q['service_id'] = serviceId;
    if (quotationId != null) q['quotation_id'] = quotationId;
    if (receiptId != null) q['receipt_id'] = receiptId;
    if (brandKit) q['brand_kit'] = 1;
    return client.get('/v2/seller/studio/web-entry', query: q);
  }

  Future<Response<dynamic>> studioStyles() {
    return client.get('/v2/seller/studio/styles');
  }

  Future<Response<dynamic>> studioLlmStatus() {
    return client.get('/v2/seller/studio/llm-status');
  }

  Future<Response<dynamic>> studioListAds({int? productId, int? serviceId}) {
    final q = <String, dynamic>{};
    if (productId != null) q['product_id'] = productId;
    if (serviceId != null) q['service_id'] = serviceId;
    return client.get('/v2/seller/studio/ads', query: q);
  }

  Future<Response<dynamic>> studioGenerateAds({
    int? productId,
    int? serviceId,
    List<String>? styles,
    int count = 3,
  }) {
    return client.post('/v2/seller/studio/ads/generate', data: {
      if (productId != null) 'product_id': productId,
      if (serviceId != null) 'service_id': serviceId,
      if (styles != null) 'styles': styles,
      'count': count,
    });
  }

  Future<Response<dynamic>> studioAdStatus({int? productId, int? serviceId}) {
    final q = <String, dynamic>{};
    if (productId != null) q['product_id'] = productId;
    if (serviceId != null) q['service_id'] = serviceId;
    return client.get('/v2/seller/studio/ads/status', query: q);
  }

  Future<Response<dynamic>> studioGetAd(int id) {
    return client.get('/v2/seller/studio/ads/$id');
  }

  Future<Response<dynamic>> studioDeleteAd(int id) {
    return client.delete('/v2/seller/studio/ads/$id');
  }

  Future<Response<dynamic>> studioGenerateCaption(int adId) {
    return client.post('/v2/seller/studio/ads/$adId/caption');
  }

  // ── Brand Kit sync ────────────────────────────────────────────────────────

  Future<Response<dynamic>> fetchBrandKit() {
    return client.get('/v2/seller/studio/brand-kit');
  }

  Future<Response<dynamic>> saveBrandKit(Map<String, dynamic> payload) {
    return client.post('/v2/seller/studio/brand-kit', data: payload);
  }

  Future<Response<dynamic>> fetchStudioSavedTemplates() {
    return client.get('/v2/seller/studio/saved-templates');
  }

  Future<Response<dynamic>> saveStudioTemplate(Map<String, dynamic> payload) {
    return client.post('/v2/seller/studio/saved-templates', data: payload);
  }

  Future<Response<dynamic>> deleteStudioTemplate(String id) {
    return client.delete('/v2/seller/studio/saved-templates/$id');
  }

  Future<Response<dynamic>> fetchStudioCatalog() {
    return client.get('/v2/seller/studio/catalog');
  }

  Future<Response<dynamic>> recordStudioTemplateUse(String templateId) {
    return client.post('/v2/seller/studio/template-use', data: {
      'template_id': templateId,
    });
  }

  Future<Response<dynamic>> fetchStudioCloudStorage() {
    return client.get('/v2/seller/studio/cloud-storage');
  }

  // ─── Sanaa Finance BNPL ───────────────────────────────────────────────────

  Future<BnplSellerStatus> getBnplSellerStatus() async {
    final res = await client.get('/v2/seller/bnpl/status');
    final payload = _extractData(res.data);
    return BnplSellerStatus.fromJson(payload);
  }

  Future<void> requestBnplEnrollment() async {
    await client.post('/v2/seller/bnpl/enable-request');
  }

  Future<void> updateProductBnpl(
    int productId,
    ProductBnplPayload payload,
  ) async {
    await client.post(
      '/v2/seller/products/$productId/bnpl',
      data: payload.toJson(),
    );
  }

  Future<void> updateServiceBnpl(
    int serviceId,
    ServiceBnplPayload payload,
  ) async {
    await client.post(
      '/v2/seller/services/$serviceId/bnpl',
      data: payload.toJson(),
    );
  }

  Future<ProductBnplPayload?> getProductBnpl(int productId) async {
    final res = await client.get('/v2/seller/products/$productId/bnpl');
    final payload = _extractData(res.data);
    if (payload.isEmpty) return null;
    return ProductBnplPayload.fromJson(payload);
  }

  Future<ServiceBnplPayload?> getServiceBnpl(int serviceId) async {
    final res = await client.get('/v2/seller/services/$serviceId/bnpl');
    final payload = _extractData(res.data);
    if (payload.isEmpty) return null;
    return ServiceBnplPayload.fromJson(payload);
  }

  static Map<String, dynamic> _extractData(dynamic data) {
    if (data is Map) {
      final body = Map<String, dynamic>.from(data);
      if (body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return body;
    }
    return const <String, dynamic>{};
  }

  static String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final message = data['error'] ?? data['message'] ?? data['msg'];
      if (message != null) return message.toString();
    }
    return '';
  }
}
