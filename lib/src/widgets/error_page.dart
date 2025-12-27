import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// Unified error page for offline/timeout/401/500 with retry and diagnostics.
class ErrorPage extends StatelessWidget {
  const ErrorPage({
    super.key,
    required this.title,
    this.message,
    this.errorCode,
    this.onRetry,
    this.showDiagnostics = false,
    this.diagnosticsInfo,
  });

  final String title;
  final String? message;
  final String? errorCode;
  final VoidCallback? onRetry;
  final bool showDiagnostics;
  final Map<String, dynamic>? diagnosticsInfo;

  /// Factory for offline errors
  factory ErrorPage.offline({VoidCallback? onRetry}) => ErrorPage(
        title: 'No Internet Connection',
        message: 'Please check your network settings and try again.',
        errorCode: 'OFFLINE',
        onRetry: onRetry,
      );

  /// Factory for timeout errors
  factory ErrorPage.timeout({VoidCallback? onRetry}) => ErrorPage(
        title: 'Request Timed Out',
        message: 'The server is taking too long to respond. Please try again.',
        errorCode: 'TIMEOUT',
        onRetry: onRetry,
      );

  /// Factory for 401 Unauthorized errors
  factory ErrorPage.unauthorized({VoidCallback? onRetry}) => ErrorPage(
        title: 'Session Expired',
        message: 'Please log in again to continue.',
        errorCode: '401',
        onRetry: onRetry,
      );

  /// Factory for 403 Forbidden errors
  factory ErrorPage.forbidden({VoidCallback? onRetry}) => ErrorPage(
        title: 'Access Denied',
        message: 'You don\'t have permission to access this resource.',
        errorCode: '403',
        onRetry: onRetry,
      );

  /// Factory for 404 Not Found errors
  factory ErrorPage.notFound({VoidCallback? onRetry}) => ErrorPage(
        title: 'Not Found',
        message: 'The requested resource could not be found.',
        errorCode: '404',
        onRetry: onRetry,
      );

  /// Factory for 500 Server errors
  factory ErrorPage.serverError({VoidCallback? onRetry}) => ErrorPage(
        title: 'Server Error',
        message: 'Something went wrong on our end. Please try again later.',
        errorCode: '500',
        onRetry: onRetry,
      );

  /// Factory from HTTP status code
  factory ErrorPage.fromStatusCode(
    int? statusCode, {
    VoidCallback? onRetry,
    String? message,
  }) {
    switch (statusCode) {
      case 401:
        return ErrorPage.unauthorized(onRetry: onRetry);
      case 403:
        return ErrorPage.forbidden(onRetry: onRetry);
      case 404:
        return ErrorPage.notFound(onRetry: onRetry);
      case 500:
      case 502:
      case 503:
      case 504:
        return ErrorPage.serverError(onRetry: onRetry);
      default:
        return ErrorPage(
          title: 'Something Went Wrong',
          message: message ?? 'An unexpected error occurred.',
          errorCode: statusCode?.toString(),
          onRetry: onRetry,
        );
    }
  }

  IconData get _icon {
    switch (errorCode) {
      case 'OFFLINE':
        return Icons.wifi_off_rounded;
      case 'TIMEOUT':
        return Icons.access_time_rounded;
      case '401':
        return Icons.lock_outline_rounded;
      case '403':
        return Icons.block_rounded;
      case '404':
        return Icons.search_off_rounded;
      case '500':
        return Icons.cloud_off_rounded;
      default:
        return Icons.error_outline_rounded;
    }
  }

  Color get _iconColor {
    switch (errorCode) {
      case 'OFFLINE':
      case 'TIMEOUT':
        return DesignTokens.warning;
      case '401':
      case '403':
        return DesignTokens.error;
      default:
        return DesignTokens.grayMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingScreen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icon,
              size: 80,
              color: _iconColor,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              title,
              style: DesignTokens.textTitle,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: DesignTokens.spaceSm),
              Text(
                message!,
                style: DesignTokens.textBody.copyWith(
                  color: DesignTokens.grayMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (errorCode != null) ...[
              const SizedBox(height: DesignTokens.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd,
                  vertical: DesignTokens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Text(
                  'Error: $errorCode',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.grayMedium,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            const SizedBox(height: DesignTokens.spaceLg),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceLg,
                    vertical: DesignTokens.spaceMd,
                  ),
                ),
              ),
            if (showDiagnostics && diagnosticsInfo != null) ...[
              const SizedBox(height: DesignTokens.spaceLg),
              ExpansionTile(
                title: Text(
                  'Diagnostics',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.grayMedium,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(DesignTokens.spaceMd),
                    color: DesignTokens.grayLight.withValues(alpha: 0.2),
                    child: SelectableText(
                      diagnosticsInfo!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                      style: DesignTokens.textSmall.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A wrapper that catches errors and shows ErrorPage
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
  });

  final Widget child;
  final VoidCallback? onRetry;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  void initState() {
    super.initState();
  }

  void _handleRetry() {
    setState(() {
      _error = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorPage(
        title: 'Something Went Wrong',
        message: _error.toString(),
        onRetry: _handleRetry,
      );
    }
    return widget.child;
  }
}
