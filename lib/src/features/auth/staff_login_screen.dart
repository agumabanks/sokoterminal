import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_staff_prefs.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/phone_normalizer.dart';
import 'auth_controller.dart';

class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _phoneFocus = FocusNode();
  final _pinFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color _bg = Color(0xFF000000);
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _surface = Color(0xFF0B0B10);
  static const Color _stroke = Color(0x22FFFFFF);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );
    _fadeController.forward();

    _phoneFocus.addListener(() => mounted ? setState(() {}) : null);
    _pinFocus.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _phoneFocus.dispose();
    _pinFocus.dispose();
    _fadeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
    if (mounted) setState(() {});
  }

  Future<void> _handleStaffLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cooldownSeconds > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = normalizeUgPhone(_phoneController.text.trim());
      final pin = _pinController.text.trim();

      if (phone.isEmpty) {
        throw Exception('Invalid phone number');
      }

      // Get dependencies
      final sellerApi = ref.read(sellerApiProvider);
      final secureStorage = ref.read(secureStorageProvider);
      final db = ref.read(appDatabaseProvider);

      // Call staff login API
      final response = await sellerApi.staffLogin(phone: phone, pin: pin);

      if (response.data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server');
      }

      final data = response.data as Map<String, dynamic>;
      final token = data['token']?.toString();
      final staff = data['staff'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['staff'] as Map<String, dynamic>)
          : null;
      final shopId = staff?['shop_id']?.toString();

      if (token == null || shopId == null) {
        throw Exception('Missing token or shop_id in response');
      }

      // Get current shop_id to check if switching
      final currentShopId = await secureStorage.read(key: 'staff_shop_id');
      final isShopSwitch = currentShopId != null && currentShopId != shopId;

      if (isShopSwitch) {
        // Clear local database when switching shops
        await _clearLocalDatabase(db);
        // Reset staff initialization flag so splash re-runs staff setup flow
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.remove(posStaffInitializedPrefKey);
      }

      // Store authentication data
      await secureStorage.writeAccessToken(token);
      await ref.read(authControllerProvider.notifier).bootstrap();
      await secureStorage.write(key: 'staff_shop_id', value: shopId);
      await secureStorage.write(
        key: 'staff_id',
        value: staff?['id']?.toString() ?? '',
      );
      await secureStorage.write(
        key: 'staff_name',
        value: staff?['name']?.toString() ?? '',
      );
      await secureStorage.write(key: 'staff_phone', value: phone);
      await secureStorage.write(key: 'login_type', value: 'staff');

      if (!mounted) return;

      // Navigate to home
      if (!mounted) return;
      _failedAttempts = 0;
      context.go('/home/checkout');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startCooldown();
        }
      }
    }
  }

  Future<void> _clearLocalDatabase(AppDatabase db) async {
    // Clear all shop-specific data
    await db.transaction(() async {
      await db.delete(db.items).go();
      await db.delete(db.itemStocks).go();
      await db.delete(db.services).go();
      await db.delete(db.serviceVariants).go();
      await db.delete(db.customers).go();
      await db.delete(db.quotations).go();
      await db.delete(db.quotationLines).go();
      await db.delete(db.ledgerEntries).go();
      await db.delete(db.ledgerLines).go();
      await db.delete(db.payments).go();
      await db.delete(db.shifts).go();
      await db.delete(db.cashMovements).go();
      await db.delete(db.expenses).go();
      await db.delete(db.syncOps).go();
      await db.delete(db.staff).go();
      await db.delete(db.roles).go();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // Base gradient (subtle)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_bg, Color(0xFF05050A), _bg],
                ),
              ),
            ),

            // Accent glow (soft, minimal)
            Positioned(
              top: -140,
              right: -120,
              child: _GlowBlob(color: _accent.withOpacity(0.16), size: 420),
            ),
            Positioned(
              bottom: -160,
              left: -130,
              child: _GlowBlob(
                color: Colors.white.withOpacity(0.06),
                size: 520,
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Form(
                            key: _formKey,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Staff Sign In',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 42,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -1.2,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Enter your phone and 6-digit PIN',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.62),
                                      fontSize: 16,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 44),
                                  _buildPhoneField(),
                                  const SizedBox(height: 20),
                                  _buildPinField(),
                                  const SizedBox(height: 32),
                                  _GradientButton(
                                    text: _cooldownSeconds > 0
                                        ? 'Wait $_cooldownSeconds s'
                                        : 'Login',
                                    isLoading:
                                        _isLoading || _cooldownSeconds > 0,
                                    onTap: _handleStaffLogin,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error pill
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _errorMessage == null
                    ? const SizedBox.shrink()
                    : _buildErrorSnack(key: ValueKey(_errorMessage)),
              ),
            ),

            // Back to Owner Login
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    'Back to Owner Login',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withOpacity(0.3),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _surface.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Sign in',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    final bool focused = _phoneFocus.hasFocus;

    return _GlassField(
      focused: focused,
      child: TextFormField(
        focusNode: _phoneFocus,
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: GoogleFonts.inter(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 18,
          ),
          filled: false,
          fillColor: Colors.transparent,
          hintText: 'Phone number',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.28),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.phone,
            color: Colors.white70,
            size: 20,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your phone number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPinField() {
    final bool focused = _pinFocus.hasFocus;

    return _GlassField(
      focused: focused,
      child: TextFormField(
        focusNode: _pinFocus,
        controller: _pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        style: GoogleFonts.inter(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 18,
          ),
          filled: false,
          fillColor: Colors.transparent,
          hintText: '6-Digit PIN',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.28),
            fontWeight: FontWeight.w500,
          ),
          counterText: '',
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: Colors.white70,
            size: 20,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your PIN';
          }
          if (value.length != 6) {
            return 'PIN must be 6 digits';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildErrorSnack({Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF453A).withOpacity(0.86),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _errorMessage = null),
                child: const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted field container (Apple-like restraint)
class _GlassField extends StatelessWidget {
  const _GlassField({required this.child, required this.focused});

  final Widget child;
  final bool focused;

  static const Color _solidBg = Color(0xFF1A1A24);
  static const Color _stroke = Color(0x33FFFFFF);
  static const Color _strokeFocused = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _solidBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? _strokeFocused : _stroke,
          width: focused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Soft background glow blob
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
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 120,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.text,
    this.isLoading = false,
    required this.onTap,
  });

  final String text;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.isLoading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: disabled
          ? null
          : () {
              setState(() => _pressed = false);
              widget.onTap();
            },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: disabled ? 0.9 : 1.0,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: DesignTokens.accentGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.brandAccent.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    widget.text,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
