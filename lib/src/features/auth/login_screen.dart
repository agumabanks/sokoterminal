import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync/sync_service.dart';
import '../../core/util/phone_normalizer.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _secretController = TextEditingController();
  bool _obscure = true;
  String? _quickPinPhone;

  @override
  void dispose() {
    _phoneController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_primeSavedPhone);
  }

  Future<void> _primeSavedPhone() async {
    final auth = ref.read(authControllerProvider.notifier);
    final last = await auth.getLastLoginPhone();
    final quick = await auth.getQuickPinPhone();
    if (!mounted) return;
    setState(() => _quickPinPhone = quick);
    if ((_phoneController.text.trim().isEmpty) && last != null && last.isNotEmpty) {
      _phoneController.text = last;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.status == AuthStatus.loading;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.apple, size: 64, color: Colors.black), // Placeholder icon, user said "smart"
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage your business',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 48),
                  _buildModernField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_iphone_rounded,
                    inputType: TextInputType.phone,
                    autofillHints: [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      LengthLimitingTextInputFormatter(18),
                    ],
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Phone is required';
                      // We allow flexible inputs now that backend supports it
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildModernField(
                    controller: _secretController,
                    label: _hintLabel(),
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  if (auth.status == AuthStatus.error && auth.message != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        auth.message!,
                        style: TextStyle(color: Colors.red[700], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isLoading ? null : _handleLogin,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_quickPinPhone == null)
                    Text(
                      'Enter your phone number to continue.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? inputType,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7), // Apple-like light grey
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
          labelText: label,
          floatingLabelStyle: TextStyle(color: Colors.grey[800]),
          labelStyle: TextStyle(color: Colors.grey[500]),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
        validator: validator,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final rawPhone = _phoneController.text.trim();
    final phone = normalizeUgPhone(rawPhone);
    final secret = _secretController.text.trim();

    final authCtrl = ref.read(authControllerProvider.notifier);
    
    // Auto-formatting note: The UI normalizes '07...' to '256...' via normalizeUgPhone
    // The backend now supports flexible search, so this is safe.
    
    if (_shouldTreatAsPin(secret, phone)) {
      await authCtrl.loginWithQuickPin(phone: phone, pin: secret);
      final after = ref.read(authControllerProvider);
      final msg = after.message ?? '';
      final canFallback = after.status != AuthStatus.authenticated &&
          (msg.contains('not set up') || msg.contains('different phone'));
      if (canFallback) {
        await authCtrl.login(emailOrPhone: phone, password: secret);
      }
    } else {
      await authCtrl.login(emailOrPhone: phone, password: secret);
    }

    final state = ref.read(authControllerProvider);
    if (state.status == AuthStatus.authenticated) {
      if (!_shouldTreatAsPin(secret, phone)) {
        await _maybeOfferQuickPin(context, phone: phone, password: secret);
      }
      ref.read(syncServiceProvider).start();
      if (mounted) context.go('/home/checkout');
    }
  }

  String _hintLabel() {
    final phone = normalizeUgPhone(_phoneController.text);
    if (_quickPinPhone != null && _quickPinPhone == phone) {
      return 'Password or PIN';
    }
    return 'Password';
  }

  bool _shouldTreatAsPin(String secret, String normalizedPhone) {
    if (_quickPinPhone == null || _quickPinPhone!.isEmpty) return false;
    if (_quickPinPhone != normalizedPhone) return false;
    return RegExp(r'^\d{4,6}$').hasMatch(secret.trim());
  }

  Future<void> _maybeOfferQuickPin(
    BuildContext context, {
    required String phone,
    required String password,
  }) async {
    final authCtrl = ref.read(authControllerProvider.notifier);
    final existing = await authCtrl.getQuickPinPhone();
    if (existing != null && existing == phone) return;

    final pin = await _promptSetPin(context);
    if (pin == null) return;
    await authCtrl.enableQuickPin(phone: phone, password: password, pin: pin);
    if (!mounted) return;
    setState(() => _quickPinPhone = phone);
  }

  Future<String?> _promptSetPin(BuildContext context) async {
    final pinCtrl = TextEditingController();
    try {
      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set quick PIN?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use a 4–6 digit PIN to sign in faster next time on this device.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    prefixIcon: Icon(Icons.pin),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final pin = pinCtrl.text.trim();
                          if (!RegExp(r'^\\d{4,6}$').hasMatch(pin)) return;
                          Navigator.pop(context, pin);
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
    } finally {
      pinCtrl.dispose();
    }
  }
}
