import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_client.dart';

class SellerApi {
  SellerApi({required this.client, required this.config, required this.storage});

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

  Future<Response<dynamic>> fetchOrderItems(int orderId) {
    return client.post('/v2/seller/orders/items/$orderId');
  }

  Future<Response<dynamic>> fetchOrderDetails(int orderId) {
    return client.get('/v2/seller/orders/details/$orderId');
  }

  Future<Response<dynamic>> updateOrderStatus({
    required int orderId,
    required String deliveryStatus,
    required String paymentStatus,
  }) {
    return client.post('/v2/seller/orders/update-delivery-status', data: {
      'order_id': orderId,
      'delivery_status': deliveryStatus,
      'payment_status': paymentStatus,
    });
  }

  // Refund requests (marketplace)
  Future<Response<dynamic>> fetchRefundRequests({int page = 1}) {
    return client.get('/v2/seller/refunds', query: {'page': page});
  }

  Future<Response<dynamic>> approveRefundRequest({required int refundId}) {
    return client.post('/v2/seller/refunds/approve', data: {'refund_id': refundId});
  }

  Future<Response<dynamic>> rejectRefundRequest({required int refundId, String? reason}) {
    return client.post('/v2/seller/refunds/reject', data: {
      'refund_id': refundId,
      if (reason != null) 'reject_reason': reason,
    });
  }

  // Products
  Future<Response<dynamic>> createProduct(Map<String, dynamic> payload) {
    return client.post('/v2/seller/products/add', data: payload);
  }

  Future<Response<dynamic>> updateProduct(String productId, Map<String, dynamic> payload) {
    return client.post('/v2/seller/products/update/$productId', data: payload);
  }

  Future<Response<dynamic>> fetchProducts({int page = 1}) {
    return client.get('/v2/seller/products/all', query: {'page': page});
  }

  // Services (service-provider addon)
  Future<Response<dynamic>> createService(Map<String, dynamic> payload) {
    return client.post('/v2/service-provider/offerings', data: payload);
  }

  Future<Response<dynamic>> updateService(String id, Map<String, dynamic> payload) {
    return client.patch('/v2/service-provider/offerings/$id', data: payload);
  }

  Future<Response<dynamic>> fetchMyServices() {
    return client.get('/v2/service-provider/my/offerings');
  }

  Future<Response<dynamic>> fetchServiceBookings() {
    return client.get('/v2/service-provider/provider/bookings');
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
    return client.get('/v2/seller/pos/sync/pull', query: {'since': since.toUtc().toIso8601String()});
  }

  Future<Response<dynamic>> fetchPosCustomers() {
    return client.get('/v2/seller/pos/get-customers');
  }

  Future<Response<dynamic>> fetchPosConfig() {
    return client.get('/v2/seller/pos/configuration');
  }

  Future<Response<dynamic>> updateDeviceToken(String token) {
    return client.post('/v2/profile/update-device-token', data: {
      'device_token': token,
      'platform': 'flutter',
    });
  }

  // Coupons
  Future<Response<dynamic>> fetchCoupons() {
    return client.get('/v2/seller/coupon/all');
  }

  Future<Response<dynamic>> createCoupon(Map<String, dynamic> payload) {
    return client.post('/v2/seller/coupon/create', data: payload);
  }

  Future<Response<dynamic>> updateCoupon(int couponId, Map<String, dynamic> payload) {
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
    return client.post('/v2/seller/conversations/message/store', data: {
      'conversation_id': conversationId,
      'message': message,
    });
  }

  // Auctions
  Future<Response<dynamic>> fetchAuctionProducts({int page = 1}) {
    return client.get('/v2/seller/auction-products', query: {'page': page});
  }

  Future<Response<dynamic>> fetchAuctionProductBids(int productId, {int page = 1}) {
    return client.get('/v2/seller/auction-product-bids/edit/$productId', query: {'page': page});
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
    return client.post('/v2/seller/shop-update', data: payload);
  }

  Future<Response<dynamic>> fetchSellerProfile() {
    return client.get('/v2/seller/profile');
  }

  Future<Response<dynamic>> updateProfile(Map<String, dynamic> payload) {
    return client.post('/v2/profile/update', data: payload);
  }

  // POS configuration (printer width)
  Future<Response<dynamic>> updatePosConfig(Map<String, dynamic> payload) {
    return client.post('/v2/seller/pos/configuration/update', data: payload);
  }

  // Product delete
  Future<Response<dynamic>> deleteProduct(String productId) {
    return client.get('/v2/seller/product/delete/$productId');
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
    return client.post('/v2/seller/seller-package/free-package', data: {
      'package_id': packageId,
      'payment_option': paymentOption,
      if (amount != null) 'amount': amount,
    });
  }

  Future<Response<dynamic>> purchaseSellerPackageOffline({
    required int packageId,
    required String paymentOption,
    String? trxId,
    String? photoBase64,
  }) {
    return client.post('/v2/seller/seller-package/offline-payment', data: {
      'package_id': packageId,
      'payment_option': paymentOption,
      if (trxId != null && trxId.trim().isNotEmpty) 'trx_id': trxId.trim(),
      if (photoBase64 != null && photoBase64.trim().isNotEmpty) 'photo': photoBase64.trim(),
    });
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
}
