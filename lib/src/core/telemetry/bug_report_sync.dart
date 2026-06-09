import 'package:flutter/foundation.dart';

import '../network/seller_api.dart';
import 'bug_logger.dart';

/// Uploads locally captured bug reports to the Soko24 backend for admin review.
class BugReportSync {
  BugReportSync._();

  static const _batchSize = 20;

  /// Upload pending reports. Returns count successfully acknowledged by server.
  static Future<int> uploadPending(SellerApi api) async {
    final pending = await BugLogger.instance.getPendingUploads();
    if (pending.isEmpty) return 0;

    var uploaded = 0;
    for (var i = 0; i < pending.length; i += _batchSize) {
      final chunk = pending.skip(i).take(_batchSize).toList();
      try {
        final res = await api.submitTerminalFeedbackBatch(
          chunk.map((r) => r.toUploadPayload()).toList(),
        );
        final body = res.data;
        if (body is Map && body['success'] == true) {
          final accepted = (body['accepted'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[];
          final duplicates = (body['duplicates'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[];
          for (final id in [...accepted, ...duplicates]) {
            await BugLogger.instance.markUploaded(id);
            uploaded++;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BugReportSync] Upload failed: $e');
        }
        break;
      }
    }
    return uploaded;
  }
}