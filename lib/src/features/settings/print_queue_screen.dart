import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../receipts/receipt_providers.dart';

final printJobsStreamProvider = StreamProvider<List<PrintJob>>((ref) {
  return ref.watch(appDatabaseProvider).watchPrintJobs(limit: 200);
});

class PrintQueueScreen extends ConsumerWidget {
  const PrintQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printer = ref.watch(printQueueServiceProvider);
    final jobsAsync = ref.watch(printJobsStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Print Queue', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            tooltip: 'Retry now',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(printQueueServiceProvider).pump();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Retry started')));
            },
          ),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          final pending = jobs.where((j) => j.status == 'pending').length;
          return ListView(
            padding: DesignTokens.paddingScreen,
            children: [
              _PrinterCard(
                enabled: printer.printerEnabled,
                printerLabel: printer.preferredPrinterLabel(),
                pendingCount: pending,
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final cleared = await ref
                            .read(appDatabaseProvider)
                            .clearPrintedJobs();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cleared $cleared printed jobs'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Clear printed'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(printQueueServiceProvider).pump();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Retrying pending jobs…'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Retry all'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              if (jobs.isEmpty)
                Center(
                  child: Text(
                    'No print jobs yet.',
                    style: DesignTokens.textBody,
                  ),
                )
              else
                ...jobs.map((job) => _JobTile(job: job)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load print queue: $e')),
      ),
    );
  }
}

class _PrinterCard extends StatelessWidget {
  const _PrinterCard({
    required this.enabled,
    required this.printerLabel,
    required this.pendingCount,
  });

  final bool enabled;
  final String printerLabel;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Printer', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            enabled ? 'Enabled' : 'Disabled',
            style: DesignTokens.textSmall.copyWith(
              color: enabled ? DesignTokens.brandAccent : DesignTokens.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text('Selected: $printerLabel', style: DesignTokens.textSmall),
          const SizedBox(height: DesignTokens.spaceXs),
          Text('Pending jobs: $pendingCount', style: DesignTokens.textSmall),
        ],
      ),
    );
  }
}

class _JobTile extends ConsumerWidget {
  const _JobTile({required this.job});
  final PrintJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = job.status;
    final isPrinted = status == 'printed';
    final isCancelled = status == 'cancelled';
    final hasError = (job.lastError ?? '').trim().isNotEmpty;

    final icon = isPrinted
        ? Icons.check_circle
        : isCancelled
        ? Icons.block
        : hasError
        ? Icons.error_outline
        : Icons.schedule;
    final color = isPrinted
        ? DesignTokens.brandAccent
        : isCancelled
        ? DesignTokens.grayMedium
        : hasError
        ? DesignTokens.error
        : DesignTokens.warning;

    final title = job.jobType == 'receipt' ? 'Receipt' : job.jobType;
    final subtitle = _fmtSubtitle(job);

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.grayLight),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          '$title • ${job.referenceId}',
          style: DesignTokens.textSmallBold,
        ),
        subtitle: Text(subtitle, style: DesignTokens.textSmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'pending')
              IconButton(
                tooltip: 'Retry',
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await ref.read(appDatabaseProvider).retryPrintJob(job.id);
                  await ref.read(printQueueServiceProvider).pump();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Retry queued')));
                },
              ),
            if (status == 'pending')
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await ref.read(appDatabaseProvider).cancelPrintJob(job.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Job cancelled')),
                  );
                },
              ),
            IconButton(
              tooltip: 'Details',
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showJobDetails(context, ref, job),
            ),
          ],
        ),
      ),
    );
  }

  void _showJobDetails(BuildContext context, WidgetRef ref, PrintJob job) {
    BottomSheetModal.show(
      context: context,
      title: 'Print job',
      subtitle: 'ID ${job.id}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Type', job.jobType),
          _kv('Reference', job.referenceId),
          _kv('Status', job.status),
          _kv('Retries', job.retryCount.toString()),
          _kv('Created', _fmt(job.createdAt)),
          _kv('Last tried', _fmt(job.lastTriedAt)),
          _kv('Printed', _fmt(job.printedAt)),
          if ((job.lastError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spaceSm),
            Text('Last error', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceXs),
            Container(
              padding: DesignTokens.paddingMd,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withOpacity(0.25),
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              child: Text(job.lastError!, style: DesignTokens.textSmall),
            ),
          ],
          const SizedBox(height: DesignTokens.spaceLg),
          OutlinedButton.icon(
            onPressed: () async {
              final payload = jsonEncode({
                'id': job.id,
                'type': job.jobType,
                'reference': job.referenceId,
                'status': job.status,
                'retry_count': job.retryCount,
                'created_at': job.createdAt.toIso8601String(),
                'last_tried_at': job.lastTriedAt?.toIso8601String(),
                'printed_at': job.printedAt?.toIso8601String(),
                'last_error': job.lastError,
              });
              await Clipboard.setData(ClipboardData(text: payload));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied details')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(k, style: DesignTokens.textSmallBold),
          ),
          Expanded(child: Text(v, style: DesignTokens.textSmall)),
        ],
      ),
    );
  }

  String _fmtSubtitle(PrintJob job) {
    final parts = <String>[];
    parts.add(job.status);
    if (job.retryCount > 0) parts.add('retries: ${job.retryCount}');
    if (job.lastError != null && job.lastError!.trim().isNotEmpty) {
      parts.add('error: ${job.lastError!.trim()}');
    }
    return parts.join(' • ');
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}
