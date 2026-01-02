import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync/sync_service.dart';
import '../../core/util/country_codes.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus nodes (UI only)
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  CountryCode _selectedCountry = defaultCountryCode;

  // Palette
  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF0B0B10);
  static const Color _glass = Color(0xFF101018);
  static const Color _stroke = Color(0x22FFFFFF);
  static const Color _strokeStrong = Color(0x44FFFFFF);
  static const Color _accent = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    _nameFocus.addListener(() => mounted ? setState(() {}) : null);
    _phoneFocus.addListener(() => mounted ? setState(() {}) : null);
    _passFocus.addListener(() => mounted ? setState(() {}) : null);
    _confirmFocus.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _nameFocus.dispose();
    _phoneFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.status == AuthStatus.loading;

    final bool showError = auth.status == AuthStatus.error && auth.message != null;
    final bool showSuccess = auth.status == AuthStatus.unauthenticated &&
        auth.message != null &&
        auth.message!.contains('created');

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // Base gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _bg,
                    Color(0xFF05050A),
                    _bg,
                  ],
                ),
              ),
            ),

            // Subtle glows
            Positioned(
              top: -140,
              right: -120,
              child: _GlowBlob(color: _accent.withOpacity(0.16), size: 420),
            ),
            Positioned(
              bottom: -160,
              left: -130,
              child: _GlowBlob(color: Colors.white.withOpacity(0.06), size: 520),
            ),

            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header row
                          Row(
                            children: [
                              _BackPill(onTap: () => context.go('/login')),
                              const SizedBox(width: 12),
                              Text(
                                'Create account',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.90),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),

                          Text(
                            'Create Account',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.1,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Start managing your business today.',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.60),
                              fontSize: 16,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 34),

                          _GlassField(
                            focused: _nameFocus.hasFocus,
                            child: TextFormField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              autofillHints: const [AutofillHints.name],
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              cursorColor: Colors.white,
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Full name',
                                icon: Icons.person_outline_rounded,
                              ),
                              onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Name is required';
                                if (value.trim().length < 2) return 'Name is too short';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          _buildPhoneField(),
                          const SizedBox(height: 14),

                          _GlassField(
                            focused: _passFocus.hasFocus,
                            child: TextFormField(
                              controller: _passwordController,
                              focusNode: _passFocus,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              cursorColor: Colors.white,
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  splashRadius: 18,
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white.withOpacity(0.35),
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Password is required';
                                if (value.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          _GlassField(
                            focused: _confirmFocus.hasFocus,
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmFocus,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              cursorColor: Colors.white,
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Confirm password',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  splashRadius: 18,
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white.withOpacity(0.35),
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              onFieldSubmitted: (_) => _handleRegister(isLoading: isLoading),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please confirm your password';
                                if (value != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                          ),

                          if (showError || showSuccess) ...[
                            const SizedBox(height: 18),
                            _StatusPill(
                              type: showError ? _StatusType.error : _StatusType.success,
                              message: auth.message!,
                            ),
                          ],

                          const SizedBox(height: 26),

                          _PrimaryButton(
                            text: 'Create Account',
                            isLoading: isLoading,
                            onTap: () => _handleRegister(isLoading: isLoading),
                          ),

                          const SizedBox(height: 18),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.92),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Text(
                            'By creating an account, you agree to our platform terms.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.30),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      filled: false,
      fillColor: Colors.transparent,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Icon(icon, color: Colors.white.withOpacity(0.35), size: 22),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w600),
      suffixIcon: suffix,
    );
  }

  Widget _buildPhoneField() {
    final bool focused = _phoneFocus.hasFocus;

    return _GlassField(
      focused: focused,
      child: Row(
        children: [
          InkWell(
            onTap: _showCountryPicker,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    _selectedCountry.code,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.white.withOpacity(0.82),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white.withOpacity(0.45)),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 26, color: Colors.white.withOpacity(0.10)),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberLocal],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              textInputAction: TextInputAction.next,
              cursorColor: Colors.white,
              style: TextStyle(
                fontSize: 17,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                filled: false,
                fillColor: Colors.transparent,
                labelText: 'Phone number',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontWeight: FontWeight.w500),
                floatingLabelStyle:
                    TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w600),
                hintText: '706272481',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.18)),
              ),
              onFieldSubmitted: (_) => _passFocus.requestFocus(),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Phone is required';
                if (v.length < 9) return 'Invalid phone number';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCountryPicker() async {
    final selected = await showCountryPickerBottomSheet(context, _selectedCountry);
    if (selected != null) {
      setState(() => _selectedCountry = selected);
    }
  }

  Future<void> _handleRegister({required bool isLoading}) async {
    if (isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final normalized = normalizePhoneWithCountry(rawPhone, _selectedCountry);
    final password = _passwordController.text;

    final authCtrl = ref.read(authControllerProvider.notifier);
    await authCtrl.register(name: name, phone: normalized, pin: password);

    final state = ref.read(authControllerProvider);
    if (!mounted) return;

    if (state.status == AuthStatus.authenticated) {
      if (mounted) context.go('/onboarding');
    }
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B10).withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white.withOpacity(0.85)),
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({required this.child, required this.focused});

  final Widget child;
  final bool focused;

  static const Color _glass = Color(0xFF101018);
  static const Color _stroke = Color(0x22FFFFFF);
  static const Color _strokeStrong = Color(0x44FFFFFF);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _glass.withOpacity(0.62),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: focused ? _strokeStrong : _stroke, width: 1),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );
  }
}

enum _StatusType { error, success }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.type, required this.message});

  final _StatusType type;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color tint = type == _StatusType.error ? const Color(0xFFFF453A) : const Color(0xFF34C759);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tint.withOpacity(0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tint.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(
                type == _StatusType.error ? Icons.error_outline : Icons.check_circle_outline,
                color: tint.withOpacity(0.95),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.text, required this.isLoading, required this.onTap});

  final String text;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.10), blurRadius: 30, offset: const Offset(0, 14)),
              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 16)),
            ],
          ),
          child: widget.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                )
              : Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
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
          BoxShadow(color: color.withOpacity(0.55), blurRadius: 120, spreadRadius: 30),
        ],
      ),
    );
  }
}
