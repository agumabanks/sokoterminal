import 'dart:async';
import 'dart:io';

import '../../core/network/seller_api.dart';

/// Result of a background-removal attempt.
class RemoveBackgroundResult {
  const RemoveBackgroundResult({
    required this.success,
    this.resultUrl,
    this.message,
  });

  final bool success;
  final String? resultUrl;
  final String? message;
}

/// Removes the background from an image using the backend's remove-bg endpoint.
///
/// [src] may be a remote http URL or a local file path (with or without
/// the `file://` prefix). Local files are uploaded first so the backend can
/// reach them.
///
/// The backend returns a `result_url` pointing to a PNG with the background
/// removed. If the server is not configured with a remove.bg API key it will
/// return a 503 and this function will surface that clearly.
Future<RemoveBackgroundResult> removeImageBackground({
  required SellerApi api,
  required String src,
  bool edgeSmoothing = true,
}) async {
  try {
    String imageUrl;
    if (src.startsWith('http')) {
      imageUrl = src;
    } else {
      final path = src.startsWith('file://') ? src.substring(7) : src;
      final file = File(path);
      if (!file.existsSync()) {
        return const RemoveBackgroundResult(
          success: false,
          message: 'Image file not found.',
        );
      }
      final uploadRes = await api.uploadSellerFile(file);
      if (uploadRes.data is! Map<String, dynamic>) {
        return const RemoveBackgroundResult(
          success: false,
          message: 'Invalid upload response from server.',
        );
      }
      final data = uploadRes.data as Map<String, dynamic>;
      if (data['result'] != true) {
        return RemoveBackgroundResult(
          success: false,
          message: data['message']?.toString() ?? 'Upload failed.',
        );
      }
      imageUrl = data['url']?.toString() ?? '';
      if (imageUrl.isEmpty) {
        return const RemoveBackgroundResult(
          success: false,
          message: 'Upload response missing image URL.',
        );
      }
    }

    final bgRes = await api.studioRemoveBackground(
      imageUrl: imageUrl,
      edgeSmoothing: edgeSmoothing,
    );
    if (bgRes.data is! Map<String, dynamic>) {
      return const RemoveBackgroundResult(
        success: false,
        message: 'Invalid remove-background response from server.',
      );
    }
    final body = bgRes.data as Map<String, dynamic>;
    if (body['success'] != true) {
      return RemoveBackgroundResult(
        success: false,
        message: body['message']?.toString() ?? 'Background removal failed.',
      );
    }
    final resultUrl = body['result_url']?.toString();
    if (resultUrl == null || resultUrl.isEmpty) {
      return const RemoveBackgroundResult(
        success: false,
        message: 'No result image returned.',
      );
    }
    return RemoveBackgroundResult(
      success: true,
      resultUrl: resultUrl,
    );
  } on SocketException catch (_) {
    return const RemoveBackgroundResult(
      success: false,
      message: 'No internet connection. Background removal requires an online server.',
    );
  } on TimeoutException catch (_) {
    return const RemoveBackgroundResult(
      success: false,
      message: 'The server took too long. Try again.',
    );
  } catch (e) {
    return RemoveBackgroundResult(
      success: false,
      message: 'Background removal failed: $e',
    );
  }
}
