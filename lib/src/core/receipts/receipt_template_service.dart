import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../app_providers.dart';
import '../db/app_database.dart';

// Re-export Value from drift for convenience
export 'package:drift/drift.dart' show Value;

/// Service for applying receipt templates to generated receipts
class ReceiptTemplateService {
  ReceiptTemplateService(this._db);
  
  final AppDatabase _db;
  ReceiptTemplate? _activeTemplate;
  
  /// Get the currently active template
  Future<ReceiptTemplate?> getActiveTemplate() async {
    if (_activeTemplate != null) return _activeTemplate;
    
    final templates = await (_db.select(_db.receiptTemplates)
      ..where((t) => t.isActive.equals(true))
      ..limit(1))
      .get();
    
    if (templates.isNotEmpty) {
      _activeTemplate = templates.first;
    }
    return _activeTemplate;
  }
  
  /// Set a template as active
  Future<void> setActiveTemplate(String templateId) async {
    // Deactivate all
    await (_db.update(_db.receiptTemplates))
      .write(const ReceiptTemplatesCompanion(isActive: Value(false)));
    
    // Activate selected
    await (_db.update(_db.receiptTemplates)
      ..where((t) => t.id.equals(templateId)))
      .write(const ReceiptTemplatesCompanion(isActive: Value(true)));
    
    // Clear cache
    _activeTemplate = null;
  }
  
  /// Build receipt header text from template
  String buildHeader({String? shopName, String? shopAddress, String? shopPhone}) {
    final template = _activeTemplate;
    final lines = <String>[];
    
    // Shop name
    if (shopName != null && shopName.isNotEmpty) {
      lines.add(shopName.toUpperCase());
    }
    
    // Shop address
    if (shopAddress != null && shopAddress.isNotEmpty) {
      lines.add(shopAddress);
    }
    
    // Shop phone
    if (shopPhone != null && shopPhone.isNotEmpty) {
      lines.add('Tel: $shopPhone');
    }
    
    // Custom header from template
    if (template?.headerText != null && template!.headerText!.isNotEmpty) {
      lines.add('');
      lines.add(template.headerText!);
    }
    
    return lines.join('\n');
  }
  
  /// Build receipt footer text from template
  String buildFooter() {
    final template = _activeTemplate;
    final lines = <String>[];
    
    // Custom footer from template
    if (template?.footerText != null && template!.footerText!.isNotEmpty) {
      lines.add(template.footerText!);
    }
    
    // Powered by
    lines.add('');
    lines.add('Powered by Soko 24');
    lines.add('www.soko24.com');
    
    return lines.join('\n');
  }
  
  /// Build payment instructions for mobile money
  String buildPaymentInstructions({
    String? mtnMerchantCode,
    String? airtelMerchantCode,
    String? paybillNumber,
  }) {
    final instructions = <String>[];
    
    if (mtnMerchantCode != null && mtnMerchantCode.isNotEmpty) {
      instructions.add('MTN: $mtnMerchantCode');
    }
    if (airtelMerchantCode != null && airtelMerchantCode.isNotEmpty) {
      instructions.add('Airtel: $airtelMerchantCode');
    }
    if (paybillNumber != null && paybillNumber.isNotEmpty) {
      instructions.add('Paybill: $paybillNumber');
    }
    
    if (instructions.isEmpty) return '';
    
    return 'Pay via Mobile Money:\n${instructions.join(' | ')}';
  }
  
  /// Get template style settings
  ReceiptStyleConfig getStyleConfig() {
    final template = _activeTemplate;
    return ReceiptStyleConfig(
      showLogo: template?.showLogo ?? true,
      showQr: template?.showQr ?? true,
      colorHex: template?.colorHex ?? '#000000',
      style: template?.style ?? 'minimal',
    );
  }
  
  /// Clear cached template
  void invalidateCache() {
    _activeTemplate = null;
  }
}

/// Receipt style configuration
class ReceiptStyleConfig {
  const ReceiptStyleConfig({
    this.showLogo = true,
    this.showQr = true,
    this.colorHex = '#000000',
    this.style = 'minimal',
  });
  
  final bool showLogo;
  final bool showQr;
  final String colorHex;
  final String style;
}

/// Provider for receipt template service
final receiptTemplateServiceProvider = Provider<ReceiptTemplateService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReceiptTemplateService(db);
});

/// Provider for active template
final activeReceiptTemplateProvider = FutureProvider<ReceiptTemplate?>((ref) async {
  final service = ref.watch(receiptTemplateServiceProvider);
  return service.getActiveTemplate();
});
