import 'dart:async';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/shop_payment_settings.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../receipts/receipt_providers.dart';
import '../settings/staff_pin_controller.dart';
import '../../core/settings/business_setup_prefs.dart';

final _primaryOutletProvider = StreamProvider<Outlet?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = (db.select(db.outlets)
        ..where((t) => t.active.equals(true))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
        ..limit(1))
      .watchSingleOrNull();
  return query;
});

final _activeReceiptTemplateProvider = StreamProvider<ReceiptTemplate?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = (db.select(db.receiptTemplates)
        ..where((t) => t.isActive.equals(true))
        ..limit(1))
      .watchSingleOrNull();
  return query;
});

class BusinessSetupWizardScreen extends ConsumerStatefulWidget {
  const BusinessSetupWizardScreen({super.key});

  @override
  ConsumerState<BusinessSetupWizardScreen> createState() =>
      _BusinessSetupWizardScreenState();
}

class _BusinessSetupWizardScreenState
    extends ConsumerState<BusinessSetupWizardScreen> {
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

  bool _loading = true;
  bool _savingBusiness = false;
  bool _savingPayments = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.event('setup_wizard_open'));
    }
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
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final outlet = await db.getPrimaryOutlet();
    if (outlet != null) {
      _shopNameCtrl.text = outlet.name;
      _shopPhoneCtrl.text = outlet.phone ?? '';
      _shopAddressCtrl.text = outlet.address ?? '';
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final cached = ShopPaymentSettingsCache.tryRead(prefs);
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
    setState(() => _loading = false);
  }

  bool get _businessComplete => _shopNameCtrl.text.trim().isNotEmpty;

  bool _paymentsComplete() {
    final prefs = ref.read(sharedPreferencesProvider);
    final cached = ShopPaymentSettingsCache.tryRead(prefs);
    return cached != null;
  }

  bool _printerComplete() {
    final printer = ref.read(printQueueServiceProvider);
    if (!printer.printerEnabled) return true;
    return printer.hasPreferredPrinter;
  }

  bool get _pinComplete => ref.read(staffPinProvider).enabled;

  bool _receiptsComplete(ReceiptTemplate? activeTemplate) {
    return activeTemplate != null;
  }

  bool _setupComplete(ReceiptTemplate? activeTemplate) {
    return _businessComplete &&
        _paymentsComplete() &&
        _printerComplete() &&
        _pinComplete &&
        _receiptsComplete(activeTemplate);
  }

  Future<void> _saveBusinessInfo() async {
    final name = _shopNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business name is required')),
      );
      return;
    }

    setState(() => _savingBusiness = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);

      final existing = await db.getPrimaryOutlet();
      final id = existing?.id ?? _uuid.v4();
      await db.upsertOutlet(
        OutletsCompanion.insert(
          id: drift.Value(id),
          name: name,
          address: drift.Value(_shopAddressCtrl.text.trim().isEmpty
              ? null
              : _shopAddressCtrl.text.trim()),
          phone: drift.Value(_shopPhoneCtrl.text.trim().isEmpty
              ? null
              : _shopPhoneCtrl.text.trim()),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          active: const drift.Value(true),
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
          telemetry.event('setup_business_profile_saved', props: {
            'has_address': _shopAddressCtrl.text.trim().isNotEmpty,
            'has_phone': _shopPhoneCtrl.text.trim().isNotEmpty,
          }),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved. Will sync when online.'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingBusiness = false);
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
    setState(() => _savingPayments = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final settings = _collectPaymentSettings();
      await ShopPaymentSettingsCache.write(prefs, settings);

      final sync = ref.read(syncServiceProvider);
      await sync.enqueue('business_profile_patch', settings.toUpdatePayload());
      unawaited(sync.syncNow());

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event('setup_payment_settings_saved', props: {
            'cash_enabled': settings.cashEnabled,
            'bank_enabled': settings.bankEnabled,
            'mobile_money_enabled': settings.mobileMoneyEnabled,
            'has_bank_details': settings.hasBankDetails,
            'has_mobile_money_codes': settings.hasMobileMoneyCodes,
          }),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment settings saved. Will sync when online.'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPayments = false);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Default receipt template created'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  Future<void> _choosePrinter() async {
    final devices = await BlueThermalPrinter.instance.getBondedDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No paired printers found. Pair one in Bluetooth settings first.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Choose printer', style: DesignTokens.textTitle),
              const SizedBox(height: 8),
              Text(
                'Pair in OS Bluetooth first',
                style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final d = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.print_outlined),
                      title: Text(d.name ?? 'Printer'),
                      subtitle: Text(d.address ?? '', style: DesignTokens.textSmall),
                      onTap: () async {
                        try {
                          await ref.read(printQueueServiceProvider).setPreferredPrinter(d);
                          await BlueThermalPrinter.instance.connect(d);
                          unawaited(ref.read(printQueueServiceProvider).pump());
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {});
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Selected printer: ${d.name ?? d.address ?? ''}'),
                              backgroundColor: DesignTokens.brandAccent,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Failed to select printer: $e')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
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
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Set terminal PIN', style: DesignTokens.textTitle),
              const SizedBox(height: 8),
              Text(
                'This locks the terminal until PIN unlock.',
                style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final pin = pinCtrl.text.trim();
                        final confirm = confirmCtrl.text.trim();
                        if (pin.length < 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN must be at least 4 digits')),
                          );
                          return;
                        }
                        if (pin != confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PINs do not match')),
                          );
                          return;
                        }

                        await ctrl.setPin(pin);
                        await ctrl.unlock(pin); // avoid immediate lock surprise

                        final telemetry = Telemetry.instance;
                        if (telemetry != null) {
                          unawaited(telemetry.event('setup_terminal_pin_set'));
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Terminal PIN enabled'),
                            backgroundColor: DesignTokens.brandAccent,
                          ),
                        );
                      },
                      child: const Text('Save PIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all setup steps first')),
      );
      return;
    }

    await ref.read(businessSetupCompletedProvider.notifier).setCompleted(true);
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.event('setup_completed'));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Setup complete'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
    context.go('/home/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final outletAsync = ref.watch(_primaryOutletProvider);
    final activeTemplateAsync = ref.watch(_activeReceiptTemplateProvider);
    final staffPin = ref.watch(staffPinProvider);
    final printer = ref.watch(printQueueServiceProvider);

    final prefs = ref.watch(sharedPreferencesProvider);
    final cachedPayments = ShopPaymentSettingsCache.tryRead(prefs);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Business Setup', style: DesignTokens.textTitle),
        actions: [
          TextButton(
            onPressed: () => ref.read(businessSetupCompletedProvider.notifier).reset(),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: DesignTokens.paddingScreen,
              children: [
                _SetupHeaderCard(
                  completed: ref.watch(businessSetupCompletedProvider),
                ),
                const SizedBox(height: DesignTokens.spaceMd),

                _StepCard(
                  title: '1) Business profile',
                  subtitle: _businessComplete
                      ? 'Complete'
                      : 'Add your business name (required)',
                  complete: _businessComplete,
                  child: Column(
                    children: [
                      AppInput(
                        controller: _shopNameCtrl,
                        label: 'Business name',
                        hint: 'e.g. Soko Mart',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      AppInput(
                        controller: _shopPhoneCtrl,
                        label: 'Phone (optional)',
                        hint: 'e.g. +256…',
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      AppInput(
                        controller: _shopAddressCtrl,
                        label: 'Address (optional)',
                        hint: 'Street, town',
                        maxLines: 2,
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _savingBusiness ? null : _saveBusinessInfo,
                              icon: _savingBusiness
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(_savingBusiness ? 'Saving…' : 'Save'),
                            ),
                          ),
                          const SizedBox(width: DesignTokens.spaceSm),
                          Expanded(
                            child: Text(
                              outletAsync.maybeWhen(
                                data: (o) => o == null ? 'No outlet yet' : 'Outlet: ${o.name}',
                                orElse: () => 'Outlet: …',
                              ),
                              style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceMd),

                _StepCard(
                  title: '2) Payment methods',
                  subtitle: cachedPayments != null
                      ? 'Complete'
                      : 'Configure what customers can pay with',
                  complete: cachedPayments != null,
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Accept cash'),
                        value: _cashEnabled,
                        onChanged: (v) => setState(() => _cashEnabled = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Accept bank transfer'),
                        value: _bankEnabled,
                        onChanged: (v) => setState(() => _bankEnabled = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Accept mobile money'),
                        value: _mobileMoneyEnabled,
                        onChanged: (v) => setState(() => _mobileMoneyEnabled = v),
                      ),
                      if (_mobileMoneyEnabled) ...[
                        const SizedBox(height: DesignTokens.spaceSm),
                        AppInput(
                          controller: _mtnMerchantCtrl,
                          label: 'MTN merchant code (optional)',
                          hint: 'e.g. 123456',
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        AppInput(
                          controller: _airtelMerchantCtrl,
                          label: 'Airtel merchant code (optional)',
                          hint: 'e.g. 654321',
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        AppInput(
                          controller: _paybillCtrl,
                          label: 'Paybill number (optional)',
                          hint: 'e.g. 200200',
                        ),
                      ],
                      if (_bankEnabled) ...[
                        const SizedBox(height: DesignTokens.spaceSm),
                        AppInput(
                          controller: _bankNameCtrl,
                          label: 'Bank name (optional)',
                          hint: 'e.g. Stanbic',
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        AppInput(
                          controller: _bankAccNameCtrl,
                          label: 'Account name (optional)',
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        AppInput(
                          controller: _bankAccNoCtrl,
                          label: 'Account number (optional)',
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        AppInput(
                          controller: _bankRoutingCtrl,
                          label: 'Routing number (optional)',
                        ),
                      ],
                      const SizedBox(height: DesignTokens.spaceSm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _savingPayments ? null : _savePaymentSettings,
                          icon: _savingPayments
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_savingPayments ? 'Saving…' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceMd),

                _StepCard(
                  title: '3) Receipts',
                  subtitle: activeTemplateAsync.maybeWhen(
                    data: (t) => t == null ? 'Create a receipt template' : 'Active: ${t.name}',
                    orElse: () => 'Loading…',
                  ),
                  complete: activeTemplateAsync.asData?.value != null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (activeTemplateAsync.asData?.value == null)
                        AppButton(
                          label: 'Create default receipt template',
                          onPressed: _createDefaultReceiptTemplate,
                        ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/home/more/receipt-templates'),
                        icon: const Icon(Icons.receipt_outlined),
                        label: const Text('Open receipt templates'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceMd),

                _StepCard(
                  title: '4) Printer',
                  subtitle: printer.printerEnabled
                      ? (printer.hasPreferredPrinter
                          ? 'Selected: ${printer.preferredPrinterLabel()}'
                          : 'Choose a printer')
                      : 'Printing disabled',
                  complete: _printerComplete(),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Bluetooth printing'),
                        value: printer.printerEnabled,
                        onChanged: (v) async {
                          await ref.read(printQueueServiceProvider).setPrinterEnabled(v);
                          if (!mounted) return;
                          setState(() {});
                        },
                      ),
                      if (printer.printerEnabled) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.print_outlined),
                          title: const Text('Choose printer'),
                          subtitle: Text(
                            printer.preferredPrinterLabel(),
                            style: DesignTokens.textSmall,
                          ),
                          onTap: _choosePrinter,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Compatibility mode'),
                          subtitle: const Text('Disable paper-cut for some models'),
                          value: printer.compatibilityMode,
                          onChanged: (v) async {
                            await ref.read(printQueueServiceProvider).setCompatibilityMode(v);
                            if (!mounted) return;
                            setState(() {});
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceMd),

                _StepCard(
                  title: '5) Terminal PIN',
                  subtitle: staffPin.enabled ? 'Enabled' : 'Set a PIN to lock this device',
                  complete: staffPin.enabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!staffPin.enabled)
                        AppButton(
                          label: 'Set terminal PIN',
                          onPressed: _setTerminalPin,
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _setTerminalPin,
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Change PIN'),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceLg),

                AppButton(
                  label: _setupComplete(activeTemplateAsync.asData?.value)
                      ? 'Finish setup'
                      : 'Finish setup (complete steps first)',
                  onPressed: _setupComplete(activeTemplateAsync.asData?.value)
                      ? _finishSetup
                      : null,
                ),
              ],
            ),
    );
  }
}

class _SetupHeaderCard extends StatelessWidget {
  const _SetupHeaderCard({required this.completed});
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: completed
            ? DesignTokens.success.withValues(alpha: 0.08)
            : DesignTokens.warning.withValues(alpha: 0.08),
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(
          color: completed ? DesignTokens.success : DesignTokens.warning,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.info_outline,
            color: completed ? DesignTokens.success : DesignTokens.warning,
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Text(
              completed
                  ? 'Setup completed. You can re-open this screen anytime.'
                  : 'Complete setup to ensure receipts, payments, and printing work smoothly.',
              style: DesignTokens.textSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool complete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.grayLight),
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: complete ? DesignTokens.success : DesignTokens.grayMedium,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(child: Text(title, style: DesignTokens.textBodyBold)),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            subtitle,
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          child,
        ],
      ),
    );
  }
}
