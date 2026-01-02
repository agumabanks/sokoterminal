import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_controller.dart';

class PaymentConfigScreen extends ConsumerStatefulWidget {
  const PaymentConfigScreen({super.key});

  @override
  ConsumerState<PaymentConfigScreen> createState() => _PaymentConfigScreenState();
}

class _PaymentConfigScreenState extends ConsumerState<PaymentConfigScreen> {
  bool _cashOnDelivery = true;
  bool _bankTransfer = false;
  final _shippingCostController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _applyOnboardingState(ref.read(onboardingControllerProvider));
    ref.listen<OnboardingState>(onboardingControllerProvider, (_, next) {
      _applyOnboardingState(next, notify: true);
    });
  }

  @override
  void dispose() {
    _shippingCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => context.go('/onboarding/business-details'),
        ),
        title: const Text(
          'Payment & Delivery',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(4, 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'How Do You Get Paid?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set up payment and delivery options',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPaymentToggle(
                      title: 'Cash on Delivery',
                      subtitle: 'Collect payment when delivering',
                      icon: Icons.local_shipping_outlined,
                      value: _cashOnDelivery,
                      onChanged: (val) => setState(() => _cashOnDelivery = val),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildPaymentToggle(
                      title: 'Bank Transfer',
                      subtitle: 'Receive payments via bank',
                      icon: Icons.account_balance_outlined,
                      value: _bankTransfer,
                      onChanged: (val) => setState(() => _bankTransfer = val),
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      'Delivery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildModernField(
                      controller: _shippingCostController,
                      label: 'Default Shipping Cost',
                      icon: Icons.delivery_dining_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This can be customized per product later',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 32),
                    
                    // Continue Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _handleContinue,
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextButton(
                      onPressed: () => context.go('/onboarding/welcome'),
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int current, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step $current of $total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${((current / total) * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
        border: value ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: value ? Colors.black : Colors.grey[500]),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        activeColor: Colors.black,
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
          labelText: label,
          hintText: hint,
          floatingLabelStyle: TextStyle(color: Colors.grey[800]),
          labelStyle: TextStyle(color: Colors.grey[500]),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }

  void _applyOnboardingState(OnboardingState onboarding, {bool notify = false}) {
    final data = onboarding.shopData;
    if (data.isEmpty) return;

    bool changed = false;
    final cashEnabled = _asBool(data['cash_on_delivery_status']);
    if (cashEnabled != null && cashEnabled != _cashOnDelivery) {
      _cashOnDelivery = cashEnabled;
      changed = true;
    }

    final bankEnabled = _asBool(data['bank_payment_status']);
    if (bankEnabled != null && bankEnabled != _bankTransfer) {
      _bankTransfer = bankEnabled;
      changed = true;
    }

    final shippingCost = _asDouble(data['shipping_cost']);
    if (shippingCost != null) {
      final current = double.tryParse(_shippingCostController.text.trim());
      if (current == null || (current == 0 && shippingCost != 0)) {
        _shippingCostController.text = shippingCost.toStringAsFixed(0);
      }
    }

    if (changed && notify && mounted) {
      setState(() {});
    }
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
      if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _handleContinue() {
    if (!_cashOnDelivery && !_bankTransfer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one payment method')),
      );
      return;
    }

    final shippingCost = double.tryParse(_shippingCostController.text);
    if (shippingCost != null && shippingCost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipping cost cannot be negative')),
      );
      return;
    }

    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.updateShopData({
      'cash_on_delivery_status': _cashOnDelivery ? 1 : 0,
      'bank_payment_status': _bankTransfer ? 1 : 0,
      'shipping_cost': shippingCost ?? 0,
    });
    controller.goToStage(5);
    
    context.go('/onboarding/welcome');
  }
}
