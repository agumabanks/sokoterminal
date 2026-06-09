import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/business_profile_cache.dart';
import '../../core/settings/shop_payment_settings.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/util/haptics.dart';
import '../receipts/receipt_providers.dart';
import '../settings/staff_pin_controller.dart';
import '../../core/settings/business_setup_prefs.dart';

final _primaryOutletProvider = StreamProvider<Outlet?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query =
      (db.select(db.outlets)
            ..where((t) => t.active.equals(true))
            ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .watchSingleOrNull();
  return query;
});

final _activeReceiptTemplateProvider = StreamProvider<ReceiptTemplate?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query =
      (db.select(db.receiptTemplates)
            ..where((t) => t.isActive.equals(true))
            ..limit(1))
          .watchSingleOrNull();
  return query;
});

/// Dark, immersive business-setup wizard.
/// One step per screen. Minimal text. Obvious inputs. Clear CTA.
class BusinessSetupWizardScreen extends ConsumerStatefulWidget {
  const BusinessSetupWizardScreen({super.key});

  @override
  ConsumerState<BusinessSetupWizardScreen> createState() =>
      _BusinessSetupWizardScreenState();
}

class _BusinessSetupWizardScreenState
    extends ConsumerState<BusinessSetupWizardScreen>
    with TickerProviderStateMixin {
  static const _uuid = Uuid();

  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();

  final _bankNameCtrl = TextEditingController();
  final _bankAccNameCtrl = TextEditingController();
  final _bankAccNoCtrl = TextEditingController();
  final _bankRoutingCtrl = TextEditingController();
  final _mtnMerchantCtrl = TextEditingController();
  final _airtelMerchantCtrl = TextEditingController();
  final _paybillCtrl = TextEditingController();

  bool _cashEnabled = true;
  bool _bankEnabled = false;
  bool _mobileMoneyEnabled = true;

  int _currentStep = 0;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Palette — same language as LoginScreen
  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF0B0B10);
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _mint = Color(0xFF0EBE7E);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.event('setup_wizard_open'));
    }

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );
    _fadeController.forward();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccNameCtrl.dispose();
    _bankAccNoCtrl.dispose();
    _bankRoutingCtrl.dispose();
    _mtnMerchantCtrl.dispose();
    _airtelMerchantCtrl.dispose();
    _paybillCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final profile = await db.getBusinessProfile();
    if (profile != null) {
      _shopNameCtrl.text = profile.shopName;
      _shopPhoneCtrl.text = profile.shopPhone ?? '';
      _shopAddressCtrl.text = profile.shopAddress ?? '';
    } else {
      final outlet = await db.getPrimaryOutlet();
      if (outlet != null) {
        _shopNameCtrl.text = outlet.name;
        _shopPhoneCtrl.text = outlet.phone ?? '';
        _shopAddressCtrl.text = outlet.address ?? '';
      }
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final cached = profile != null
        ? businessProfileToPaymentSettings(profile)
        : ShopPaymentSettingsCache.tryRead(prefs);
    final settings = cached ?? ShopPaymentSettings.defaults();
    _cashEnabled = settings.cashEnabled;
    _bankEnabled = settings.bankEnabled;
    _mobileMoneyEnabled = settings.mobileMoneyEnabled;
    _bankNameCtrl.text = settings.bankName;
    _bankAccNameCtrl.text = settings.bankAccountName;
    _bankAccNoCtrl.text = settings.bankAccountNumber;
    _bankRoutingCtrl.text = settings.bankRoutingNumber;
    _mtnMerchantCtrl.text = settings.mtnMerchantCode;
    _airtelMerchantCtrl.text = settings.airtelMerchantCode;
    _paybillCtrl.text = settings.paybillNumber;

    if (!mounted) return;
    setState(() {
      _currentStep = _suggestedStepIndex(null);
    });
  }

  bool get _businessComplete => _shopNameCtrl.text.trim().isNotEmpty;

  bool _paymentsComplete() {
    final prefs = ref.read(sharedPreferencesProvider);
    final cached = ShopPaymentSettingsCache.tryRead(prefs);
    return hasRequiredPaymentSetup(cached);
  }

  bool _printerComplete() {
    final printer = ref.read(printQueueServiceProvider);
    if (!printer.printerEnabled) return true;
    return printer.hasPreferredPrinter;
  }

  bool _receiptsComplete(ReceiptTemplate? activeTemplate) {
    return activeTemplate != null;
  }

  bool _setupComplete(ReceiptTemplate? activeTemplate) {
    return _businessComplete &&
        _paymentsComplete() &&
        _receiptsComplete(activeTemplate);
  }

  Future<void> _saveBusinessInfo() async {
    final name = _shopNameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Enter your business name');
      return;
    }

    try {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);

      final existing = await db.getPrimaryOutlet();
      final id = existing?.id ?? _uuid.v4();
      await db.upsertOutlet(
        OutletsCompanion.insert(
          id: drift.Value(id),
          name: name,
          address: drift.Value(
            _shopAddressCtrl.text.trim().isEmpty
                ? null
                : _shopAddressCtrl.text.trim(),
          ),
          phone: drift.Value(
            _shopPhoneCtrl.text.trim().isEmpty
                ? null
                : _shopPhoneCtrl.text.trim(),
          ),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          active: const drift.Value(true),
        ),
      );
      final existingProfile = await db.getBusinessProfile();
      await db.upsertBusinessProfile(
        BusinessProfilesCompanion.insert(
          id: kPrimaryBusinessProfileId,
          sellerId: existingProfile?.sellerId == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerId),
          sellerName: existingProfile?.sellerName == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerName),
          sellerEmail: existingProfile?.sellerEmail == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerEmail),
          sellerPhone: existingProfile?.sellerPhone == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerPhone),
          shopId: drift.Value(id),
          shopName: name,
          shopAddress: drift.Value(
            _shopAddressCtrl.text.trim().isEmpty
                ? null
                : _shopAddressCtrl.text.trim(),
          ),
          shopPhone: drift.Value(
            _shopPhoneCtrl.text.trim().isEmpty
                ? null
                : _shopPhoneCtrl.text.trim(),
          ),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          synced: const drift.Value(false),
        ),
      );

      await sync.enqueue('business_profile_patch', {
        'name': name,
        'address': _shopAddressCtrl.text.trim().isEmpty
            ? null
            : _shopAddressCtrl.text.trim(),
        'phone': _shopPhoneCtrl.text.trim().isEmpty
            ? null
            : _shopPhoneCtrl.text.trim(),
      });
      unawaited(sync.syncNow());

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'setup_business_profile_saved',
            props: {
              'has_address': _shopAddressCtrl.text.trim().isNotEmpty,
              'has_phone': _shopPhoneCtrl.text.trim().isNotEmpty,
            },
          ),
        );
      }

      if (!mounted) return;
      Haptics.impact();
      _nextStep();
    } catch (e) {
      if (!mounted) return;
      _showError('Save failed: $e');
    }
  }

  ShopPaymentSettings _collectPaymentSettings() {
    return ShopPaymentSettings(
      cashEnabled: _cashEnabled,
      bankEnabled: _bankEnabled,
      mobileMoneyEnabled: _mobileMoneyEnabled,
      bankName: _bankNameCtrl.text.trim(),
      bankAccountName: _bankAccNameCtrl.text.trim(),
      bankAccountNumber: _bankAccNoCtrl.text.trim(),
      bankRoutingNumber: _bankRoutingCtrl.text.trim(),
      mtnMerchantCode: _mtnMerchantCtrl.text.trim(),
      airtelMerchantCode: _airtelMerchantCtrl.text.trim(),
      paybillNumber: _paybillCtrl.text.trim(),
    );
  }

  Future<void> _savePaymentSettings() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final settings = _collectPaymentSettings();
      await ShopPaymentSettingsCache.write(prefs, settings);
      final db = ref.read(appDatabaseProvider);
      final existingProfile = await db.getBusinessProfile();
      await db.upsertBusinessProfile(
        BusinessProfilesCompanion.insert(
          id: kPrimaryBusinessProfileId,
          sellerId: existingProfile?.sellerId == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerId),
          sellerName: existingProfile?.sellerName == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerName),
          sellerEmail: existingProfile?.sellerEmail == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerEmail),
          sellerPhone: existingProfile?.sellerPhone == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.sellerPhone),
          shopId: existingProfile?.shopId == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.shopId),
          shopName: existingProfile?.shopName ?? 'Shop',
          shopAddress: existingProfile?.shopAddress == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.shopAddress),
          shopPhone: existingProfile?.shopPhone == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.shopPhone),
          logoUploadId: existingProfile?.logoUploadId == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.logoUploadId),
          logoUrl: existingProfile?.logoUrl == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.logoUrl),
          metaTitle: existingProfile?.metaTitle == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.metaTitle),
          metaDescription: existingProfile?.metaDescription == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.metaDescription),
          thermalPrinterWidth: existingProfile?.thermalPrinterWidth == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.thermalPrinterWidth),
          shippingCost: existingProfile?.shippingCost == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.shippingCost),
          selfDeliveryActive: drift.Value(
            existingProfile?.selfDeliveryActive ?? false,
          ),
          deliveryRadiusKm: existingProfile?.deliveryRadiusKm == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.deliveryRadiusKm),
          deliveryPickupLatitude:
              existingProfile?.deliveryPickupLatitude == null
                  ? const drift.Value.absent()
                  : drift.Value(existingProfile!.deliveryPickupLatitude),
          deliveryPickupLongitude:
              existingProfile?.deliveryPickupLongitude == null
                  ? const drift.Value.absent()
                  : drift.Value(existingProfile!.deliveryPickupLongitude),
          cashOnDeliveryEnabled: drift.Value(settings.cashEnabled),
          bankPaymentEnabled: drift.Value(settings.bankEnabled),
          mobileMoneyEnabled: drift.Value(settings.mobileMoneyEnabled),
          bankName: drift.Value(settings.bankName),
          bankAccName: drift.Value(settings.bankAccountName),
          bankAccNo: drift.Value(settings.bankAccountNumber),
          bankRoutingNo: drift.Value(settings.bankRoutingNumber),
          mtnMerchantCode: drift.Value(settings.mtnMerchantCode),
          airtelMerchantCode: drift.Value(settings.airtelMerchantCode),
          paybillNumber: drift.Value(settings.paybillNumber),
          receiptPaymentMethodsJson: drift.Value(
            jsonEncode(settings.receiptPaymentMethods ?? const {}),
          ),
          deliveryProfileJson: existingProfile?.deliveryProfileJson == null
              ? const drift.Value.absent()
              : drift.Value(existingProfile!.deliveryProfileJson),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          synced: const drift.Value(false),
        ),
      );

      final sync = ref.read(syncServiceProvider);
      await sync.enqueue('business_profile_patch', settings.toUpdatePayload());
      unawaited(sync.syncNow());

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'setup_payment_settings_saved',
            props: {
              'cash_enabled': settings.cashEnabled,
              'bank_enabled': settings.bankEnabled,
              'mobile_money_enabled': settings.mobileMoneyEnabled,
              'has_bank_details': settings.hasBankDetails,
              'has_mobile_money_codes': settings.hasMobileMoneyCodes,
            },
          ),
        );
      }

      if (!mounted) return;
      Haptics.impact();
      _nextStep();
    } catch (e) {
      if (!mounted) return;
      _showError('Save failed: $e');
    }
  }

  Future<void> _createDefaultReceiptTemplate() async {
    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    final id = _uuid.v4();

    await db.upsertReceiptTemplate(
      ReceiptTemplatesCompanion.insert(
        id: drift.Value(id),
        name: drift.Value('Default'),
        style: drift.Value('minimal'),
        headerText: drift.Value('Thank you for your purchase'),
        footerText: drift.Value('Powered by Soko 24'),
        showLogo: const drift.Value(false),
        showQr: const drift.Value(true),
        colorHex: drift.Value('#00A884'),
        isActive: const drift.Value(true),
        updatedAt: drift.Value(DateTime.now().toUtc()),
        synced: const drift.Value(true),
      ),
    );

    await sync.enqueue('receipt_template_update', {
      'local_id': id,
      'name': 'Default',
      'style': 'minimal',
      'header_color': '#00A884',
      'footer_message': 'Powered by Soko 24',
      'show_logo': false,
      'show_qr': true,
      'is_active': true,
    });
    unawaited(sync.syncNow());

    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.event('setup_receipt_template_created'));
    }

    if (!mounted) return;
    Haptics.impact();
    setState(() {
      _currentStep = _suggestedStepIndex(null);
    });
  }

  Future<void> _choosePrinter() async {
    final devices = await BlueThermalPrinter.instance.getBondedDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      _showError('No paired printers found. Pair one in Bluetooth settings first.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: _surface.withOpacity(0.95),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Choose printer', style: _titleStyle),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final d = devices[index];
                          return ListTile(
                            leading: const Icon(Icons.print_outlined, color: Colors.white70),
                            title: Text(d.name ?? 'Printer', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              d.address ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                            ),
                            onTap: () async {
                              try {
                                await ref
                                    .read(printQueueServiceProvider)
                                    .setPreferredPrinter(d);
                                await BlueThermalPrinter.instance.connect(d);
                                unawaited(ref.read(printQueueServiceProvider).pump());
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!mounted) return;
                                setState(() {});
                                setState(() {
                                  _currentStep = _suggestedStepIndex(null);
                                });
                              } catch (e) {
                                if (!mounted) return;
                                _showError('Failed to select printer: $e');
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _setTerminalPin() async {
    final ctrl = ref.read(staffPinProvider.notifier);
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: _surface.withOpacity(0.95),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Set terminal PIN', style: _titleStyle),
                      const SizedBox(height: 8),
                      Text(
                        '4–8 digits to lock this device.',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      _DarkInput(controller: pinCtrl, label: 'PIN', obscure: true, digitsOnly: true),
                      const SizedBox(height: 12),
                      _DarkInput(controller: confirmCtrl, label: 'Confirm PIN', obscure: true, digitsOnly: true),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _GlassButton(
                              onTap: () => Navigator.pop(ctx),
                              child: const Center(
                                child: Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _SolidButton(
                              onTap: () async {
                                final pin = pinCtrl.text.trim();
                                final confirm = confirmCtrl.text.trim();
                                if (pin.length < 4) {
                                  setSheetState(() {});
                                  _showError('PIN must be at least 4 digits');
                                  return;
                                }
                                if (pin != confirm) {
                                  setSheetState(() {});
                                  _showError('PINs do not match');
                                  return;
                                }
                                await ctrl.setPin(pin);
                                await ctrl.unlock(pin);
                                final telemetry = Telemetry.instance;
                                if (telemetry != null) {
                                  unawaited(telemetry.event('setup_terminal_pin_set'));
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!mounted) return;
                                setState(() {
                                  _currentStep = _suggestedStepIndex(null);
                                });
                              },
                              child: const Center(
                                child: Text('Save PIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    pinCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _finishSetup() async {
    final activeTemplateAsync = ref.read(_activeReceiptTemplateProvider);
    final activeTemplate = activeTemplateAsync.asData?.value;
    if (!_setupComplete(activeTemplate)) {
      _showError('Complete the required steps first');
      return;
    }

    await ref.read(businessSetupCompletedProvider.notifier).setCompleted(true);
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.event('setup_completed'));
    }

    if (!mounted) return;
    Haptics.impact();
    context.go('/home/checkout');
  }

  List<_WizardStepMeta> _buildSteps(ReceiptTemplate? activeTemplate) {
    final staffPin = ref.read(staffPinProvider);
    return [
      _WizardStepMeta(
        title: 'Business',
        subtitle: 'What is your business called?',
        isComplete: _businessComplete,
        icon: Icons.storefront_outlined,
      ),
      _WizardStepMeta(
        title: 'Payments',
        subtitle: 'How do you get paid?',
        isComplete: _paymentsComplete(),
        icon: Icons.payments_outlined,
      ),
      _WizardStepMeta(
        title: 'Receipts',
        subtitle: 'Ready to print receipts?',
        isComplete: activeTemplate != null,
        icon: Icons.receipt_long_outlined,
      ),
      _WizardStepMeta(
        title: 'Printer',
        subtitle: 'Connect a Bluetooth printer.',
        isComplete: _printerComplete(),
        optional: true,
        icon: Icons.print_outlined,
      ),
      _WizardStepMeta(
        title: 'Lock',
        subtitle: 'Protect this device with a PIN.',
        isComplete: staffPin.enabled,
        optional: true,
        icon: Icons.lock_outline,
      ),
    ];
  }

  int _suggestedStepIndex(ReceiptTemplate? activeTemplate) {
    final resolvedTemplate =
        activeTemplate ?? ref.read(_activeReceiptTemplateProvider).asData?.value;
    final staffPin = ref.read(staffPinProvider);
    final steps = [
      _businessComplete,
      _paymentsComplete(),
      resolvedTemplate != null,
      _printerComplete(),
      staffPin.enabled,
    ];
    for (var i = 0; i < steps.length; i++) {
      if (!steps[i]) return i;
    }
    return steps.length - 1;
  }

  void _goToStep(int step, int totalSteps) {
    setState(() {
      _currentStep = step.clamp(0, totalSteps - 1);
    });
  }

  void _nextStep() {
    final activeTemplateAsync = ref.read(_activeReceiptTemplateProvider);
    final activeTemplate = activeTemplateAsync.asData?.value;
    final steps = _buildSteps(activeTemplate);
    final totalSteps = steps.length;
    if (_currentStep < totalSteps - 1) {
      _goToStep(_currentStep + 1, totalSteps);
    }
  }

  void _prevStep() {
    final activeTemplateAsync = ref.read(_activeReceiptTemplateProvider);
    final activeTemplate = activeTemplateAsync.asData?.value;
    final steps = _buildSteps(activeTemplate);
    final totalSteps = steps.length;
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1, totalSteps);
    }
  }

  void _showError(String message) {
    Haptics.warning();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD30005),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  static TextStyle get _titleStyle => const TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle get _captionStyle => TextStyle(
    color: Colors.white.withOpacity(0.45),
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final outletAsync = ref.watch(_primaryOutletProvider);
    final activeTemplateAsync = ref.watch(_activeReceiptTemplateProvider);
    final activeTemplate = activeTemplateAsync.asData?.value;
    final steps = _buildSteps(activeTemplate);
    final totalSteps = steps.length;
    final currentStep = _currentStep.clamp(0, totalSteps - 1);
    final currentMeta = steps[currentStep];
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_bg, Color(0xFF05050A), _bg],
                ),
              ),
            ),
            // Glow blobs
            Positioned(
              top: -140,
              right: -120,
              child: _GlowBlob(color: _accent.withOpacity(0.14), size: 380),
            ),
            Positioned(
              bottom: -160,
              left: -130,
              child: _GlowBlob(color: _mint.withOpacity(0.08), size: 420),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(currentStep, totalSteps, steps),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutQuart,
                        switchOutCurve: Curves.easeInQuart,
                        transitionBuilder: (child, animation) => SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(currentStep),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: switch (currentStep) {
                              0 => _buildBusinessStep(outletAsync),
                              1 => _buildPaymentsStep(),
                              2 => _buildReceiptsStep(activeTemplate),
                              3 => _buildPrinterStep(),
                              _ => _buildPinStep(),
                            },
                          ),
                        ),
                      ),
                    ),
                    _buildBottomBar(currentMeta, currentStep, totalSteps, activeTemplate),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int currentStep, int totalSteps, List<_WizardStepMeta> steps) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: currentStep > 0 ? _prevStep : () => context.go('/home/checkout'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    currentStep > 0 ? Icons.arrow_back_ios_new : Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  steps[currentStep].title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '${currentStep + 1} / $totalSteps',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Segmented progress
          Row(
            children: List.generate(totalSteps, (index) {
              final isActive = index <= currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessStep(AsyncValue<Outlet?> outletAsync) {
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 48,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(height: 20),
        Text(
          'What is your business called?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customers will see this name on receipts and listings.',
          style: _captionStyle,
        ),
        const SizedBox(height: 32),
        _DarkInput(
          controller: _shopNameCtrl,
          label: 'Business name',
          hint: 'e.g. Soko Mart',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _DarkInput(
          controller: _shopPhoneCtrl,
          label: 'Phone',
          hint: 'e.g. +256…',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _DarkInput(
          controller: _shopAddressCtrl,
          label: 'Address',
          hint: 'Street, town',
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Text(
          outletAsync.maybeWhen(
            data: (o) => o == null ? '' : 'Current: ${o.name}',
            orElse: () => '',
          ),
          style: _captionStyle,
        ),
      ],
    );
  }

  Widget _buildPaymentsStep() {
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      children: [
        Icon(
          Icons.payments_outlined,
          size: 48,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(height: 20),
        Text(
          'How do you get paid?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toggle the methods you accept at checkout.',
          style: _captionStyle,
        ),
        const SizedBox(height: 32),
        _PaymentToggle(
          icon: Icons.payments_outlined,
          title: 'Cash',
          value: _cashEnabled,
          onChanged: (v) => setState(() => _cashEnabled = v),
        ),
        const SizedBox(height: 12),
        _PaymentToggle(
          icon: Icons.account_balance_outlined,
          title: 'Bank transfer',
          value: _bankEnabled,
          onChanged: (v) => setState(() => _bankEnabled = v),
        ),
        if (_bankEnabled) ...[
          const SizedBox(height: 12),
          _DarkInput(controller: _bankNameCtrl, label: 'Bank name', hint: 'e.g. Stanbic'),
          const SizedBox(height: 12),
          _DarkInput(controller: _bankAccNameCtrl, label: 'Account name'),
          const SizedBox(height: 12),
          _DarkInput(controller: _bankAccNoCtrl, label: 'Account number'),
        ],
        const SizedBox(height: 12),
        _PaymentToggle(
          icon: Icons.phone_iphone_outlined,
          title: 'Mobile money',
          value: _mobileMoneyEnabled,
          onChanged: (v) => setState(() => _mobileMoneyEnabled = v),
        ),
        if (_mobileMoneyEnabled) ...[
          const SizedBox(height: 12),
          _DarkInput(controller: _mtnMerchantCtrl, label: 'MTN merchant code', hint: 'e.g. 123456'),
          const SizedBox(height: 12),
          _DarkInput(controller: _airtelMerchantCtrl, label: 'Airtel merchant code', hint: 'e.g. 654321'),
          const SizedBox(height: 12),
          _DarkInput(controller: _paybillCtrl, label: 'Paybill number', hint: 'e.g. 200200'),
        ],
      ],
    );
  }

  Widget _buildReceiptsStep(ReceiptTemplate? activeTemplate) {
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 48,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(height: 20),
        Text(
          'Print receipts?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          activeTemplate == null
              ? 'Create a template so every sale gets a receipt.'
              : 'Your receipt template is ready.',
          style: _captionStyle,
        ),
        const SizedBox(height: 32),
        if (activeTemplate == null)
          _SolidButton(
            onTap: _createDefaultReceiptTemplate,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text('Create default template', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _mint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _mint.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: _mint),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Template active: ${activeTemplate.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _GlassButton(
          onTap: () => context.go('/home/more/receipt-templates'),
          child: const Center(
            child: Text('Edit templates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterStep() {
    final printer = ref.watch(printQueueServiceProvider);
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      children: [
        Icon(
          Icons.print_outlined,
          size: 48,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(height: 20),
        Text(
          'Connect a printer',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — skip if you email or SMS receipts.',
          style: _captionStyle,
        ),
        const SizedBox(height: 32),
        _PaymentToggle(
          icon: Icons.bluetooth_outlined,
          title: 'Enable Bluetooth printing',
          value: printer.printerEnabled,
          onChanged: (v) async {
            await ref.read(printQueueServiceProvider).setPrinterEnabled(v);
            if (!mounted) return;
            setState(() {});
          },
        ),
        if (printer.printerEnabled) ...[
          const SizedBox(height: 16),
          _GlassButton(
            onTap: _choosePrinter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.print_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  printer.hasPreferredPrinter ? printer.preferredPrinterLabel() : 'Choose printer',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PaymentToggle(
            icon: Icons.settings_outlined,
            title: 'Compatibility mode',
            subtitle: 'For older printers',
            value: printer.compatibilityMode,
            onChanged: (v) async {
              await ref.read(printQueueServiceProvider).setCompatibilityMode(v);
              if (!mounted) return;
              setState(() {});
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPinStep() {
    final staffPin = ref.watch(staffPinProvider);
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      children: [
        Icon(
          Icons.lock_outline,
          size: 48,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(height: 20),
        Text(
          'Lock this device?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — set a PIN to protect shared devices.',
          style: _captionStyle,
        ),
        const SizedBox(height: 32),
        if (!staffPin.enabled)
          _SolidButton(
            onTap: _setTerminalPin,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text('Set PIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _mint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _mint.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: _mint),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Device lock is active',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                _GlassButton(
                  onTap: _setTerminalPin,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(
    _WizardStepMeta currentMeta,
    int currentStep,
    int totalSteps,
    ReceiptTemplate? activeTemplate,
  ) {
    final isLast = currentStep == totalSteps - 1;
    final canFinish = _setupComplete(activeTemplate);
    final canContinue = currentMeta.isComplete || currentMeta.optional;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _bg.withOpacity(0),
            _bg.withOpacity(0.9),
            _bg,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SolidButton(
              onTap: isLast
                  ? (canFinish ? _finishSetup : null)
                  : (canContinue ? () {
                      if (currentStep == 0) _saveBusinessInfo();
                      else if (currentStep == 1) _savePaymentSettings();
                      else _nextStep();
                    } : null),
              child: Center(
                child: Text(
                  isLast
                      ? (canFinish ? 'Start selling' : 'Complete required steps')
                      : 'Continue',
                  style: TextStyle(
                    color: isLast && !canFinish ? Colors.white.withOpacity(0.4) : Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (currentMeta.optional && !isLast) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _nextStep,
                child: Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────

class _WizardStepMeta {
  const _WizardStepMeta({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.icon,
    this.optional = false,
  });

  final String title;
  final String subtitle;
  final bool isComplete;
  final IconData icon;
  final bool optional;
}

// ── Reusable dark widgets ──────────────────────────────────────────────────

class _DarkInput extends StatefulWidget {
  const _DarkInput({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.onChanged,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool digitsOnly;

  @override
  State<_DarkInput> createState() => _DarkInputState();
}

class _DarkInputState extends State<_DarkInput> {
  late final FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused
                  ? Colors.white.withOpacity(0.45)
                  : Colors.white.withOpacity(0.12),
              width: _focused ? 1.5 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.04),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscure,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            inputFormatters: widget.digitsOnly
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 16),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentToggle extends StatelessWidget {
  const _PaymentToggle({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF0EBE7E).withOpacity(0.12) : const Color(0xFF0B0B10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? const Color(0xFF0EBE7E).withOpacity(0.4) : Colors.white.withOpacity(0.1),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF0EBE7E).withOpacity(0.18) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: value ? const Color(0xFF0EBE7E) : Colors.white70, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: value
                  ? Icon(Icons.check_circle, color: const Color(0xFF0EBE7E), key: const ValueKey('on'))
                  : Icon(Icons.circle_outlined, color: Colors.white.withOpacity(0.2), key: const ValueKey('off')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolidButton extends StatefulWidget {
  const _SolidButton({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_SolidButton> createState() => _SolidButtonState();
}

class _SolidButtonState extends State<_SolidButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.onTap == null ? Colors.white.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.onTap == null
                ? null
                : [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.35), blurRadius: 80, spreadRadius: 30),
        ],
      ),
    );
  }
}
